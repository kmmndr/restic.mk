PREFIX?=/usr/local

install:
	@install -Dm755 restic.mk ${PREFIX}/bin/restic.mk

uninstall:
	@rm ${PREFIX}/bin/restic.mk
