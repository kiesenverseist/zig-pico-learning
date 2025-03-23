//! the main file!

const std = @import("std");

pub const debug = @import("debug.zig");
pub const pico = @import("pico.zig");
pub const drivers = @import("drivers.zig");

const Servo = drivers.Servo;
const Display = drivers.SSD1306;

const assert = debug.assert;
const stdout = pico.stdout;
const p = pico.p;

/// the entry point that is externally linked to
export fn main() c_int {
    _ = p.stdio_init_all();
    zig_main() catch |err| {
        stdout.print("exiting with error: {}", .{err}) catch {};
        return 1;
    };
    return 0;
}

fn zig_main() !void {
    assert(p.cyw43_arch_init() == 0, "Couldn't init wifi", .{}, @src());

    Servo.init(.{});
    const servo = Servo.create(15);

    Display.init();

    var tgt: u16 = 0;

    while (true) {
        p.cyw43_arch_gpio_put(p.CYW43_WL_GPIO_LED_PIN, true);
        p.sleep_ms(1000);
        p.cyw43_arch_gpio_put(p.CYW43_WL_GPIO_LED_PIN, false);
        p.sleep_ms(500);

        _ = try stdout.print("tgt at {d}deg\n", .{tgt});

        servo.setDeg(@truncate(tgt));
        tgt += 90;
        if (tgt > 180) {
            tgt = 0;
        }
    }
}

/// the panic handler~
pub fn panic(msg: []const u8, _: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    @branchHint(.cold);

    stdout.print("\n!! PANIC !!\n{s}\n", .{msg}) catch {};

    @breakpoint();
    while (true) {}
}
