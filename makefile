# agent-base — build/test helpers. Everything runs from the repo root; the
# image build context is image/ (see docker-bake.hcl).
SERVICE   ?= agent-base
SHELL_BIN ?= bash

# Harness stack, plus compose/local.yml when present (gitignored, machine
# specific: proxy, host mounts, limits — see README.md#overrides).
LOCAL_COMPOSE := $(wildcard compose/local.yml)
COMPOSE := docker compose -f compose/harness.yml $(if $(LOCAL_COMPOSE),-f $(LOCAL_COMPOSE))

.PHONY: default build test smoke up down ps logs exec debug config

default:
	@echo "Usage:"
	@echo "  make build              build agent-base via scripts/bake.sh (pinned versions)"
	@echo "  make test               build the test stage: shellcheck + tool selftest"
	@echo "  make smoke              run scripts/smoke.sh against a real container"
	@echo "  make up                 run the harness stack (compose/harness.yml)"
	@echo "  make down               stop it and drop its volumes"
	@echo "  make logs               follow the harness logs"
	@echo "  make exec               shell in it as the agent user"
	@echo "  make debug              shell in it as root"
	@echo "  make config             validate and print the effective compose config"
	@echo ""
	@echo "  Optional: a gitignored compose/local.yml is merged automatically"
	@echo "  (start from examples/compose/*.yml). SERVICE=$(SERVICE) SHELL_BIN=$(SHELL_BIN)."

# scripts/bake.sh, not `docker buildx bake` directly: it exports GIT_SHA/GIT_REF
# (OCI labels) and runs from the repo root so the relative context resolves.
build:
	scripts/bake.sh

# Builds the Dockerfile's "test" stage: shellcheck on every script plus a
# tool-matrix selftest. Needs no devices or daemon.
test:
	scripts/bake.sh test

# Builds and runs the image with the devices/seccomp profile the daemon needs,
# then validates it from inside (scripts/smoke.sh).
smoke:
	scripts/smoke.sh

up:
	$(COMPOSE) up --detach --build

down:
	$(COMPOSE) down --volumes --timeout 0

ps:
	$(COMPOSE) ps

logs:
	$(COMPOSE) logs --follow $(SERVICE) || true

exec:
	$(COMPOSE) exec --user 1000 --tty --interactive $(SERVICE) $(SHELL_BIN)

debug:
	$(COMPOSE) exec --user 0 --workdir /root --tty --interactive $(SERVICE) $(SHELL_BIN)

config:
	$(COMPOSE) config
