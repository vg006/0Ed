const std = @import("std");

const rl = @import("raylib");

const types = @import("types.zig");
const state = @import("global_state.zig");
const constants = @import("constants.zig");

pub fn createTerminalProcess() !void {
    state.terminalProcess = std.process.Child.init(
        &[_][]const u8{ constants.terminalCommand, constants.terminalCommandArg },
        state.allocator,
    );

    // TODO: destroy and re-create process on
    state.terminalProcess.cwd = try std.process.getCwdAlloc(state.allocator); // This is not a memory leak, terminal has same lifetime as program.

    state.terminalProcess.stdout_behavior = .Pipe;
    state.terminalProcess.stderr_behavior = .Pipe;
    state.terminalProcess.stdin_behavior = .Pipe;

    try state.terminalProcess.spawn();
    try state.terminalProcess.waitForSpawn();

    state.terminalStdoutThread = try createStreamReaderThread(state.terminalProcess.stdout.?.reader(), &state.terminalStdoutBuff, &state.terminalStdoutBuffMutex);
    state.terminalStderrThread = try createStreamReaderThread(state.terminalProcess.stderr.?.reader(), &state.terminalStderrBuff, &state.terminalStderrBuffMutex);

    //try sendInput("where python\n");
}

fn readToBuff(from: std.fs.File.Reader, to: *std.ArrayList(u8), mutex: *std.Thread.Mutex) !void {
    const maybeByte = from.readByte();

    if (maybeByte) |byte| {
        while (!mutex.tryLock()) {
            std.Thread.sleep(10000000);
        }
        try to.append(byte);
        mutex.unlock();
    } else |err| switch (err) {
        error.EndOfStream => return,
        else => {
            return err;
        },
    }
}

fn createStreamReaderThread(reader: std.fs.File.Reader, buffer: *std.ArrayList(u8), mutex: *std.Thread.Mutex) !std.Thread {
    return std.Thread.spawn(
        .{ .allocator = state.allocator },
        readStream,
        .{ reader, buffer, mutex },
    );
}

fn readStream(reader: std.fs.File.Reader, buffer: *std.ArrayList(u8), mutex: *std.Thread.Mutex) !void {
    while (true) {
        if (state.shouldEndAllThreads) break;

        if (readToBuff(reader, buffer, mutex)) {} else |err| {
            std.log.err("Error in Terminal output reading thread: {any}", .{err});
            break;
        }
    }
}

fn addLineOrAppendToTerminal(codepoints: std.ArrayList(i32)) !void {
    if (codepoints.items.len > 0) {
        var lastChar: i32 = 0;
        var lastLine: ?*std.ArrayList(i32) = null;

        if (state.terminalBuffer.items.len > 0) {
            const line: std.ArrayList(i32) = state.terminalBuffer.items[state.terminalBuffer.items.len - 1];

            if (line.items.len > 0) {
                lastLine = &state.terminalBuffer.items[state.terminalBuffer.items.len - 1];
                lastChar = line.items[line.items.len - 1];
            }
        }

        if (lastChar != 0) {
            try lastLine.?.appendSlice(codepoints.items);
            codepoints.deinit();
        } else {
            try state.terminalBuffer.append(codepoints);
        }
    } else {
        codepoints.deinit();
    }
}

fn pollStream(stdBuff: *std.ArrayList(u8)) !void {
    var codepoints = std.ArrayList(i32).init(state.allocator);

    var it = std.unicode.Utf8Iterator{
        .bytes = stdBuff.items,
        .i = 0,
    };

    while (it.nextCodepoint()) |c| {
        if (c == @as(u21, @intCast('\r'))) continue;
        if (c == @as(u21, @intCast('\n'))) {
            try codepoints.append(0);
            try addLineOrAppendToTerminal(codepoints);
            codepoints = std.ArrayList(i32).init(state.allocator);
            continue;
        }
        try codepoints.append(@intCast(c));
    }
    try addLineOrAppendToTerminal(codepoints);

    stdBuff.clearRetainingCapacity();
}

pub fn pollTerminalOutput() !void {
    if (state.terminalStdoutBuff.items.len > 0 and state.terminalStdoutBuffMutex.tryLock()) {
        defer state.terminalStdoutBuffMutex.unlock();
        try pollStream(&state.terminalStdoutBuff);
    }

    if (state.terminalStderrBuff.items.len > 0 and state.terminalStderrBuffMutex.tryLock()) {
        defer state.terminalStderrBuffMutex.unlock();
        try pollStream(&state.terminalStderrBuff);
    }
}

pub inline fn sendInput(input: []const u8) !void {
    return state.terminalProcess.stdin.?.writeAll(input);
}

