# agent-base — build/test helpers.
#
#   make build     build the base image via bake (OCI labels resolved from git)
#   make test      build + run the in-image test stage (shellcheck, selftest)
#   make smoke     build and run the image in a real container (dockerd, storage)
#   make up/down   run the test harness stack from docker-compose.yml
SERVICE ?= agent-base
SHELL_BIN ?= bash

.PHONY: default build test smoke up down ps logs exec debug config

default:
	@echo "Usage:"
	@echo "  make build              build agent-base with bake.sh (pinned versions)"
	@echo "  make test               build the test stage: shellcheck + tool selftest"
	@echo "  make smoke              run scripts/smoke.sh against a real container"
	@echo "  make up                 run the test harness stack (docker-compose.yml)"
	@echo "  make down               stop it and drop its volumes"
	@echo "  make logs               follow the stack's logs"
	@echo "  make exec               shell in the running container as the agent user"
	@echo "  make debug              shell in the running container as root"
	@echo "  make config             validate and print docker-compose.yml"
	@echo ""
	@echo "  SERVICE=$(SERVICE) SHELL_BIN=$(SHELL_BIN) are overridable."

# bake.sh, not `docker buildx bake` directly: it exports GIT_SHA/GIT_REF so the
# OCI revision/ref.name labels aren't "unknown".
build:
	bash bake.sh

# Builds the Dockerfile's "test" stage: shellcheck on the entrypoint scripts
# plus a tool-matrix selftest. Needs no devices or daemon.
test:
	bash bake.sh test

# Builds and runs the image with the devices/seccomp profile the rootless
# daemon needs, then validates it from inside (scripts/smoke.sh).
smoke:
	./scripts/smoke.sh

up:
	docker compose up --detach --build

down:
	docker compose down --volumes --timeout 0

ps:
	docker compose ps

logs:
	docker compose logs --follow $(SERVICE) || true

exec:
	docker compose exec --tty --interactive $(SERVICE) $(SHELL_BIN)

debug:
	docker compose exec --tty --interactive --user 0 --workdir /root $(SERVICE) $(SHELL_BIN)

config:
	docker compose config
