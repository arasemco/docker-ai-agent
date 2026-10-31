# opencode — build/run helpers. The image context is image/; the stack is the
# root docker-compose.yml, merged with a gitignored compose/local.yml when one
# exists (proxy, host mounts, limits — see README#overrides).
SERVICE   ?= opencode
SHELL_BIN ?= bash

LOCAL_COMPOSE := $(wildcard compose/local.yml)
COMPOSE := docker compose $(if $(LOCAL_COMPOSE),-f compose/local.yml)

.PHONY: default build up down ps logs exec debug smoke config

default:
	@echo "Usage:"
	@echo "  make build              build the image via scripts/bake.sh"
	@echo "  make up                 build + start the stack (docker-compose.yml)"
	@echo "  make down               stop it and drop its volumes"
	@echo "  make smoke              check the running stack (scripts/smoke.sh)"
	@echo "  make logs               follow the logs"
	@echo "  make exec               shell in it as the agent user"
	@echo "  make debug              shell in it as root"
	@echo "  make config             validate and print the effective compose config"
	@echo ""
	@echo "  Optional: a gitignored compose/local.yml is merged automatically"
	@echo "  (start from examples/compose/*.yml). SERVICE=$(SERVICE)."

build:
	scripts/bake.sh

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

smoke:
	scripts/smoke.sh

config:
	$(COMPOSE) config
