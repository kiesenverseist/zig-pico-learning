const std = @import("std");

// Choose your board
const Board =
    // .pico;
    // .pico_w;
    // .pico2;
    .pico2_w;

// Choose whether Stdio goes to USB or UART
const StdioUsb = false;
const PicoStdlibDefine = if (StdioUsb) "LIB_PICO_STDIO_USB" else "LIB_PICO_STDIO_UART";

// Pico SDK path can be specified here for your convenience
const PicoSDKPath: ?[]const u8 = null;

// arm-none-eabi toolchain path may be specified here as well
const ARMNoneEabiPath: ?[]const u8 = null;

pub fn build(b: *std.Build) anyerror!void { // $ls root_id 0

    const target = std.Target.Query{
        .abi = .eabi,
        .cpu_arch = .thumb,
        .cpu_model = .{ .explicit = cpu_model_by_board(Board) },
        .os_tag = .freestanding,
    };

    const optimize = b.standardOptimizeOption(.{});

    const lib = b.addObject(.{
        .name = "main",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = b.resolveTargetQuery(target),
            .optimize = optimize,
        }),
    });

    const make_step = try build_pico(b, lib);

    const uf2_create_step = b.addInstallFile(b.path("build/mlem.uf2"), "firmware.uf2");
    uf2_create_step.step.dependOn(make_step);

    const elf_create_step = b.addInstallFile(b.path("build/mlem.elf"), "firmware.elf");
    elf_create_step.step.dependOn(make_step);

    const bin_step = b.step("bin", "Create firmware.elf and firmware.uf2");
    bin_step.dependOn(&uf2_create_step.step);
    bin_step.dependOn(&elf_create_step.step);

    // const upload_step = b.step("upload", "Upload elf to the pico using the debugger");
    const upload_argv = [_][]const u8{ "openocd", "-f", "interface/cmsis-dap.cfg", "-f", "target/rp2350.cfg", "-c", "\"adapter speed 5000\"", "-c", "\"program ./zig-out/firmware.elf verify reset exit\"" };
    const upload_step = b.addSystemCommand(&upload_argv);
    upload_step.step.dependOn(&elf_create_step.step);

    const docs_install = b.addInstallDirectory(.{
        .source_dir = lib.getEmittedDocs(),
        .install_dir = .prefix,
        .install_subdir = "doc",
    });
    docs_install.step.dependOn(&lib.step);

    const docs_step = b.step("doc", "Build docs into zig-out/doc");
    docs_step.dependOn(&docs_install.step);

    b.getInstallStep().dependOn(&docs_install.step);
    b.getInstallStep().dependOn(bin_step);
}

