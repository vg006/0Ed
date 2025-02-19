const std = @import("std");
const rl = @import("raylib");

const state = @import("global_state.zig");
const constants = @import("constants.zig");

pub fn drawDebugInfos() !void {
    const fps = rl.getFPS();
    const fontHeight = 15;
    const fontSize = 17;

    var fpsBuff: [32:0]u8 = undefined;
    _ = try std.fmt.bufPrintZ(&fpsBuff, "FPS:   {d}", .{fps});

    rl.drawTextEx(
        state.uiFont,
        &fpsBuff,
        rl.Vector2{
            .x = 5.0,
            .y = @floatFromInt(constants.topBarHeight + 5),
        },
        fontSize,
        0,
        rl.Color.white,
    );

    if (state.openedFiles.items.len > 0) {
        const cursorPos = state.openedFiles.items[state.currentlyDisplayedFileIdx].cursorPos;

        var cursorStartBuff: [32:0]u8 = undefined;
        _ = try std.fmt.bufPrintZ(
            &cursorStartBuff,
            "Start: Ln:{any} Col:{any}",
            .{ cursorPos.start.line + 1, cursorPos.start.column + 1 },
        );

        var cursorEndBuff: [32:0]u8 = undefined;

        if (cursorPos.end) |_| {
            _ = try std.fmt.bufPrintZ(
                &cursorEndBuff,
                "End:   Ln:{any} Col:{any}",
                .{ cursorPos.end.?.line + 1, cursorPos.end.?.column + 1 },
            );
        } else {
            _ = try std.fmt.bufPrintZ(&cursorEndBuff, "", .{});
        }

        rl.drawTextEx(
            state.uiFont,
            &cursorStartBuff,
            rl.Vector2{
                .x = 5.0,
                .y = @floatFromInt(constants.topBarHeight + 5 + fontHeight),
            },
            fontSize,
            0,
            rl.Color.white,
        );
        rl.drawTextEx(
            state.uiFont,
            &cursorEndBuff,
            rl.Vector2{
                .x = 5.0,
                .y = @floatFromInt(constants.topBarHeight + 5 + 2 * fontHeight),
            },
            fontSize,
            0,
            rl.Color.white,
        );
    }

    var winBuff: [32:0]u8 = undefined;
    _ = try std.fmt.bufPrintZ(&winBuff, "WSize: {d}x{d}", .{ rl.getRenderWidth(), rl.getRenderHeight() });

    rl.drawTextEx(
        state.uiFont,
        &winBuff,
        rl.Vector2{
            .x = 5.0,
            .y = @floatFromInt(constants.topBarHeight + 5 + 3 * fontHeight),
        },
        fontSize,
        0,
        rl.Color.white,
    );

    const wpX: i32 = @intFromFloat(state.windowPosition.x);
    const wpY: i32 = @intFromFloat(state.windowPosition.y);

    var winPosBuff: [32:0]u8 = undefined;
    _ = try std.fmt.bufPrintZ(&winPosBuff, "WPos:  {d}x{d}", .{ wpX, wpY });

    rl.drawTextEx(
        state.uiFont,
        &winPosBuff,
        rl.Vector2{
            .x = 5.0,
            .y = @floatFromInt(constants.topBarHeight + 5 + 4 * fontHeight),
        },
        fontSize,
        0,
        rl.Color.white,
    );

    var mousePosBuff: [32:0]u8 = undefined;
    _ = try std.fmt.bufPrintZ(&mousePosBuff, "Mouse: {d}x{d}", .{ rl.getMouseX(), rl.getMouseY() });

    rl.drawTextEx(
        state.uiFont,
        &mousePosBuff,
        rl.Vector2{
            .x = 5.0,
            .y = @floatFromInt(constants.topBarHeight + 5 + 5 * fontHeight),
        },
        fontSize,
        0,
        rl.Color.white,
    );

    const mspX: i32 = @intFromFloat(state.mouseScreenPosition.x);
    const mspY: i32 = @intFromFloat(state.mouseScreenPosition.y);

    var mouseScreenPosBuff: [32:0]u8 = undefined;
    _ = try std.fmt.bufPrintZ(&mouseScreenPosBuff, "ScrPos:{d}x{d}", .{ mspX, mspY });

    rl.drawTextEx(
        state.uiFont,
        &mouseScreenPosBuff,
        rl.Vector2{
            .x = 5.0,
            .y = @floatFromInt(constants.topBarHeight + 5 + 6 * fontHeight),
        },
        fontSize,
        0,
        rl.Color.white,
    );

    if (state.openedFiles.items.len > 0) {
        const filePtr = &state.openedFiles.items[state.currentlyDisplayedFileIdx];

        var cachedBuff: [32:0]u8 = undefined;
        _ = try std.fmt.bufPrintZ(&cachedBuff, "ReCach:{d}", .{filePtr.styleCache.cachedLinesNb});

        rl.drawTextEx(
            state.uiFont,
            &cachedBuff,
            rl.Vector2{
                .x = 5.0,
                .y = @floatFromInt(constants.topBarHeight + 5 + 7 * fontHeight),
            },
            fontSize,
            0,
            rl.Color.white,
        );
    }
}
