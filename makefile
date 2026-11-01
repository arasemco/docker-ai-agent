# ai/agent — build and run helpers for the base image and every stack.
#
# One project: the base image plus one stack per agent CLI, selected by PROFILE.
#
#   make build                         # base image + the stack in PROFILE
#   make build-all                     # base image, then every stack
#   make up PROFILE=opencode           # default profile
#   make up PROFILE=dsh
#   make up PROFILE=claude
#   make smoke PROFILE=dsh
PROFILE   ?= opencode
SHELL_BIN ?= bash
# The compose service behind a profile has the same name.
SERVICE   := $(PROFILE)
COMPOSE   := docker compose --profile $(PROFILE)

.PHONY: default build build-all test test-dsh up down ps logs exec debug smoke config

default:
	@echo "Usage:"
	@echo "  make build              build the base image, then the PROFILE stack"
	@echo "  make build-all          build the base image, then every stack"
	@echo "  make test               base image test stage (shellcheck + tool matrix)"
	@echo "  make test-dsh           dsh test stage: real API key + headless run"
	@echo "  make up                 start the PROFILE stack (default: opencode)"
	@echo "  make down               stop it and drop its volumes"
	@echo "  make smoke              check the running stack"
	@echo "  make logs               follow the logs"
	@echo "  make exec               shell in the service as the agent user"
	@echo "  make debug              shell in the service as root"
	@echo "  make config             print the merged compose config"
	@echo ""
	@echo "  PROFILE=opencode|dsh|claude   (currently: $(PROFILE))"

# The base image must exist before a stack builds FROM it, so the two runs are
# sequential rather than one parallel bake.
build:
	scripts/bake.sh agent-base
	@case "$(PROFILE)" in \
		opencode) scripts/bake.sh opencode ;; \
		dsh) scripts/bake.sh dsh ;; \
		claude) scripts/bake.sh claude ;; \
		*) echo "unknown PROFILE=$(PROFILE)"; exit 1 ;; \
	esac

build-all:
	scripts/bake.sh agent-base
	scripts/bake.sh opencode dsh claude

test:
	scripts/bake.sh test

# Needs DSH_CREDENTIALS (or data/dsh-home/.credentials.yaml); see docs/build.md.
test-dsh:
	scripts/bake.sh dsh-test --allow=fs.read="$$(realpath "$${DSH_CREDENTIALS:-data/dsh-home/.credentials.yaml}")"

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
	scripts/smoke.sh $(PROFILE)

config:
	$(COMPOSE) config
