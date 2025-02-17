const rl = @import("raylib");
const std = @import("std");
const builtin = @import("builtin");

const state = @import("global_state.zig");
const constants = @import("constants.zig");
const file = @import("file.zig");

pub fn clearDataOnClose() void {
    file.removeAllFiles();
    state.openedFiles.deinit();
    state.inputBuffer.clearAndFree();
    state.pressedKeys.clearAndFree();
    state.fontCharset.clearAndFree();
}

pub fn closeWindow() void {
    rl.closeWindow();

    // Print leaked memory addresses at end of program
    // Only if is in debug release mode
    if (comptime builtin.mode == .Debug) {
        clearDataOnClose(); // This is functionally useless, but helps displaying actual memory leaks
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
