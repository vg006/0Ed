const std = @import("std");
const rl = @import("raylib");

const types = @import("types.zig");

/// Global allocator for the program, may be SmpAllocator or DebugAllocator
/// depending on compilation mode (Debug/Release)
pub var allocator: std.mem.Allocator = undefined;

pub const debugAllocatorConf: std.heap.DebugAllocatorConfig = .{
    .verbose_log = true,
};

/// Will always be undefined if compilation mode is not in Release.
/// Always check for compilation mode using `builtin.mode` before accessing.
pub var debugAllocator: std.heap.DebugAllocator(debugAllocatorConf) = undefined;

/// Modifiable struct indicating the need to redraw a part of the UI.
/// Setting a field to true does not guarantee a redraw if the drawing logic
/// of the field in question was already executed this frame.
///
/// To guarantee a redraw use `shouldRedrawNext`
pub var shouldRedraw: types.ShouldRedraw = .{
    .topBar = false,
    .sideBar = false,
    .fileTabs = false,
    .textEditor = false,
    .terminal = false,
};

/// Modifiable struct indicating the need to redraw a part of the UI next frame.
pub var shouldRedrawNext: types.ShouldRedraw = .{
    .topBar = false,
    .sideBar = false,
    .fileTabs = false,
    .textEditor = false,
    .terminal = false,
};

pub var currentDisplayedUi: types.DisplayedUi = .Terminal;

/// Time spent drawing previous frame
pub var deltaTime: f32 = 0.0;
/// Number of frames rendered since the start of program, may wrap back to 0
/// on overflow.
pub var frameCount: usize = 0;

/// Modifiable var indicating the need for a change of the target FPS of the
/// program. If `targetFps != currentTargetFps`, then the target FPS will be
/// updated next frame.
pub var targetFps: i32 = 120;
/// Do not modify.
pub var currentTargetFps: i32 = 120;
// Ms/frame of the current target FPS. Do not modify.
pub var currentMsPerFrame: usize = @intFromFloat((1.0 / 120.0) * 1000.0);
// Frames per refresh interval
// Must be a power of two for fast modulo (bit shift) op
pub var forceRefreshIntervalFrames: usize = std.math.ceilPowerOfTwoAssert(usize, @intFromFloat((500.0 / 1000.0) * 120.0));

/// Buffer of keys to handle by the program. Is cleared and updated each frame,
/// do not modify.
///
/// Correctly simulates repeating keys.
pub var inputBuffer: std.ArrayList(types.KeyChar) = undefined;
/// Buffer keeping track of currently pressed keys, updated each frame do not use or modify.
///
/// See `inputBuffer` for usable input buffer.
pub var pressedKeys: std.ArrayList(types.PressedKeyState) = undefined;

/// Collection of codepoints used to define available UTF8 characters when
/// loading a font.
/// Initialized at start of program, do not modify.
pub var fontCharset: std.ArrayList(types.CodePoint) = undefined;

/// Current window width, do not modify without user input.
/// Modifying without resizing is useless
pub var windowWidth: i32 = 1280;
/// Current window height, do not modify without user input and resizing.
/// Modifying without resizing is useless
pub var windowHeight: i32 = 720;

/// Whether the window is maximized. Do not modify.
pub var windowMaximized = false;
/// Size of the window before it was maximized. Do not modify.
pub var windowSizeAndPosBeforeMaximized = types.Recti32{ .x = 0, .y = 0, .width = 0, .height = 0 };

/// Whether the window of the program should be moved along with the mouse.
/// Handled inside main loop, do not modify.
pub var movingWindow = false;
/// Current window position, do not modify without user input.
/// Modifying without moving window is useless
pub var windowPosition = rl.Vector2{ .x = 0, .y = 0 };
/// Handled inside main loop, do not modify.
pub var windowDragOrigin = rl.Vector2{ .x = 0, .y = 0 };
/// Handled inside main loop, do not modify.
pub var windowDragOffset = rl.Vector2{ .x = 0, .y = 0 };

/// Movement of the mouse's wheel during this frame. Do not modify.
pub var mouseWheelMove = rl.Vector2{ .x = 0, .y = 0 };
/// Current position of the mouse relative to window. Do not modify.
pub var mousePosition = rl.Vector2{ .x = 0, .y = 0 };
/// Current position of the mouse relative to window. Do not modify.
pub var mousePosi32 = types.Vec2i32{ .x = 0, .y = 0 };
/// Position of the mouse during the previous frame. Do not modify.
pub var prevMousePosition = rl.Vector2{ .x = 0, .y = 0 };

/// Current position of the mouse relative to the monitor.
/// This may not be accurate if the mouse is outside the bounds of the window.
/// Do not modify.
pub var mouseScreenPosition = rl.Vector2{ .x = 0, .y = 0 };
/// Position of the mouse relative to the monitor during the previous frame.
/// This may not be accurate if the mouse is outside the bounds of the window.
/// Do not modify.
pub var prevMouseScreenPosition = rl.Vector2{ .x = 0, .y = 0 };

/// Whether the left click was pressed this frame. Do not modify.
/// To know if the left click was just pressed, use `mouse.isJustLeftClick()`
pub var mouseLeftClick: bool = false;
/// Whether the left click was pressed during the previous frame. Do not modify.
pub var prevMouseLeftClick: bool = false;

