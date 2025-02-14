const std = @import("std");

const nfd = @import("nfd");

const types = @import("types.zig");
const state = @import("global_state.zig");
const toCodepoint = @import("char_to_codepoint.zig");

// Function called by button callback, cannot return error
pub fn openFileDialog() void {
    // TODO: default path should be CWD
    if (nfd.openFileDialog(null, null)) |path| {
        if (path) |nonNullPath| {
            openFile(nonNullPath) catch |err| {
                std.log.err("Error when trying to open file: {s} {any}", .{ nonNullPath, err });
            };
        }
    } else |err| {
        // TODO: Show error modal when implemented
        std.log.err("Error with openFileDialog: {any}", .{err});
    }
}

// Function called by button callback, cannot return error
pub fn openFolderDialog() void {
    // TODO: default path should be CWD
    if (nfd.openFolderDialog(null)) |path| {
        if (path) |nonNullPath| {
            openFolder(nonNullPath) catch |err| {
                std.log.err("Error when trying to open folder: {s} {any}", .{ nonNullPath, err });
            };
        }
    } else |err| {
        // TODO: Show error modal when implemented
        std.log.err("Error with openFileDialog: {any}", .{err});
    }
}

pub fn addOpenedFile(file: types.OpenedFile) void {
    if (state.openedFiles.append(file)) |_| {
        state.currentlyDisplayedFileIdx = state.openedFiles.items.len - 1;

        state.shouldRedrawNext.fileTabs = true;
        state.shouldRedrawNext.textEditor = true;
    } else |err| {
        std.log.err("Error with addOpenedFile: {any}", .{err});
    }
}

// Function called by button callback, cannot return error
pub fn displayFile(index: usize) void {
    if (index >= state.openedFiles.items.len) return;
    state.currentlyDisplayedFileIdx = index;

    state.shouldRedrawNext.textEditor = true;
}

// Function called by button callback, cannot return error
pub fn removeFile(index: usize) void {
    if (index >= state.openedFiles.items.len) return;

    var file = state.openedFiles.orderedRemove(index);
    //var file = &state.openedFiles.items[index];

    if (state.currentlyDisplayedFileIdx >= index and state.currentlyDisplayedFileIdx > 0) {
        state.currentlyDisplayedFileIdx -= 1;
    }

    state.allocator.free(file.name);

    if (file.path) |nonNullPath| {
        state.allocator.free(nonNullPath);
    }

    for (file.lines.items) |_line| {
        var line: std.ArrayList(i32) = _line;
        line.deinit();
    }
    file.lines.deinit();

    state.shouldRedrawNext.fileTabs = true;
    state.shouldRedrawNext.textEditor = true;
}

pub fn removeAllFiles() void {
    while (state.openedFiles.items.len > 0) {
        removeFile(0);
    }
}

fn writeFile(file: *types.OpenedFile) !void {
    if (file.path == null) return;

    const maybeFile = std.fs.cwd().openFile(
        file.path.?,
        std.fs.File.OpenFlags{ .mode = .write_only },
    );

    var f: std.fs.File = undefined;

    if (maybeFile) |ff| {
        f = ff;
    } else |err| {
        std.log.err("Failed to open file for saving: {s}; Error: {any}", .{ file.path.?, err });
        return error.OpenError;
    }
    defer f.close();

    var bufWriter = std.io.bufferedWriter(f.writer());

    for (file.lines.items) |line| {
        for (line.items) |codepoint| {
            var utfBuf: [4]u8 = undefined;
            const seqLen: usize = @intCast(try std.unicode.utf8Encode(@intCast(codepoint), &utfBuf));
            _ = try bufWriter.write(utfBuf[0..seqLen]);
        }
        const newLine = [1]u8{'\n'};
        _ = try bufWriter.write(&newLine);
    }

    try bufWriter.flush();
}

// Function called by button callback, cannot return error
pub fn saveFileAs() void {
    if (state.openedFiles.items.len == 0) return;

    var currentFile = state.openedFiles.items[state.currentlyDisplayedFileIdx];

    if (nfd.saveFileDialog(null, null)) |path| {
        currentFile.path = path;
        writeFile(&currentFile) catch |err| {
            std.log.err("Error with writeFile: {any}", .{err});
        };
    } else |err| {
        std.log.err("Error with saveFileDialog: {any}", .{err});
    }
}

// Function called by button callback, cannot return error
pub fn saveFile() void {
    if (state.openedFiles.items.len == 0) return;

    var currentFile = state.openedFiles.items[state.currentlyDisplayedFileIdx];

    if (currentFile.path) |_| {
        writeFile(&currentFile) catch |err| {
            std.log.err("Error with writeFile: {any}", .{err});
        };
    } else {
        saveFileAs();
    }
}

