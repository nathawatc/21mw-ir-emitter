# 21MW IR Emitter

x86_64 assembly + udev helper to initialize the Chicony IR camera on Lenovo
ThinkBook 16 G7 ARP (21MW)

No daemon, configuration file, or systemd service is needed. Success is silent;
errors are written to stderr for udev to capture.

## Packages

### Arch Linux (PKGBUILD)

```sh
cd archlinux
makepkg -si
```

### Build from Source

Requires GCC, make, and GNU binutils with `-z nosectionheader` support.
`make check` also requires `udevadm verify` from systemd.

```sh
make
sudo make install
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

## Uninstall

Use `sudo pacman -R 21mw-ir-emitter` for a package install. For a source install:

```sh
sudo make uninstall
sudo udevadm control --reload
```

## Verify and Troubleshoot

Check `journalctl -b -u systemd-udevd` for helper failures. If the journal shows
only an exit code, run `sudo udevadm control --log-level=debug`, trigger an add
event again, and recheck it. Restore the level with
`sudo udevadm control --log-level=info`.

If invoking the helper manually, pass exactly one verified IR device node. It does
not check the camera identity itself and returns a non-zero status on failure.
