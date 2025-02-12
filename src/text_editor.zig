const std = @import("std");
const rl = @import("raylib");
const regex = @import("regex_codepoint.zig");

const state = @import("global_state.zig");
const types = @import("types.zig");
const constants = @import("constants.zig");
const mouse = @import("mouse.zig");

fn lineInSelection(cursor: types.CursorPosition, lineIdx: i32) bool {
    if (cursor.start.line == lineIdx) return true;
    if (cursor.end) |cursorEnd| {
        if (cursorEnd.line == lineIdx) return true;
        return (lineIdx > cursor.start.line and lineIdx < cursorEnd.line);
    } else {
        return false;
    }
}

fn collapseSelection(file: *types.OpenedFile) !void {
    if (file.cursorPos.end) |cursorEnd| {
        // If selection is on same line, just remove range
        if (file.cursorPos.start.line == cursorEnd.line) {
            const line: *std.ArrayList(i32) = &file.lines.items[@intCast(cursorEnd.line)];
            const emptyList: [0]i32 = undefined;
            try line.replaceRange(
                @intCast(file.cursorPos.start.column),
                @intCast(cursorEnd.column - file.cursorPos.start.column),
                &emptyList,
            );
            file.cursorPos.end = null;
            return;
        }
        // If selection is on two lines, remove end of first line, begining of
        // second line and append the second line to the first.
        else if (cursorEnd.line == file.cursorPos.start.line + 1) {
            const line: *std.ArrayList(i32) = &file.lines.items[@intCast(file.cursorPos.start.line)];
            const emptyList: [0]i32 = undefined;
            try line.replaceRange(
                @intCast(file.cursorPos.start.column),
                @intCast(line.items.len - @as(usize, @intCast(file.cursorPos.start.column))),
                &emptyList,
            );
            const line2: *std.ArrayList(i32) = &file.lines.items[@intCast(cursorEnd.line)];
            try line2.replaceRange(
                @intCast(0),
                @intCast(cursorEnd.column),
                &emptyList,
            );
            try line.appendSlice(line2.items);

            _ = file.lines.orderedRemove(@intCast(cursorEnd.line));
            file.cursorPos.end = null;
            return;
        }
        // If selection is on >2 lines, remove end of first line, begining of
        // last line and append the second line to the first.
        // Removes all the lines in between the two
        else {
            const line: *std.ArrayList(i32) = &file.lines.items[@intCast(file.cursorPos.start.line)];
            const emptyList: [0]i32 = undefined;
            try line.replaceRange(
                @intCast(file.cursorPos.start.column),
                @intCast(line.items.len - @as(usize, @intCast(file.cursorPos.start.column))),
                &emptyList,
            );
            const line2: *std.ArrayList(i32) = &file.lines.items[@intCast(cursorEnd.line)];
            try line2.replaceRange(
                @intCast(0),
                @intCast(cursorEnd.column),
                &emptyList,
            );
            try line.appendSlice(line2.items);

            for (@intCast(file.cursorPos.start.line)..@intCast(cursorEnd.line)) |_| {
                _ = file.lines.orderedRemove(@intCast(file.cursorPos.start.line + 1));
            }
            file.cursorPos.end = null;
            return;
        }
    } else {
        return;
    }
}

pub fn getColorFromStyleName(name: []const u8) types.Rgb {
    // TODO: change this to a hashmap ONLY IF the amount of styles becomes > 50
    // string comparison is more efficient up until then.
    for (state.styles) |style| {
        if (std.mem.eql(u8, style.name, name)) {
            return style.rgb;
        }
    }
    return .{ constants.colorCodeFont.r, constants.colorCodeFont.g, constants.colorCodeFont.b };
}

