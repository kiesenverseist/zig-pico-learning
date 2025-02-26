pub const p = @cImport({
    @cInclude("stdio.h");

    @cInclude("pico.h");
    @cInclude("pico/stdlib.h");

    @cInclude("hardware/pwm.h");
    @cInclude("hardware/clocks.h");
    @cInclude("hardware/gpio.h");

    // PICO W specific header
    @cInclude("pico/cyw43_arch.h");
});
