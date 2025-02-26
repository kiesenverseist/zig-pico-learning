const std = @import("std");
const assert = std.debug.assert;

const p = @import("pico.zig").p;

// Basically the pico_w blink sample
export fn main() c_int {
    _ = p.stdio_init_all();
    if (p.cyw43_arch_init() != 0) {
        return -1;
    }

    pwm();

    var tgt: u16 = 600;

    while (true) {
        p.cyw43_arch_gpio_put(p.CYW43_WL_GPIO_LED_PIN, true);
        p.sleep_ms(1000);
        p.cyw43_arch_gpio_put(p.CYW43_WL_GPIO_LED_PIN, false);
        p.sleep_ms(500);
        _ = p.printf("tgt at %dus\n", tgt);

        setPulse(tgt);
        tgt += 1800;
        if (tgt > 2400) {
            tgt = 600;
        }
    }
}

fn pwm() void {
    p.gpio_set_function(15, p.GPIO_FUNC_PWM);
    const slice = p.pwm_gpio_to_slice_num(15);

    const servo_pwm_freq = 50;
    const clock_khz = p.frequency_count_khz(p.CLOCKS_FC0_SRC_VALUE_PLL_SYS_CLKSRC_PRIMARY);
    _ = p.printf("clock is %dkHz\n", clock_khz);

    const div: u8 = 64;
    _ = p.printf("divider is %d\n", div);
    const wrap: u32 = @divTrunc(clock_khz * 1000, servo_pwm_freq * @as(u32, div));
    _ = p.printf("wrap is %d, truncated to %d\n", wrap, @as(u16, @truncate(wrap)));

    var config = p.pwm_get_default_config();
    p.pwm_config_set_clkdiv_int(&config, div);
    p.pwm_config_set_wrap(&config, @truncate(wrap));
    p.pwm_init(slice, &config, true);

    // 50 wraps per second * cycles per wrap / us per second
    const cycles_per_us = (50.0 * @as(f32, @floatFromInt(wrap))) / 1e6;
    _ = p.printf("%f cycles / us\n", cycles_per_us);
    const cycles: u16 = @intFromFloat(1500.0 * cycles_per_us);
    _ = p.printf("duty cycle is %d / %d\n", cycles, wrap);

    p.pwm_set_gpio_level(15, cycles);
    p.pwm_set_enabled(slice, true);
}

fn setPulse(us: u16) void {
    std.debug.assert(us >= 500 and us <= 2500);
    const cycles_per_us = 2.343750;
    const cycles: u16 = @intFromFloat(cycles_per_us * @as(f32, @floatFromInt(us)));
    _ = p.printf("duty cycle is %d/46875\n", cycles);
    p.pwm_set_gpio_level(15, cycles);
}

fn setDeg(deg: u8) void {
    // range is 2400 - 600 = 1800
    // 1800 ms / 180 deg = 10 ms / deg
    std.debug.assert(deg <= 180);
    const us: u16 = 600 + 10 * @as(u16, deg);
    setPulse(us);
}