pub fn handleTerminalInput() !bool {
    var stateChanged = false;
    var keyIdx: usize = state.inputBuffer.items.len -% 1;

    while (keyIdx != std.math.maxInt(usize)) {
        // Get last key in input buffer
        const key: types.KeyChar = state.inputBuffer.items[keyIdx];
        keyIdx -%= 1;

        // Key is non-control character, collapse selection and write to line
        if (key.char != 0) {
            try state.terminalUserInputBuffer.append(key.char);
            stateChanged = true;
        }
        // Handle Enter
        else if (key.key == .enter) {
            var u8InputBuff = std.ArrayList(u8).init(state.allocator);
            defer u8InputBuff.deinit();

            for (state.terminalUserInputBuffer.items) |c| {
                var utfBuf: [4]u8 = undefined;
                const seqLen: usize = @intCast(try std.unicode.utf8Encode(@intCast(c), &utfBuf));
                try u8InputBuff.appendSlice(utfBuf[0..seqLen]);
            }
            try u8InputBuff.append('\n');

            try sendInput(u8InputBuff.items);
            state.terminalUserInputBuffer.clearRetainingCapacity();
            stateChanged = true;
        }
        // Handle Backspace
        else if (key.key == .backspace) {
            _ = state.terminalUserInputBuffer.pop();
            stateChanged = true;
        }
        // TODO: Handle other special keys
    }
    return stateChanged;
}

pub fn displayTerminalContents(terminalRect: types.Recti32) !void {
    //var arena = std.heap.ArenaAllocator.init(state.allocator);
    //defer arena.deinit();
    //const alloc = arena.allocator();
    const fontSize: usize = 20;
    const fontWidth: usize = 10;
    //const topOffset: usize = @intCast(terminalRect.y + constants.paddingSize);
    const leftOffset: usize = @intCast(terminalRect.x + constants.paddingSize);

    const scrolledTop: i32 = @as(i32, @intFromFloat(state.terminalScroll.y)) + terminalRect.y + constants.paddingSize;

    const renderBoundTop: i32 = terminalRect.y - constants.paddingSize;
    const renderBoundBott: i32 = state.windowHeight + constants.paddingSize;

    const firstLineIdx: usize = @intCast(@max(0, @divFloor((renderBoundTop - scrolledTop), constants.lineHeight)));

    var textPos = rl.Vector2{
        .x = @floatFromInt(leftOffset),
        .y = 0.0,
    };

    var i: usize = firstLineIdx;
    while (i < state.terminalBuffer.items.len) : (i += 1) {
        const idx: i32 = @intCast(i);
        const line: types.UtfLine = state.terminalBuffer.items[i];

        const yPos: i32 = idx * constants.lineHeight + scrolledTop;
        if (yPos > renderBoundBott) break;

        var isNullTerminated = false;

        if (line.items.len > 0 and line.items[line.items.len - 1] == 0) {
            isNullTerminated = true;
        }
        textPos.y = @floatFromInt(yPos);

        rl.drawTextCodepoints(
            state.codeFont,
            if (isNullTerminated) line.items[0 .. line.items.len - 1] else line.items,
            textPos,
            @floatFromInt(fontSize),
            0,
            constants.colorCodeFont,
        );

        if (i == state.terminalBuffer.items.len - 1) {
            rl.drawTextCodepoints(
                state.codeFont,
                state.terminalUserInputBuffer.items,
                .{
                    .x = textPos.x + @as(f32, @floatFromInt(line.items.len * fontWidth)),
                    .y = textPos.y,
                },
                @floatFromInt(fontSize),
                0,
                constants.colorUiFont,
            );
            rl.drawRectangleRec(
                .{
                    .x = textPos.x + @as(f32, @floatFromInt((line.items.len + state.terminalUserInputBuffer.items.len) * fontWidth)),
                    .y = textPos.y,
                    .width = 2,
                    .height = @floatFromInt(fontSize),
                },
                rl.Color.white,
            );
        }
    }
}

pub fn killTerminal() void {
    state.shouldEndAllThreads = true;

    // Send dud input to terminal to update the output reading threads.
    // If this isn't done, threads will stay locked and panic on proc kill.
    if (sendInput(constants.terminalStdoutRefreshCommand)) |_| {} else |err| {
        std.log.err("Error when sending file command to terminal proc: {any}", .{err});
    }
    state.terminalStdoutThread.join();

    if (sendInput(constants.terminalStderrRefreshCommand)) |_| {} else |err| {
        std.log.err("Error when sending file command to terminal proc: {any}", .{err});
    }
    state.terminalStderrThread.join();

    state.allocator.free(state.terminalProcess.cwd.?);

    if (state.terminalProcess.kill()) |_| {} else |err| {
        std.log.err("Error when killing terminal proc: {any}", .{err});
    }
}
