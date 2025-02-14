const std = @import("std");
const state = @import("global_state.zig");

/// Converts a 1 byte char array to a 4 bytes char array, UTF8 sequences are
/// encoded as a single char.
///
/// You might want to use this as a way to draw UTF8 strings using raylib's
/// `rl.drawTextCodepoints()`
///
/// Consumer is responsible for `deinit` of the result ArrayList.
pub fn charToCodepoint(allocator: std.mem.Allocator, s: []u8) !std.ArrayList(i32) {
    var codepoints = std.ArrayList(i32).init(allocator);

    var it = std.unicode.Utf8Iterator{ .bytes = s, .i = 0 };
    while (it.nextCodepoint()) |codepoint| {
        try codepoints.append(@intCast(codepoint));
    }
    return codepoints;
}
