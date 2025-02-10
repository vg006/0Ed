const rl = @import("raylib");

const state = @import("global_state.zig");
const types = @import("types.zig");

pub fn isMouseInRect(rect: types.Recti32) bool {
    const mouseX: i32 = @intFromFloat(state.mousePosition.x);
    const mouseY: i32 = @intFromFloat(state.mousePosition.y);
    if (mouseX < rect.x + 1 or mouseY < rect.y + 1) return false;
    if (mouseX < rect.x + rect.width and mouseY < rect.y + rect.height) return true;
    return false;
}
