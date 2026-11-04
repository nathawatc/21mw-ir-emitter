CFLAGS ?=
ALL_LDFLAGS = -nostdlib -static -s -Wl,-n -Wl,-z,noexecstack -Wl,--build-id=none -Wl,--no-eh-frame-hdr -Wl,--gc-sections $(LDFLAGS)

# $(1) = arguments, $(2) = exact expected stderr. Requires exit status 1 and empty stdout.
define expect_failure
	test "$$(./$< $(1) 2>/dev/null; echo $$?)" = 1
	test "$$(./$< $(1) 2>&1 >/dev/null)" = $(2)
endef

all: 21mw-ir-emitter

21mw-ir-emitter: src/main.s
	$(CC) $(CFLAGS) $< $(ALL_LDFLAGS) -o $@

check: 21mw-ir-emitter
	$(call expect_failure,,"usage: 21mw-ir-emitter DEVICE")
	$(call expect_failure,"" extra,"usage: 21mw-ir-emitter DEVICE")
	$(call expect_failure,"","21mw-ir-emitter: open failed")
	$(call expect_failure,/dev/null,"21mw-ir-emitter: UVCIOC_CTRL_QUERY failed")
	udevadm verify udev/61-21mw-ir-emitter.rules

install: 21mw-ir-emitter
	install -D -m 755 21mw-ir-emitter $(DESTDIR)/usr/lib/udev/21mw-ir-emitter
	install -D -m 644 udev/61-21mw-ir-emitter.rules $(DESTDIR)/usr/lib/udev/rules.d/61-21mw-ir-emitter.rules

uninstall:
	rm -f $(DESTDIR)/usr/lib/udev/21mw-ir-emitter
	rm -f $(DESTDIR)/usr/lib/udev/rules.d/61-21mw-ir-emitter.rules

clean:
	rm -f 21mw-ir-emitter

.PHONY: all check install uninstall clean
