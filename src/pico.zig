const std = @import("std");

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

/// Writer implementation for the pico printf
pub const UART = struct {
    const Writer = std.io.Writer(
        UART,
        error{
            /// The UART could not be written to
            UARTError,
        },
        appendWrite,
    );

    fn appendWrite(_: UART, data: []const u8) error{UARTError}!usize {
        const err = p.printf("%.*s", data.len, data.ptr);
        if (err != 0) return error.UARTError;
        return 0;
    }

    pub fn writer() Writer {
        return .{ .context = UART{} };
    }
};

pub const stdout = UART.writer();
