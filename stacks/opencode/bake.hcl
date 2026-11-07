target "opencode" {
  context    = "stacks/opencode/image"
  dockerfile = "Dockerfile"
  target     = "opencode"
  args = {
    AGENT_CONTRACT = AGENT_CONTRACT
    AGENT_BASE = base_ref("")
    OPENCODE_VERSION = OPENCODE_VERSION
  }
  tags = [
    image_ref("opencode", TAG),
    image_ref("opencode", OPENCODE_VERSION),
  ]
  labels = oci_labels("OpenCode", "OpenCode CLI/Web UI on agent-base", OPENCODE_VERSION, base_ref(""))
  cache-from = REGISTRY != "" ? ["type=registry,ref=${REGISTRY}/opencode:buildcache"] : []
  cache-to   = CACHE_WRITE && REGISTRY != "" ? ["type=registry,ref=${REGISTRY}/opencode:buildcache,mode=max"] : []
  platforms  = split(",", PLATFORMS)
}

target "opencode-dev" {
  inherits = ["opencode"]
  tags     = [image_ref("opencode", "dev")]
}

target "opencode-test" {
  inherits = ["opencode"]
  target   = "test"
  tags     = []
  output   = ["type=cacheonly"]
}
