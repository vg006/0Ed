const std = @import("std");
const state = @import("global_state.zig");

pub fn charToCodepoint(allocator: std.mem.Allocator, s: []u8) !std.ArrayList(i32) {
    var codepoints = std.ArrayList(i32).init(allocator);

    var it = std.unicode.Utf8Iterator{ .bytes = s, .i = 0 };

    while (it.nextCodepoint()) |codepoint| {
        try codepoints.append(@intCast(codepoint));
    }
    return codepoints;
}
