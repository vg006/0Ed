const std = @import("std");
const types = @import("types.zig");
const state = @import("global_state.zig");
const toCodepoint = @import("char_to_codepoint.zig");

pub fn openFile(allocator: std.mem.Allocator, filePath: []const u8) error{ OpenError, ReadError, OutOfMemory }!void {
    const maxFileSize = @as(usize, 0) -% 1;

    var openedFile = types.OpenedFile{
        .path = filePath,
        .name = std.fs.path.basename(filePath),
        .lines = std.ArrayList(std.ArrayList(i32)).init(allocator),
        .cursorPos = types.CursorPosition{
            .start = .{
                .column = 0,
                .line = 0,
            },
            .end = null,
            .dragOrigin = null,
        },
    };

    const maybeFile = std.fs.cwd().openFile(
        filePath,
        std.fs.File.OpenFlags{},
    );

    var f: std.fs.File = undefined;

    if (maybeFile) |file| {
        f = file;
    } else |err| {
        std.log.err("Failed to open file: {s}; Error: {any}", .{ filePath, err });
        return error.OpenError;
    }

    defer f.close();

    const fReader = f.reader();

    std.log.info("Reading file: {s}", .{filePath});

    while (fReader.readUntilDelimiterOrEofAlloc(
        allocator,
        '\n',
        maxFileSize,
    )) |maybeLine| {
        if (maybeLine) |line| {
            defer allocator.free(line);

            const codepoints = try toCodepoint.charToCodepoint(
                state.allocator,
                line,
            );

            defer codepoints.deinit();

            const lineList = std.ArrayList(types.CodePoint).init(allocator);
            try openedFile.lines.append(lineList);
            var lastList: *std.ArrayList(types.CodePoint) = &openedFile.lines.items[openedFile.lines.items.len - 1];

            try lastList.appendSlice(codepoints.items);
        } else {
            break;
        }
    } else |err| {
        if (err != error.EndOfStream) {
            std.log.err("Failed to read file: {s}; Error: {any}", .{ filePath, err });
            return error.ReadError;
        }
    }

    try state.openedFiles.append(openedFile);
}
