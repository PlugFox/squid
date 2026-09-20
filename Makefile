SHELL :=/bin/bash -e -o pipefail
PWD   := $(shell pwd)

.DEFAULT_GOAL := all
.PHONY: all
all: ## build pipeline
all: format check test

.PHONY: ci
ci: ## CI build pipeline
ci: all

.PHONY: precommit
precommit: ## validate the branch before commit
precommit: all

.PHONY: help
help:
	@echo 'Usage: make <OPTIONS> ... <TARGETS>'
	@echo ''
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

.PHONY: version
version: ## Check flutter version
	@flutter --version

.PHONY: doctor
doctor: ## Check flutter doctor
	@flutter doctor

.PHONY: format
format: ## Format the code
	@dart format lib/ test/ example/lib/ example/test/

.PHONY: fmt
fmt: format

.PHONY: fix
fix: format ## Fix the code
	@dart fix --apply lib
	@dart fix --apply test
	@dart fix --apply example

.PHONY: get
get: ## Get the dependencies
	@flutter pub get

.PHONY: upgrade
upgrade: get ## Upgrade dependencies
	@flutter pub upgrade

.PHONY: upgrade-major
upgrade-major: get ## Upgrade to major versions
	@flutter pub upgrade --major-versions

.PHONY: outdated
outdated: get ## Check for outdated dependencies
	@flutter pub outdated --show-all --dev-dependencies --dependency-overrides --transitive --no-prereleases

.PHONY: dependencies
dependencies: get ## Check outdated dependencies
	@flutter pub outdated --dependency-overrides \
		--dev-dependencies --prereleases --show-all --transitive

.PHONY: test
test: get ## Run the tests
	@flutter test --coverage --concurrency=6 test/squid_test.dart
	@cd example && flutter test --concurrency=6

.PHONY: coverage
coverage: get ## Generate the coverage report
	@flutter test --coverage --concurrency=6 test/squid_test.dart
	@lcov --list coverage/lcov.info
	@genhtml -q -o coverage/html coverage/lcov.info
	@echo "Open coverage/html/index.html"

.PHONY: doc
doc: get ## Generate the documentation
	@dart doc --output doc/api

.PHONY: publish-check
publish-check: ## Check the package before publishing
	@flutter pub publish --dry-run

.PHONY: publish
publish: ## Publish the package
	@flutter pub publish

.PHONY: analyze
analyze: get ## Analyze the code
	@dart format --set-exit-if-changed -o none lib/ test/ example/lib/ example/test/
	@flutter analyze --fatal-infos --fatal-warnings lib/ test/
	@flutter analyze --fatal-infos --fatal-warnings example/

.PHONY: check
check: analyze publish-check ## Check the code
#	@flutter pub global activate pana
#	@pana --json --no-warning --line-length 80 > log.pana.json

.PHONY: clean
clean: ## Clean the project and remove all generated files
	@rm -rf dist bin out build
	@rm -rf coverage.* coverage .dart_tool .packages pubspec.lock

.PHONY: diff
diff: ## git diff
	$(call print-target)
	@git diff --exit-code
	@RES=$$(git status --porcelain) ; if [ -n "$$RES" ]; then echo $$RES && exit 1 ; fi
