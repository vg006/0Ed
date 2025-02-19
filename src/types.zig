const std = @import("std");
const rl = @import("raylib");

const regex = @import("regex_codepoint.zig");

pub const ShouldRedraw = struct {
    topBar: bool,
    sideBar: bool,
    fileTabs: bool,
    textEditor: bool,
    terminal: bool,
};

pub const DisplayedUi = enum {
    Editor,
    Terminal,
};

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
pub const UtfLine = std.ArrayList(CodePoint);
pub const UtfLineList = std.ArrayList(UtfLine);

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

pub const FsType = enum(u8) {
    Folder,
    File,
};

pub const FileSystemTree = struct {
    name: [:0]const u8,
    path: [:0]const u8,
    children: std.ArrayList(FileSystemTree),
    type: FsType,
    expanded: bool,
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

pub const Rgb = [3]u8;

pub const ExprColor = struct {
    name: []const u8,
    rgb: Rgb,
};

pub const Style = struct {
    name: []const u8,
    expr: []const u8,
    regex: ?regex.Regex,
};

pub const MatchedStyle = struct {
    style: ?Style,
    priority: usize,
    start: usize,
    end: usize,
};

pub const MatchedColor = struct {
    start: usize,
    end: usize,
    priority: usize,
    color: Rgb,
};

pub const StyleCache = struct {
    stylesPerLines: std.ArrayList(?std.ArrayList(MatchedColor)),
    cachedLinesNb: usize,
    valid: bool,

    pub fn resize(self: *StyleCache, size: usize) !void {
        const previousSize = self.stylesPerLines.items.len;

        if (previousSize != size) {
            try self.stylesPerLines.resize(size);
        }

        if (previousSize < size) {
            for (previousSize..size) |i| {
                self.stylesPerLines.items[i] = null;
            }
        }
        self.invalidate();
    }

    pub fn invalidate(self: *StyleCache) void {
        if (!self.valid) return;

        for (self.stylesPerLines.items, 0..) |line, i| {
            if (line) |nonNullLine| {
                nonNullLine.deinit();
            }
            self.stylesPerLines.items[i] = null;
        }
        self.cachedLinesNb = 0;
        self.valid = false;
    }

    pub fn invalidateLine(self: *StyleCache, index: usize) void {
        if (!self.valid) return;

        if (self.stylesPerLines.items[index]) |nonNullLine| {
            nonNullLine.deinit();
        }
        self.stylesPerLines.items[index] = null;

        self.cachedLinesNb -%= 1;
        if (self.cachedLinesNb == std.math.maxInt(usize)) {
            self.cachedLinesNb = 0;
        }
    }

    pub fn deinit(self: *StyleCache) void {
        for (self.stylesPerLines.items) |line| {
            if (line) |nonNullLine| {
                nonNullLine.deinit();
            }
        }
        self.stylesPerLines.deinit();
    }
};

pub const OpenedFile = struct {
    name: [:0]u8,
    path: ?[:0]u8,
    lines: UtfLineList,
    styleCache: StyleCache,
    cursorPos: CursorPosition,
    scroll: rl.Vector2,
};
