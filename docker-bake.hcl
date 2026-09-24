// =============================================================================
// docker-bake.hcl — build definition for the DeepSeek Harness (dsh) Web UI
// container image
// =============================================================================
//
// Usage (via bake.sh):
//   bash bake.sh --print   # resolve and print the full config, no build
//   bash bake.sh           # build the "default" group (the "dsh" target)
//   bash bake.sh --push    # build and push
//
// GIT_SHA/GIT_REF/REGISTRY/etc. can't be detected from inside this file —
// HCL has no access to git, the filesystem, or CI context. bake.sh computes
// them (e.g. `git rev-parse HEAD`) and exports them as env vars before
// calling `docker buildx bake`, since env vars override a `variable`
// block's default whenever the names match. The defaults below only cover
// a bare, no-args build.

// REGISTRY: where images get pushed (e.g. ghcr.io/arasemco).
// SOURCE_URL: where THESE packaging files live — deliberately not upstream's
// deepseek-ai/deepseek-harness repo, since upstream doesn't own or publish
// this Dockerfile/bake file. Point this at wherever you host this directory.
variable "REGISTRY"   { default = "ghcr.io/arasemco" }
variable "SOURCE_URL" { default = "https://github.com/arasemco/docker-dsh" }

// Static identity/provenance metadata, same across every build.
variable "PROVENANCE_METADATA" {
  default = {
    authors  = "Aram SEMO <aram.semo@asemo.pro>",
    vendor   = "asemo.pro",
    licenses = "MIT",
  }
}

// Base image pinned by digest, not just tag — floating tags (including
// "22-bookworm-slim") can be repointed upstream at any time, so pinning here
// guarantees every build starts from the exact same layer.
//
// Must be a glibc base such as Debian "bookworm-slim": dsh's plugin loader
// needs node-addon-require-builtin, which publishes only glibc prebuilt
// binaries (see dsh/Dockerfile's base-image comment).
//
// To bump, resolve the new digest and set it here and in dsh/Dockerfile's
// NODE_REF default (the two must agree):
//   docker pull node:22-bookworm-slim --platform linux/amd64
//   docker inspect --format='{{index .RepoDigests 0}}' node:22-bookworm-slim
//
// Must satisfy upstream's package.json engines constraint:
// "node": "^22.19.0 || >=24.0.0" — don't drop below 22.19 on a retag.
variable "NODE_BASE" {
  default = {
    name   = "docker.io/library/node"
    tag    = "22-bookworm-slim"
    digest = "sha256:83f487e0a63425e5b4d146fb5e5be574bcbe1b7b843d3ebafdd95eaf7767a7e5"
  }
}

// Turns a base map into the full "name:tag@digest" string a Dockerfile's
// FROM instruction accepts.
function "pinned_ref" {
  params = [base]
  result = "${base.name}:${base.tag}@${base.digest}"
}

// Exact @deepseek-ai/dsh version the Dockerfile installs from npm, also used
// as the image tag and OCI version label. List published versions with
// `npm view @deepseek-ai/dsh versions`. Pin an exact version, not a
// dist-tag; upstream warns "THERE WILL BE COMPATIBILITY-BREAKING CHANGES".
variable "DSH_VERSION" { default = "0.1.5-rc.3" }

// Docker Engine version for the image's rootless daemon (docker-ce,
// docker-ce-cli, docker-ce-rootless-extras from Docker's Debian repo).
variable "DOCKER_VERSION" { default = "29.8.1" }

// Default to "unknown" rather than empty string — a bare build outside of
// bake.sh (or before the first commit) can't know these, and "unknown" is
// unambiguous in the resulting image.revision/ref.name labels. Set normally
// by bake.sh via `git rev-parse HEAD` / `git rev-parse --abbrev-ref HEAD`.
variable "GIT_SHA" { default = "unknown" }
variable "GIT_REF" { default = "unknown" }

// Comma-separated string, not an HCL list — env vars are always strings,
// so this can be overridden with PLATFORMS=linux/amd64,linux/arm64 without
// touching the file. split(",", PLATFORMS) below turns it into the list
// `platforms` actually needs.
variable "PLATFORMS" { default = "linux/amd64" }


// -----------------------------------------------------------------------
// dsh-specific labels
// -----------------------------------------------------------------------
// Custom (non-OCI-standard) labels describing the upstream product itself,
// not this repo's packaging of it.
variable "DSH_LABELS" {
  default = {
    "ai.deepseek.product" = "DeepSeek Harness (dsh)"
    "ai.deepseek.website" = "https://deepseek.com"
    "ai.deepseek.docs"    = "https://deepseek-harness.github.io/deepseek-harness/"
    "ai.deepseek.source"  = "https://github.com/deepseek-ai/deepseek-harness"
  }
}

// -----------------------------------------------------------------------
// OCI Labels function - pure OCI standard labels only
// -----------------------------------------------------------------------
function "oci_labels" {
  params = [
    title,        // human-readable image title
    description,  // human-readable description of the packaged software
    version,      // packaged software version, ideally semver
    base,         // the base image map above (NODE_BASE) "dict of name, tag and digest"
  ]
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
    "org.opencontainers.image.base.name"     = "${base.name}:${base.tag}"
    "org.opencontainers.image.base.digest"   = base.digest
  }
}

// default group: `bash bake.sh` with no target name builds the "dsh" image.
group "default" {
  targets = ["dsh"]
}

// DeepSeek Harness Web UI image. Build context is just this repo's own
// "dsh" directory (Dockerfile, docker-entrypoint.sh, healthcheck.mjs). The
// Dockerfile installs @deepseek-ai/dsh@${DSH_VERSION} from npm.
target "dsh" {
  context    = "dsh"
  dockerfile = "Dockerfile"
  // "runtime", not the Dockerfile's last stage: "test" comes after it and
  // must never end up as the pushed image.
  target     = "runtime"
  pull       = true

  args = {
    NODE_REF       = pinned_ref(NODE_BASE)
    DSH_VERSION    = DSH_VERSION
    DOCKER_VERSION = DOCKER_VERSION
  }

  tags = [
    "${REGISTRY}/dsh:latest",
    "${REGISTRY}/dsh:${DSH_VERSION}",
  ]

  labels = merge(
    DSH_LABELS,
    oci_labels(
      "dsh",
      "DeepSeek Harness (dsh) Web UI, installed from npm; loopback-only by design (see SAFETY.md)",
      DSH_VERSION,
      NODE_BASE,
    )
  )

  platforms = split(",", PLATFORMS)
}

// Where the "test" target reads dsh's credentials file (see dsh/Dockerfile's
// "test" stage). Defaults to the key this repo's own docker-compose.yml
// persists (./data/dsh-home → /home/dsh/.dsh). When this file is missing,
// `make test` copies it out of a deployed container's DSH_HOME volume
// ($DSH_VOLUME) instead.
variable "DSH_CREDENTIALS" { default = "data/dsh-home/.credentials.yaml" }

// Builds the runtime image plus the "test" stage, which loads the DeepSeek
// API key from DSH_CREDENTIALS and checks it against the real API and a real
// dsh headless run. Not in the default group (CI has no key) and exports
// nothing: output=cacheonly keeps it out of the image store and the
// registry. no-cache-filter re-runs the check every time, because BuildKit
// does not use secret contents in the cache key, so a revoked key would
// otherwise keep passing from cache.
target "test" {
  inherits        = ["dsh"]
  target          = "test"
  tags            = []
  output          = ["type=cacheonly"]
  secret          = ["type=file,id=dsh_credentials,src=${DSH_CREDENTIALS}"]
  no-cache-filter = ["test"]
}