pub fn handleFileInput(file: *types.OpenedFile) !void {
    var keyIdx: usize = @subWithOverflow(state.inputBuffer.items.len, 1)[0];
    while (keyIdx != std.math.maxInt(usize)) {
        // Get last key in input buffer
        const key: types.KeyChar = state.inputBuffer.items[keyIdx];
        keyIdx = @subWithOverflow(keyIdx, 1)[0];

        // Char is UTF8 and as such is stored as a codepoint (i32)
        var char: i32 = 0;

        const cursorPos = file.cursorPos.start;

        // Key is non-control character, collapse selection and write to line
        if (key.char != 0) {
            char = key.char;
            try collapseSelection(file);

            const editLine: usize = @intCast(file.cursorPos.start.line);
            const editCol: usize = @intCast(file.cursorPos.start.column);

            var line: *std.ArrayList(types.CodePoint) = &file.lines.items[editLine];

            try line.insert(editCol, key.char);
            file.cursorPos.start.column += 1;
        }
        // Key is control character, handle special cases
        else {
            const cursorPosLine: usize = @intCast(cursorPos.line);
            const cursorPosCol: usize = @intCast(cursorPos.column);

            // TODO: handle special keys
            // del, tab

            // Is arrow
            if (key.key == .up or key.key == .down or key.key == .left or key.key == .right) {
                file.cursorPos.dragOrigin = null;
                file.cursorPos.end = null;

                if (key.key == .up and file.cursorPos.start.line > 0) {
                    file.cursorPos.start.line -= 1;
                }

                if (key.key == .down and file.cursorPos.start.line < @as(i32, @intCast(file.lines.items.len - 1))) {
                    file.cursorPos.start.line += 1;
                }

                if (key.key == .left) {
                    if (file.cursorPos.start.column == 0 and file.cursorPos.start.line == 0) {
                        // Do nothing
                    } else if (file.cursorPos.start.column == 0 and file.cursorPos.start.line > 0) {
                        file.cursorPos.start.line -= 1;
                        file.cursorPos.start.column = std.math.maxInt(i32);
                    } else {
                        file.cursorPos.start.column -= 1;
                    }
                }

                if (key.key == .right) {
                    const lineLen: i32 = @intCast(file.lines.items[@intCast(file.cursorPos.start.line)].items.len);
                    if (file.cursorPos.start.column >= lineLen and file.cursorPos.start.line == @as(i32, @intCast(file.lines.items.len - 1))) {
                        // Do nothing
                    } else if (file.cursorPos.start.column >= lineLen and file.cursorPos.start.line < @as(i32, @intCast(file.lines.items.len - 1))) {
                        file.cursorPos.start.line += 1;
                        file.cursorPos.start.column = 0;
                    } else {
                        file.cursorPos.start.column += 1;
                    }
                }

                const line: *std.ArrayList(i32) = &file.lines.items[@intCast(file.cursorPos.start.line)];
                if (file.cursorPos.start.column > line.items.len) {
                    file.cursorPos.start.column = @intCast(line.items.len);
                }
            }
            // Is Enter
            else if (key.key == .enter or key.key == .kp_enter) {
                try collapseSelection(file);

                // Split line and insert rest of line under
                const line: *std.ArrayList(i32) = &file.lines.items[cursorPosLine];

                var lineStart = std.ArrayList(i32).init(state.allocator);
                try lineStart.appendSlice(line.items[0..cursorPosCol]);

                var lineEnd = std.ArrayList(i32).init(state.allocator);
                try lineEnd.appendSlice(line.items[cursorPosCol..]);

                const removedLine: std.ArrayList(i32) = file.lines.orderedRemove(cursorPosLine);
                defer removedLine.deinit();

                try file.lines.insert(cursorPosLine, lineStart);
                try file.lines.insert(cursorPosLine + 1, lineEnd);

                file.cursorPos.start = .{
                    .line = cursorPos.line + 1,
                    .column = 0,
                };
            }
            // Is Backspace (leftward delete)
            else if (key.key == .backspace) {
                if (file.cursorPos.end) |_| {
                    // If we have range selection, just collapse it
                    try collapseSelection(file);
                } else if (cursorPos.column == 0 and cursorPosLine == 0) {
                    // Do nothing, top of file
                } else if (cursorPos.column == 0) {
                    // Special case where needs to join lines
                    const prevLineEnd: i32 = @intCast(file.lines.items[cursorPosLine - 1].items.len);

                    const removedLine: std.ArrayList(i32) = file.lines.orderedRemove(cursorPosLine);
                    defer removedLine.deinit();

                    const prevLine: *std.ArrayList(i32) = &file.lines.items[cursorPosLine - 1];
                    try prevLine.appendSlice(removedLine.items);

                    file.cursorPos.start = .{
                        .line = cursorPos.line - 1,
                        .column = prevLineEnd,
                    };
                } else {
                    // Remove char at cursor pos
                    const line: *std.ArrayList(i32) = &file.lines.items[cursorPosLine];
                    _ = line.orderedRemove(cursorPosCol - 1);
                    file.cursorPos.start.column -= 1;
                }
            }
        }
    }
}

