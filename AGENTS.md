# Development Guide

## Scope and Constraints

Keep this project specific to the Lenovo ThinkBook 16 G7 ARP (21MW) and its
Chicony IR emitter. Do not turn it into a generic camera or UVC framework.
Keep README.md focused on installation, migration, use, and troubleshooting;
keep implementation details and developer validation notes here.

The Linux-only helper must do only: validate argv, open the device, send the
control, close the descriptor, and exit. Accept exactly one device-node
argument. Success must be silent; report errors to stderr and return non-zero
on failure. Always close an opened descriptor.

Use direct x86_64 assembly with raw Linux syscalls. Keep the payload and
query structure on the stack. Direct kernel syscalls avoid runtime initialization
and all libc dependencies. Avoid heap allocation. Do not add threads,
configuration parsing, environment dependencies, shell commands, subprocesses,
daemons, PAM hooks, or systemd units.

## Exact Control

Send `UVCIOC_CTRL_QUERY` with `struct uvc_xu_control_query`:

```text
unit     = 14
selector = 6
query    = UVC_SET_CUR
size     = 9
payload  = 01 03 02 00 00 00 00 00 00
```

This control is known to work on the target camera. Do not substitute the
protocol used by `chicony-ir-toggle`.

## Device Matching

The rule was derived from both `udevadm info -q property -n /dev/video2` and
`udevadm info -a -n /dev/video2` on the actual 21MW:

- `ID_VENDOR_ID=04f2`, `ID_MODEL_ID=b7e8`: Chicony USB camera.
- `ID_USB_INTERFACE_NUM=02`: IR interface, not RGB interface `00`.
- `ATTR{index}=="0"`: capture node, not metadata index `1`.

`60-persistent-v4l.rules` imports the USB properties.
`61-21mw-ir-emitter.rules` follows it immediately. Match only `ACTION=="add"`
and `SUBSYSTEM=="video4linux"` with the identity above, then run
`/usr/lib/udev/21mw-ir-emitter $devnode`. Never hard-code a video number.
On the inspected machine, video0/video1 are RGB capture/metadata;
video2/video3 are IR capture/metadata.

Do not match only the supplied by-id link: both RGB and IR interfaces claim
`usb-Chicony_Electronics_Co._Ltd._Integrated_Camera_0001-video-index0`.
It resolved to video2 during inspection, but does not uniquely identify the IR
interface. The rule uses USB identity, interface, and index instead.
The helper deliberately does not identify cameras itself.

## Build and Isolated Tests

Requires GCC and make. `make check` also requires `udevadm verify` from systemd.

```sh
make
make check
```

The four helper tests cover missing/extra arguments, an empty path, and an
unsupported ioctl on `/dev/null`. Each requires exit status 1, empty stdout, and
the exact stderr text, so a crash or misdirected error fails the test.
`make check` then validates the rule with `udevadm verify`. Normal tests must
never require, open, or modify a camera. Do not add fake shell wrappers,
emulators, or large mocking infrastructure.

```text
lib/udev/21mw-ir-emitter
lib/udev/rules.d/61-21mw-ir-emitter.rules
```

Deployment uses `/usr` as the installation prefix. The inspected native release
binary is ~1.1 KB, static, stripped, with zero external dependencies. This is an
observation, not a size guarantee or a universally portable Linux artifact.

## Hardware and Lifecycle Validation

The target machine reports DMI product `21MW`. The release helper successfully
sent the control to `/dev/video2`, exited 0, and produced no output. The installed
udev rule has been tested: Howdy works reliably, including after suspend/resume,
without manually rerunning the helper or adding a suspend/resume hook. The udev
rule alone is sufficient; do not add PAM or other lifecycle hooks.

`udevadm test --extra-rules-dir=udev --action=add` queued the helper only for
video2, not video0, video1, or video3. Change/remove events did not queue it.
This simulates matching; it does not execute `RUN` commands. Builds,
isolated tests, and udev rule validation passed. Binary dependencies and staged
layout were inspected.
