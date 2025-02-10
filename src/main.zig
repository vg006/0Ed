const std = @import("std");
const rl = @import("raylib");

const state = @import("global_state.zig");
const constants = @import("constants.zig");
const types = @import("types.zig");
const button = @import("button.zig");
const mouse = @import("mouse.zig");
const editor = @import("text_editor.zig");
const file = @import("file.zig");
const keys = @import("keys.zig");

pub fn closeWindow() void {
    rl.closeWindow();
    std.process.exit(0);
}

pub fn dud() void {}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    state.allocator = gpa.allocator();

    state.inputBuffer = std.ArrayList(types.KeyChar).init(state.allocator);
    state.pressedKeys = std.ArrayList(types.PressedKeyState).init(state.allocator);

    state.openedFiles = std.ArrayList(types.OpenedFile).init(state.allocator);

    try file.openFile(state.allocator, "./src/main.zig");
    state.currentlyDisplayedFileIdx = 0;

    const charSet = try std.fs.cwd().readFileAlloc(
        state.allocator,
        "./resources/font_charset.txt",
        std.math.maxInt(u64),
    );
    var charSetCodepoints = std.ArrayList(types.CodePoint).init(state.allocator);

    var it = std.unicode.Utf8Iterator{ .bytes = charSet, .i = 0 };

    while (it.nextCodepoint()) |codepoint| {
        try charSetCodepoints.append(@intCast(codepoint));
    }

    // TODO: handle multiple files open
    // tabs?

    rl.setConfigFlags(.{
        .window_resizable = true,
        .window_transparent = true,
        .window_undecorated = true,
    });

    rl.initWindow(state.initialWindowWidth, state.initialWindowHeight, "wed2");
    defer rl.closeWindow();

    rl.setTargetFPS(60);

    if (rl.loadFontEx(
        "resources/CascadiaMono.ttf",
        42,
        charSetCodepoints.items,
    )) |font| {
        state.codeFont = font;
    } else |err| {
        std.log.err("Failed to load font CascadiaMono.ttf Error: {any}", .{err});
        return;
    }

    if (rl.loadFontEx(
        "resources/RobotoMono.ttf",
        42,
        charSetCodepoints.items,
    )) |font| {
        state.uiFont = font;
    } else |err| {
        std.log.err("Failed to load font RobotoMono.ttf Error: {any}", .{err});
        return;
    }

    rl.setTextureFilter(state.codeFont.texture, .bilinear);
    rl.setTextureFilter(state.uiFont.texture, .bilinear);

    // Main game loop
    while (!rl.windowShouldClose()) { // Detect window close button or ESC key

        // Poll state changes
        {
            state.scrollVelocityY /= 1.5;

            try keys.getInputBuffer();

            state.windowWidth = rl.getScreenWidth();
            state.windowHeight = rl.getScreenHeight();

            state.windowPosition = rl.getWindowPosition();

            state.mouseWheelMove = rl.getMouseWheelMoveV();

            state.prevMousePosition = state.mousePosition;
            state.mousePosition = rl.getMousePosition();

            state.prevMouseScreenPosition = state.mouseScreenPosition;
            state.mouseScreenPosition = rl.Vector2{
                .x = state.windowPosition.x + state.mousePosition.x,
                .y = state.windowPosition.y + state.mousePosition.y,
            };

            state.prevMouseLeftClick = state.mouseLeftClick;
            state.mouseLeftClick = rl.isMouseButtonDown(rl.MouseButton.left);

            state.prevMouseRightClick = state.mouseRightClick;
            state.mouseRightClick = rl.isMouseButtonDown(rl.MouseButton.right);

            if (state.mouseWheelMove.y != 0.0) {
                state.scrollVelocityY += state.mouseWheelMove.y * constants.scrollVelocityMultiplier;
            }

            state.editorScroll.y += state.scrollVelocityY * constants.scrollIncrement;

            if (state.editorScroll.y > 0.0) state.editorScroll.y = 0.0;
            if (state.editorScroll.x > 0.0) state.editorScroll.x = 0.0;
        }

        const codeScrollInt: types.Vec2i32 = types.Vec2i32{
            .x = @intFromFloat(state.editorScroll.x),
            .y = @intFromFloat(state.editorScroll.y),
        };

        rl.beginDrawing();
        defer rl.endDrawing();

        // Draw side bar
        {
            const sideBarRect: types.Recti32 = types.Recti32{
                .x = 0,
                .y = 39,
                .width = 200,
                .height = state.windowHeight - 39,
            };

            if (mouse.isMouseInRect(sideBarRect)) {
                rl.setMouseCursor(.default);
            }

            rl.drawRectangle(
                sideBarRect.x,
                sideBarRect.y,
                sideBarRect.width,
                sideBarRect.height,
                constants.colorBackground,
            );
            rl.drawRectangleLines(
                sideBarRect.x,
                sideBarRect.y,
                sideBarRect.width,
                sideBarRect.height,
                constants.colorLines,
            );
        }

        // Draw text rect
        {
            const codeRect: types.Recti32 = types.Recti32{
                .x = 199,
                .y = 39,
                .width = state.windowWidth - 199,
                .height = state.windowHeight - 39,
            };

            if (mouse.isMouseInRect(codeRect)) {
                rl.setMouseCursor(.ibeam);
            }

            rl.drawRectangle(
                codeRect.x,
                codeRect.y,
                codeRect.width,
                codeRect.height,
                constants.colorCodeBackground,
            );
            rl.drawRectangleLines(
                codeRect.x,
                codeRect.y,
                codeRect.width,
                codeRect.height,
                constants.colorLines,
            );

            try editor.drawFileContents(
                &state.openedFiles.items[state.currentlyDisplayedFileIdx],
                codeRect,
                codeScrollInt.y,
            );
        }

        // Draw top bar
        {
            const topBarRect: types.Recti32 = types.Recti32{
                .x = 0,
                .y = 0,
                .width = state.windowWidth,
                .height = 40,
            };

            if (mouse.isMouseInRect(topBarRect)) {
                rl.setMouseCursor(.default);
            }

            rl.drawRectangle(
                topBarRect.x,
                topBarRect.y,
                topBarRect.width,
                topBarRect.height,
                constants.colorBackground,
            );
            rl.drawRectangleLines(
                topBarRect.x,
                topBarRect.y,
                topBarRect.width,
                topBarRect.height,
                constants.colorLines,
            );

            // TODO: implement menus

            button.drawButton("File", 22, types.Recti32{
                .x = 0,
                .y = 0,
                .height = topBarRect.height,
                .width = 60,
            }, types.Vec2i32{
                .x = 10,
                .y = 9,
            }, dud);

            button.drawButton("Edit", 22, types.Recti32{
                .x = 59,
                .y = 0,
                .height = topBarRect.height,
                .width = 60,
            }, types.Vec2i32{
                .x = 10,
                .y = 9,
            }, dud);

            button.drawButton("X", 22, types.Recti32{
                .x = state.windowWidth - 50,
                .y = 0,
                .height = topBarRect.height,
                .width = 50,
            }, types.Vec2i32{
                .x = 19,
                .y = 9,
            }, closeWindow);

            // TODO: put that at the top of the loop
            // no rendering needed but adds a frame of latency for no reason
            const topBarMoveRect: types.Recti32 = types.Recti32{
                .x = 119, // width of buttons
                .y = 0,
                .width = state.windowWidth - 119 - 50, // window width - width of buttons
                .height = topBarRect.height,
            };

            if (state.movingWindow) {
                const moveRight: f32 = state.mouseScreenPosition.x - state.prevMouseScreenPosition.x;
                const moveBottom: f32 = state.mouseScreenPosition.y - state.prevMouseScreenPosition.y;

                const newPosX: i32 = @intFromFloat(state.windowPosition.x + moveRight);
                const newPosY: i32 = @intFromFloat(state.windowPosition.y + moveBottom);
                rl.setWindowPosition(newPosX, newPosY);

                // Update new positions
                state.mousePosition = rl.getMousePosition();
                state.windowPosition = rl.getWindowPosition();
            }

            if (state.mouseLeftClick and !state.prevMouseLeftClick and mouse.isMouseInRect(topBarMoveRect)) {
                state.movingWindow = true;
            } else if (!state.mouseLeftClick) {
                state.movingWindow = false;
            }
        }

        var fpsBuff: [12:0]u8 = undefined;
        _ = try std.fmt.bufPrintZ(&fpsBuff, "FPS:   {d}", .{rl.getFPS()});

        rl.drawTextEx(
            state.uiFont,
            &fpsBuff,
            rl.Vector2{
                .x = 5.0,
                .y = @floatFromInt(state.windowHeight - 17 - 30),
            },
            15,
            0,
            rl.Color.white,
        );

        const cursorPos = state.openedFiles.items[0].cursorPos;

        var cursorStartBuff: [128:0]u8 = undefined;
        _ = try std.fmt.bufPrintZ(&cursorStartBuff, "Start: Ln:{any} Col:{any}", .{ cursorPos.start.line + 1, cursorPos.start.column + 1 });

        var cursorEndBuff: [128:0]u8 = undefined;

        if (cursorPos.end) |_| {
            _ = try std.fmt.bufPrintZ(&cursorEndBuff, "End:   Ln:{any} Col:{any}", .{ cursorPos.end.?.line + 1, cursorPos.end.?.column + 1 });
        } else {
            _ = try std.fmt.bufPrintZ(&cursorEndBuff, "", .{});
        }

        rl.drawTextEx(
            state.uiFont,
            &cursorStartBuff,
            rl.Vector2{
                .x = 5.0,
                .y = @floatFromInt(state.windowHeight - 17 - 15),
            },
            15,
            0,
            rl.Color.white,
        );

        rl.drawTextEx(
            state.uiFont,
            &cursorEndBuff,
            rl.Vector2{
                .x = 5.0,
                .y = @floatFromInt(state.windowHeight - 17),
            },
            15,
            0,
            rl.Color.white,
        );
    }
}