/// Do the stuff to build and link the pico sdk
/// This function contains two steps:
/// 1. run the cmake configuration
pub fn build_pico(b: *std.Build, lib: *std.Build.Step.Compile) anyerror!*std.Build.Step {
    // get and perform basic verification on the pico sdk path
    // if the sdk path contains the pico_sdk_init.cmake file then we know its correct
    const pico_sdk_path = if (PicoSDKPath) |sdk_path|
        sdk_path
    else
        std.process.getEnvVarOwned(b.allocator, "PICO_SDK_PATH") catch |err| {
            std.log.err("The Pico SDK path must be set either through the PICO_SDK_PATH environment variable or at the top of build.zig.", .{});
            return err;
        };

    const pico_init_cmake_path = b.pathJoin(&.{ pico_sdk_path, "pico_sdk_init.cmake" });
    std.fs.cwd().access(pico_init_cmake_path, .{}) catch |err| {
        std.log.err(
            \\Provided Pico SDK path does not contain the file pico_sdk_init.cmake
            \\Tried: {s}
            \\Are you sure you entered the path correctly?"
        , .{pico_init_cmake_path});
        return err;
    };

    // default arm-none-eabi includes
    lib.linkLibC();

    // Standard libary headers may be in different locations on different platforms
    const arm_header_location = blk: {
        if (ARMNoneEabiPath) |path| {
            break :blk path;
        }

        if (std.process.getEnvVarOwned(b.allocator, "ARM_NONE_EABI_PATH") catch null) |path| {
            break :blk path;
        }

        const unix_path = "/usr/arm-none-eabi/include";
        if (std.fs.accessAbsolute(unix_path, .{})) |_| {
            break :blk unix_path;
        } else |err| err catch {};

        break :blk error.StandardHeaderLocationNotSpecified;
    } catch |err| {
        std.log.err(
            \\Could not determine ARM Toolchain include directory.
            \\Please set the ARM_NONE_EABI_PATH environment variable with the correct path
            \\or set the ARMNoneEabiPath variable at the top of build.zig
        , .{});
        return err;
    };
    lib.addSystemIncludePath(.{ .cwd_relative = arm_header_location });

    // Sort out the platform specifics
    const IsRP2040 = Board == .pico or Board == .pico_w;
    const Platform = comptime platform_by_board(Board);

    // find the board header
    const board_header = blk: {
        const header_file = @tagName(Board) ++ ".h";
        const _board_header = b.pathJoin(&.{ pico_sdk_path, "src/boards/include/boards", header_file });

        std.fs.cwd().access(_board_header, .{}) catch |err| {
            std.log.err("Could not find the header file for board '{s}'\n", .{@tagName(Board)});
            return err;
        };

        break :blk header_file;
    };

    // Autogenerate the header file like the pico sdk would
    const cmsys_exception_prefix = if (IsRP2040) "" else "//";
    const header_str = try std.fmt.allocPrint(b.allocator,
        \\#include "{s}/src/boards/include/boards/{s}"
        \\{s}#include "{s}/src/rp2_common/cmsis/include/cmsis/rename_exceptions.h"
    , .{ pico_sdk_path, board_header, cmsys_exception_prefix, pico_sdk_path });

    // Write and include the generated header
    const config_autogen_step = b.addWriteFile("pico/config_autogen.h", header_str);
    lib.step.dependOn(&config_autogen_step.step);
    lib.addIncludePath(config_autogen_step.getDirectory());

    // requires running cmake at least once
    lib.addSystemIncludePath(b.path("build/generated/pico_base"));

    // PICO SDK includes
    // Find all folders called include in the Pico SDK
    {
        const pico_sdk_src = try std.fmt.allocPrint(b.allocator, "{s}/src", .{pico_sdk_path});
        var dir = try std.fs.cwd().openDir(pico_sdk_src, .{
            .iterate = true,
            .no_follow = true,
        });

        const allowed_paths = [_][]const u8{ @tagName(Platform), "rp2_common", "common" };

        var walker = try dir.walk(b.allocator);
        defer walker.deinit();
        while (try walker.next()) |entry| {
            if (std.mem.eql(u8, entry.basename, "include")) {
                for (allowed_paths) |path| {
                    if (std.mem.indexOf(u8, entry.path, path)) |_| {
                        const pico_sdk_include = try std.fmt.allocPrint(b.allocator, "{s}/src/{s}", .{ pico_sdk_path, entry.path });
                        lib.addIncludePath(.{ .cwd_relative = pico_sdk_include });
                        continue;
                    }
                }
            }
        }
    }

    // Define the platform specific macros
    define_platform_specific_macros(lib, Platform);

    // Define UART or USB constant for headers
    lib.root_module.addCMacro(PicoStdlibDefine, "1");

    // required for pico_w wifi
    lib.root_module.addCMacro("PICO_CYW43_ARCH_THREADSAFE_BACKGROUND", "1");
    const cyw43_include = try std.fmt.allocPrint(b.allocator, "{s}/lib/cyw43-driver/src", .{pico_sdk_path});
    lib.addIncludePath(.{ .cwd_relative = cyw43_include });

    // required by cyw43
    const lwip_include = try std.fmt.allocPrint(b.allocator, "{s}/lib/lwip/src/include", .{pico_sdk_path});
    lib.addIncludePath(.{ .cwd_relative = lwip_include });

    // options headers
    lib.addIncludePath(b.path("config/"));

    const compiled = lib.getEmittedBin();
    const install_step = b.addInstallFile(compiled, "mlem.o");
    install_step.step.dependOn(&lib.step);

    // create build directory
    if (std.fs.cwd().makeDir("build")) |_| {} else |err| {
        if (err != error.PathAlreadyExists) return err;
    }

    // run cmake configuration
    const uart_or_usb = if (StdioUsb) "-DSTDIO_USB=1" else "-DSTDIO_UART=1";
    const cmake_pico_sdk_path = b.fmt("-DPICO_SDK_PATH={s}", .{pico_sdk_path});
    const cmake_argv = [_][]const u8{ "cmake", "-B", "./build", "-S .", "-DPICO_BOARD=" ++ @tagName(Board), "-DPICO_PLATFORM=" ++ @tagName(Platform), cmake_pico_sdk_path, uart_or_usb };
    const configure_step = b.addSystemCommand(&cmake_argv);
    configure_step.step.dependOn(&install_step.step);
    // configure_step.expectExitCode(0);

    // build the actual project
    const make_argv = [_][]const u8{ "cmake", "--build", "./build", "--parallel" };
    const make_step = b.addSystemCommand(&make_argv);
    make_step.step.dependOn(&configure_step.step);
    make_step.expectExitCode(0);

    return &make_step.step;
}

// ------------------ Board support

pub fn cpu_model_by_board(board: @TypeOf(.enum_literal)) *const std.Target.Cpu.Model {
    return switch (board) {
        .pico, .pico_w => &std.Target.arm.cpu.cortex_m0plus,
        .pico2, .pico2_w => &std.Target.arm.cpu.cortex_m33,
        else => @compileError("Unknown board type"),
    };
}

pub fn platform_by_board(board: @TypeOf(.enum_literal)) @TypeOf(.enum_literal) {
    return switch (board) {
        .pico, .pico_w => .rp2040,
        .pico2, .pico2_w => .rp2350,
        else => @compileError("Unknown platform"),
    };
}

pub fn define_platform_specific_macros(compile: *std.Build.Step.Compile, platform: @TypeOf(.enum_literal)) void {
    switch (platform) {
        .rp2040 => {
            compile.root_module.addCMacro("PICO_RP2040", "1");
            compile.root_module.addCMacro("PICO_32BIT", "1");
            compile.root_module.addCMacro("PICO_ARM", "1");
            compile.root_module.addCMacro("PICO_CMSIS_DEVICE", "RP2040");
            compile.root_module.addCMacro("PICO_DEFAULT_FLASH_SIZE_BYTES", "\"2 * 1024 * 1024\"");
        },
        .rp2350 => {
            compile.root_module.addCMacro("PICO_RP2350", "1");
            compile.root_module.addCMacro("PICO_32BIT", "1");
            compile.root_module.addCMacro("PICO_ARM", "1");
            compile.root_module.addCMacro("PICO_PIO_VERSION", "1");
            compile.root_module.addCMacro("NUM_DOORBELLS", "1");
            compile.root_module.addCMacro("PICO_CMSIS_DEVICE", "RP2350");
            compile.root_module.addCMacro("PICO_DEFAULT_FLASH_SIZE_BYTES", "\"4 * 1024 * 1024\"");
        },
        else => @compileError("Unknown platform"),
    }
}
