const rl = @import("raylib");
const std = @import("std");
const builtin = @import("builtin");

const state = @import("global_state.zig");
const constants = @import("constants.zig");
const file = @import("file.zig");
const terminal = @import("terminal.zig");

/// As most people will remark, this function is useless in a vaccum considering
/// the OS will reclaim the memory at close.
/// We use this to track memory leaks.
pub fn clearDataOnClose() void {
    file.removeAllFiles();
    state.openedFiles.deinit();
    state.inputBuffer.clearAndFree();
    state.pressedKeys.clearAndFree();
    state.fontCharset.clearAndFree();

    for (state.zigStyles) |style| {
        if (style.regex) |re| {
            re.deinit();
        }
    }

    state.terminalStdoutBuff.deinit();
    state.terminalStderrBuff.deinit();
    state.terminalUserInputBuffer.deinit();

    for (state.terminalBuffer.items) |_line| {
        var line: std.ArrayList(i32) = _line;
        line.deinit();
    }
    state.terminalBuffer.deinit();

    std.log.info("Successfully cleared all allocated memory.", .{});
}

pub fn closeWindow() void {
    rl.closeWindow();
    terminal.killTerminal();

    // Print leaked memory addresses at end of program
    // Only if is in debug release mode
    if (comptime builtin.mode == .Debug) {
        clearDataOnClose();
        _ = state.debugAllocator.detectLeaks();
    }
    std.process.exit(0);
}

pub fn maximizeWindow() void {
    state.windowSizeAndPosBeforeMaximized = .{
        .x = @intFromFloat(state.windowPosition.x),
        .y = @intFromFloat(state.windowPosition.y),
        .width = state.windowWidth,
        .height = state.windowHeight,
    };
    const monitor: i32 = rl.getCurrentMonitor();
    rl.setWindowSize(
        rl.getMonitorWidth(monitor),
        rl.getMonitorHeight(monitor) - 48,
    );
    rl.setWindowPosition(0, 0);
    state.windowPosition = .{
        .x = 0,
        .y = 0,
    };

    state.windowHeight = rl.getScreenHeight();
    state.windowWidth = rl.getScreenWidth();
    state.mousePosition = rl.getMousePosition();
    state.windowMaximized = true;

    state.shouldRedrawNext = .{
        .textEditor = true,
        .fileTabs = true,
        .sideBar = true,
        .terminal = true,
        .topBar = true,
    };
}

pub fn unmaximizeWindow() void {
    rl.setWindowPosition(
        state.windowSizeAndPosBeforeMaximized.x,
        state.windowSizeAndPosBeforeMaximized.y,
    );
    rl.setWindowSize(
        state.windowSizeAndPosBeforeMaximized.width,
        state.windowSizeAndPosBeforeMaximized.height,
    );
    state.windowHeight = rl.getScreenHeight();
    state.windowWidth = rl.getScreenWidth();
    state.mousePosition = rl.getMousePosition();
    state.windowMaximized = false;

    state.shouldRedrawNext = .{
        .textEditor = true,
        .fileTabs = true,
        .sideBar = true,
        .terminal = true,
        .topBar = true,
    };
}

pub fn toggleMaximizeWindow() void {
    if (state.windowMaximized) {
        unmaximizeWindow();
    } else {
        maximizeWindow();
    }
}

pub fn minimizeWindow() void {
    rl.minimizeWindow();
}

pub fn setTargetFps(fps: i32) void {
    state.targetFps = fps;
    rl.setTargetFPS(state.targetFps);
    state.currentTargetFps = state.targetFps;
    const targetFpsF: f64 = @floatFromInt(state.currentTargetFps);
    state.currentMsPerFrame = @intFromFloat((1.0 / targetFpsF) * 1000.0);
    const refreshIntervalF: f64 = @floatFromInt(constants.forceRefreshIntervalMs);
    state.forceRefreshIntervalFrames = std.math.ceilPowerOfTwoAssert(usize, @intFromFloat((refreshIntervalF / 1000.0) * 120.0));
}
