const std = @import("std");

const shouldDebugLog = false;

fn debugLog(comptime fmt: []const u8, args: anytype) void {
    if (comptime !shouldDebugLog) return;
    std.log.debug(fmt, args);
}

const ExprType = enum(u8) {
    root,
    charLiteral,
    any,
    anyWord,
    anyDigit,
    anyWhitespace,
    charSet,
    negatedCharSet,
    wordBound,
    strStart,
    strEnd,
    logicalOr,
    captureGroup,
    zeroOrMany,
    oneOrMany,
    zeroOrOne,
};

pub const Regex = struct {
    children: ?std.ArrayList(Regex),
    charLiteral: i32,
    type: ExprType,

    /// Frees the memory allocated by the compilation of the Regex.
    /// Invalidates the regex.
    pub fn deinit(self: *const Regex) void {
        if (self.children) |c| {
            for (c.items) |re| {
                re.free();
            }
            c.deinit();
        }
    }

    fn printDepth(self: *const Regex, allocator: std.mem.Allocator, depth: usize) !void {
        const padding: []u8 = try allocator.alloc(u8, depth * 4);
        defer allocator.free(padding);
        @memset(padding, ' ');

        std.debug.print("{s}{any}", .{ padding, self.type });
        if (self.children) |c| {
            std.debug.print(" {{\n", .{});
            for (c.items) |re| {
                try re.printDepth(allocator, depth + 1);
            }
            std.debug.print("{s}}},", .{padding});
        } else {
            std.debug.print(",", .{});
        }
        std.debug.print("\n", .{});
    }

    /// Print the Regex structure as a tree to stdout.
    pub fn print(self: *const Regex, allocator: std.mem.Allocator) !void {
        std.debug.print("Regex tree:\n{any} {{\n", .{self.type});
        if (self.children) |c| {
            for (c.items) |re| {
                try re.printDepth(allocator, 1);
            }
        }
        std.debug.print("}}\n", .{});
    }
};

/// Portion of the string that was matched by the RegEx.
/// `start` is inclusive and `end` is exclusive.
pub const ReMatch = struct {
    start: usize,
    end: usize,
};

