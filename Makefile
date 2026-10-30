PREFIX?=/usr/local
SHELL := /bin/sh
TESTS ?= $(wildcard tests/test-*.sh)

install:
	@install -Dm755 restic.mk ${PREFIX}/bin/restic.mk

uninstall:
	@rm ${PREFIX}/bin/restic.mk

.PHONY: check
check:
	@failed=0; \
	for t in $(TESTS); do \
	  echo "==> $$t"; \
	  ./$$t || failed=1; \
	done; \
	exit $$failed
