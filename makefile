SERVICE ?=
SHELL_BIN ?= sh
# Deployed stack's dsh home volume (~/stacks/deepseek-harness), read by
# `make test` when neither DSH_CREDENTIALS nor data/dsh-home/.credentials.yaml
# is available.
DSH_VOLUME ?= deepseek-harness_dsh_home

.PHONY: default fs test

default:
	@echo "Usage:"
	@echo "  make down SERVICE=<name>"
	@echo "  make build SERVICE=<name>"
	@echo "  make up SERVICE=<name>"
	@echo "  make from_scratch SERVICE=<name>"
	@echo "  make logs SERVICE=<name>"
	@echo "  make test [DSH_CREDENTIALS=<file>] [DSH_VOLUME=<volume>]"
	@echo "  make exec SERVICE=<name> [SHELL_BIN=<shell>]"
	@echo "  make run SERVICE=<name>  [SHELL_BIN=<shell>]"
	@echo "  export SERVICE=<name> to avoid passing service name on each call time"
	@echo "  export SHELL_BIN=<shell> to override shell (default: sh)"

build:
	docker buildx bake

# Builds the Dockerfile's "test" stage with dsh's .credentials.yaml as a
# BuildKit secret. Source, in order: $DSH_CREDENTIALS, the local
# data/dsh-home/.credentials.yaml, then a 0600 temp copy out of $(DSH_VOLUME)
# (deleted on exit). The volume is checked first, because `docker run -v` would
# silently create an empty one.
test:
	@if [ -n "$$DSH_CREDENTIALS" ] || [ -f data/dsh-home/.credentials.yaml ]; then \
		bash bake.sh test; \
	else \
		docker volume inspect $(DSH_VOLUME) >/dev/null && \
		tmp=$$(mktemp) && trap 'rm -f "$$tmp"' EXIT && \
		docker run --rm --entrypoint cat -v $(DSH_VOLUME):/dsh-home:ro ghcr.io/arasemco/dsh:latest /dsh-home/.credentials.yaml > "$$tmp" && \
		DSH_CREDENTIALS="$$tmp" bash bake.sh test; \
	fi

services:
	docker compose config --services

check:
	@if [ -z "$(SERVICE)" ]; then \
		echo "SERVICE is required. Usage: make <target> SERVICE=<service_name>"; \
		echo "Available services:"; \
		docker compose config --services; \
		exit 1; \
	fi

pull:
	docker compose pull $(SERVICE)

up:
	docker compose up --remove-orphans --detach $(SERVICE)

down:
	docker compose down --volumes --timeout 0 $(SERVICE)

start:
	docker compose start $(SERVICE)

stop:
	docker compose stop $(SERVICE)

restart:
	docker compose restart $(SERVICE)

logs:
	docker compose logs --follow $(SERVICE) || true

exec: check
	docker compose exec --tty --interactive --user 0 --workdir /root $(SERVICE) $(SHELL_BIN)

run: check
	docker compose run --rm --tty --interactive --user 0 --workdir /root $(SERVICE) $(SHELL_BIN)

erun: check
	docker compose run --rm --tty --interactive --user 0 --workdir /root --entrypoint $(SHELL_BIN) $(SERVICE)

from_scratch: build down up
fs: from_scratch
