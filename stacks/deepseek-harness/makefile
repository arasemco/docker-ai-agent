# dsh — build and run helpers.
#
# The stack is assembled from agent-base's compose fragments by
# scripts/compose.sh: base.yml always, plus whatever WITH lists.
#
#   make up                      # base + daemon
#   make up WITH=daemon,proxy    # + outbound proxy (values from .env)
#   make test                    # verify a real DeepSeek API key (see below)
SERVICE   ?= dsh
SHELL_BIN ?= bash
WITH      ?= daemon
# Volume the stack persists $DSH_HOME in; `make test` reads the credentials file
# from it when no local copy exists.
DSH_VOLUME ?= dsh_dsh-home
# Compose project name, used for the volume above.
COMPOSE_PROJECT ?= dsh

COMPOSE := scripts/compose.sh --with $(WITH) --

.PHONY: default build test up down ps logs exec debug smoke config

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
	@echo "  make test [DSH_CREDENTIALS=<file>] [DSH_VOLUME=<volume>]"
	@echo "                          build the test stage: real API check + headless run"
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

# Builds the Dockerfile's "test" stage, which loads a real credentials file as a
# BuildKit secret, checks the DeepSeek API key against the API and runs dsh
# headless once. Source, in order: $DSH_CREDENTIALS, data/dsh-home/.credentials.yaml,
# then a 0600 temp copy out of $(DSH_VOLUME) (deleted on exit).
test:
	@creds="$${DSH_CREDENTIALS:-data/dsh-home/.credentials.yaml}"; \
	if [ -z "$$DSH_CREDENTIALS" ] && [ ! -f "$$creds" ]; then \
		docker volume inspect $(DSH_VOLUME) >/dev/null 2>&1 || { \
			echo "no credentials at $$creds and no volume $(DSH_VOLUME)"; \
			echo "run 'make up', sign in and add the API key in Settings -> Models, then retry"; \
			exit 1; }; \
		creds=$$(mktemp) && trap 'rm -f "$$creds"' EXIT && \
		docker run --rm --entrypoint cat -v $(DSH_VOLUME):/dsh-home:ro dsh:local /dsh-home/.credentials.yaml > "$$creds" || exit 1; \
	fi; \
	creds=$$(realpath "$$creds") && \
	DSH_CREDENTIALS="$$creds" scripts/bake.sh test --allow=fs.read="$$creds"
