# agent-base — build/test helpers.
#
# The stack is assembled from compose fragments (see compose/ and
# scripts/compose.sh): base.yml always, plus whatever WITH lists.
#
#   make up                      # base + daemon
#   make up WITH=daemon,proxy    # + outbound proxy (values from .env)
#   make up WITH=daemon,limits,mounts
SERVICE   ?= agent-base
SHELL_BIN ?= bash
WITH      ?= daemon

COMPOSE := scripts/compose.sh --with $(WITH) --file compose/harness.yml --

.PHONY: default build test smoke up down ps logs exec debug config

default:
	@echo "Usage:"
	@echo "  make build              build agent-base via scripts/bake.sh"
	@echo "  make test               build the test stage: shellcheck + tool selftest"
	@echo "  make smoke              run scripts/smoke.sh against a real container"
	@echo "  make up                 start the harness stack (fragments: $(WITH))"
	@echo "  make down               stop it and drop its volumes"
	@echo "  make logs               follow the harness logs"
	@echo "  make exec               shell in it as the agent user"
	@echo "  make debug              shell in it as root"
	@echo "  make config             print the merged compose config"
	@echo ""
	@echo "  WITH=<fragments>  add compose fragments: daemon, proxy, limits, mounts"
	@echo "  compose/local.yml is merged automatically when present (gitignored)."

build:
	scripts/bake.sh

test:
	scripts/bake.sh test

smoke:
	WITH=$(WITH) scripts/smoke.sh

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
