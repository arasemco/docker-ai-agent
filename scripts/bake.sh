#!/bin/bash
# Wraps `docker buildx bake`: HCL can't call git, so this resolves
# GIT_SHA/GIT_REF (this repo's own history, for the OCI revision/ref.name
# labels) and exports them before invoking buildx bake, from the repo root so
# docker-bake.hcl's relative `context = "image"` resolves.
#
# Falls back to "unknown" (docker-bake.hcl's own default) when this directory
# isn't a git checkout, instead of letting `git rev-parse` print its
# "fatal: not a git repository" noise to stderr — harmless either way (the
# build still runs), just quieter.
set -e

cd "$(dirname "$0")/.."

GIT_SHA=$(git rev-parse HEAD 2>/dev/null || echo unknown)
GIT_REF=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)

GIT_SHA="$GIT_SHA" GIT_REF="$GIT_REF" exec docker buildx bake -f docker-bake.hcl "$@"
