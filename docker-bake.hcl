// =============================================================================
// docker-bake.hcl — build definition for the OpenCode image
// =============================================================================
//
// Usage (via scripts/bake.sh, which derives the provenance variables — see its
// header, or the README's "Publishing"):
//   scripts/bake.sh --print
//   scripts/bake.sh            # build the "default" group
//   scripts/bake.sh --push     # needs REGISTRY, derived from the git remote
//   scripts/bake.sh --set OPENCODE_VERSION=1.19.6
//
// The image is built FROM agent-base, which this repo does not build. Pin the
// base tag in AGENT_BASE and bump it deliberately.

// Image repository prefix, without a trailing slash. Empty means plain local
// tags ("opencode:1.19.5"); scripts/bake.sh derives it from the git remote and
// an environment variable overrides both.
variable "REGISTRY" { default = "" }

// Optional provenance metadata; scripts/bake.sh fills it in, and anything that
// stays unset renders as "unknown" in the OCI labels.
variable "SOURCE_URL" { default = "" }
variable "AUTHOR"     { default = "" }
variable "VENDOR"     { default = "" }
variable "LICENSES"   { default = "MIT" }

// The shared base image, by tag (never :latest — a rebuild must be
// reproducible). Point this at a registry to use a pushed agent-base.
variable "AGENT_BASE" { default = "agent-base:1.2.0" }

// Exact opencode-ai version from npm (`npm view opencode-ai versions`).
variable "OPENCODE_VERSION" { default = "1.19.5" }

variable "GIT_SHA" { default = "unknown" }
variable "GIT_REF" { default = "unknown" }

// Comma-separated so PLATFORMS=linux/amd64,linux/arm64 can override it.
variable "PLATFORMS" { default = "linux/amd64" }

// Tag with the registry prefix when one is configured, plain name otherwise.
function "image_ref" {
  params = [name, tag]
  result = REGISTRY == "" ? "${name}:${tag}" : "${REGISTRY}/${name}:${tag}"
}

function "oci_labels" {
  params = [title, description, version]
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
    "org.opencontainers.image.base.name"     = AGENT_BASE
  }
}

group "default" {
  targets = ["opencode"]
}

target "opencode" {
  // The build context is image/ only (Dockerfile). Compose files, examples and
  // scripts are host tooling.
  context    = "image"
  dockerfile = "Dockerfile"

  args = {
    AGENT_BASE       = AGENT_BASE
    OPENCODE_VERSION = OPENCODE_VERSION
  }

  tags = [
    image_ref("opencode", "latest"),
    image_ref("opencode", OPENCODE_VERSION),
  ]

  labels = oci_labels(
    "opencode",
    "OpenCode CLI/Web UI on agent-base: s6-supervised sandbox, rootless Docker, persistent state",
    OPENCODE_VERSION,
  )

  platforms = split(",", PLATFORMS)
}

// Mutable tag for local development; not in the default group.
target "opencode-dev" {
  inherits = ["opencode"]
  tags     = [image_ref("opencode", "dev")]
}