/// Compiles a regular expression (string) to a Regex struct
///
/// Consumer is responsible for call to `deinit` of the Regex
pub fn compileRegex(allocator: std.mem.Allocator, re: []const u8) !Regex {
    var regex: Regex = Regex{
        .type = .root,
        .charLiteral = 0,
        .children = std.ArrayList(Regex).init(allocator),
    };

    var parentRegexStack: std.ArrayList(*Regex) = std.ArrayList(*Regex).init(allocator);
    defer parentRegexStack.deinit();

    var currRegex: *Regex = &regex;

    var escaped: bool = false;

    for (re) |char| {
        if (escaped) {
            escaped = false;

            // Any word
            if (char == 'w') {
                try currRegex.children.?.append(.{
                    .type = .anyWord,
                    .charLiteral = 0,
                    .children = null,
                });
                continue;
            }
            // Any digit
            if (char == 'd') {
                try currRegex.children.?.append(.{
                    .type = .anyDigit,
                    .charLiteral = 0,
                    .children = null,
                });
                continue;
            }
            // Any whitespace
            if (char == 's') {
                try currRegex.children.?.append(.{
                    .type = .anyWhitespace,
                    .charLiteral = 0,
                    .children = null,
                });
                continue;
            }
            // Word bound
            if (char == 'b') {
                try currRegex.children.?.append(.{
                    .type = .wordBound,
                    .charLiteral = 0,
                    .children = null,
                });
                continue;
            }
            // Tab
            if (char == 't') {
                try currRegex.children.?.append(.{
                    .type = .charLiteral,
                    .charLiteral = @intCast('\t'),
                    .children = null,
                });
                continue;
            }
            // NewLine
            if (char == 'n') {
                try currRegex.children.?.append(.{
                    .type = .charLiteral,
                    .charLiteral = @intCast('\n'),
                    .children = null,
                });
                continue;
            }
            // Carriage Return
            if (char == 'r') {
                try currRegex.children.?.append(.{
                    .type = .charLiteral,
                    .charLiteral = @intCast('\r'),
                    .children = null,
                });
                continue;
            }

            try currRegex.children.?.append(.{
                .type = .charLiteral,
                .charLiteral = char,
                .children = null,
            });
            continue;
        }
        // escape sequence
        else if (char == '\\') {
            escaped = true;
            continue;
        }
        // Any chars (except newLine)
        else if (char == '.') {
            try currRegex.children.?.append(.{
                .type = .any,
                .charLiteral = 0,
                .children = null,
            });
            continue;
        }
        // Capture group start
        else if (char == '(') {
            try parentRegexStack.append(currRegex);
            try currRegex.children.?.append(.{
                .type = .captureGroup,
                .charLiteral = 0,
                .children = std.ArrayList(Regex).init(allocator),
            });
            currRegex = &currRegex.children.?.items[currRegex.children.?.items.len - 1];
            continue;
        }
        // Capture group end
        else if (char == ')') {
            if (currRegex.type != .captureGroup) {
                return error.RegexSyntax;
            }
            currRegex = parentRegexStack.pop().?;
            continue;
        }
        // Char set start
        else if (char == '[') {
            try parentRegexStack.append(currRegex);
            try currRegex.children.?.append(.{
                .type = .charSet,
                .charLiteral = 0,
                .children = std.ArrayList(Regex).init(allocator),
            });
            currRegex = &currRegex.children.?.items[currRegex.children.?.items.len - 1];
            continue;
        }
        // Char set end
        else if (char == ']') {
            if (currRegex.type != .charSet and currRegex.type != .negatedCharSet) {
                return error.RegexSyntax;
            }
            currRegex = parentRegexStack.pop().?;
            continue;
        }
        // String start or char set negation
        else if (char == '^') {
            if (currRegex.type == .charSet and currRegex.children.?.items.len == 0) {
                currRegex.type = .negatedCharSet;
            } else {
                try currRegex.children.?.append(.{
                    .type = .strStart,
                    .charLiteral = 0,
                    .children = null,
                });
            }
            continue;
        }
        // String end
        else if (char == '$') {
            try currRegex.children.?.append(.{
                .type = .strEnd,
                .charLiteral = 0,
                .children = null,
            });
            continue;
        }
        // Logical OR
        else if (char == '|') {
            try currRegex.children.?.append(.{
                .type = .logicalOr,
                .charLiteral = 0,
                .children = null,
            });
            continue;
        }
        // 0 or many
        else if (char == '*') {
            if (currRegex.children.?.items.len == 0) {
                return error.RegexSyntax;
            }

            var wrapperRegex = Regex{
                .type = .zeroOrMany,
                .charLiteral = 0,
                .children = std.ArrayList(Regex).init(allocator),
            };
            try wrapperRegex.children.?.append(currRegex.children.?.items[currRegex.children.?.items.len - 1]);

            // Replace previous regex with wrapper
            currRegex.children.?.items[currRegex.children.?.items.len - 1] = wrapperRegex;
            continue;
        }
        // 1 or many
        else if (char == '+') {
            if (currRegex.children.?.items.len == 0) {
                return error.RegexSyntax;
            }

            var wrapperRegex = Regex{
                .type = .oneOrMany,
                .charLiteral = 0,
                .children = std.ArrayList(Regex).init(allocator),
            };
            try wrapperRegex.children.?.append(currRegex.children.?.items[currRegex.children.?.items.len - 1]);

            // Replace previous regex with wrapper
            currRegex.children.?.items[currRegex.children.?.items.len - 1] = wrapperRegex;
            continue;
        }
        // 0 or 1
        else if (char == '?') {
            if (currRegex.children.?.items.len == 0) {
                return error.RegexSyntax;
            }

            var wrapperRegex = Regex{
                .type = .zeroOrOne,
                .charLiteral = 0,
                .children = std.ArrayList(Regex).init(allocator),
            };
            try wrapperRegex.children.?.append(currRegex.children.?.items[currRegex.children.?.items.len - 1]);

            // Replace previous regex with wrapper
            currRegex.children.?.items[currRegex.children.?.items.len - 1] = wrapperRegex;
            continue;
        }
        // Char literal
        else {
            try currRegex.children.?.append(.{
                .type = .charLiteral,
                .charLiteral = char,
                .children = null,
            });
            continue;
        }
    }

    return regex;
}

