const rl = @import("raylib");
const std = @import("std");
const builtin = @import("builtin");

const state = @import("global_state.zig");
const file = @import("file.zig");

pub fn clearDataOnClose() void {
    file.removeAllFiles();
    state.openedFiles.deinit();
}

pub fn closeWindow() void {
    rl.closeWindow();
    clearDataOnClose();

    // Print leaked memory addresses at end of program
    // Only if is in debug release mode
    if (comptime builtin.mode == .Debug) {
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
