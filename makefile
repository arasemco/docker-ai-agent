# opencode — build/run helpers. The image context is image/; the stack is the
# root docker-compose.yml, merged with a gitignored compose/local.yml when one
# exists (proxy, host mounts, limits — see README#overrides).
SERVICE   ?= opencode
SHELL_BIN ?= bash
WITH      ?= daemon

# scripts/compose.sh assembles agent-base's fragments (WITH) with this stack,
# renaming their service key to "opencode", and merges compose/local.yml when
# it exists.
COMPOSE := scripts/compose.sh --with $(WITH) --

.PHONY: default build up down ps logs exec debug smoke config

default:
	@echo "Usage:"
	@echo "  make build              build the image via scripts/bake.sh"
	@echo "  make up                 build + start the stack (fragments: $(WITH))"
	@echo "  make down               stop it and drop its volumes"
	@echo "  make smoke              check the running stack (scripts/smoke.sh)"
	@echo "  make logs               follow the logs"
	@echo "  make exec               shell in it as the agent user"
	@echo "  make debug              shell in it as root"
	@echo "  make config             validate and print the effective compose config"
	@echo ""
	@echo "  WITH=<fragments>  agent-base compose fragments: daemon, proxy, limits, mounts"
	@echo "  compose/local.yml is merged automatically when present (gitignored)."

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
