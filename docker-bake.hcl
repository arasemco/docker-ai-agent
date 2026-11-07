// Shared build definition. Module fragments (base/bake.hcl, stacks/*/bake.hcl)
// define their targets; tooling/bake.sh passes every fragment as -f.
// Values come from versions.env through the wrapper; the HCL declares the
// variables without defaults so a missing pin fails instead of floating.

variable "REGISTRY"      { default = "" }
variable "SOURCE_URL"    { default = "" }
variable "AUTHOR"        { default = "unknown" }
variable "VENDOR"        { default = "unknown" }
variable "LICENSES"      { default = "unknown" }
variable "BASE_VERSION"  {}
variable "AGENT_CONTRACT" {}
variable "TAG"           { default = "latest" }

variable "AGENT_USER"    {}
variable "AGENT_UID"     {}
variable "AGENT_GID"     {}
variable "DEBIAN_REF"    {}
variable "S6_OVERLAY_VERSION" {}
variable "S6_SHA256_NOARCH"   {}
variable "S6_SHA256_X86_64"   {}
variable "S6_SHA256_AARCH64"  {}
variable "DOCKER_VERSION"     {}
variable "UV_VERSION"         {}
variable "NODE_REF"           {}

variable "OPENCODE_VERSION" {}
variable "DSH_VERSION"      {}
variable "CLAUDE_VERSION"   {}
variable "PNPM_VERSION"     {}
variable "DSH_CREDENTIALS" { default = "data/dsh-home/.credentials.yaml" }

variable "GIT_SHA"      { default = "unknown" }
variable "GIT_REF"      { default = "unknown" }
variable "BUILD_CREATED" { default = "unknown" }
variable "PLATFORMS"    { default = "linux/amd64" }
variable "CACHE_READ" {
  type    = bool
  default = false
}
variable "CACHE_WRITE" {
  type    = bool
  default = false
}

function "image_ref" {
  params = [name, tag]
  result = REGISTRY == "" ? "${name}:${tag}" : "${REGISTRY}/${name}:${tag}"
}

function "base_ref" {
  params = [variant]
  result = variant == "" ? image_ref("agent-base", BASE_VERSION) : image_ref("agent-base", "${BASE_VERSION}-${variant}")
}

function "oci_labels" {
  params = [title, description, version, base_name]
  result = {
    "org.opencontainers.image.created"       = BUILD_CREATED
    "org.opencontainers.image.authors"       = AUTHOR
    "org.opencontainers.image.url"           = SOURCE_URL != "" ? SOURCE_URL : "unknown"
    "org.opencontainers.image.documentation" = SOURCE_URL != "" ? "${SOURCE_URL}/src/commit/${GIT_SHA}/README.md" : "unknown"
    "org.opencontainers.image.source"        = SOURCE_URL
    "org.opencontainers.image.version"       = version
    "org.opencontainers.image.revision"      = GIT_SHA
    "org.opencontainers.image.vendor"        = VENDOR
    "org.opencontainers.image.licenses"      = LICENSES
    "org.opencontainers.image.ref.name"      = GIT_REF
    "org.opencontainers.image.title"         = title
    "org.opencontainers.image.description"   = description
    "org.opencontainers.image.base.name"     = base_name
  }
}

group "default" { targets = ["agent-base"] }
group "all"     { targets = ["agent-base", "agent-base-node22", "opencode", "dsh", "claude"] }
