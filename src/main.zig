const std = @import("std");
const builtin = @import("builtin");
const rl = @import("raylib");

const flags = @import("flags.zig");
const state = @import("global_state.zig");
const h = @import("helper.zig");
const constants = @import("constants.zig");
const types = @import("types.zig");
const button = @import("button.zig");
const mouse = @import("mouse.zig");
const editor = @import("text_editor.zig");
const file = @import("file.zig");
const keys = @import("keys.zig");
const regex = @import("regex_codepoint.zig");
const window = @import("window.zig");
const terminal = @import("terminal.zig");
const fileTabs = @import("file_tabs.zig");
const debug = @import("debug.zig");

pub fn main() !void {
    // ---- Conditional allocator Release/Debug ----
    if (comptime builtin.mode == .Debug) {
        state.debugAllocator = std.heap.DebugAllocator(state.debugAllocatorConf).init;
        state.allocator = state.debugAllocator.allocator();
    } else {
        state.allocator = std.heap.smp_allocator;
    }

    { // ---- Init global state buffers ----
        state.inputBuffer = std.ArrayList(types.KeyChar).init(state.allocator);
        state.pressedKeys = std.ArrayList(types.PressedKeyState).init(state.allocator);
        state.openedFiles = std.ArrayList(types.OpenedFile).init(state.allocator);
        state.fontCharset = types.UtfLine.init(state.allocator);
        state.terminalBuffer = types.UtfLineList.init(state.allocator);
        state.terminalUserInputBuffer = std.ArrayList(i32).init(state.allocator);
        state.terminalStdoutBuff = std.ArrayList(u8).init(state.allocator);
        state.terminalStderrBuff = std.ArrayList(u8).init(state.allocator);
    }

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
        defer state.allocator.free(charSet);
        var it = std.unicode.Utf8Iterator{
            .bytes = charSet,
            .i = 0,
        };
        while (it.nextCodepoint()) |codepoint| {
            try state.fontCharset.append(@intCast(codepoint));
        }
    }

    const windowConfig = rl.ConfigFlags{
        .window_always_run = true,
        .window_resizable = true,
        .window_transparent = false,
        .window_undecorated = true,
        .vsync_hint = flags.enableVsync,
        .msaa_4x_hint = true, // disabling causes flickering due to
        // raylib's double-buffer approach and our current optimizations
        .window_highdpi = false, // raylib's hidpi has a bug when
        // minimizing window, causes a mismatch between expected window size
        // and actual window size
        .interlaced_hint = true,
    };

    { // ---- Set raylib window flags ----
        rl.setConfigFlags(windowConfig);
        rl.setTargetFPS(constants.targetFpsHigh);

        state.targetFps = constants.targetFpsHigh;
        state.currentTargetFps = state.targetFps;

        rl.setExitKey(.null); // Remove ESC as exit key
    }

    // ---- Start Terminal Emulator ----
    {
        try terminal.createTerminalProcess();
    }

    rl.initWindow(
        constants.initialWindowWidth,
        constants.initialWindowHeight,
        "0Ed",
    );
    defer rl.closeWindow();

    state.windowHeight = rl.getRenderHeight();
    state.windowWidth = rl.getRenderWidth();

    const icon = try rl.loadImage("resources/icons/icon.png");
    rl.setWindowIcon(icon);
    var iconTexture = try rl.loadTextureFromImage(icon);
    iconTexture.height = h.casti(h.castf(constants.topBarHeight) / 1.25);
    iconTexture.width = iconTexture.height;
    rl.setTextureFilter(iconTexture, .bilinear);

    { // ---- Load fonts ----
        state.codeFont = try rl.loadFontEx(
            "resources/fonts/CascadiaMono.ttf",
            64,
            state.fontCharset.items,
        );
        state.uiFont = try rl.loadFontEx(
            "resources/fonts/RobotoMono.ttf",
            64,
            state.fontCharset.items,
        );
        rl.setTextureFilter(state.codeFont.texture, .bilinear);
        rl.setTextureFilter(state.uiFont.texture, .bilinear);
    }

    // ---- Compile RegExs ----
    {
        var i: u64 = 0;
        while (i < state.zigStyles.len) : (i += 1) {
            var style = &state.zigStyles[i];
            style.regex = try regex.compileRegex(
                state.allocator,
                style.expr,
            );
        }
    }

    { // ---- Initial frame drawing ----
        state.shouldRedrawNext = .{
            .topBar = true,
            .fileTabs = true,
            .sideBar = true,
            .textEditor = true,
            .terminal = true,
        };
    }

    // ---- Main loop ----
    while (!rl.windowShouldClose()) : (state.frameCount +%= 1) {
        { // ---- Low CPU usage modes ----
            if (rl.isWindowHidden()) {
                rl.waitTime(0.2);
                continue;
            }

            if (rl.isWindowFocused()) {
                state.targetFps = constants.targetFpsHigh;
            } else {
                state.targetFps = constants.targetFpsLow;
            }
        }

        rl.beginDrawing();
        defer rl.endDrawing();

        // Refresh frames will allways trigger a full redraw of the screen.
        const isRefreshFrame = flags.intermitentScreenRefresh and
            (state.frameCount & (state.forceRefreshIntervalFrames - 1)) == 0;

        { // ---- Poll state changes ----
            state.shouldRedraw = .{
                .topBar = state.shouldRedrawNext.topBar or isRefreshFrame,
                .fileTabs = state.shouldRedrawNext.fileTabs or isRefreshFrame,
                .sideBar = state.shouldRedrawNext.sideBar or isRefreshFrame,
                .textEditor = state.shouldRedrawNext.textEditor or isRefreshFrame,
                .terminal = state.shouldRedrawNext.terminal or isRefreshFrame,
            };

            state.shouldRedrawNext = .{
                .topBar = false,
                .fileTabs = false,
                .sideBar = false,
                .textEditor = false,
                .terminal = false,
            };

            try keys.pollInputBuffer();

            state.deltaTime = rl.getFrameTime();

            if (h.floatEq(state.scrollVelocityY, 0, 0.01)) {
                state.scrollVelocityY = 0.0;
            } else {
                state.scrollVelocityY /= 1 +
                    (state.deltaTime * constants.scrollDecayMultiplier);
            }

            state.windowPosition = rl.getWindowPosition();
            state.mouseWheelMove = rl.getMouseWheelMoveV();

            state.prevMousePosition = state.mousePosition;
            state.prevMouseScreenPosition = state.mouseScreenPosition;

            mouse.getMousePosition();

            state.prevMouseLeftClick = state.mouseLeftClick;
            state.mouseLeftClick = rl.isMouseButtonDown(.left);

            state.prevMouseRightClick = state.mouseRightClick;
            state.mouseRightClick = rl.isMouseButtonDown(.right);

            state.scrollVelocityY += (state.mouseWheelMove.y *
                constants.scrollVelocityMultiplier) * state.deltaTime;

            try terminal.pollTerminalOutput();
        }

        { // ---- Draw Text Section (Editor/Terminal) ----
            const textRect = types.Recti32{
                .x = 199,
                .y = (constants.topBarHeight * 2) - 2,
                .width = state.windowWidth - 199,
                .height = state.windowHeight - (constants.topBarHeight * 2) + 2,
            };

            switch (state.currentDisplayedUi) {
                .Editor => {
                    if (state.openedFiles.items.len > 0) {
                        const f = &state.openedFiles.items[state.currentlyDisplayedFileIdx];

                        var stateChanged = editor.handleMouseInput(f, textRect);
                        stateChanged = try editor.handleFileInput(f) or stateChanged;
                        stateChanged = editor.handleScrollBarMove(
                            f.lines.items.len,
                            &f.scroll,
                            textRect,
                        ) or stateChanged;

                        if (mouse.isMouseInRect(textRect)) {
                            stateChanged = mouse.handleScroll(&f.scroll) or stateChanged;
                        }

                        // Redraws text only if user input or another part of
                        // the program triggers a redraw
                        if (stateChanged or state.shouldRedraw.textEditor) {
                            state.shouldRedraw.fileTabs = true;
                            editor.drawEditorBackground(textRect);
                            try editor.drawFileContents(f, textRect);
                            editor.drawScrollBars(
                                f.lines.items.len,
                                &f.scroll,
                                textRect,
                            );
                        }
                    } else if (state.shouldRedraw.textEditor) {
                        editor.drawEditorBackground(textRect);
                    }
                },
                .Terminal => {
                    var stateChanged = try terminal.handleTerminalInput();
                    stateChanged = editor.handleScrollBarMove(
                        state.terminalBuffer.items.len,
                        &state.terminalScroll,
                        textRect,
                    ) or stateChanged;

                    if (mouse.isMouseInRect(textRect)) {
                        stateChanged = mouse.handleScroll(&state.terminalScroll) or stateChanged;
                    }

                    if (stateChanged or state.shouldRedraw.terminal) {
                        state.shouldRedraw.fileTabs = true;
                        editor.drawEditorBackground(textRect);
                        try terminal.displayTerminalContents(textRect);
                        editor.drawScrollBars(
                            state.terminalBuffer.items.len,
                            &state.terminalScroll,
                            textRect,
                        );
                    }
                },
            }
        }

        { // ---- Draw file tabs ----
            const fileTabsRect = types.Recti32{
                .x = 199,
                .y = constants.topBarHeight - 1,
                .width = state.windowWidth - 199,
                .height = constants.topBarHeight,
            };

            const fileTabsRectPadding = types.Recti32{
                .x = fileTabsRect.x - 10,
                .y = fileTabsRect.y - 10,
                .width = fileTabsRect.width + 20,
                .height = fileTabsRect.height + 20,
            };

            if (mouse.isMouseInRect(fileTabsRectPadding)) {
                state.shouldRedraw.fileTabs = true;

                if (mouse.isMouseInRect(fileTabsRect)) {
                    state.pointerType = .default;
                }
            }

            if (state.shouldRedraw.fileTabs) {
                fileTabs.drawFileTabs(fileTabsRect);
            }
        }

        { // ---- Draw side bar ----
            const sideBarRect = types.Recti32{
                .x = 0,
                .y = 39,
                .width = 200,
                .height = state.windowHeight - 39,
            };

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

            try debug.drawDebugInfos();
        }

        const topBarRect = types.Recti32{
            .x = 0,
            .y = 0,
            .width = state.windowWidth,
            .height = constants.topBarHeight,
        };

        { // ---- Draw top bar ----
            const topBarRectPadding = types.Recti32{
                .x = topBarRect.x - 10,
                .y = topBarRect.y - 10,
                .width = topBarRect.width + 20,
                .height = topBarRect.height + 20,
            };

            if (mouse.isMouseInRect(topBarRectPadding)) {
                // Top bar is mostly static except for buttons
                // padding allows for buttons to disable hover color/anim
                state.shouldRedraw.topBar = true;

                if (mouse.isMouseInRect(topBarRect)) {
                    state.pointerType = .default;
                }
            }

            if (state.shouldRedraw.topBar) {
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
                    &window.closeWindow,
                );
                button.drawButton(
                    "[]",
                    22,
                    types.Recti32{
                        .x = state.windowWidth - 99,
                        .y = 0,
                        .height = topBarRect.height,
                        .width = 50,
                    },
                    types.Vec2i32{
                        .x = 15,
                        .y = 8,
                    },
                    &window.toggleMaximizeWindow,
                );
                button.drawButton(
                    "__",
                    22,
                    types.Recti32{
                        .x = state.windowWidth - 148,
                        .y = 0,
                        .height = topBarRect.height,
                        .width = 50,
                    },
                    types.Vec2i32{
                        .x = 15,
                        .y = 8,
                    },
                    &window.minimizeWindow,
                );

                rl.drawTexture(iconTexture, 7, 5, .white);
            }

            const topBarMoveRect = types.Recti32{
                .x = 119 + constants.topBarHeight + 5, // width of buttons
                .y = 0,
                .width = state.windowWidth - (119 + constants.topBarHeight + 5) - 100, // window width - width of buttons
                .height = topBarRect.height,
            };

            // Debug window move handle
            // rl.drawRectangle(
            //     topBarMoveRect.x,
            //     topBarMoveRect.y,
            //     topBarMoveRect.width,
            //     topBarMoveRect.height,
            //     rl.Color.red,
            // );

            if (mouse.isJustLeftClick() and mouse.isMouseInRect(topBarMoveRect)) {
                std.log.info("Started dragging.", .{});
                state.movingWindow = true;
                state.windowDragOrigin = state.mouseScreenPosition; // Store initial mouse position

                state.windowDragOffset = rl.Vector2{
                    .x = state.windowPosition.x - state.windowDragOrigin.x,
                    .y = state.windowPosition.y - state.windowDragOrigin.y,
                };
            } else if (!mouse.isLeftClickDown()) {
                state.movingWindow = false;
            }

            if (state.movingWindow) {
                // Needs fps cap for moving the window around
                // Removing it causes weird jitterness that gets worse with higher
                // refresh rates.
                // I honestly have no idea why this happens but it starts around 80FPS

                // This is equivalent to `state.frameCount % x == 0`
                // WARNING: right hand value of bitwise AND must be ( (multiple of 2) - 1 )

                const isFastRefreshFrame = flags.intermitentScreenRefresh and
                    (state.frameCount & ((state.forceRefreshIntervalFrames / 16) - 1)) == 0;

                if (isFastRefreshFrame) {
                    const movedRight: f32 = state.mouseScreenPosition.x - state.windowDragOrigin.x;
                    const movedBottom: f32 = state.mouseScreenPosition.y - state.windowDragOrigin.y;

                    const newPosX: f32 = state.windowDragOrigin.x + movedRight + state.windowDragOffset.x;
                    const newPosY: f32 = state.windowDragOrigin.y + movedBottom + state.windowDragOffset.y;

                    const iX: i32 = @intFromFloat(newPosX);
                    const iY: i32 = @intFromFloat(newPosY);

                    rl.setWindowPosition(iX, iY);
                }
            }
        }

        { // ---- Draw top bar menu dropdowns ----
            const menuItems = switch (state.topBarMenuOpened) {
                .None => null,

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

            if (menuItems) |_menu| {
                const menu: types.Menu = _menu;

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

        { // ---- Draw folder tree ----
            if (state.openedDir) |dir| {
                var parentStack = std.ArrayList(types.FileSystemTree).init(state.allocator);
                defer parentStack.deinit();
                // TODO: Make recursive
                for (dir.children.items) |_entry| {
                    const entry: types.FileSystemTree = _entry;
                    _ = entry;
                }
            }
        }

        { // ---- Handle state changes ----
            if (state.targetFps != state.currentTargetFps) {
                window.setTargetFps(state.targetFps);
            }

            if (state.pointerType != state.previousPointerType) {
                mouse.setMouseCursor(state.pointerType);
                state.previousPointerType = state.pointerType;
            }
        }
    }

    window.closeWindow();
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
