const std = @import("std");
const rl = @import("raylib");

const types = @import("types.zig");

pub var allocator: std.mem.Allocator = undefined;

// General state (window / input)
pub var inputBuffer: std.ArrayList(types.KeyChar) = undefined;
pub var pressedKeys: std.ArrayList(types.PressedKeyState) = undefined;

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

pub var editorScroll: rl.Vector2 = rl.Vector2{ .x = 0, .y = 0 };

pub var mouseLeftClick: bool = false;
pub var prevMouseLeftClick: bool = false;

pub var mouseRightClick: bool = false;
pub var prevMouseRightClick: bool = false;

pub var codeFont: rl.Font = undefined;
pub var uiFont: rl.Font = undefined;

// Editor state
pub var openedFiles: std.ArrayList(types.OpenedFile) = undefined;
pub var currentlyDisplayedFileIdx: usize = 0;
pub var movingScrollBarY: bool = false;

pub var scrollVelocityY: f32 = 0.0;
