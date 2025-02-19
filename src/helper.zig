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

pub inline fn castf(x: comptime_int) comptime_float {
    return @floatFromInt(x);
}

pub inline fn casti(x: comptime_float) comptime_int {
    return @intFromFloat(x);
}

pub inline fn castii(x: comptime_int) comptime_int {
    return @intCast(x);
}

pub inline fn castff(x: comptime_float) comptime_float {
    return @floatCast(x);
}

pub inline fn castf32(x: comptime_int) f32 {
    return @floatFromInt(x);
}

pub inline fn casti32(x: comptime_int) i32 {
    return @intCast(x);
}

pub inline fn castfi32(x: comptime_float) i32 {
    return @intFromFloat(x);
}

pub inline fn cast(comptime T: type, x: anytype) @TypeOf(T) {
    return @as(T, x);
}
