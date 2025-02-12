const rl = @import("raylib");

const types = @import("types.zig");
const mouse = @import("mouse.zig");
const state = @import("global_state.zig");
const constants = @import("constants.zig");

pub fn drawButton(text: [*:0]const u8, fontSize: f32, rect: types.Recti32, padding: types.Vec2i32, callback: *const fn () void) void {
    const hovering = mouse.isMouseInRect(rect);

    if (hovering) {
        state.pointerType = .pointing_hand;
    }

    if (hovering and mouse.isJustLeftClick()) {
        callback();
    }

    rl.drawRectangle(
        rect.x,
        rect.y,
        rect.width,
        rect.height,
        if (hovering) constants.colorHighlightedColumn else constants.colorBackground,
    );
    rl.drawRectangleLines(
        rect.x,
        rect.y,
        rect.width,
        rect.height,
        constants.colorLines,
    );

    const textPos: rl.Vector2 = rl.Vector2{
        .x = @floatFromInt(rect.x + padding.x),
        .y = @floatFromInt(rect.y + padding.y),
    };
    rl.drawTextEx(
        state.uiFont,
        text,
        textPos,
        fontSize,
        0.0,
        rl.Color.gray,
    );
}

pub fn drawButtonArg(text: [*:0]const u8, fontSize: f32, rect: types.Recti32, padding: types.Vec2i32, arg: anytype, callback: *const fn (@TypeOf(arg)) void) void {
    const hovering = mouse.isMouseInRect(rect);

    if (hovering) {
        state.pointerType = .pointing_hand;
    }

    if (hovering and mouse.isJustLeftClick()) {
        callback(arg);
    }

    rl.drawRectangle(
        rect.x,
        rect.y,
        rect.width,
        rect.height,
        if (hovering) constants.colorHighlightedColumn else constants.colorBackground,
    );
    rl.drawRectangleLines(
        rect.x,
        rect.y,
        rect.width,
        rect.height,
        constants.colorLines,
    );

    const textPos: rl.Vector2 = rl.Vector2{
        .x = @floatFromInt(rect.x + padding.x),
        .y = @floatFromInt(rect.y + padding.y),
    };
    rl.drawTextEx(
        state.uiFont,
        text,
        textPos,
        fontSize,
        0.0,
        rl.Color.gray,
    );
}
