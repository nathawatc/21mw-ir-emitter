const c = @cImport({
    @cInclude("fcntl.h");
    @cInclude("unistd.h");
    @cInclude("stdio.h");
    @cInclude("sys/ioctl.h");
    @cInclude("linux/uvcvideo.h");
    @cInclude("linux/usb/video.h");
});

pub export fn main(argc: c_int, argv: [*]const [*:0]const u8) c_int {
    if (argc != 2) {
        const usage = "usage: 21mw-ir-emitter DEVICE\n";
        _ = c.write(c.STDERR_FILENO, usage.ptr, usage.len);
        return 1;
    }

    const fd = c.open(argv[1], c.O_RDWR | c.O_CLOEXEC);
    if (fd < 0) {
        c.perror("21mw-ir-emitter: open");
        return 1;
    }

    var payload = [_]u8{ 0x01, 0x03, 0x02, 0, 0, 0, 0, 0, 0 };
    var query = c.struct_uvc_xu_control_query{
        .unit = 14,
        .selector = 6,
        .query = c.UVC_SET_CUR,
        .size = payload.len,
        .data = &payload,
    };
    var status: c_int = 0;
    if (c.ioctl(fd, c.UVCIOC_CTRL_QUERY, &query) < 0) {
        c.perror("21mw-ir-emitter: UVCIOC_CTRL_QUERY");
        status = 1;
    }
    // Linux releases the descriptor even when close reports an error; do not retry.
    if (c.close(fd) < 0) {
        c.perror("21mw-ir-emitter: close");
        status = 1;
    }
    return status;
}