const MatchState = struct {
    pos: usize,
    start: usize,
    text: []const u8,
};

pub fn match(regex: Regex, text: []const u8) ?ReMatch {
    var matchState = MatchState{
        .pos = 0,
        .start = 0,
        .text = text,
    };

    // Try matching at each position in the text
    while (matchState.pos <= text.len) : (matchState.pos += 1) {
        matchState.start = matchState.pos;
        if (matchNode(&regex, &matchState)) {
            return ReMatch{
                .start = matchState.start,
                .end = matchState.pos,
            };
        }
    }
    return null;
}

const MatchStateCodepoint = struct {
    pos: usize,
    start: usize,
    text: []const i32,
};

pub fn matchCodepoint(regex: Regex, text: []const i32) ?ReMatch {
    var matchState = MatchStateCodepoint{
        .pos = 0,
        .start = 0,
        .text = text,
    };

    // Try matching at each position in the text
    while (matchState.pos <= text.len) : (matchState.pos += 1) {
        matchState.start = matchState.pos;
        if (matchNodeCodepoint(&regex, &matchState)) {
            return ReMatch{
                .start = matchState.start,
                .end = matchState.pos,
            };
        }
    }
    return null;
}

pub fn getMatchesCodepoint(allocator: std.mem.Allocator, regex: Regex, text: []const i32) !std.ArrayList(ReMatch) {
    var result = std.ArrayList(ReMatch).init(allocator);

    var matchState = MatchStateCodepoint{
        .pos = 0,
        .start = 0,
        .text = text,
    };

    // Try matching at each position in the text
    while (matchState.pos <= text.len) : (matchState.pos += 1) {
        matchState.start = matchState.pos;
        if (matchNodeCodepoint(&regex, &matchState)) {
            try result.append(.{
                .start = matchState.start,
                .end = matchState.pos,
            });
            matchState.pos -= 1;
        }
    }
    return result;
}

