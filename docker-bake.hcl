// =============================================================================
// docker-bake.hcl — build definition for the dsh image
// =============================================================================
//
// Usage (through scripts/bake.sh, which fills the provenance variables):
//   scripts/bake.sh --print
//   scripts/bake.sh                 # build the "default" group (runtime image)
//   scripts/bake.sh --push          # needs REGISTRY, derived from the remote
//   scripts/bake.sh test            # build + verify a real API key (see below)
//
// The image is built FROM agent-base, which this repository does not build. Pin
// the base tag in AGENT_BASE and bump it deliberately.
// =============================================================================

// Image repository prefix, without a trailing slash. Empty means plain local
// tags ("dsh:1.0.0"); scripts/bake.sh derives it from the git remote, and an
// environment variable overrides both.
variable "REGISTRY" { default = "" }

// Optional provenance metadata, filled in by scripts/bake.sh. Anything unset
// renders as "unknown" in the OCI labels.
variable "SOURCE_URL" { default = "" }
variable "AUTHOR"     { default = "" }
variable "VENDOR"     { default = "" }
variable "LICENSES"   { default = "" }

// Tag applied to the built images.
variable "TAG" { default = "latest" }

// The shared base image, by tag: never :latest, so a rebuild is reproducible.
variable "AGENT_BASE" { default = "agent-base:1.4.1" }

// Exact @deepseek-ai/dsh version (`npm view @deepseek-ai/dsh versions`). Pin an
// exact version, not a dist-tag: upstream warns of breaking changes between
// releases.
variable "DSH_VERSION" { default = "0.2.1-rc.5" }

// Official Node 22 image, pinned by digest. Only its node binary and npm are
// copied into the runtime image; it is the same glibc distribution as the base.
variable "NODE_REF" {
  default = "docker.io/library/node:22-bookworm-slim@sha256:4b150b48b4116e2a22f2c39cc27025fbf4f153e2078fd3b14d159fdb5c7279da"
}

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
  targets = ["dsh"]
}

target "dsh" {
  // The build context is image/ only; compose files, docs and scripts are host
  // tooling.
  context    = "image"
  dockerfile = "Dockerfile"
  // The Dockerfile's last stage is "test" (it needs a BuildKit secret); the
  // pushed image must be "runtime".
  target     = "runtime"

  args = {
    AGENT_BASE  = AGENT_BASE
    DSH_VERSION = DSH_VERSION
    NODE_REF    = NODE_REF
  }

  tags = [
    image_ref("dsh", TAG),
    image_ref("dsh", DSH_VERSION),
  ]

  labels = oci_labels(
    "dsh",
    "DeepSeek Harness (dsh) Web UI on agent-base: Node 22 from the official image, s6-supervised rootless Docker, loopback-only UI",
    DSH_VERSION,
  )

  platforms = split(",", PLATFORMS)
}

// Mutable tag for local development; not in the default group.
target "dsh-dev" {
  inherits = ["dsh"]
  tags     = [image_ref("dsh", "dev")]
}

// Where the "test" target reads dsh's credentials file from: the
// $DSH_HOME/.credentials.yaml the running container writes (Settings -> Models).
// `make test` supplies a copy when this path does not exist.
variable "DSH_CREDENTIALS" { default = "data/dsh-home/.credentials.yaml" }

// Builds the runtime image plus the "test" stage, which loads that credentials
// file as a BuildKit secret and checks it against the real API and a real dsh
// headless run. Not in the default group (CI has no key) and exports nothing;
// no-cache-filter re-runs the check every time, because BuildKit does not use
// secret contents in the cache key, so a revoked key would otherwise keep
// passing from cache.
target "test" {
  inherits        = ["dsh"]
  target          = "test"
  tags            = []
  output          = ["type=cacheonly"]
  secret          = ["type=file,id=dsh_credentials,src=${DSH_CREDENTIALS}"]
  no-cache-filter = ["test"]
}
