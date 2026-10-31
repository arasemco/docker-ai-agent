# opencode — build and run helpers.
#
# The stack is assembled from agent-base's compose fragments by
# scripts/compose.sh: base.yml always, plus whatever WITH lists.
#
#   make up                      # base + daemon
#   make up WITH=daemon,proxy    # + outbound proxy (values from .env)
#   make up WITH=daemon,limits,mounts
SERVICE   ?= opencode
SHELL_BIN ?= bash
WITH      ?= daemon

COMPOSE := scripts/compose.sh --with $(WITH) --

.PHONY: default build up down ps logs exec debug smoke config

default:
	@echo "Usage:"
	@echo "  make build              build the image via scripts/bake.sh"
	@echo "  make up                 start the stack (fragments: $(WITH))"
	@echo "  make down               stop it and drop its volumes"
	@echo "  make smoke              check the running stack (scripts/smoke.sh)"
	@echo "  make logs               follow the logs"
	@echo "  make exec               shell in it as the agent user"
	@echo "  make debug              shell in it as root"
	@echo "  make config             print the merged compose config"
	@echo ""
	@echo "  WITH=<fragments>  agent-base fragments: daemon (default), proxy, limits, mounts, skills"
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
	WITH=$(WITH) scripts/smoke.sh

config:
	$(COMPOSE) config
