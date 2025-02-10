// WARNING: Not implemented yet, in the works

// const std = @import("std");
// const state = @import("global_state.zig");

// const ExprType = enum(u8) {
//     root,
//     charLiteral,
//     any,
//     anyWord,
//     anyDigit,
//     anyWhitespace,
//     charSet,
//     negatedCharSet,
//     wordBound,
//     strStart,
//     strEnd,
//     logicalOr,
//     captureGroup,
//     zeroOrMany,
//     oneOrMany,
//     zeroOrOne,
// };

// const CompiledRegex = struct {
//     type: ExprType,
//     charLiteral: i32,
//     children: ?std.ArrayList(CompiledRegex),

//     fn free(self: *CompiledRegex) void {
//         if (self.children) |c| {
//             for (c.items) |re| {
//                 re.free();
//             }
//             c.deinit();
//         }
//     }
// };

// const ReMatch = struct {
//     start: usize,
//     end: usize,
// };

// pub fn compileRegex(re: []u8) CompiledRegex {
//     var regex: CompiledRegex = CompiledRegex{
//         .type = .root,
//         .charLiteral = 0,
//         .children = std.ArrayList(CompiledRegex).init(state.allocator),
//     };

//     var parentRegexStack: std.ArrayList(*CompiledRegex) = std.ArrayList(*CompiledRegex).init(state.allocator);
//     var currRegex: *CompiledRegex = &regex;

//     var escaped: bool = false;

//     for (re) |char| {
//         if (escaped) {
//             escaped = false;

//             // Any word
//             if (char == 'w') {
//                 currRegex.children.?.append(.{
//                     .type = .anyWord,
//                     .charLiteral = 0,
//                     .children = null,
//                 });
//                 continue;
//             }
//             // Any digit
//             if (char == 'd') {
//                 currRegex.children.?.append(.{
//                     .type = .anyDigit,
//                     .charLiteral = 0,
//                     .children = null,
//                 });
//                 continue;
//             }
//             // Any whitespace
//             if (char == 's') {
//                 currRegex.children.?.append(.{
//                     .type = .anyWhitespace,
//                     .charLiteral = 0,
//                     .children = null,
//                 });
//                 continue;
//             }
//             // Word bound
//             if (char == 'b') {
//                 currRegex.children.?.append(.{
//                     .type = .wordBound,
//                     .charLiteral = 0,
//                     .children = null,
//                 });
//                 continue;
//             }
//             // Tab
//             if (char == 't') {
//                 currRegex.children.?.append(.{
//                     .type = .charLiteral,
//                     .charLiteral = @intCast('\t'),
//                     .children = null,
//                 });
//                 continue;
//             }
//             // NewLine
//             if (char == 'n') {
//                 currRegex.children.?.append(.{
//                     .type = .charLiteral,
//                     .charLiteral = @intCast('\n'),
//                     .children = null,
//                 });
//                 continue;
//             }
//             // Carriage Return
//             if (char == 'r') {
//                 currRegex.children.?.append(.{
//                     .type = .charLiteral,
//                     .charLiteral = @intCast('\r'),
//                     .children = null,
//                 });
//                 continue;
//             }

