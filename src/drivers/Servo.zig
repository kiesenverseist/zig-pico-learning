//! A module to control a servo motor using PWM

const assert = @import("../debug.zig").assert;
const p = @import("../pico.zig").p;

const Servo = @This();

/// The gpio pin that the servo is attached to
pin: u8,

var pwm_config: ?p.pwm_config = null;
var cycles_per_us: ?f32 = null;

/// Init the Servo system. Configures the divider for pwm.
pub fn init(args: struct {
    div: u8 = 64,
    servo_pwm_freq: u32 = 50.0,
}) void {
    const clock_khz = p.frequency_count_khz(p.CLOCKS_FC0_SRC_VALUE_PLL_SYS_CLKSRC_PRIMARY);

    _ = p.printf("Servo config:\n");
    _ = p.printf("clock is %dkHz\n", clock_khz);

    _ = p.printf("divider is %d\n", args.div);

    const wrap_full: u32 = @divTrunc(clock_khz * 1000, args.servo_pwm_freq * @as(u32, args.div));
    const wrap: u16 = @truncate(wrap_full);
    _ = p.printf("wrap is %d, truncated to %d\n", wrap_full, wrap);

    // wraps per second * cycles per wrap / us per second
    cycles_per_us = @as(f32, @floatFromInt(args.servo_pwm_freq * wrap)) / 1e6;
    _ = p.printf("%f cycles / us\n", cycles_per_us.?);

    pwm_config = p.pwm_get_default_config();
    p.pwm_config_set_clkdiv_int(&pwm_config.?, args.div);
    p.pwm_config_set_wrap(&pwm_config.?, @truncate(wrap));
}

/// Start a servo on the given pin.
pub fn create(pin: u8) Servo {
    assert(pwm_config != null, "pwm_config not set in Servo. Make sure to call Servo.init first.", .{}, @src());
    assert(cycles_per_us != null, "cycles_per_us not set in Servo. Make sure to call Servo.init first.", .{}, @src());

    p.gpio_set_function(pin, p.GPIO_FUNC_PWM);
    const slice = p.pwm_gpio_to_slice_num(pin);

    p.pwm_init(slice, &pwm_config.?, true);

    return Servo{
        .pin = pin,
    };
}

/// Set the pulse width sent to the servo in microseconds.
fn setPulse(servo: *const Servo, us: u16) void {
    assert(
        us >= 500 and us <= 2500,
        "{d} is out of pulse range",
        .{us},
        @src(),
    );
    const cycles: u16 = @intFromFloat(cycles_per_us.? * @as(f32, @floatFromInt(us)));
    // _ = p.printf("duty cycle is %d/46875\n", cycles);
    p.pwm_set_gpio_level(servo.pin, cycles);
}

/// Sets the target position for the servo.
pub fn setDeg(servo: *const Servo, deg: u8) void {
    // range is 2400 - 600 = 1800
    // 1800 ms / 180 deg = 10 ms / deg
    assert(deg <= 180, "Angle {d} is greater than 180 deg", .{deg}, @src());
    const us: u16 = 600 + 10 * @as(u16, deg);
    servo.setPulse(us);
}
