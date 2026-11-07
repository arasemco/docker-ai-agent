// =============================================================================
// docker-bake.hcl — build definition for the base image and every stack
// =============================================================================
//
// Usage (through scripts/bake.sh, which fills the provenance variables):
//   scripts/bake.sh --print          # resolved config, no build
//   scripts/bake.sh                  # default group: the base image only
//   scripts/bake.sh opencode         # one stack (needs the base image)
//   scripts/bake.sh all              # base + every stack, in order
//   scripts/bake.sh --push           # needs REGISTRY, derived from the remote
//
// Stack targets build FROM the base image. `scripts/bake.sh all` builds the base
// first and then each stack against it; the stack build args point at the same
// tag, so a single run produces a consistent set.
// =============================================================================

// Image repository prefix, without a trailing slash. Empty means plain local
// tags; scripts/bake.sh derives it from the git remote and an environment
// variable overrides both.
variable "REGISTRY" { default = "" }

// Optional provenance metadata, filled in by scripts/bake.sh. Unset values
// render as "unknown" in the OCI labels.
variable "SOURCE_URL" { default = "" }
variable "AUTHOR"     { default = "" }
variable "VENDOR"     { default = "" }
variable "LICENSES"   { default = "" }

// The base image's own version. Stacks pin this tag, so bump it whenever
// anything under image/ changes.
variable "BASE_VERSION" { default = "1.5.0" }

// Tag applied in addition to the version tag, for every target.
variable "TAG" { default = "latest" }

// The unprivileged user the base image runs.
variable "AGENT_USER" { default = "agent" }
variable "AGENT_UID"  { default = "1000" }
variable "AGENT_GID"  { default = "1000" }

// Pinned tool versions for the base image.
variable "DOCKER_VERSION"     { default = "29.8.1" }
variable "UV_VERSION"         { default = "0.13.6" }
variable "S6_OVERLAY_VERSION" { default = "3.2.3.0" }

// Frozen build input, pinned by digest. To bump:
//   docker buildx imagetools inspect debian:bookworm-slim
// and update both this digest and image/Dockerfile's DEBIAN_REF default.
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

// Build layers are cached in the registry as <REGISTRY>/agent-base:buildcache
// and always read from it (a failed read is a cache miss). Writing needs push
// rights, so it is off unless CACHE_WRITE=true — CI sets it on push and tag
// runs and leaves pull requests read-only.
variable "CACHE_WRITE" {
  type    = bool
  default = false
}

// Reading the registry cache is also off by default: until the cache tag has
// been written once it only produces a "cache importer ... not found" line on
// every local build. CI turns it on where the cache actually exists.
variable "CACHE_READ" {
  type    = bool
  default = false
}

// ---------------------------------------------------------------------------
// Stack pins
// ---------------------------------------------------------------------------
// Exact versions, never dist-tags: a rebuild must be reproducible.

variable "OPENCODE_VERSION" { default = "1.19.5" }

variable "DSH_VERSION" { default = "0.2.2-rc.1" }

variable "CLAUDE_VERSION" { default = "2.1.316" }

// Official Node 22 image, pinned by digest; the dsh and claude stacks copy its
// node and npm because the base image ships Debian's Node 18.
variable "NODE_REF" {
  default = "docker.io/library/node:22-bookworm-slim@sha256:4b150b48b4116e2a22f2c39cc27025fbf4f153e2078fd3b14d159fdb5c7279da"
}

// Where the dsh "test" target reads $DSH_HOME/.credentials.yaml from.
variable "DSH_CREDENTIALS" { default = "data/dsh-home/.credentials.yaml" }

// ---------------------------------------------------------------------------
// Labels
// ---------------------------------------------------------------------------
function "oci_labels" {
  params = [title, description, version, base_name]
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
    "org.opencontainers.image.base.name"     = base_name
  }
}

// The base image's own tags, reused by the stack build args so one run produces
// a consistent set.
variable "AGENT_BASE" {
  default = image_ref("agent-base", BASE_VERSION)
}

group "default" {
  targets = ["agent-base"]
}

// Every image in the repository, base first.
group "all" {
  targets = ["agent-base", "opencode", "dsh", "claude"]
}