pub fn drawFileContents(file: *types.OpenedFile, codeRect: types.Recti32) !void {
    //const startMics = std.time.microTimestamp();
    // TODO: implement find/replace

    if (file.lines.items.len > std.math.maxInt(i32)) {
        return error.FileTooBig;
    }

    var scrollOffset: i32 = @intFromFloat(file.scroll.y);

    // TODO: Horizontal scrollbar handling

    // Handle scrollbar move before render
    const scrollBarTrackY = types.Recti32{
        .x = codeRect.x + codeRect.width - 10,
        .y = codeRect.y,
        .width = 10,
        .height = codeRect.height,
    };

    {
        const totalLinesSize: usize = file.lines.items.len * @as(usize, @intCast(constants.lineHeight)) + @as(usize, @intCast(codeRect.height)) - 20;
        const totalLinesSizeF: f32 = @floatFromInt(totalLinesSize);

        if (state.movingScrollBarY) {
            const moveY: f32 = state.mousePosition.y - state.prevMousePosition.y;
            const moveRelY: f32 = moveY / @as(f32, @floatFromInt(codeRect.height));
            file.scroll.y -= totalLinesSizeF * moveRelY;

            if (file.scroll.y > 0.0) {
                file.scroll.y = 0.0;
            }
        }

        // Cap the scroll depending on file size.
        // We do that regardless of scroll wheel move / scroll bar move
        if (file.scroll.y < -totalLinesSizeF + @as(f32, @floatFromInt(codeRect.height - 10))) {
            file.scroll.y = -totalLinesSizeF + @as(f32, @floatFromInt(codeRect.height - 10));
        }
        scrollOffset = @intFromFloat(file.scroll.y);

        if (mouse.isMouseInRect(scrollBarTrackY) and mouse.isJustLeftClick()) {
            state.movingScrollBarY = true;
        } else if (!mouse.isLeftClickDown()) {
            state.movingScrollBarY = false;
        }
    }

    const codeRectLeftOffset: i32 = codeRect.x + constants.paddingSize + 80;

    var lineNbPos: rl.Vector2 = rl.Vector2{
        .x = @floatFromInt(codeRect.x + constants.paddingSize),
        .y = 0.0,
    };
    var textPos: rl.Vector2 = rl.Vector2{
        .x = @floatFromInt(codeRectLeftOffset),
        .y = 0.0,
    };
    var lineRect: types.Recti32 = types.Recti32{
        .x = codeRect.x,
        .y = 0.0,
        .height = constants.lineHeight,
        .width = codeRect.width,
    };

    const scrolledTop: i32 = codeRect.y + scrollOffset + constants.paddingSize;

    const renderBoundTop: f32 = @floatFromInt(codeRect.y - constants.paddingSize);
    const renderBoundBott: f32 = @floatFromInt(state.windowHeight + constants.paddingSize);

    const firstLineIdx: usize = @intFromFloat(@max(0, @ceil((renderBoundTop - @as(f32, @floatFromInt(scrolledTop))) / @as(f32, @floatFromInt(constants.lineHeight)))));

    //var renderedLines: i32 = 0;
    var i: usize = firstLineIdx;

    while (i < file.lines.items.len) : (i += 1) {
        const idx: i32 = @intCast(i);
        const line: std.ArrayList(i32) = file.lines.items[i];

        const yPos: f32 = @floatFromInt(scrolledTop + (idx * constants.lineHeight));

        if (yPos > renderBoundBott) break;

        //renderedLines += 1;

        lineNbPos.y = yPos;
        textPos.y = yPos;
        lineRect.y = @intFromFloat(yPos);

        // Handle cursor position change + range select
        // Shouldn't be in here but this so much more convenient
        if (mouse.isMouseInRect(lineRect) and !state.movingScrollBarY) {
            const relativeX: f32 = state.mousePosition.x - textPos.x;
            const colWidthF: f32 = @floatFromInt(constants.colWidth);
            var approximateColumn: i32 = @intFromFloat(@round(relativeX / colWidthF));

            if (approximateColumn >= line.items.len) {
                approximateColumn = @intCast(line.items.len);
            }

            if (approximateColumn < 0) {
                approximateColumn = 0;
            }

            // Set cursor position
            if (mouse.isJustLeftClick()) {
                file.cursorPos = types.CursorPosition{
                    .start = .{
                        .column = approximateColumn,
                        .line = idx,
                    },
                    .end = null,
                    .dragOrigin = null,
                };
            } else if (mouse.isLeftClickDown()) {
                if (file.cursorPos.end) |_| {} else {
                    file.cursorPos.dragOrigin = file.cursorPos.start;
                }

                const dragOrigin = file.cursorPos.dragOrigin.?;

                const dragPos = types.TextPos{
                    .column = approximateColumn,
                    .line = idx,
                };

                // Make sure selecting in every direction works as intended
                // if drag == prev pos we keep it as single char cursor
                if (!std.meta.eql(file.cursorPos.start, dragPos)) {
                    if (dragPos.line > dragOrigin.line or (dragPos.line == dragOrigin.line and dragPos.column > dragOrigin.column)) {
                        file.cursorPos.start = dragOrigin;
                        file.cursorPos.end = dragPos;
                    } else {
                        file.cursorPos.start = dragPos;
                        file.cursorPos.end = dragOrigin;
                    }
                }
            }
        }

        // Draw cursor
        if (lineInSelection(file.cursorPos, idx)) {
            const cursorPos = file.cursorPos;

            if (cursorPos.end) |endPos| {
                // If there's a range selection, highlight it
                const lineStart: i32 = if (idx == cursorPos.start.line) cursorPos.start.column else 0;
                const lineEnd: i32 = if (idx == endPos.line) endPos.column else @intCast(line.items.len);

                // Draw selection highlight
                rl.drawRectangle(
                    (lineStart * constants.colWidth) + codeRectLeftOffset,
                    lineRect.y,
                    ((lineEnd - lineStart) * constants.colWidth),
                    constants.lineHeight,
                    constants.colorSelectHighlight,
                );
            } else {
                const cursorRect: types.Recti32 = types.Recti32{
                    .x = (cursorPos.start.column * 10) + codeRectLeftOffset,
                    .y = lineRect.y,
                    .width = 2,
                    .height = 20,
                };

                // Draw single-char cursor
                rl.drawRectangle(
                    cursorRect.x,
                    cursorRect.y,
                    cursorRect.width,
                    cursorRect.height,
                    rl.Color.white,
                );
            }
        }

        // Draw line number
        var lineBuff: [4:0]u8 = undefined;
        _ = try std.fmt.bufPrint(@ptrCast(&lineBuff), "{d:4}", .{i + 1});
        lineBuff[4] = 0;

        rl.drawTextEx(
            state.codeFont,
            @ptrCast(&lineBuff),
            lineNbPos,
            constants.fontSize,
            0,
            constants.colorUiFont,
        );

        // TODO: handle styles

        var styleStack = std.ArrayList(types.MatchedStyle).init(state.allocator);
        defer styleStack.deinit();

        for (state.zigStyles, 0..) |style, j| {
            const re = try regex.compileRegex(state.allocator, style.expr);
            const matches = try regex.getMatchesCodepoint(state.allocator, re, line.items);
            for (matches.items) |untypedMatch| {
                const match: regex.ReMatch = untypedMatch;
                try styleStack.append(.{
                    .style = style,
                    .priority = @intCast(j),
                    .start = @intCast(match.start),
                    .end = @intCast(match.end),
                });
            }
        }

        var flattenedStyleStack = std.ArrayList(types.MatchedStyle).init(state.allocator);
        defer flattenedStyleStack.deinit();

        try flattenedStyleStack.append(.{
            .style = null,
            .priority = 999,
            .start = 0,
            .end = std.math.maxInt(i32),
        });

        var currentStyle: *types.MatchedStyle = &flattenedStyleStack.items[flattenedStyleStack.items.len - 1];

        for (line.items, 0..) |c, j| {
            _ = c;

            for (styleStack.items) |untypedStyle| {
                const style: types.MatchedStyle = untypedStyle;

                // Higher priority style, end previous style and start new one.
                if (style.priority < currentStyle.priority and style.start == @as(i32, @intCast(j))) {
                    currentStyle.end = @as(i32, @intCast(j));
                    try flattenedStyleStack.append(.{
                        .style = style.style,
                        .priority = style.priority,
                        .start = @as(i32, @intCast(j)),
                        .end = std.math.maxInt(i32),
                    });
                    currentStyle = &flattenedStyleStack.items[flattenedStyleStack.items.len - 1];
                }
                // Style match ended
                else if (style.priority == currentStyle.priority and style.end == @as(i32, @intCast(j))) {
                    currentStyle.end = @as(i32, @intCast(j));
                    try flattenedStyleStack.append(.{
                        .style = null,
                        .priority = 999,
                        .start = @as(i32, @intCast(j)),
                        .end = std.math.maxInt(i32),
                    });
                    currentStyle = &flattenedStyleStack.items[flattenedStyleStack.items.len - 1];
                }
            }
        }
        currentStyle.end = @intCast(line.items.len);

        // Draws line as UTF8
        // rl.drawTextCodepoints(
        //     state.codeFont,
        //     line.items,
        //     textPos,
        //     constants.fontSize,
        //     0,
        //     constants.colorCodeFont,
        // );

        var offset: f32 = 0.0;

        for (flattenedStyleStack.items) |untypedStyle| {
            const style: types.MatchedStyle = untypedStyle;

            var color: types.Rgb = undefined;
            if (style.style) |nonNullStyle| {
                color = getColorFromStyleName(nonNullStyle.name);
            } else {
                color[0] = constants.colorCodeFont.r;
                color[1] = constants.colorCodeFont.g;
                color[2] = constants.colorCodeFont.b;
            }

            const start: usize = @intCast(style.start);
            const end: usize = @intCast(style.end);

            var newTextPos = textPos;
            newTextPos.x += offset;

            const segmentColor = rl.Color.init(color[0], color[1], color[2], 255);

            rl.drawTextCodepoints(
                state.codeFont,
                line.items[start..end],
                newTextPos,
                constants.fontSize,
                0,
                segmentColor,
            );

            offset += @floatFromInt((style.end - style.start) * 10);
        }
    }

    //std.debug.print("                         ", .{});
    //std.debug.print("\rRendered lines: {d}", .{renderedLines});

    // TODO: Horizontal scrollbar

    // Vertical scrollbar drawing
    const firstLineF: f32 = @floatFromInt(firstLineIdx);
    const linesLen: f32 = @floatFromInt(file.lines.items.len);

    const relLinePosition: f32 = firstLineF / linesLen;
    const codeRectHeightF: f32 = @floatFromInt(codeRect.height);

    const scrollBarRect = types.Recti32{
        .x = codeRect.x + codeRect.width - 10,
        .y = @divTrunc(codeRect.y, 2) + @as(i32, @intFromFloat((codeRectHeightF * relLinePosition) + ((relLinePosition * -constants.scrollBarHeightF) + (constants.scrollBarHeightF / 2.0)))),
        .width = 10,
        .height = constants.scrollBarHeight,
    };

    // Draw scrollbar track
    rl.drawRectangle(
        scrollBarTrackY.x,
        scrollBarTrackY.y,
        scrollBarTrackY.width,
        scrollBarTrackY.height,
        constants.colorBackground,
    );
    rl.drawRectangleLines(
        scrollBarTrackY.x,
        scrollBarTrackY.y,
        scrollBarTrackY.width,
        scrollBarTrackY.height,
        constants.colorLines,
    );
    // Draw scrollbar thumb
    rl.drawRectangle(
        scrollBarRect.x,
        scrollBarRect.y,
        scrollBarRect.width,
        scrollBarRect.height,
        constants.colorLines,
    );

    //const timeSpent = std.time.microTimestamp() - startMics;
    //if (timeSpent > 1000) {
    //    std.debug.print("                                                                     ", .{});
    //    std.debug.print("\rRendering file contents took: {d} mics", .{timeSpent});
    //}
}
