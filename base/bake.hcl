target "agent-base" {
  context    = "base"
  dockerfile = "Dockerfile"
  target     = "agent-base"
  pull       = true
  args = {
    DEBIAN_REF         = DEBIAN_REF
    S6_OVERLAY_VERSION = S6_OVERLAY_VERSION
    S6_SHA256_NOARCH   = S6_SHA256_NOARCH
    S6_SHA256_X86_64   = S6_SHA256_X86_64
    S6_SHA256_AARCH64  = S6_SHA256_AARCH64
    DOCKER_VERSION     = DOCKER_VERSION
    UV_VERSION         = UV_VERSION
    AGENT_USER         = AGENT_USER
    AGENT_UID          = AGENT_UID
    AGENT_GID          = AGENT_GID
    NODE_REF           = NODE_REF
  }
  tags = [
    image_ref("agent-base", TAG),
    image_ref("agent-base", BASE_VERSION),
  ]
  labels = oci_labels(
    "agent-base",
    "Shared sandbox base for AI coding-agent CLIs: Debian 12, s6-supervised rootless Docker, unprivileged user, Python/uv, dev toolchain",
    BASE_VERSION,
    DEBIAN_REF,
  )
  cache-from = CACHE_READ && REGISTRY != "" ? ["type=registry,ref=${REGISTRY}/agent-base:buildcache"] : []
  cache-to   = CACHE_WRITE && REGISTRY != "" ? ["type=registry,ref=${REGISTRY}/agent-base:buildcache,mode=max"] : []
  platforms  = split(",", PLATFORMS)
}

target "agent-base-node22" {
  context    = "base"
  dockerfile = "Dockerfile"
  target     = "agent-base-node22"
  pull       = true
  args = {
    DEBIAN_REF         = DEBIAN_REF
    S6_OVERLAY_VERSION = S6_OVERLAY_VERSION
    S6_SHA256_NOARCH   = S6_SHA256_NOARCH
    S6_SHA256_X86_64   = S6_SHA256_X86_64
    S6_SHA256_AARCH64  = S6_SHA256_AARCH64
    DOCKER_VERSION     = DOCKER_VERSION
    UV_VERSION         = UV_VERSION
    AGENT_USER         = AGENT_USER
    AGENT_UID          = AGENT_UID
    AGENT_GID          = AGENT_GID
    NODE_REF           = NODE_REF
  }
  tags = [
    image_ref("agent-base", "${BASE_VERSION}-node22"),
  ]
  labels = oci_labels(
    "agent-base-node22",
    "agent-base with the Node 22 runtime for CLIs that require newer Node",
    "${BASE_VERSION}-node22",
    DEBIAN_REF,
  )
  cache-from = CACHE_READ && REGISTRY != "" ? ["type=registry,ref=${REGISTRY}/agent-base:buildcache"] : []
  cache-to   = CACHE_WRITE && REGISTRY != "" ? ["type=registry,ref=${REGISTRY}/agent-base:buildcache,mode=max"] : []
  platforms  = split(",", PLATFORMS)
}

target "agent-base-dev" {
  inherits = ["agent-base"]
  tags     = [image_ref("agent-base", "dev")]
}

target "test" {
  inherits = ["agent-base"]
  target   = "test"
  args     = { NODE_REF = NODE_REF }
  tags     = []
  output   = ["type=cacheonly"]
}

target "test-node22" {
  inherits = ["agent-base-node22"]
  target   = "test"
  tags     = []
  output   = ["type=cacheonly"]
}
