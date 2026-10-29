PREFIX ?= /usr
CFLAGS ?=
ALL_LDFLAGS = -nostdlib -static -s -Wl,-n -Wl,-z,noexecstack -Wl,--build-id=none -Wl,--no-eh-frame-hdr -Wl,--gc-sections $(LDFLAGS)

all: 21mw-ir-emitter

21mw-ir-emitter: src/main.s
	$(CC) $(CFLAGS) $< $(ALL_LDFLAGS) -o $@

check: 21mw-ir-emitter
	! ./$< >/dev/null 2>&1
	! ./$< "" extra >/dev/null 2>&1
	! ./$< "" >/dev/null 2>&1
	! ./$< /dev/null >/dev/null 2>&1
	udevadm verify udev/61-21mw-ir-emitter.rules

install: 21mw-ir-emitter
	install -D -m 755 21mw-ir-emitter $(DESTDIR)$(PREFIX)/lib/udev/21mw-ir-emitter
	install -D -m 644 udev/61-21mw-ir-emitter.rules $(DESTDIR)$(PREFIX)/lib/udev/rules.d/61-21mw-ir-emitter.rules

clean:
	rm -f 21mw-ir-emitter

.PHONY: all check install clean
