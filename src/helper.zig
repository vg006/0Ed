const std = @import("std");
const rl = @import("raylib");

const types = @import("types.zig");

pub fn floatEq(a: f32, b: f32, precision: f32) bool {
    return @abs(a - b) < precision;
}

pub inline fn vecToi32(vec: rl.Vector2) types.Vec2i32 {
    return types.Vec2i32{ .x = @intFromFloat(vec.x), .y = @intFromFloat(vec.y) };
}

pub inline fn veci32ToRl(vec: types.Vec2i32) rl.Vector2 {
    return rl.Vector2{ .x = @floatFromInt(vec.x), .y = @floatFromInt(vec.y) };
}