fn matchNode(node: *const Regex, matchState: *MatchState) bool {
    switch (node.type) {
        .root => {
            debugLog("root", .{});
            if (node.children) |children| {
                return matchAlternatives(children.items, matchState);
            }
            return true;
        },

        .captureGroup => {
            debugLog("captureGroup", .{});
            if (node.children) |children| {
                return matchAlternatives(children.items, matchState);
            }
            return true;
        },

        .charLiteral => {
            debugLog("charLiteral exp: {d}", .{@as(u8, @intCast(node.charLiteral))});
            if (matchState.pos >= matchState.text.len) return false;
            if (matchState.text[matchState.pos] != @as(u8, @intCast(node.charLiteral))) return false;
            matchState.pos += 1;
            return true;
        },

        .any => {
            debugLog("any", .{});
            if (matchState.pos >= matchState.text.len) return false;
            if (matchState.text[matchState.pos] == '\n') return false;
            matchState.pos += 1;
            return true;
        },

        .anyWord => {
            debugLog("anyWord char: {c}", .{matchState.text[matchState.pos]});
            if (matchState.pos >= matchState.text.len) return false;
            const c = matchState.text[matchState.pos];
            if (!isWordChar(c)) return false;
            matchState.pos += 1;
            return true;
        },

        .anyDigit => {
            debugLog("anyDigit", .{});
            if (matchState.pos >= matchState.text.len) return false;
            const c = matchState.text[matchState.pos];
            if (c < '0' or c > '9') return false;
            matchState.pos += 1;
            return true;
        },

        .anyWhitespace => {
            debugLog("anyWhitespace", .{});
            if (matchState.pos >= matchState.text.len) return false;
            const c = matchState.text[matchState.pos];
            if (!std.ascii.isWhitespace(c)) return false;
            matchState.pos += 1;
            return true;
        },

        .charSet, .negatedCharSet => {
            debugLog("charSet", .{});
            if (matchState.pos >= matchState.text.len) return false;
            const c = matchState.text[matchState.pos];
            var matched = false;

            if (node.children) |children| {
                for (children.items) |child| {
                    if (child.type == .charLiteral and c == @as(u8, @intCast(child.charLiteral))) {
                        matched = true;
                        break;
                    }
                }
            }

            if (node.type == .negatedCharSet) matched = !matched;
            if (!matched) return false;

            matchState.pos += 1;
            return true;
        },

        .wordBound => {
            debugLog("wordBound", .{});
            if (matchState.pos > 0 and matchState.pos < matchState.text.len) {
                const prev = isWordChar(matchState.text[matchState.pos - 1]);
                const curr = isWordChar(matchState.text[matchState.pos]);
                return prev != curr;
            }
            return matchState.pos == 0 or matchState.pos == matchState.text.len;
        },

        .strStart => {
            debugLog("strStart", .{});
            return matchState.pos == 0;
        },

        .strEnd => {
            debugLog("strEnd", .{});
            return matchState.pos == matchState.text.len;
        },

        .logicalOr => return true, // Just a marker, always succeeds

        .zeroOrMany => {
            debugLog("zeroOrMany", .{});
            if (node.children) |children| {
                while (matchState.pos < matchState.text.len) {
                    const saved_pos = matchState.pos;
                    if (!matchNode(&children.items[0], matchState)) {
                        matchState.pos = saved_pos;
                        break;
                    }
                }
            }
            return true;
        },

        .oneOrMany => {
            debugLog("oneOrMany", .{});
            if (node.children) |children| {
                var matched_once = false;

                while (matchState.pos < matchState.text.len) {
                    const saved_pos = matchState.pos;
                    if (!matchNode(&children.items[0], matchState)) {
                        matchState.pos = saved_pos;
                        break;
                    }
                    matched_once = true;
                }

                return matched_once;
            }
            return false;
        },

        .zeroOrOne => {
            debugLog("zeroOrOne", .{});
            if (node.children) |children| {
                const saved_pos = matchState.pos;
                if (!matchNode(&children.items[0], matchState)) {
                    matchState.pos = saved_pos;
                }
            }
            return true;
        },
    }
}

fn matchOtherNodes(node: *const Regex, matchState: *MatchState) bool {
    switch (node.type) {
        .root => {
            debugLog("root", .{});
            if (node.children) |children| {
                return matchAlternatives(children.items, matchState);
            }
            return true;
        },
        .charLiteral => {
            debugLog("charLiteral", .{});
            if (matchState.pos >= matchState.text.len) return false;
            if (matchState.text[matchState.pos] != @as(u8, @intCast(node.charLiteral))) return false;
            matchState.pos += 1;
            return true;
        },
        .any => {
            debugLog("any", .{});
            if (matchState.pos >= matchState.text.len) return false;
            if (matchState.text[matchState.pos] == '\n') return false;
            matchState.pos += 1;
            return true;
        },
        .strStart => {
            debugLog("strStart", .{});
            return matchState.pos == 0;
        },
        .strEnd => {
            debugLog("strEnd", .{});
            return matchState.pos == matchState.text.len;
        },
        .logicalOr => return true,
        .captureGroup => {
            debugLog("captureGroup", .{});
            if (node.children) |children| {
                return matchAlternatives(children.items, matchState);
            }
            return true;
        },
        else => return false,
    }
}

