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

    // Init global state buffers
    state.inputBuffer = std.ArrayList(types.KeyChar).init(state.allocator);
    state.pressedKeys = std.ArrayList(types.PressedKeyState).init(state.allocator);
    state.openedFiles = std.ArrayList(types.OpenedFile).init(state.allocator);
    state.fontCharset = std.ArrayList(types.CodePoint).init(state.allocator);

    // Reads charset file, and creates codepoints out of each char.
    // This is needed as Raylib expects a list of characters the loaded font can
    // handle, and assumes ASCII by default.
    // Codepoint will be a recurrent term in this codebase as it is the way for
    // Raylib to draw UTF8 characters.
    {
        const charSet = try std.fs.cwd().readFileAlloc(
            state.allocator,
            "./resources/fonts/font_charset.txt",
            std.math.maxInt(u64),
        );
        var it = std.unicode.Utf8Iterator{
            .bytes = charSet,
            .i = 0,
        };
        while (it.nextCodepoint()) |codepoint| {
            try state.fontCharset.append(@intCast(codepoint));
        }
        state.allocator.free(charSet);
    }

    { // Set raylib window flags
        rl.setConfigFlags(.{
            .window_resizable = true,
            .window_transparent = false,
            .window_undecorated = true,
            .vsync_hint = false,
            .msaa_4x_hint = true,
            .window_highdpi = true,
            .interlaced_hint = true,
        });
        rl.setTargetFPS(120);
        rl.setExitKey(.null); // Remove ESC as exit key
    }

    rl.initWindow(state.initialWindowWidth, state.initialWindowHeight, "0Ed");
    defer rl.closeWindow();

    const icon = try rl.loadImage("resources/icons/icon.png");
    rl.setWindowIcon(icon);
    var iconTexture = try rl.loadTextureFromImage(icon);
    iconTexture.height = @intFromFloat(@as(f32, @floatFromInt(constants.topBarHeight)) / 1.25);
    iconTexture.width = @intFromFloat(@as(f32, @floatFromInt(constants.topBarHeight)) / 1.25);
    rl.setTextureFilter(iconTexture, .bilinear);

    { // Load fonts
        if (rl.loadFontEx(
            "resources/fonts/CascadiaMono.ttf",
            64,
            state.fontCharset.items,
        )) |font| {
            state.codeFont = font;
        } else |err| {
            std.log.err("Failed to load font CascadiaMono.ttf Error: {any}", .{err});
            return;
        }

        if (rl.loadFontEx(
            "resources/fonts/RobotoMono.ttf",
            64,
            state.fontCharset.items,
        )) |font| {
            state.uiFont = font;
        } else |err| {
            std.log.err("Failed to load font RobotoMono.ttf Error: {any}", .{err});
            return;
        }

        rl.setTextureFilter(state.codeFont.texture, .bilinear);
        rl.setTextureFilter(state.uiFont.texture, .bilinear);
    }

    // Main loop
    while (!rl.windowShouldClose()) {
        rl.beginDrawing();
        defer rl.endDrawing();

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

        { // Draw text rect
            const codeRect = types.Recti32{
                .x = 199,
                .y = (constants.topBarHeight * 2) - 2,
                .width = state.windowWidth - 199,
                .height = state.windowHeight - (constants.topBarHeight * 2) + 2,
            };

            if (mouse.isMouseInRect(codeRect)) {
                state.pointerType = .ibeam;
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

            if (state.openedFiles.items.len > 0) {
                const f = &state.openedFiles.items[state.currentlyDisplayedFileIdx];
                try editor.handleFileInput(f);
                try editor.drawFileContents(f, codeRect);
            }
        }

        { // Draw file tabs
            const fileTabsRect = types.Recti32{
                .x = 199,
                .y = constants.topBarHeight - 1,
                .width = state.windowWidth - 199,
                .height = constants.topBarHeight,
            };

            if (mouse.isMouseInRect(fileTabsRect)) {
                state.pointerType = .default;
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

            // TODO: Scroll tabs if the width > viewport width
            // TODO: Way to close tab

            var i: usize = 0;
            while (i < state.openedFiles.items.len) {
                const openedFile = &state.openedFiles.items[i];
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
                    &file.displayFile, // Displays file with index i
                );

                offset += tabWidth - 1;

                button.drawButtonArg(
                    "x",
                    22,
                    .{
                        .x = 199 + offset,
                        .y = constants.topBarHeight - 1,
                        .width = constants.topBarHeight,
                        .height = constants.topBarHeight,
                    },
                    .{
                        .x = 15,
                        .y = 8,
                    },
                    i,
                    &file.removeFile, // Remove file with index i
                );

                offset += constants.topBarHeight - 1;
                i += 1;
            }
        }

        const sideBarRect = types.Recti32{
            .x = 0,
            .y = 39,
            .width = 200,
            .height = state.windowHeight - 39,
        };

        { // Draw side bar
            if (mouse.isMouseInRect(sideBarRect)) {
                state.pointerType = .default;
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

        const topBarRect = types.Recti32{
            .x = 0,
            .y = 0,
            .width = state.windowWidth,
            .height = constants.topBarHeight,
        };

        { // Draw top bar
            if (mouse.isMouseInRect(topBarRect)) {
                state.pointerType = .default;
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

            button.drawButton(
                "File",
                22,
                types.Recti32{
                    .x = constants.topBarHeight + 5,
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
                    .x = 59 + constants.topBarHeight + 5,
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
                "x",
                28,
                types.Recti32{
                    .x = state.windowWidth - 50,
                    .y = 0,
                    .height = topBarRect.height,
                    .width = 50,
                },
                types.Vec2i32{
                    .x = 19,
                    .y = 3,
                },
                &closeWindow,
            );

            rl.drawTexture(iconTexture, 7, 5, .white);

            const topBarMoveRect = types.Recti32{
                .x = 119 + constants.topBarHeight + 5, // width of buttons
                .y = 0,
                .width = state.windowWidth - (119 + constants.topBarHeight + 5) - 50, // window width - width of buttons
                .height = topBarRect.height,
            };

            // Move window while user is dragging top bar
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
            const menuItems = switch (state.topBarMenuOpened) {
                .None => null,

                // X before menu item name means not implemented
                .File => types.Menu{
                    .origin = .{ .x = constants.topBarHeight + 5, .y = constants.topBarHeight - 1 },
                    .items = @constCast(&[_]types.MenuItem{
                        .{ .name = "New File", .callback = &file.newFile },
                        .{ .name = "Open File", .callback = &file.openFileDialog },
                        .{ .name = "Open Folder", .callback = &file.openFolderDialog },
                        .{ .name = "Save", .callback = &file.saveFile },
                        .{ .name = "Save As", .callback = &file.saveFileAs },
                    }),
                },

                // X before menu item name means not implemented
                .Edit => types.Menu{
                    .origin = .{ .x = 59 + constants.topBarHeight + 5, .y = constants.topBarHeight - 1 },
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
            if (state.openedDir) |dir| {
                // TODO: Make recursive
                for (dir.children.items) |_entry| {
                    const entry: types.FileSystemTree = _entry;
                    _ = entry;
                }
            }
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

            if (state.openedFiles.items.len > 0) {
                const cursorPos = state.openedFiles.items[state.currentlyDisplayedFileIdx].cursorPos;

                var cursorStartBuff: [128:0]u8 = undefined;
                _ = try std.fmt.bufPrintZ(
                    &cursorStartBuff,
                    "Start: Ln:{any} Col:{any}",
                    .{ cursorPos.start.line + 1, cursorPos.start.column + 1 },
                );

                var cursorEndBuff: [128:0]u8 = undefined;

                if (cursorPos.end) |_| {
                    _ = try std.fmt.bufPrintZ(
                        &cursorEndBuff,
                        "End:   Ln:{any} Col:{any}",
                        .{ cursorPos.end.?.line + 1, cursorPos.end.?.column + 1 },
                    );
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

        rl.setMouseCursor(state.pointerType);
    }
}
