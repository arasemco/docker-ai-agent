// =============================================================================
// docker-bake.hcl — build definition for the agent-base image
// =============================================================================
//
// Usage (via bake.sh, which resolves GIT_SHA/GIT_REF):
//   bash bake.sh --print            # resolve and print the config, no build
//   bash bake.sh                    # build the "default" group (agent-base)
//   bash bake.sh agent-base-dev     # build the :dev tag
//   bash bake.sh test               # build + run the in-image test stage
//   bash bake.sh --push             # build and push
//
// HCL cannot read git or CI context, so bake.sh computes GIT_SHA/GIT_REF and
// exports them: an env var overrides a `variable` block's default whenever
// the names match. The defaults below only serve a bare, no-args build.

// Where images get pushed, and where THESE packaging files live (not the
// upstream project — upstream doesn't own this Dockerfile).
variable "REGISTRY"   { default = "git.omesa.net/asemo" }
variable "SOURCE_URL" { default = "https://git.omesa.net/asemo/agent-base" }

// agent-base's own version, independent of the CLIs installed on top of it.
// Child images pin the base by this tag (or by digest, which is stronger).
variable "BASE_VERSION" { default = "1.0.0" }

// The unprivileged user the image runs. Children override AGENT_USER to their
// own tool name (claude/opencode/dsh) and rebuild with the same uid/gid.
variable "AGENT_USER" { default = "agent" }
variable "AGENT_UID"  { default = "1000" }
variable "AGENT_GID"  { default = "1000" }

// Pinned tool versions. DOCKER_VERSION is the in-container rootless engine;
// list candidates with `apt-cache madison docker-ce` inside the base image.
variable "DOCKER_VERSION" { default = "29.8.1" }
variable "YQ_VERSION"     { default = "4.54.1" }
variable "UV_VERSION"     { default = "0.13.6" }

// Frozen build inputs, pinned by digest where possible: a floating tag can be
// repointed upstream at any time, digests cannot. NODE_BASE must stay a glibc
// base (see the Dockerfile header). To bump:
//   docker buildx imagetools inspect node:22-bookworm-slim
// and update both this digest and the Dockerfile's NODE_REF default.
variable "NODE_BASE" {
  default = {
    name   = "docker.io/library/node"
    tag    = "22-bookworm-slim"
    digest = "sha256:4b150b48b4116e2a22f2c39cc27025fbf4f153e2078fd3b14d159fdb5c7279da"
  }
}

function "pinned_ref" {
  params = [base]
  result = "${base.name}:${base.tag}@${base.digest}"
}

variable "GIT_SHA" { default = "unknown" }
variable "GIT_REF" { default = "unknown" }

// Comma-separated so an env var can override it: PLATFORMS=linux/amd64,linux/arm64.
variable "PLATFORMS" { default = "linux/amd64" }

variable "PROVENANCE_METADATA" {
  default = {
    authors  = "Aram SEMO <aram.semo@asemo.pro>"
    vendor   = "asemo.pro"
    licenses = "MIT"
  }
}

// Pure OCI-standard labels (no product-specific keys: this image is not one
// product, it is the shared base for several).
function "oci_labels" {
  params = [title, description, version, base]
  result = {
    "org.opencontainers.image.created"       = timestamp()
    "org.opencontainers.image.authors"       = PROVENANCE_METADATA.authors
    "org.opencontainers.image.url"           = SOURCE_URL
    "org.opencontainers.image.documentation" = "${SOURCE_URL}/blob/${GIT_SHA != "unknown" ? GIT_SHA : "main"}/README.md"
    "org.opencontainers.image.source"        = SOURCE_URL
    "org.opencontainers.image.version"       = version
    "org.opencontainers.image.revision"      = GIT_SHA
    "org.opencontainers.image.vendor"        = PROVENANCE_METADATA.vendor
    "org.opencontainers.image.licenses"      = PROVENANCE_METADATA.licenses
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
  context    = "."
  dockerfile = "Dockerfile"
  // Never the last stage: "test" comes after and must not be pushed.
  target     = "agent-base"
  pull       = true

  args = {
    NODE_REF       = pinned_ref(NODE_BASE)
    AGENT_USER     = AGENT_USER
    AGENT_UID      = AGENT_UID
    AGENT_GID      = AGENT_GID
    DOCKER_VERSION = DOCKER_VERSION
    YQ_VERSION     = YQ_VERSION
    UV_VERSION     = UV_VERSION
  }

  tags = [
    "${REGISTRY}/agent-base:latest",
    "${REGISTRY}/agent-base:${BASE_VERSION}",
  ]

  labels = oci_labels(
    "agent-base",
    "Shared sandbox base for AI coding-agent CLIs: Debian + Node 22, unprivileged agent user, rootless Docker, Python/uv, dev toolchain",
    BASE_VERSION,
    NODE_BASE,
  )

  platforms = split(",", PLATFORMS)
}

// Mutable tag for local development; not in the default group.
target "agent-base-dev" {
  inherits = ["agent-base"]
  tags     = ["${REGISTRY}/agent-base:dev"]
}

// Builds the image plus the "test" stage: shellcheck on the entrypoint
// scripts and a tool-matrix selftest, all at build time (no daemon needed).
// Not in the default group and exports nothing.
target "test" {
  inherits = ["agent-base"]
  target   = "test"
  tags     = []
  output   = ["type=cacheonly"]
}
