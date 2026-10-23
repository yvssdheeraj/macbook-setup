.PHONY: test-deps test lint upstream policy

test-deps:
	bash scripts/test-deps.sh

test: test-deps
	bash scripts/test-deps.sh --run tests/test-containers.bats tests/test-deps.bats tests/test-packages.bats tests/test-preflight.bats tests/test-runtimes.bats tests/test-setup.bats tests/test-utils.bats

upstream: test-deps
	RUN_UPSTREAM_TESTS=1 bash scripts/test-deps.sh --run tests/test-upstream.bats

policy: test-deps
	bash scripts/test-deps.sh --run --filter 'prefix|symlink|privileged|dry-run|OS bypass|without writes' tests/test-*.bats

lint:
	shellcheck setup.sh uninstall.sh scripts/*.sh scripts/install/*.sh scripts/customize/*.sh scripts/utils/*.sh dotfiles/zshrc tests/*.bats tests/helpers.bash tests/fixtures/*.sh
	ruby -c scripts/support.rb
	bash -n setup.sh uninstall.sh scripts/*.sh scripts/install/*.sh scripts/customize/*.sh scripts/utils/*.sh
