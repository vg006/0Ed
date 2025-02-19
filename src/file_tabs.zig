const rl = @import("raylib");

const types = @import("types.zig");
const constants = @import("constants.zig");
const button = @import("button.zig");
const state = @import("global_state.zig");
const file = @import("file.zig");

pub fn drawFileTabs(fileTabsRect: types.Recti32) void {
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

    const terminalTabWidth = 20 + @as(i32, @intCast("Terminal".len)) * 10;

    // Draw terminal tab
    button.drawButton(
        "Terminal",
        22,
        .{
            .x = 199,
            .y = constants.topBarHeight - 1,
            .width = terminalTabWidth,
            .height = constants.topBarHeight,
        },
        .{
            .x = 10,
            .y = 8,
        },
        &displayTerminal, // Displays file with index i
    );

    const leftOffset = terminalTabWidth + 198;
    var offset: i32 = 0;

    // TODO: Scroll tabs if the width > viewport width

    var i: usize = 0;
    while (i < state.openedFiles.items.len) {
        const openedFile: *types.OpenedFile = &state.openedFiles.items[i];
        const tabWidth = 20 + @as(i32, @intCast(openedFile.name.len)) * 10;

        //std.log.info("len: {d}", .{openedFile.name.len});

        button.drawButtonArg(
            openedFile.name,
            22,
            .{
                .x = leftOffset + offset,
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
                .x = leftOffset + offset,
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

pub fn displayTerminal() void {
    state.shouldRedrawNext.terminal = true;
    state.currentDisplayedUi = .Terminal;
}
