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

Use the Linux UVC ABI directly through `@cImport`. Keep the payload and query
structure on the stack. Preserve the C-compatible entry point and direct libc
calls rather than introducing general-purpose process/I/O initialization.
Avoid heap allocation. Do not add threads, configuration parsing, environment
dependencies, shell commands, subprocesses, daemons, PAM hooks, or systemd units.

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

Requires Zig 0.16.0, libc development headers, and Linux UAPI headers.

```sh
zig fmt .
zig build --release=small
zig build test --release=small
udevadm verify udev/61-21mw-ir-emitter.rules
```

The four tests cover missing/extra arguments, an empty path, and an unsupported
ioctl on `/dev/null`. They expect failure and empty stdout. Normal tests must
never require, open, or modify a camera. Do not add fake shell wrappers,
emulators, or large mocking infrastructure. There is deliberately no generic
`run` build step.

```text
lib/udev/21mw-ir-emitter
lib/udev/rules.d/61-21mw-ir-emitter.rules
```

Deployment uses `/usr` as the installation prefix. A plain `zig build` is a
debug build; use `--release=small` for deployment. The inspected native release
binary was 4,264 bytes, stripped, dynamically linked only to libc. This is an
observation, not a size guarantee or a universally portable Linux artifact.

## Hardware and Lifecycle Validation

Verified during initial implementation:

- The machine reports DMI product `21MW`.
- The release helper successfully sent the control to `/dev/video2`, exited 0,
  and produced no output.
- `udevadm test --extra-rules-dir=udev --action=add` queued the helper only for
  video2, not video0, video1, or video3. Change/remove events did not queue it.
  This simulates matching; it does not execute `RUN` commands.
- Formatting, Debug/ReleaseSmall builds, isolated tests, and udev rule
  validation passed. Binary dependencies and staged layout were inspected.

Still requires attended testing after installation and PAM migration:

1. Apply the control once, then authenticate with Howdy repeatedly without
   rerunning the helper. Verify the emitter works on every attempt. The old
   `linux-enable-ir-emitter` PAM hook must be removed first, or it can mask
   failures by reapplying the control.
2. Separately suspend and resume. Observe events with
   `sudo udevadm monitor --udev --property --subsystem-match=video4linux` and
   repeat authentication without manually reapplying the control.
3. Reboot, or perform a deliberate camera USB reset in a safe session. Verify
   a matching add event, successful helper execution in udev debug logs, and
   working Howdy without manual initialization. A synthetic add event checks
   wiring but does not prove reset or reboot behavior.

Reboot, USB reset, suspend/resume, and repeated Howdy authentication were not
performed during initial implementation. System installation and PAM migration
were not performed either. Do not add suspend/resume hooks unless testing proves
that the camera loses the setting without generating a suitable add event.