fn matchAlternatives(nodes: []const Regex, matchState: *MatchState) bool {
    const saved_pos = matchState.pos;
    var start_idx: usize = 0;

    // Try each alternative sequence
    while (start_idx < nodes.len) {
        matchState.pos = saved_pos;
        const sequence_end = findSequenceEnd(nodes, start_idx);

        if (matchSequence(nodes[start_idx..sequence_end], matchState)) {
            return true;
        }

        // Skip the OR marker if present
        start_idx = if (sequence_end < nodes.len and nodes[sequence_end].type == .logicalOr)
            sequence_end + 1
        else
            sequence_end;
    }

    matchState.pos = saved_pos;
    return false;
}

fn matchSequence(nodes: []const Regex, matchState: *MatchState) bool {
    for (nodes) |*node| {
        if (!matchNode(node, matchState)) {
            return false;
        }
    }
    return true;
}

fn findSequenceEnd(nodes: []const Regex, start: usize) usize {
    var i = start;
    while (i < nodes.len) : (i += 1) {
        if (nodes[i].type == .logicalOr) {
            return i;
        }
    }
    return nodes.len;
}

fn isWordChar(c: u8) bool {
    return std.ascii.isAlphanumeric(c) or c == '_';
}

fn matchNodeCodepoint(node: *const Regex, matchState: *MatchStateCodepoint) bool {
    switch (node.type) {
        .root => {
            debugLog("root", .{});
            if (node.children) |children| {
                return matchAlternativesCodepoint(children.items, matchState);
            }
            return true;
        },

        .captureGroup => {
            debugLog("captureGroup", .{});
            if (node.children) |children| {
                return matchAlternativesCodepoint(children.items, matchState);
            }
            return true;
        },

        .charLiteral => {
            debugLog("charLiteral exp: {d}", .{node.charLiteral});
            if (matchState.pos >= matchState.text.len) return false;
            if (matchState.text[matchState.pos] != node.charLiteral) return false;
            matchState.pos += 1;
            return true;
        },

        .any => {
            debugLog("any", .{});
            if (matchState.pos >= matchState.text.len) return false;
            if (matchState.text[matchState.pos] == '\n') return false;
            matchState.pos += 1;
            return true;
        },

        .anyWord => {
            debugLog("anyWord char: {d}", .{matchState.text[matchState.pos]});
            if (matchState.pos >= matchState.text.len) return false;
            const c = matchState.text[matchState.pos];
            if (!isWordCodepoint(c)) return false;
            matchState.pos += 1;
            return true;
        },

        .anyDigit => {
            debugLog("anyDigit", .{});
            if (matchState.pos >= matchState.text.len) return false;
            const c = matchState.text[matchState.pos];
            if (c < '0' or c > '9') return false;
            matchState.pos += 1;
            return true;
        },

        .anyWhitespace => {
            debugLog("anyWhitespace", .{});
            if (matchState.pos >= matchState.text.len) return false;
            const c = matchState.text[matchState.pos];
            if (c > std.math.maxInt(u8)) return false;
            if (!std.ascii.isWhitespace(@intCast(c))) return false;
            matchState.pos += 1;
            return true;
        },

        .charSet, .negatedCharSet => {
            debugLog("charSet", .{});
            if (matchState.pos >= matchState.text.len) return false;
            const c = matchState.text[matchState.pos];
            var matched = false;

            if (node.children) |children| {
                for (children.items) |child| {
                    if (child.type == .charLiteral and c == child.charLiteral) {
                        matched = true;
                        break;
                    }
                }
            }

            if (node.type == .negatedCharSet) matched = !matched;
            if (!matched) return false;

            matchState.pos += 1;
            return true;
        },

        .wordBound => {
            debugLog("wordBound", .{});
            if (matchState.pos > 0 and matchState.pos < matchState.text.len) {
                const prev = isWordCodepoint(matchState.text[matchState.pos - 1]);
                const curr = isWordCodepoint(matchState.text[matchState.pos]);
                return prev != curr;
            }
            return matchState.pos == 0 or matchState.pos == matchState.text.len;
        },

        .strStart => {
            debugLog("strStart", .{});
            return matchState.pos == 0;
        },

        .strEnd => {
            debugLog("strEnd", .{});
            return matchState.pos == matchState.text.len;
        },

        .logicalOr => return true, // Just a marker, always succeeds

        .zeroOrMany => {
            debugLog("zeroOrMany", .{});
            if (node.children) |children| {
                while (matchState.pos < matchState.text.len) {
                    const saved_pos = matchState.pos;
                    if (!matchNodeCodepoint(&children.items[0], matchState)) {
                        matchState.pos = saved_pos;
                        break;
                    }
                }
            }
            return true;
        },

        .oneOrMany => {
            debugLog("oneOrMany", .{});
            if (node.children) |children| {
                var matched_once = false;

                while (matchState.pos < matchState.text.len) {
                    const saved_pos = matchState.pos;
                    if (!matchNodeCodepoint(&children.items[0], matchState)) {
                        matchState.pos = saved_pos;
                        break;
                    }
                    matched_once = true;
                }

                return matched_once;
            }
            return false;
        },

        .zeroOrOne => {
            debugLog("zeroOrOne", .{});
            if (node.children) |children| {
                const saved_pos = matchState.pos;
                if (!matchNodeCodepoint(&children.items[0], matchState)) {
                    matchState.pos = saved_pos;
                }
            }
            return true;
        },
    }
}

