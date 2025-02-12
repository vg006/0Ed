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

pub fn dudArg(arg: anytype) void {
    _ = arg;
}

pub fn buttonCbFile() void {
    state.topBarMenuOpened = types.TopBarMenu.File;
}

pub fn buttonCbEdit() void {
    state.topBarMenuOpened = types.TopBarMenu.Edit;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    state.allocator = gpa.allocator();

    state.inputBuffer = std.ArrayList(types.KeyChar).init(state.allocator);
    state.pressedKeys = std.ArrayList(types.PressedKeyState).init(state.allocator);

    state.openedFiles = std.ArrayList(types.OpenedFile).init(state.allocator);

    try file.openFile("./src/main.zig");
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
    rl.setExitKey(.null);

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

    // Main loop
    while (!rl.windowShouldClose()) {
        { // Poll state changes
            if (state.scrollVelocityY < 0.001 and state.scrollVelocityY > -0.001) {
                state.scrollVelocityY = 0.0;
            } else {
                state.scrollVelocityY /= 1.5;
            }

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
            state.mouseLeftClick = rl.isMouseButtonDown(.left);

            state.prevMouseRightClick = state.mouseRightClick;
            state.mouseRightClick = rl.isMouseButtonDown(.right);

            if (state.openedFiles.items.len > 0) {
                var displayedFile = &state.openedFiles.items[state.currentlyDisplayedFileIdx];

                if (state.mouseWheelMove.y != 0.0) {
                    state.scrollVelocityY += state.mouseWheelMove.y * constants.scrollVelocityMultiplier;
                }
                displayedFile.scroll.y += state.scrollVelocityY * constants.scrollIncrement;

                if (displayedFile.scroll.y > 0.0) displayedFile.scroll.y = 0.0;
                if (displayedFile.scroll.x > 0.0) displayedFile.scroll.x = 0.0;
            }
        }

        rl.beginDrawing();
        defer rl.endDrawing();

        { // Draw side bar
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

        { // Draw text rect
            const codeRect: types.Recti32 = types.Recti32{
                .x = 199,
                .y = (constants.topBarHeight * 2) - 2,
                .width = state.windowWidth - 199,
                .height = state.windowHeight - (constants.topBarHeight * 2) + 2,
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
            );
        }

        { // Draw file tabs
            const fileTabsRect: types.Recti32 = types.Recti32{
                .x = 199,
                .y = constants.topBarHeight - 1,
                .width = state.windowWidth - 199,
                .height = constants.topBarHeight,
            };

            if (mouse.isMouseInRect(fileTabsRect)) {
                rl.setMouseCursor(.default);
            }

            rl.drawRectangle(
                fileTabsRect.x,
                fileTabsRect.y,
                fileTabsRect.width,
                fileTabsRect.height,
                constants.colorBackground,
            );
            rl.drawRectangleLines(
                fileTabsRect.x,
                fileTabsRect.y,
                fileTabsRect.width,
                fileTabsRect.height,
                constants.colorLines,
            );

            var offset: i32 = 0;

            for (state.openedFiles.items, 0..) |openedFile, i| {
                const tabWidth = 20 + @as(i32, @intCast(openedFile.name.len)) * 10;

                button.drawButtonArg(
                    openedFile.name,
                    22,
                    .{
                        .x = 199 + offset,
                        .y = constants.topBarHeight - 1,
                        .width = tabWidth,
                        .height = constants.topBarHeight,
                    },
                    .{
                        .x = 10,
                        .y = 8,
                    },
                    i,
                    &file.displayFile,
                );

                offset += tabWidth - 1;
            }
        }

        const topBarRect: types.Recti32 = types.Recti32{
            .x = 0,
            .y = 0,
            .width = state.windowWidth,
            .height = constants.topBarHeight,
        };

        { // Draw top bar
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

            button.drawButton(
                "File",
                22,
                types.Recti32{
                    .x = 0,
                    .y = 0,
                    .height = topBarRect.height,
                    .width = 60,
                },
                types.Vec2i32{
                    .x = 10,
                    .y = 9,
                },
                &buttonCbFile,
            );

            button.drawButton(
                "Edit",
                22,
                types.Recti32{
                    .x = 59,
                    .y = 0,
                    .height = topBarRect.height,
                    .width = 60,
                },
                types.Vec2i32{
                    .x = 10,
                    .y = 9,
                },
                &buttonCbEdit,
            );

            button.drawButton(
                "X",
                22,
                types.Recti32{
                    .x = state.windowWidth - 50,
                    .y = 0,
                    .height = topBarRect.height,
                    .width = 50,
                },
                types.Vec2i32{
                    .x = 19,
                    .y = 9,
                },
                &closeWindow,
            );

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

            if (mouse.isMouseInRect(topBarMoveRect) and mouse.isJustLeftClick()) {
                state.movingWindow = true;
            } else if (!mouse.isLeftClickDown()) {
                state.movingWindow = false;
            }
        }

        { // Draw top bar menus

            // X before menu item name means not implemented
            const menuItems = switch (state.topBarMenuOpened) {
                .None => null,

                .File => types.Menu{
                    .origin = .{ .x = 0, .y = constants.topBarHeight - 1 },
                    .items = @constCast(&[_]types.MenuItem{
                        .{ .name = "New File", .callback = &file.newFile },
                        .{ .name = "Open File", .callback = &file.openFileDialog },
                        .{ .name = "X Open Folder", .callback = &dud },
                        .{ .name = "Save", .callback = &file.saveFile },
                        .{ .name = "Save As", .callback = &file.saveFileAs },
                    }),
                },

                .Edit => types.Menu{
                    .origin = .{ .x = constants.topBarMenuButtonWidth - 1, .y = constants.topBarHeight - 1 },
                    .items = @constCast(&[_]types.MenuItem{
                        .{ .name = "X Undo", .callback = &dud },
                        .{ .name = "X Redo", .callback = &dud },
                        .{ .name = "X Copy", .callback = &dud },
                        .{ .name = "X Cut", .callback = &dud },
                        .{ .name = "X Paste", .callback = &dud },
                    }),
                },
            };

            if (menuItems) |untypedMenu| {
                const menu: types.Menu = untypedMenu;

                // Draw menu buttons
                for (menu.items, 0..) |item, i| {
                    button.drawButton(
                        item.name,
                        constants.fontSize,
                        .{
                            .x = menu.origin.x,
                            .y = constants.topBarHeight - 1 + @as(i32, @intCast(i)) * (constants.topBarMenuItemHeight - 1),
                            .width = 130,
                            .height = constants.topBarMenuItemHeight,
                        },
                        .{ .x = 10, .y = 5 },
                        item.callback,
                    );
                }

                // Hide menu if clicked outside of top bar
                if (!mouse.isMouseInRect(topBarRect) and mouse.isJustLeftClick()) {
                    state.topBarMenuOpened = .None;
                }
            }
        }

        { // Draw folder tree

        }

        { // Draw debug infos
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
}
