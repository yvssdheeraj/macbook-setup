.PHONY: test lint clean

test:
	./tests/bats-core/bin/bats tests/*.bats

lint:
	shellcheck setup.sh uninstall.sh scripts/**/*.sh tests/*.bats

clean:
	rm -f ~/Desktop/Setup_Report.md