fn matchOtherNodesCodepoint(node: *const Regex, matchState: *MatchStateCodepoint) bool {
    switch (node.type) {
        .root => {
            debugLog("root", .{});
            if (node.children) |children| {
                return matchAlternativesCodepoint(children.items, matchState);
            }
            return true;
        },
        .charLiteral => {
            debugLog("charLiteral", .{});
            if (matchState.pos >= matchState.text.len) return false;
            if (matchState.text[matchState.pos] != node.charLiteral) return false;
            matchState.pos += 1;
            return true;
        },
        .any => {
            debugLog("any", .{});
            if (matchState.pos >= matchState.text.len) return false;
            if (matchState.text[matchState.pos] == '\n') return false;
            matchState.pos += 1;
            return true;
        },
        .strStart => {
            debugLog("strStart", .{});
            return matchState.pos == 0;
        },
        .strEnd => {
            debugLog("strEnd", .{});
            return matchState.pos == matchState.text.len;
        },
        .logicalOr => return true,
        .captureGroup => {
            debugLog("captureGroup", .{});
            if (node.children) |children| {
                return matchAlternativesCodepoint(children.items, matchState);
            }
            return true;
        },
        else => return false,
    }
}

fn matchAlternativesCodepoint(nodes: []const Regex, matchState: *MatchStateCodepoint) bool {
    const saved_pos = matchState.pos;
    var start_idx: usize = 0;

    // Try each alternative sequence
    while (start_idx < nodes.len) {
        matchState.pos = saved_pos;
        const sequence_end = findSequenceEndCodepoint(nodes, start_idx);

        if (matchSequenceCodepoint(nodes[start_idx..sequence_end], matchState)) {
            return true;
        }

        // Skip the OR marker if present
        start_idx = if (sequence_end < nodes.len and nodes[sequence_end].type == .logicalOr)
            sequence_end + 1
        else
            sequence_end;
    }

    matchState.pos = saved_pos;
    return false;
}

fn matchSequenceCodepoint(nodes: []const Regex, matchState: *MatchStateCodepoint) bool {
    for (nodes) |*node| {
        if (!matchNodeCodepoint(node, matchState)) {
            return false;
        }
    }
    return true;
}

fn findSequenceEndCodepoint(nodes: []const Regex, start: usize) usize {
    var i = start;
    while (i < nodes.len) : (i += 1) {
        if (nodes[i].type == .logicalOr) {
            return i;
        }
    }
    return nodes.len;
}

fn isWordCodepoint(c: i32) bool {
    if (c > std.math.maxInt(u8)) return false;
    return std.ascii.isAlphanumeric(@intCast(c)) or c == '_';
}