// ---------------------------------------------------------------------------
// agent-base
// ---------------------------------------------------------------------------
target "agent-base" {
  // The build context is image/ only: Dockerfile plus rootfs/.
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

  // Registry cache: no dependency on a CI-specific cache service, so the same
  // build definition works on GitHub Actions, Gitea Actions and a laptop.
  cache-from = CACHE_READ && REGISTRY != "" ? ["type=registry,ref=${REGISTRY}/agent-base:buildcache"] : []
  cache-to   = CACHE_WRITE && REGISTRY != "" ? ["type=registry,ref=${REGISTRY}/agent-base:buildcache,mode=max"] : []

  tags = [
    image_ref("agent-base", TAG),
    image_ref("agent-base", BASE_VERSION),
  ]

  labels = oci_labels(
    "agent-base",
    "Shared sandbox base for AI coding-agent CLIs: Debian 12, s6-supervised rootless Docker and agent service, unprivileged user, Python/uv, dev toolchain",
    BASE_VERSION,
    "${DEBIAN_BASE.name}:${DEBIAN_BASE.tag}",
  )

  platforms = split(",", PLATFORMS)
}

// Mutable tag for local development; not in the default group.
target "agent-base-dev" {
  inherits = ["agent-base"]
  tags     = [image_ref("agent-base", "dev")]
}

// Builds the base image plus its "test" stage (shellcheck + tool matrix).
// Not in the default group and exports nothing.
target "test" {
  inherits = ["agent-base"]
  target   = "test"
  tags     = []
  output   = ["type=cacheonly"]
}

// ---------------------------------------------------------------------------
// opencode
// ---------------------------------------------------------------------------
target "opencode" {
  context    = "stacks/opencode/image"
  dockerfile = "Dockerfile"
  target     = "opencode"

  args = {
    AGENT_BASE       = AGENT_BASE
    OPENCODE_VERSION = OPENCODE_VERSION
  }

  tags = [
    image_ref("opencode", TAG),
    image_ref("opencode", OPENCODE_VERSION),
  ]

  labels = oci_labels(
    "opencode",
    "OpenCode CLI/Web UI on agent-base: s6-supervised sandbox, rootless Docker, persistent state",
    OPENCODE_VERSION,
    "${AGENT_BASE}",
  )

  platforms = split(",", PLATFORMS)
}

target "opencode-dev" {
  inherits = ["opencode"]
  tags     = [image_ref("opencode", "dev")]
}

// ---------------------------------------------------------------------------
// dsh (DeepSeek Harness)
// ---------------------------------------------------------------------------
target "dsh" {
  context    = "stacks/deepseek-harness/image"
  dockerfile = "Dockerfile"
  // The Dockerfile's last stage is "test" (it needs a BuildKit secret), so the
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
    "${AGENT_BASE}",
  )

  platforms = split(",", PLATFORMS)
}

target "dsh-dev" {
  inherits = ["dsh"]
  tags     = [image_ref("dsh", "dev")]
}

// Builds the dsh runtime image plus its "test" stage, which loads a real
// credentials file as a BuildKit secret and checks it against the API and a
// headless run. Never pushed; `make test` supplies the secret.
target "dsh-test" {
  inherits        = ["dsh"]
  target          = "test"
  tags            = []
  output          = ["type=cacheonly"]
  secret          = ["type=file,id=dsh_credentials,src=${DSH_CREDENTIALS}"]
  no-cache-filter = ["test"]
}

// ---------------------------------------------------------------------------
// claude (Claude Code)
// ---------------------------------------------------------------------------
target "claude" {
  context    = "stacks/claude/image"
  dockerfile = "Dockerfile"
  target     = "claude"

  args = {
    AGENT_BASE     = AGENT_BASE
    CLAUDE_VERSION = CLAUDE_VERSION
    NODE_REF       = NODE_REF
  }

  tags = [
    image_ref("claude", TAG),
    image_ref("claude", CLAUDE_VERSION),
  ]

  labels = oci_labels(
    "claude",
    "Claude Code on agent-base: Node 22 from the official image, s6-supervised rootless Docker, interactive CLI",
    CLAUDE_VERSION,
    "${AGENT_BASE}",
  )

  platforms = split(",", PLATFORMS)
}

target "claude-dev" {
  inherits = ["claude"]
  tags     = [image_ref("claude", "dev")]
}
