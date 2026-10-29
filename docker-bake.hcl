variable "REGISTRY" {
  default = "git.omesa.net/asemo"
}

variable "TAG" {
  default = "latest"
}

variable "OPENCODE_UID" {
  default = "1000"
}

variable "OPENCODE_GID" {
  default = "1000"
}

variable "OPENCODE_VERSION" {
  default = "1.19.5"
}

variable "DOCKER_VERSION" {
  default = "29.8.1"
}

group "default" {
  targets = ["opencode"]
}

target "opencode" {
  context    = "."
  dockerfile = "Dockerfile"
  tags       = ["${REGISTRY}/opencode:${TAG}"]
  args = {
    OPENCODE_UID     = OPENCODE_UID
    OPENCODE_GID     = OPENCODE_GID
    OPENCODE_VERSION = OPENCODE_VERSION
    DOCKER_VERSION   = DOCKER_VERSION
  }
  platforms = ["linux/amd64"]
}

target "opencode-dev" {
  inherits  = ["opencode"]
  tags      = ["${REGISTRY}/opencode:dev"]
  platforms = ["linux/amd64"]
}
