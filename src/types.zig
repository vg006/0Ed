const std = @import("std");
const rl = @import("raylib");

pub const Recti32 = struct {
    x: i32,
    y: i32,
    width: i32,
    height: i32,
};

pub const Vec2i32 = struct {
    x: i32,
    y: i32,
};

pub const TextPos = struct {
    column: i32,
    line: i32,
};

pub const CodePoint = i32;

pub const KeyChar = struct {
    key: rl.KeyboardKey,
    char: CodePoint,
};

pub const PressedKeyState = struct {
    keyChar: KeyChar,
    pressedFrames: usize,
};

pub const CursorPosition = struct {
    start: TextPos,
    end: ?TextPos,
    dragOrigin: ?TextPos,
};

pub const OpenedFile = struct {
    name: [:0]const u8,
    path: ?[:0]const u8,
    lines: std.ArrayList(std.ArrayList(CodePoint)),
    cursorPos: CursorPosition,
    scroll: rl.Vector2,
};

pub const TopBarMenu = enum(u8) {
    None = 0,
    File,
    Edit,
};

pub const MenuItem = struct {
    name: [:0]const u8,
    callback: *const fn () void,
};

pub const Menu = struct {
    origin: Vec2i32,
    items: []MenuItem,
};
