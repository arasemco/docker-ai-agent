# ai/agent — one base image and one module per agent CLI.
#
#   make check                     hermetic contract checks
#   make build PROFILE=opencode    base variant + the profile's image
#   make build-all                 base variants + every stack
#   make up PROFILE=dsh            build, then run the profile
#   make smoke PROFILE=dsh         probe the running stack
#   make generate                  regenerate reference pages
#   make release                   assert the tag and build/push every image
#
# The host overlay is optional:
#   make up PROFILE=dsh LOCAL_COMPOSE=docker-compose.local.yml
PROFILE       ?= opencode
SHELL_BIN     ?= bash
LOCAL_COMPOSE ?=
SERVICE       := $(if $(filter base,$(PROFILE)),agent-base,$(PROFILE))
COMPOSE       := docker compose --profile $(PROFILE) $(if $(LOCAL_COMPOSE),-f docker-compose.yml -f $(LOCAL_COMPOSE),)
EXPORT        := eval "$$(tooling/versions.sh --export)"

.PHONY: default check build build-all test test-node22 test-dsh up down ps logs exec debug smoke config generate generate-check release

default:
	@echo "Usage:"
	@echo "  make check               hermetic contract checks (no daemon)"
	@echo "  make build               base image and the PROFILE image"
	@echo "  make build-all           base variants and every stack image"
	@echo "  make test                base test stage"
	@echo "  make test-node22         Node 22 base test stage"
	@echo "  make test-dsh            dsh integration test (needs credentials)"
	@echo "  make up                  build and start the PROFILE stack"
	@echo "  make down                stop it and drop its volumes"
	@echo "  make smoke               check the running stack"
	@echo "  make generate            regenerate docs/reference"
	@echo "  make release             assert the tag and build/push every image"
	@echo ""
	@echo "  PROFILE=base|opencode|dsh|claude (currently: $(PROFILE))"
	@echo "  LOCAL_COMPOSE=docker-compose.local.yml applies the host overlay"

check:
	tooling/check.sh

# The base and its variant are built first, then the stack builds FROM the
# tagged base. Two invocations, never one parallel bake.
build:
	tooling/bake.sh agent-base
	@case "$(PROFILE)" in \
		base) tooling/bake.sh agent-base ;; \
		opencode) tooling/bake.sh opencode ;; \
		dsh) tooling/bake.sh agent-base-node22; tooling/bake.sh dsh ;; \
		claude) tooling/bake.sh agent-base-node22; tooling/bake.sh claude ;; \
		*) echo "unknown PROFILE=$(PROFILE)" >&2; exit 1 ;; \
	esac

build-all:
	tooling/bake.sh agent-base agent-base-node22
	tooling/bake.sh opencode dsh claude

test:
	tooling/bake.sh test

test-node22:
	tooling/bake.sh test-node22

# Needs DSH_CREDENTIALS (or data/dsh-home/.credentials.yaml).
test-dsh:
	tooling/bake.sh dsh-integration --allow=fs.read="$$(realpath "$${DSH_CREDENTIALS:-data/dsh-home/.credentials.yaml}")"

up: build
	@$(EXPORT); $(COMPOSE) up --detach --no-build

down:
	@$(EXPORT); $(COMPOSE) down --volumes --timeout 0

ps:
	@$(EXPORT); $(COMPOSE) ps

logs:
	@$(EXPORT); $(COMPOSE) logs --follow $(SERVICE) || true

exec:
	@$(EXPORT); $(COMPOSE) exec --user 1000 --tty --interactive $(SERVICE) $(SHELL_BIN)

debug:
	@$(EXPORT); $(COMPOSE) exec --user 0 --workdir /root --tty --interactive $(SERVICE) $(SHELL_BIN)

smoke:
	tooling/smoke.sh $(PROFILE)

config:
	@$(EXPORT); $(COMPOSE) config

generate:
	tooling/generate.sh

generate-check:
	tooling/generate.sh --check

release:
	tooling/release.sh