// Function called by button callback, cannot return error
pub fn newFile() void {
    const nameZ = state.allocator.dupeZ(u8, "NewFile.txt") catch |err| {
        std.log.err("Error with newFile: {any}", .{err});
        return;
    };

    var openedFile = types.OpenedFile{
        .path = null,
        .name = nameZ,
        .lines = std.ArrayList(std.ArrayList(i32)).init(state.allocator),
        .cursorPos = types.CursorPosition{
            .start = .{
                .column = 0,
                .line = 0,
            },
            .end = null,
            .dragOrigin = null,
        },
        .scroll = .{ .x = 0.0, .y = 0.0 },
    };

    // Add 1 empty line to the file
    if (openedFile.lines.append(std.ArrayList(i32).init(state.allocator))) |_| {} else |err| {
        std.log.err("Error with newFile: {any}", .{err});
    }

    addOpenedFile(openedFile);
}

pub fn openFile(filePath: []const u8) error{ OpenError, ReadError, OutOfMemory }!void {
    const maxFileSize = @as(usize, 0) -% 1;

    const fileName = std.fs.path.basename(filePath);

    const filePathZ = try state.allocator.dupeZ(u8, filePath);
    const fileNameZ = try state.allocator.dupeZ(u8, fileName);

    var openedFile = types.OpenedFile{
        .path = filePathZ,
        .name = fileNameZ,
        .lines = std.ArrayList(std.ArrayList(i32)).init(state.allocator),
        .cursorPos = types.CursorPosition{
            .start = .{
                .column = 0,
                .line = 0,
            },
            .end = null,
            .dragOrigin = null,
        },
        .scroll = .{ .x = 0.0, .y = 0.0 },
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
        state.allocator,
        '\n',
        maxFileSize,
    )) |maybeLine| {
        if (maybeLine) |line| {
            defer state.allocator.free(line);

            const codepoints = try toCodepoint.charToCodepoint(
                state.allocator,
                line,
            );

            defer codepoints.deinit();

            const lineList = std.ArrayList(types.CodePoint).init(state.allocator);
            try openedFile.lines.append(lineList);
            try openedFile.lines.append(std.ArrayList(types.CodePoint).init(state.allocator));
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

    if (openedFile.lines.items.len == 0) {
        // Add 1 empty line to the file
        if (openedFile.lines.append(std.ArrayList(i32).init(state.allocator))) |_| {} else |err| {
            std.log.err("Error with openFile: {any}", .{err});
        }
    }

    addOpenedFile(openedFile);
}

fn openFolderRecursive(path: [:0]const u8) !types.FileSystemTree {
    std.debug.print("openFolderRecursive with path: {s}\n", .{path});
    const folderName = std.fs.path.basename(path);

    const folderPathZ = try state.allocator.dupeZ(u8, path);
    const folderNameZ = try state.allocator.dupeZ(u8, folderName);

    var children = std.ArrayList(types.FileSystemTree).init(state.allocator);

    var dir = try std.fs.openDirAbsolute(path, .{ .iterate = true });
    defer dir.close();

    var dirIter = dir.iterate();

    while (dirIter.next()) |entry| {
        if (entry) |nonNullEntry| {
            if (nonNullEntry.kind != .directory and nonNullEntry.kind != .file) continue;

            if (nonNullEntry.kind == .directory) {
                const fullPathZ = try std.fs.path.joinZ(state.allocator, &[_][]const u8{ path, nonNullEntry.name });
                try children.append(try openFolderRecursive(fullPathZ));
                state.allocator.free(fullPathZ);
            } else {
                const nameZ: [:0]const u8 = try state.allocator.dupeZ(u8, nonNullEntry.name);
                const fullPathZ: [:0]const u8 = try std.fs.path.joinZ(state.allocator, &[_][]const u8{ path, nonNullEntry.name });

                try children.append(.{
                    .name = nameZ,
                    .path = fullPathZ,
                    .type = .File,
                    .children = std.ArrayList(types.FileSystemTree).init(state.allocator),
                    .expanded = false,
                });
            }
        } else {
            break;
        }
    } else |err| {
        std.log.err("Error with openFile: {any}", .{err});
        return err;
    }

    return types.FileSystemTree{
        .name = folderNameZ,
        .path = folderPathZ,
        .type = .Folder,
        .children = children,
        .expanded = false,
    };
}

pub fn openFolder(folderPath: []const u8) !void {
    state.currentlyDisplayedFileIdx = 0;

    while (state.openedFiles.items.len > 0) {
        removeFile(0);
    }

    const folderPathZ = try state.allocator.dupeZ(u8, folderPath);
    state.openedDir = try openFolderRecursive(folderPathZ);
    state.allocator.free(folderPathZ);
}
