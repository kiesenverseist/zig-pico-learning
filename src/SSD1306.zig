//? SSD1306 i2c driver
//? based on raspberry pi's example: https://github.com/raspberrypi/pico-examples/blob/master/i2c/ssd1306_i2c/ssd1306_i2c.c

const std = @import("std");
const assert = @import("debug.zig").assert;
const p = @import("pico.zig").p;

const height = 32;
const width = 128;

const i2c_addr: u16 = 0x3c;
const i2c_clk: u16 = 400;

const commands = enum(u16) {
    set_mem_mode = 0x20,
    set_col_addr = 0x21,
    set_page_addr = 0x22,
    set_horiz_scroll = 0x26,
    set_scroll = 0x2E,

    set_disp_start_line = 0x40,

    set_constrast = 0x81,
    set_charge_pump = 0x8D,

    set_seg_remap = 0xA0,
    set_entire_on = 0xA4,
    set_all_on = 0xA5,
    set_norm_disp = 0xA6,
    set_inv_disp = 0xA7,
    set_mux_ratio = 0xA8,
    set_disp = 0xAE,
    set_com_out_dir = 0xC0,
    set_com_out_dir_flip = 0xC0,

    set_disp_offset = 0xD3,
    set_disp_clk_div = 0xD5,
    set_precharge = 0xD9,
    set_com_pin_cfg = 0xDA,
    set_vcom_desel = 0xDB,

    write_mode = 0xFE,
    read_mode = 0xFF,
};

const page_height: u8 = 8;
const num_pages = height / page_height;
const buf_len = num_pages * width;