//             currRegex.children.?.append(.{
//                 .type = .charLiteral,
//                 .charLiteral = char,
//                 .children = null,
//             });
//             continue;
//         }
//         // escape sequence
//         else if (char == '\\') {
//             escaped = true;
//             continue;
//         }
//         // Any chars (except newLine)
//         else if (char == '.') {
//             currRegex.children.?.append(.{
//                 .type = .any,
//                 .charLiteral = 0,
//                 .children = null,
//             });
//             continue;
//         }
//         // Capture group start
//         else if (char == '(') {
//             currRegex.children.?.append(.{
//                 .type = .captureGroup,
//                 .charLiteral = 0,
//                 .children = std.ArrayList(CompiledRegex).init(state.allocator),
//             });
//             parentRegexStack.append(currRegex);
//             currRegex = &currRegex.children.?.getLast();
//             continue;
//         }
//         // Capture group end
//         else if (char == ')') {
//             if (currRegex.type != .captureGroup) {
//                 return error.RegexSyntax;
//             }
//             currRegex = parentRegexStack.pop();
//             continue;
//         }
//         // Char set start
//         else if (char == '[') {
//             currRegex.children.?.append(.{
//                 .type = .charSet,
//                 .charLiteral = 0,
//                 .children = std.ArrayList(CompiledRegex).init(state.allocator),
//             });
//             parentRegexStack.append(currRegex);
//             currRegex = &currRegex.children.?.getLast();
//             continue;
//         }
//         // Char set end
//         else if (char == ']') {
//             if (currRegex.type != .charSet and currRegex.type != .negatedCharSet) {
//                 return error.RegexSyntax;
//             }
//             currRegex = parentRegexStack.pop();
//             continue;
//         }
//         // String start or char set negation
//         else if (char == '^') {
//             if (currRegex.type == .charSet and currRegex.children.?.items.len == 0) {
//                 currRegex.type = .negatedCharSet;
//             } else {
//                 currRegex.children.?.append(.{
//                     .type = .strStart,
//                     .charLiteral = 0,
//                     .children = null,
//                 });
//             }
//             continue;
//         }
//         // String end
//         else if (char == '$') {
//             currRegex.children.?.append(.{
//                 .type = .strEnd,
//                 .charLiteral = 0,
//                 .children = null,
//             });
//             continue;
//         }
//         // Logical OR
//         else if (char == '|') {
//             currRegex.children.?.append(.{
//                 .type = .logicalOr,
//                 .charLiteral = 0,
//                 .children = null,
//             });
//             continue;
//         }
//         // 0 or many
//         else if (char == '*') {
//             currRegex.children.?.append(.{
//                 .type = .zeroOrMany,
//                 .charLiteral = 0,
//                 .children = null,
//             });
//             continue;
//         }
//         // 1 or many
//         else if (char == '+') {
//             currRegex.children.?.append(.{
//                 .type = .oneOrMany,
//                 .charLiteral = 0,
//                 .children = null,
//             });
//             continue;
//         }
//         // 0 or 1
//         else if (char == '?') {
//             currRegex.children.?.append(.{
//                 .type = .zeroOrOne,
//                 .charLiteral = 0,
//                 .children = null,
//             });
//             continue;
//         }
//     }

//     return regex;
// }

// pub fn match(regex: CompiledRegex, text: []const u8) ?ReMatch {
//     var matchState = MatchState{
//         .pos = 0,
//         .start = 0,
//         .text = text,
//     };

//     // Try matching at each position in the text
//     while (matchState.pos <= text.len) : (matchState.pos += 1) {
//         matchState.start = matchState.pos;
//         if (matchNode(&regex, &matchState)) {
//             return ReMatch{
//                 .start = matchState.start,
//                 .end = matchState.pos,
//             };
//         }
//     }
//     return null;
// }

// const MatchState = struct {
//     pos: usize,
//     start: usize,
//     text: []const u8,
// };

// fn matchNode(node: *const CompiledRegex, matchState: *MatchState) bool {
//     switch (node.type) {
//         .root => {
//             if (node.children) |children| {
//                 return matchAlternatives(children.items, matchState);
//             }
//             return true;
//         },

//         .charLiteral => {
//             if (matchState.pos >= matchState.text.len) return false;
//             if (matchState.text[matchState.pos] != @as(u8, @intCast(node.charLiteral))) return false;
//             matchState.pos += 1;
//             return true;
//         },

//         .any => {
//             if (matchState.pos >= matchState.text.len) return false;
//             if (matchState.text[matchState.pos] == '\n') return false;
//             matchState.pos += 1;
//             return true;
//         },

//         .anyWord => {
//             if (matchState.pos >= matchState.text.len) return false;
//             const c = matchState.text[matchState.pos];
//             if (!isWordChar(c)) return false;
//             matchState.pos += 1;
//             return true;
//         },

//         .anyDigit => {
//             if (matchState.pos >= matchState.text.len) return false;
//             const c = matchState.text[matchState.pos];
//             if (c < '0' or c > '9') return false;
//             matchState.pos += 1;
//             return true;
//         },

