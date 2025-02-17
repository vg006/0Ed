const rl = @import("raylib");

const state = @import("global_state.zig");
const types = @import("types.zig");

pub fn getMousePosition() void {
    state.mousePosition = rl.getMousePosition();

    state.mousePosi32 = types.Vec2i32{
        .x = @intFromFloat(state.mousePosition.x),
        .y = @intFromFloat(state.mousePosition.y),
    };

    state.mouseScreenPosition = rl.Vector2{
        .x = @round(state.windowPosition.x + state.mousePosition.x),
        .y = @round(state.windowPosition.y + state.mousePosition.y),
    };
}

pub inline fn isMouseInRect(rect: types.Recti32) bool {
    return (state.mousePosi32.x >= rect.x + 1 and
        state.mousePosi32.y >= rect.y + 1 and
        state.mousePosi32.x < rect.x + rect.width and
        state.mousePosi32.y < rect.y + rect.height);
}

pub inline fn isJustLeftClick() bool {
    return (state.mouseLeftClick and !state.prevMouseLeftClick);
}

pub inline fn isJustRightClick() bool {
    return (state.mouseRightClick and !state.prevMouseRightClick);
}

pub inline fn isLeftClickDown() bool {
    return state.mouseLeftClick;
}

pub inline fn isRightClickDown() bool {
    return state.mouseRightClick;
}

pub inline fn setMouseCursor(cursor: rl.MouseCursor) void {
    rl.setMouseCursor(cursor);
}
