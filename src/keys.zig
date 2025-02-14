const std = @import("std");
const rl = @import("raylib");
const state = @import("global_state.zig");
const types = @import("types.zig");
const constants = @import("constants.zig");

/// Polls for currently pressed keys this frame and handles repeating keys
///
/// Result of the polling will be stored in `state.inputBuffer`
pub fn pollInputBuffer() !void {
    // Invalidate released keys
    var i: usize = 0;
    while (true) {
        if (i >= state.pressedKeys.items.len) break;
        var keyState = &state.pressedKeys.items[i];

        if (keyState.keyChar.key == .null or rl.isKeyUp(keyState.keyChar.key)) {
            //std.log.info("Released: {any}", .{keyState.keyChar.char});
            _ = state.pressedKeys.orderedRemove(i);
        } else {
            keyState.pressedFrames += 1;
            i += 1;
        }
    }

    // Get just pressed keys
    while (true) {
        const key: rl.KeyboardKey = rl.getKeyPressed();
        const char: i32 = rl.getCharPressed();

        if (key == rl.KeyboardKey.null) break;

        const keyState = types.PressedKeyState{
            .keyChar = .{
                .key = key,
                .char = char,
            },
            .pressedFrames = 0,
        };
        try state.pressedKeys.append(keyState);
        //std.log.info("Pressed: {any}", .{keyState.keyChar.char});
    }

    // Fill input buffer if key just pressed or repeating key
    state.inputBuffer.clearRetainingCapacity();

    const initialRepeatFrameAmount: usize = @intFromFloat(0.25 * @as(f32, @floatFromInt(state.currentTargetFps)));
    const repeatFrameInterval: usize = @intFromFloat(0.05 * @as(f32, @floatFromInt(state.currentTargetFps)));

    for (state.pressedKeys.items) |keyState| {
        if (keyState.pressedFrames == 0) {
            try state.inputBuffer.append(keyState.keyChar);
        } else if (keyState.pressedFrames > initialRepeatFrameAmount and keyState.pressedFrames % repeatFrameInterval == 0) {
            try state.inputBuffer.append(keyState.keyChar);
        }
    }
}
