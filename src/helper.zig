const std = @import("std");

pub fn floatEq(a: f32, b: f32, precision: f32) bool {
    return @abs(a - b) < precision;
}
