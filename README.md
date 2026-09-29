# 21MW IR Emitter

Tiny Zig + udev helper to initialize the Chicony IR camera on Lenovo ThinkBook 16 G7 ARP (21MW)

No daemon, configuration file, or systemd service is needed. Success is silent;
errors are written to stderr for udev to capture.

## Packages

## Arch Linux (PKGBUILD)

```sh
cd archlinux
makepkg -si
```

## Build from Source

Requires Zig 0.16.0, libc development headers, and Linux UAPI headers (`linux/uvcvideo.h` and `linux/usb/video.h`).

```sh
zig build --release=small
```

```sh
sudo install -Dm755 zig-out/lib/udev/21mw-ir-emitter /usr/lib/udev/21mw-ir-emitter
sudo install -Dm644 udev/61-21mw-ir-emitter.rules /usr/lib/udev/rules.d/61-21mw-ir-emitter.rules
sudo udevadm control --reload
```

The rule selects the IR capture node automatically, regardless of its video
number. Reloading rules does not initialize an already-present camera. Reboot
to apply the rule, or trigger an add event after confirming the current IR node:

```sh
sudo udevadm trigger --action=add --settle /sys/class/video4linux/video2
```

`video2` was verified on the development machine; confirm it before using this
command on yours. Do not rely on the camera's by-id link alone: it can identify
either the RGB or IR interface.

## Verify and Troubleshoot

Check `journalctl -b -u systemd-udevd` for helper failures. If invoking the helper
manually, pass exactly one verified IR device node. It does not check the camera
identity itself and returns a non-zero status on failure.
