target "claude" {
  context    = "stacks/claude/image"
  dockerfile = "Dockerfile"
  target     = "claude"
  args = {
    AGENT_CONTRACT = AGENT_CONTRACT
    AGENT_BASE = base_ref("node22")
    CLAUDE_VERSION = CLAUDE_VERSION
  }
  tags = [
    image_ref("claude", TAG),
    image_ref("claude", CLAUDE_VERSION),
  ]
  labels = oci_labels("Claude Code", "Claude Code on agent-base", CLAUDE_VERSION, base_ref("node22"))
  cache-from = REGISTRY != "" ? ["type=registry,ref=${REGISTRY}/claude:buildcache"] : []
  cache-to   = CACHE_WRITE && REGISTRY != "" ? ["type=registry,ref=${REGISTRY}/claude:buildcache,mode=max"] : []
  platforms  = split(",", PLATFORMS)
}

target "claude-dev" {
  inherits = ["claude"]
  tags     = [image_ref("claude", "dev")]
}

target "claude-test" {
  inherits = ["claude"]
  target   = "test"
  tags     = []
  output   = ["type=cacheonly"]
}
