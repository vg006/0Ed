const std = @import("std");
const rl = @import("raylib");
const state = @import("global_state.zig");
const types = @import("types.zig");
const constants = @import("constants.zig");

pub fn getInputBuffer() !void {
    // Invalidate released keys
    var i: usize = 0;
    while (true) {
        if (i >= state.pressedKeys.items.len) break;

        var keyState = &state.pressedKeys.items[i];

        if (keyState.keyChar.key == .null or rl.isKeyUp(keyState.keyChar.key)) {
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

        if (key == rl.KeyboardKey.null and char == 0) break;

        const keyState = types.PressedKeyState{
            .keyChar = .{
                .key = key,
                .char = char,
            },
            .pressedFrames = 0,
        };
        try state.pressedKeys.append(keyState);
    }

    // Fill input buffer if key just pressed or repeating key
    state.inputBuffer.clearRetainingCapacity();
    for (state.pressedKeys.items) |keyState| {
        if (keyState.pressedFrames == 0) {
            try state.inputBuffer.append(keyState.keyChar);
        } else if (keyState.pressedFrames > constants.keyPressRepeatFrameNb and
            keyState.pressedFrames % 2 == 0)
        {
            try state.inputBuffer.append(keyState.keyChar);
        }
    }

    // std.debug.print("                                                ", .{});
    // std.debug.print("\rPressed keys: ", .{});

    // for (state.inputBuffer.items) |keyChar| {
    //     std.debug.print("key:{any} char:{d}, ", .{ keyChar.key, keyChar.char });
    // }
}