//         .anyWhitespace => {
//             if (matchState.pos >= matchState.text.len) return false;
//             const c = matchState.text[matchState.pos];
//             if (!std.ascii.isWhitespace(c)) return false;
//             matchState.pos += 1;
//             return true;
//         },

//         .charSet, .negatedCharSet => {
//             if (matchState.pos >= matchState.text.len) return false;
//             const c = matchState.text[matchState.pos];
//             var matched = false;

//             if (node.children) |children| {
//                 for (children.items) |child| {
//                     if (child.type == .charLiteral and c == @as(u8, @intCast(child.charLiteral))) {
//                         matched = true;
//                         break;
//                     }
//                 }
//             }

//             if (node.type == .negatedCharSet) matched = !matched;
//             if (!matched) return false;

//             matchState.pos += 1;
//             return true;
//         },

//         .wordBound => {
//             if (matchState.pos > 0 and matchState.pos < matchState.text.len) {
//                 const prev = isWordChar(matchState.text[matchState.pos - 1]);
//                 const curr = isWordChar(matchState.text[matchState.pos]);
//                 return prev != curr;
//             }
//             return matchState.pos == 0 or matchState.pos == matchState.text.len;
//         },

//         .strStart => return matchState.pos == 0,

//         .strEnd => return matchState.pos == matchState.text.len,

//         .logicalOr => return true, // Just a marker, always succeeds

//         .captureGroup => {
//             if (node.children) |children| {
//                 return matchAlternatives(children.items, matchState);
//             }
//             return true;
//         },

//         .zeroOrMany => {
//             if (node.children) |children| {
//                 while (matchState.pos < matchState.text.len) {
//                     const saved_pos = matchState.pos;
//                     if (!matchAlternatives(children.items, matchState)) {
//                         matchState.pos = saved_pos;
//                         break;
//                     }
//                 }
//             }
//             return true;
//         },

//         .oneOrMany => {
//             if (node.children) |children| {
//                 var matched_once = false;

//                 while (matchState.pos < matchState.text.len) {
//                     const saved_pos = matchState.pos;
//                     if (!matchAlternatives(children.items, matchState)) {
//                         matchState.pos = saved_pos;
//                         break;
//                     }
//                     matched_once = true;
//                 }

//                 return matched_once;
//             }
//             return false;
//         },

//         .zeroOrOne => {
//             if (node.children) |children| {
//                 const saved_pos = matchState.pos;
//                 if (!matchAlternatives(children.items, matchState)) {
//                     matchState.pos = saved_pos;
//                 }
//             }
//             return true;
//         },
//     }
// }

// fn matchAlternatives(nodes: []const CompiledRegex, matchState: *MatchState) bool {
//     const saved_pos = matchState.pos;
//     var start_idx: usize = 0;

//     // Try each alternative sequence
//     while (start_idx < nodes.len) {
//         matchState.pos = saved_pos;
//         const sequence_end = findSequenceEnd(nodes, start_idx);

//         if (matchSequence(nodes[start_idx..sequence_end], matchState)) {
//             return true;
//         }

//         // Skip the OR marker if present
//         start_idx = if (sequence_end < nodes.len and nodes[sequence_end].type == .logicalOr)
//             sequence_end + 1
//         else
//             sequence_end;
//     }

//     matchState.pos = saved_pos;
//     return false;
// }

// fn matchSequence(nodes: []const CompiledRegex, matchState: *MatchState) bool {
//     for (nodes) |*node| {
//         if (!matchNode(node, matchState)) {
//             return false;
//         }
//     }
//     return true;
// }

// fn findSequenceEnd(nodes: []const CompiledRegex, start: usize) usize {
//     var i = start;
//     while (i < nodes.len) : (i += 1) {
//         if (nodes[i].type == .logicalOr) {
//             return i;
//         }
//     }
//     return nodes.len;
// }

// fn isWordChar(c: u8) bool {
//     return std.ascii.isAlphanumeric(c) or c == '_';
// }
