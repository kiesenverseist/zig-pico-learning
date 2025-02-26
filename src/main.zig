const std = @import("std");
const assert = @import("debug.zig").assert;
const p = @import("pico.zig").p;
const Servo = @import("Servo.zig");

export fn main() c_int {
    _ = p.stdio_init_all();
    assert(p.cyw43_arch_init() == 0, "Couldn't init wifi", .{}, @src());

    Servo.init(.{});
    const servo = Servo.create(15);

    var tgt: u16 = 0;

    while (true) {
        p.cyw43_arch_gpio_put(p.CYW43_WL_GPIO_LED_PIN, true);
        p.sleep_ms(1000);
        p.cyw43_arch_gpio_put(p.CYW43_WL_GPIO_LED_PIN, false);
        p.sleep_ms(500);
        _ = p.printf("tgt at %ddeg\n", tgt);

        servo.setDeg(@truncate(tgt));
        tgt += 90;
        if (tgt > 180) {
            tgt = 0;
        }
    }
}

pub fn panic(msg: []const u8, _: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    @setCold(true);

    _ = p.printf("\n!! PANIC !!\n");
    _ = p.printf(msg.ptr);
    _ = p.printf("\n");

    @breakpoint();
    while (true) {}
}
