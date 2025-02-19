const std = @import("std");

const nfd = @import("nfd");

const types = @import("types.zig");
const state = @import("global_state.zig");
const toCodepoint = @import("char_to_codepoint.zig");

/// Opens a OS specific file dialog and opens selected file in editor.
/// Silently fails if user cancels or errors.
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

/// Opens a OS specific folder dialog and opens selected folder as CWD.
/// Silently fails if user cancels or errors.
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

/// Adds a file to the list of opened files and displays it in editor.
/// Usually called by procedures inside the `file.zig` file.
pub fn addOpenedFile(file: types.OpenedFile) void {
    if (state.openedFiles.append(file)) |_| {
        displayFile(state.openedFiles.items.len - 1);
    } else |err| {
        std.log.err("Error with addOpenedFile: {any}", .{err});
    }
}

/// Displays one of the opened files using its index in `state.openedFiles`
/// Silently fails if index is out of bounds.
pub fn displayFile(index: usize) void {
    if (index >= state.openedFiles.items.len) return;
    state.currentlyDisplayedFileIdx = index;

    state.currentDisplayedUi = .Editor;
    state.shouldRedrawNext.fileTabs = true;
    state.shouldRedrawNext.textEditor = true;
}

/// Removes one of the opened files using its index and frees its memory.
pub fn removeFile(index: usize) void {

    // TODO: Check for changes and ask user with modal to confirm
    if (index >= state.openedFiles.items.len) return;

    var file = state.openedFiles.orderedRemove(index);

    if (state.currentlyDisplayedFileIdx >= index and state.currentlyDisplayedFileIdx > 0) {
        state.currentlyDisplayedFileIdx -= 1;
    }

    state.allocator.free(file.name);

    if (file.path) |_| {
        state.allocator.free(file.path.?);
    }

    for (file.lines.items) |_line| {
        var line: std.ArrayList(i32) = _line;
        line.deinit();
    }
    file.lines.deinit();

    file.styleCache.deinit();

    state.shouldRedrawNext.fileTabs = true;
    state.shouldRedrawNext.textEditor = true;
}

/// Removes all currently opened files.
pub fn removeAllFiles() void {
    while (state.openedFiles.items.len > 0) {
        removeFile(0);
    }
    state.shouldRedrawNext.fileTabs = true;
    state.shouldRedrawNext.textEditor = true;
}

/// Writes the contents of the file, as well as its modifications, to disk.
///
/// Uses a bufferd writer to reduce the amounts of syscalls, not sure if there
/// is a case where this isn't optimal.
fn writeFile(file: *types.OpenedFile) !void {

    // TODO: Display modals in case of error.
    if (file.path == null) {
        std.log.err("Could not save file, path to file is null.", .{});
    }

    const maybeFile = std.fs.cwd().createFile(
        file.path.?,
        std.fs.File.CreateFlags{},
    );

    var f: std.fs.File = undefined;

    if (maybeFile) |ff| {
        f = ff;
    } else |err| {
        std.log.err("Failed to open file for saving: {s}; Error: {any}", .{ file.path.?, err });
        return error.OpenError;
    }
    defer f.close();

    try f.seekTo(0);
    _ = try f.write("");

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
    std.log.info("Saved file: {s}", .{file.path.?});
}

/// Displays OS specific "Save As" dialog and writes currently displayed file to disk.
///
/// Silently fails if user cancels or errors.
pub fn saveFileAs() void {

    // TODO: Display modals in case of error.
    if (state.openedFiles.items.len == 0) return;

    var currentFile = &state.openedFiles.items[state.currentlyDisplayedFileIdx];

    if (nfd.saveFileDialog(null, null)) |path| {
        if (path) |nonNullPath| {
            const pathSlice = @constCast(nonNullPath);
            currentFile.path = pathSlice;
            currentFile.path.?.len = pathSlice.len;

            const previousFileName = currentFile.name;
            state.allocator.free(previousFileName);

            const newName = state.allocator.dupeZ(u8, std.fs.path.basename(nonNullPath[0..nonNullPath.len])) catch |err| {
                std.log.err("Error with saveFileDialog: {any}", .{err});
                return;
            };

            currentFile.name = newName;

            writeFile(currentFile) catch |err| {
                std.log.err("Error with writeFile: {any}", .{err});
            };
        } else {
            return;
        }
    } else |err| {
        std.log.err("Error with saveFileDialog: {any}", .{err});
    }
}

/// Writes currently displayed file to disk.
/// Displays OS specific "Save As" dialog if is new unsaved file.
///
/// Silently fails if user cancels or errors.
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

/// Adds a new empty file to the list of opened files and displays it in editor.
///
/// "Save As" dialog will appear on save.
pub fn newFile() void {
    const nameZ = state.allocator.dupeZ(u8, "NewFile.txt") catch |err| {
        std.log.err("Error with newFile: {any}", .{err});
        return;
    };

    var openedFile = types.OpenedFile{
        .path = null,
        .name = nameZ,
        .lines = types.UtfLineList.init(state.allocator),
        .styleCache = .{
            .stylesPerLines = std.ArrayList(?std.ArrayList(types.MatchedColor)).init(state.allocator),
            .cachedLinesNb = 0,
            .valid = true,
        },
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

    openedFile.styleCache.resize(openedFile.lines.items.len) catch |err| {
        std.log.err("Error with style cache in newFile: {any}", .{err});
    };

    addOpenedFile(openedFile);
}

/// Opens a file using an absolute path, adds it to the list of opened files
/// and displays it in editor.
pub fn openFile(filePath: []const u8) error{ OpenError, ReadError, OutOfMemory }!void {
    const maxFileSize = @as(usize, 0) -% 1;

    const fileName = std.fs.path.basename(filePath);

    const filePathZ = try state.allocator.dupeZ(u8, filePath);
    const fileNameZ = try state.allocator.dupeZ(u8, fileName);

    var openedFile = types.OpenedFile{
        .path = filePathZ,
        .name = fileNameZ,
        .lines = types.UtfLineList.init(state.allocator),
        .styleCache = .{
            .stylesPerLines = std.ArrayList(?std.ArrayList(types.MatchedColor)).init(state.allocator),
            .cachedLinesNb = 0,
            .valid = true,
        },
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

            var codepoints = try toCodepoint.charToCodepoint(
                state.allocator,
                line,
            );
            defer codepoints.deinit();

            if (codepoints.items.len > 0) {
                // Remove \r on windows platforms
                if (codepoints.items[codepoints.items.len - 1] == @as(i32, '\r')) {
                    _ = codepoints.pop();
                }
            }

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

    try openedFile.styleCache.resize(openedFile.lines.items.len);

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
                const nameZ = try state.allocator.dupeZ(u8, nonNullEntry.name);
                const fullPathZ = try std.fs.path.joinZ(state.allocator, &[_][]const u8{ path, nonNullEntry.name });

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
