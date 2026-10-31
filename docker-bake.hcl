// =============================================================================
// docker-bake.hcl — build definition for the OpenCode image
// =============================================================================
//
// Usage (via bake.sh, which resolves GIT_SHA/GIT_REF for the OCI labels):
//   bash bake.sh --print    # resolve and print the config, no build
//   bash bake.sh            # build the "default" group (opencode)
//   bash bake.sh --push     # build and push
//
// The image is built FROM agent-base, which is not built here — it has its own
// repo/targets. Pin the base tag in AGENT_BASE and bump it deliberately.

variable "REGISTRY"   { default = "git.omesa.net/asemo" }
variable "SOURCE_URL" { default = "https://git.omesa.net/asemo/opencode" }
variable "TAG"        { default = "latest" }

// The shared base image, by tag (agent-base also publishes :latest; pin the
// version so a rebuild cannot silently pick up a new base).
variable "AGENT_BASE" { default = "git.omesa.net/asemo/agent-base:1.1.0" }

// Exact opencode-ai version from npm (`npm view opencode-ai versions`).
variable "OPENCODE_VERSION" { default = "1.19.5" }

variable "GIT_SHA" { default = "unknown" }
variable "GIT_REF" { default = "unknown" }

// Comma-separated so PLATFORMS=linux/amd64,linux/arm64 can override it.
variable "PLATFORMS" { default = "linux/amd64" }

variable "PROVENANCE_METADATA" {
  default = {
    authors  = "Aram SEMO <aram.semo@asemo.pro>"
    vendor   = "asemo.pro"
    licenses = "MIT"
  }
}

function "oci_labels" {
  params = [title, description, version]
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
    "org.opencontainers.image.base.name"     = AGENT_BASE
  }
}

group "default" {
  targets = ["opencode"]
}

target "opencode" {
  context    = "."
  dockerfile = "Dockerfile"
  args = {
    AGENT_BASE       = AGENT_BASE
    OPENCODE_VERSION = OPENCODE_VERSION
  }
  tags = [
    "${REGISTRY}/opencode:${TAG}",
    "${REGISTRY}/opencode:${OPENCODE_VERSION}",
  ]
  labels = oci_labels(
    "opencode",
    "OpenCode CLI/Web UI on agent-base: rootless Docker sandbox, Ollama provider, persistent state",
    OPENCODE_VERSION,
  )
  platforms = split(",", PLATFORMS)
}

// Mutable tag for local development; not in the default group.
target "opencode-dev" {
  inherits = ["opencode"]
  tags     = ["${REGISTRY}/opencode:dev"]
}