/// Whether the right click was pressed this frame. Do not modify.
/// To know if the right click was just pressed, use `mouse.isJustRightClick()`
pub var mouseRightClick: bool = false;
/// Whether the right click was pressed during the previous frame. Do not modify.
pub var prevMouseRightClick: bool = false;

/// Modifiable var indicating which or none top bar menu should be open.
/// Modifying without user input is not recommended.
pub var topBarMenuOpened: types.TopBarMenu = .None;

/// Modifiable var indicating which mouse pointer should be used.
pub var pointerType: rl.MouseCursor = .default;

/// Apparently calling rl.setMouseCursor multiple time causes a memory leak
/// yikes.
/// This is just a way to reduce these calls, but yes the memory leak is well
/// and alive.
// TODO: fix raylib?
pub var previousPointerType: rl.MouseCursor = .default;

pub var codeFont: rl.Font = undefined;
pub var uiFont: rl.Font = undefined;

/// List of opened files, usually modified by the procedures in `file.zig`
/// To change which file is displayed, see `currentlyDisplayedFileIdx`
pub var openedFiles: std.ArrayList(types.OpenedFile) = undefined;
/// Modifiable index to the file to be displayed in editor.
/// Indexes directly into `openedFiles`, if is out of bounds will cause crash.
pub var currentlyDisplayedFileIdx: usize = 0;

/// Whether the vertical scrollbar should follow the mouse.
pub var movingScrollBarY: bool = false;

/// File system tree of the currently opened directory.
/// Modified by `file.openFolder`
pub var openedDir: ?types.FileSystemTree = null;

/// Velocity of the vertical scrolling, do not modify without user input.
pub var scrollVelocityY: f32 = 0.0;

// TODO: Move this to config files.
pub const styles: []types.ExprColor = @constCast(&[_]types.ExprColor{
    .{
        .name = "comments",
        .rgb = .{ 100, 100, 100 },
    },
    .{
        .name = "strings",
        .rgb = .{ 110, 195, 255 },
    },
    .{
        .name = "numbers",
        .rgb = .{ 110, 195, 255 },
    },
    .{
        .name = "operators2",
        .rgb = .{ 175, 175, 175 },
    },
    .{
        .name = "operators",
        .rgb = .{ 230, 110, 110 },
    },
    .{
        .name = "parent",
        .rgb = .{ 230, 155, 80 },
    },
    .{
        .name = "builtin",
        .rgb = .{ 110, 195, 255 },
    },
    .{
        .name = "function",
        .rgb = .{ 210, 145, 250 },
    },
    .{
        .name = "keywords",
        .rgb = .{ 230, 110, 110 },
    },
});

pub var zigStyles = [_]types.Style{
    .{
        .name = "comments",
        .expr = "//.*",
        .regex = null,
    },
    .{
        .name = "numbers",
        .expr = "\\b\\d(\\d|\\.)*",
        .regex = null,
    },
    .{
        .name = "strings",
        .expr = "\"[^\"]*\"",
        .regex = null,
    },
    .{
        .name = "operators2",
        .expr = "\\.|\\(|\\)|\\[|\\]|{|}|,|;|:",
        .regex = null,
    },
    .{
        .name = "operators",
        .expr = "=|-|\\+|\\*|\\/|>|<|&|!|\\?|\\||%",
        .regex = null,
    },
    .{
        .name = "keywords",
        .expr = "\\b(fn|bool|true|false|try|return|const|var|pub|while|for|if|else|orelse|defer|defererr|or|and|void|null|comptime|inline)\\b",
        .regex = null,
    },
    .{
        .name = "builtin",
        .expr = "@\\w+\\s*\\(",
        .regex = null,
    },
    .{
        .name = "function",
        .expr = "\\w+\\s*\\(",
        .regex = null,
    },
    .{
        .name = "parent",
        .expr = "\\w+\\.",
        .regex = null,
    },
};

// TODO: Move these to own struct to allow multiple

/// Process of the currently running terminal emulator.
/// Created by `terminal.createTerminalProcess()`
/// Do not modify.
pub var terminalProcess: std.process.Child = undefined;

/// Read buffer for the terminal process' stdout.
/// Do not use when `terminalStdoutBuffMutex` is locked.
pub var terminalStdoutBuff: std.ArrayList(u8) = undefined;
/// Read buffer for the terminal process' stderr.
/// Do not use when `terminalStderrBuffMutex` is locked.
pub var terminalStderrBuff: std.ArrayList(u8) = undefined;

/// Mutex for safely accessing `terminalStdoutBuff`
pub var terminalStdoutBuffMutex = std.Thread.Mutex{};
/// Mutex for safely accessing `terminalStderrBuff`
pub var terminalStderrBuffMutex = std.Thread.Mutex{};

pub var shouldEndAllThreads = false;

/// Thread listening to the stdout of the terminal process
/// Lifetime is same as program
pub var terminalStdoutThread: std.Thread = undefined;
/// Thread listening to the stderr of the terminal process
/// Lifetime is same as program
pub var terminalStderrThread: std.Thread = undefined;

/// Similar to how files are handled, however lines are terminated unless new
/// output should be appended to the last line.
pub var terminalBuffer: types.UtfLineList = undefined;

/// Buffer for user input in terminal.
/// Do not modify without user input.
pub var terminalUserInputBuffer: types.UtfLine = undefined;

pub var terminalScroll: rl.Vector2 = .{ .x = 0, .y = 0 };
