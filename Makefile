SHELL := /bin/bash
.ONESHELL:
.PHONY: test lint format test-ci lint-ci build upload-release setup docker-shell

BUILDINFO=ingestr/src/buildinfo.py

venv: venv/touchfile

venv/touchfile: requirements-dev.txt requirements.txt
	test -d venv || python3 -m venv venv
	. venv/bin/activate; pip install uv; $(MAKE) deps
	touch venv/touchfile

lock-deps:
	uv pip compile requirements.in -o requirements.txt

deps: lock-deps
	uv pip install -r requirements-dev.txt

deps-ci:
	uv pip install --system -r requirements-dev.txt

test-ci:
	TESTCONTAINERS_RYUK_DISABLED=true pytest -n auto -x -rP -vv --tb=short --durations=10 --cov=ingestr --no-cov-on-fail

test: venv
	. venv/bin/activate; $(MAKE) test-ci

test-specific: venv
	. venv/bin/activate; pytest -rP -vv --tb=short --capture=no -k $(test)

lint-ci:
	ruff format ingestr && ruff check ingestr --fix
	mypy --config-file pyproject.toml --explicit-package-bases ingestr

lint: venv
	. venv/bin/activate; $(MAKE) lint-ci

lint-docs:
	vale docs --glob='!**/.vitepress/**'

tl: test lint

build:
	cat > ${BUILDINFO} <<< "version = \"$$(git describe --tags --abbrev=0)\""
	rm -rf dist && python3 -m build
	rm -f ${BUILDINFO}

upload-release:
	twine upload --verbose dist/*

setup:
	@echo "installing git hooks ..."
	@install -m 755 .githooks/pre-commit-hook.sh .git/hooks/pre-commit

docker-shell:
	# run a docker container to build and run ingestr
	@docker run -v $(PWD):/root/code -w /root/code -it --rm --entrypoint /bin/bash python:3.11
