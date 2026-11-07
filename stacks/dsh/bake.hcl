target "dsh" {
  context    = "stacks/dsh/image"
  dockerfile = "Dockerfile"
  target     = "runtime"
  args = {
    AGENT_CONTRACT = AGENT_CONTRACT
    AGENT_BASE = base_ref("node22")
    DSH_VERSION = DSH_VERSION
  }
  tags = [
    image_ref("dsh", TAG),
    image_ref("dsh", DSH_VERSION),
  ]
  labels = oci_labels("DeepSeek Harness (dsh)", "dsh Web UI on agent-base", DSH_VERSION, base_ref("node22"))
  cache-from = REGISTRY != "" ? ["type=registry,ref=${REGISTRY}/dsh:buildcache"] : []
  cache-to   = CACHE_WRITE && REGISTRY != "" ? ["type=registry,ref=${REGISTRY}/dsh:buildcache,mode=max"] : []
  platforms  = split(",", PLATFORMS)
}

target "dsh-dev" {
  inherits = ["dsh"]
  tags     = [image_ref("dsh", "dev")]
}

target "dsh-test" {
  inherits = ["dsh"]
  target   = "test"
  tags     = []
  output   = ["type=cacheonly"]
}

target "dsh-integration" {
  inherits        = ["dsh"]
  target          = "integration"
  tags            = []
  output          = ["type=cacheonly"]
  secret          = ["type=file,id=dsh_credentials,src=${DSH_CREDENTIALS}"]
  no-cache-filter = ["test"]
}
