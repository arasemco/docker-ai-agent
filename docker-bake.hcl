// =============================================================================
// docker-bake.hcl — build definition for the agent-base image
// =============================================================================
//
// Usage (through scripts/bake.sh, which also fills the provenance variables):
//   scripts/bake.sh --print        # resolve and print the config, no build
//   scripts/bake.sh                # build the "default" group
//   scripts/bake.sh --push         # build and push
//   scripts/bake.sh test           # build + run the in-image test stage
//
// Every variable has a neutral default: no registry, no author, no source URL.
// Set one through the environment (an env var overrides a `variable` block's
// default when the names match) or with `scripts/bake.sh --set REGISTRY=...`.
//
// HCL cannot read git or CI context, so scripts/bake.sh computes GIT_SHA,
// GIT_REF and the rest and exports them before invoking bake.
// =============================================================================

// Image repository prefix, without a trailing slash, e.g.
// "ghcr.io/youruser" or "registry.example:5000/team". Empty means plain local
// tags ("agent-base:1.2.0"), which is what an unconfigured clone gets.
variable "REGISTRY" { default = "" }

// Where this packaging lives and who publishes it. All optional: the OCI
// labels fall back to "unknown" when unset, so nothing here assumes a
// particular owner.
variable "SOURCE_URL" { default = "" }
variable "AUTHOR"     { default = "" }
variable "VENDOR"     { default = "" }
// Empty by default: the licence belongs to whoever owns the repository.
// scripts/bake.sh fills it from the LICENSE file when one exists.
variable "LICENSES" { default = "" }

// agent-base's own version, independent of any CLI installed on top of it.
// Child images pin the base by this tag (or by digest, which is stronger).
variable "BASE_VERSION" { default = "1.2.0" }

// The unprivileged user the image runs. Children normally keep "agent" — one
// home path shared by every stack — and only rename it when they must.
variable "AGENT_USER" { default = "agent" }
variable "AGENT_UID"  { default = "1000" }
variable "AGENT_GID"  { default = "1000" }

// Pinned tool versions. DOCKER_VERSION is the in-container rootless engine;
// list candidates with `apt-cache madison docker-ce` inside the base image.
variable "DOCKER_VERSION" { default = "29.8.1" }
// uv (Python toolchain) from PyPI; Debian does not package it.
variable "UV_VERSION" { default = "0.13.6" }

// s6-overlay release, pinned rather than tracked as "latest". The per-arch
// sha256 digests live in image/Dockerfile next to the download, because both
// tarballs are verified there; bump the two together.
variable "S6_OVERLAY_VERSION" { default = "3.2.3.0" }

// Frozen build input, pinned by digest: a floating tag can be repointed
// upstream at any time, digests cannot. Must stay a glibc base (several agent
// CLIs ship glibc-only native builds). To bump:
//   docker buildx imagetools inspect debian:bookworm-slim
// and update both this digest and image/Dockerfile's DEBIAN_REF default.
// Node/npm come from Debian's own packages, not from the base image.
variable "DEBIAN_BASE" {
  default = {
    name   = "docker.io/library/debian"
    tag    = "bookworm-slim"
    digest = "sha256:99c0b25c46d0214d5a2091092e7908907dcaecd6a962cde0ac700acee222b6f3"
  }
}

function "pinned_ref" {
  params = [base]
  result = "${base.name}:${base.tag}@${base.digest}"
}

// Tag with the registry prefix when one is configured, plain name otherwise.
function "image_ref" {
  params = [name, tag]
  result = REGISTRY == "" ? "${name}:${tag}" : "${REGISTRY}/${name}:${tag}"
}

variable "GIT_SHA" { default = "unknown" }
variable "GIT_REF" { default = "unknown" }

// Comma-separated so PLATFORMS=linux/amd64,linux/arm64 can override it.
variable "PLATFORMS" { default = "linux/amd64" }

// Pure OCI-standard labels. Optional metadata renders as "unknown" instead of
// assuming an owner for the image.
function "oci_labels" {
  params = [title, description, version, base]
  result = {
    "org.opencontainers.image.created"       = timestamp()
    "org.opencontainers.image.authors"       = AUTHOR != "" ? AUTHOR : "unknown"
    "org.opencontainers.image.url"           = SOURCE_URL != "" ? SOURCE_URL : "unknown"
    "org.opencontainers.image.documentation" = SOURCE_URL != "" ? "${SOURCE_URL}/blob/${GIT_SHA != "unknown" ? GIT_SHA : "main"}/README.md" : "unknown"
    "org.opencontainers.image.source"        = SOURCE_URL != "" ? SOURCE_URL : "unknown"
    "org.opencontainers.image.version"       = version
    "org.opencontainers.image.revision"      = GIT_SHA
    "org.opencontainers.image.vendor"        = VENDOR != "" ? VENDOR : "unknown"
    "org.opencontainers.image.licenses"      = LICENSES != "" ? LICENSES : "unknown"
    "org.opencontainers.image.ref.name"      = GIT_REF
    "org.opencontainers.image.title"         = title
    "org.opencontainers.image.description"   = description
    "org.opencontainers.image.base.name"     = "${base.name}:${base.tag}"
    "org.opencontainers.image.base.digest"   = base.digest
  }
}

group "default" {
  targets = ["agent-base"]
}

target "agent-base" {
  // The build context is image/ only: Dockerfile plus rootfs/. Compose files,
  // examples and scripts are host tooling and stay out of the image.
  context    = "image"
  dockerfile = "Dockerfile"
  // Never the last stage: "test" comes after and must not be pushed.
  target     = "agent-base"
  pull       = true

  args = {
    DEBIAN_REF         = pinned_ref(DEBIAN_BASE)
    AGENT_USER         = AGENT_USER
    AGENT_UID          = AGENT_UID
    AGENT_GID          = AGENT_GID
    DOCKER_VERSION     = DOCKER_VERSION
    UV_VERSION         = UV_VERSION
    S6_OVERLAY_VERSION = S6_OVERLAY_VERSION
  }

  tags = [
    image_ref("agent-base", "latest"),
    image_ref("agent-base", BASE_VERSION),
  ]

  labels = oci_labels(
    "agent-base",
    "Shared sandbox base for AI coding-agent CLIs: Debian 12, s6-supervised rootless Docker and agent service, unprivileged user, Python/uv, dev toolchain",
    BASE_VERSION,
    DEBIAN_BASE,
  )

  platforms = split(",", PLATFORMS)
}

// Mutable tag for local development; not in the default group.
target "agent-base-dev" {
  inherits = ["agent-base"]
  tags     = [image_ref("agent-base", "dev")]
}

// Builds the image plus the "test" stage: shellcheck on every script plus a
// tool-matrix selftest, all at build time (no daemon needed). Not in the
// default group and exports nothing.
target "test" {
  inherits = ["agent-base"]
  target   = "test"
  tags     = []
  output   = ["type=cacheonly"]
}
