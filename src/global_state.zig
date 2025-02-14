const std = @import("std");
const rl = @import("raylib");

const types = @import("types.zig");

pub var allocator: std.mem.Allocator = undefined;

// General state (window / input)
pub var inputBuffer: std.ArrayList(types.KeyChar) = undefined;
pub var pressedKeys: std.ArrayList(types.PressedKeyState) = undefined;

pub var fontCharset: std.ArrayList(types.CodePoint) = undefined;

pub const initialWindowWidth: i32 = 1280;
pub const initialWindowHeight: i32 = 720;

pub var windowWidth: i32 = 1280;
pub var windowHeight: i32 = 720;

pub var movingWindow: bool = false;

pub var windowPosition: rl.Vector2 = rl.Vector2{ .x = 0, .y = 0 };

pub var mouseWheelMove: rl.Vector2 = rl.Vector2{ .x = 0, .y = 0 };

pub var mousePosition: rl.Vector2 = rl.Vector2{ .x = 0, .y = 0 };
pub var prevMousePosition: rl.Vector2 = rl.Vector2{ .x = 0, .y = 0 };

pub var mouseScreenPosition: rl.Vector2 = rl.Vector2{ .x = 0, .y = 0 };
pub var prevMouseScreenPosition: rl.Vector2 = rl.Vector2{ .x = 0, .y = 0 };

pub var mouseLeftClick: bool = false;
pub var prevMouseLeftClick: bool = false;

pub var mouseRightClick: bool = false;
pub var prevMouseRightClick: bool = false;

pub var topBarMenuOpened: types.TopBarMenu = .None;

pub var pointerType: rl.MouseCursor = .default;

pub var codeFont: rl.Font = undefined;
pub var uiFont: rl.Font = undefined;

// Editor state
pub var openedFiles: std.ArrayList(types.OpenedFile) = undefined;
pub var currentlyDisplayedFileIdx: usize = 0;
pub var movingScrollBarY: bool = false;

pub var openedDir: ?types.FileSystemTree = null;

pub var scrollVelocityY: f32 = 0.0;

// Theme
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
        .name = "function",
        .rgb = .{ 210, 145, 250 },
    },
    .{
        .name = "keywords",
        .rgb = .{ 230, 110, 110 },
    },
});

pub const zigStyles: []types.Style = @constCast(&[_]types.Style{
    .{
        .name = "comments",
        .expr = "//.*",
    },
    .{
        .name = "numbers",
        .expr = "\\b\\d(\\d|\\.)*",
    },
    .{
        .name = "strings",
        .expr = "\"[^\"]*\"",
    },
    .{
        .name = "operators2",
        .expr = "\\.|\\(|\\)|\\[|\\]|{|}|,|;|:",
    },
    .{
        .name = "operators",
        .expr = "=|-|\\+|\\*|\\/|>|<|&|!|?|\\|",
    },
    .{
        .name = "keywords",
        .expr = "\\b(fn|bool|true|false|try|return|const|var|pub|while|for|if|else|orelse|defer|defererr|or|and|void|null|comptime)\\b",
    },
    .{
        .name = "function",
        .expr = "@?\\w+\\s*\\(",
    },
    .{
        .name = "parent",
        .expr = "\\w+\\.",
    },
});
