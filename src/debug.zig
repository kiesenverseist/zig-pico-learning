const std = @import("std");
const p = @import("pico.zig").p;

/// Assert a condition using the custom dump function. Since this is an
/// embedded environment, we don't get proper stack traces. Therefore a message
/// can be included along with the src location of where the assert is called.
pub fn assert(ok: bool, comptime fmt: []const u8, args: anytype, src: std.builtin.SourceLocation) void {
    if (ok) return;
    dump(fmt, args, src);
}

/// Prints a message along with the location of the provided src. Then panics.
pub fn dump(comptime fmt: []const u8, args: anytype, src: std.builtin.SourceLocation) noreturn {
    @setCold(true);

    var buffer: [1024]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    const allocator = fba.allocator();

    const msg_str = std.fmt.allocPrint(allocator, fmt, args) catch @panic("OOM during dump");
    const str = std.fmt.allocPrintZ(allocator, "{s}\nFile: {s}\nFunction: {s}\nLine: {d}\n", .{
        msg_str,
        src.file,
        src.fn_name,
        src.line,
    }) catch @panic("OOM during dump");

    @panic(str);
}
