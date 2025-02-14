const rl = @import("raylib");

pub const initialWindowWidth: i32 = 1280;
pub const initialWindowHeight: i32 = 720;

pub const targetFpsHigh: i32 = 2000;
pub const targetFpsLow: i32 = 10;

pub const scrollIncrement: f32 = 2.0;
pub const scrollVelocityMultiplier: f32 = 1000.0;
pub const scrollDecayMultiplier: f32 = 20.0;

pub const paddingSize: i32 = 10;

pub const topBarHeight: i32 = 40;

pub const topBarMenuButtonWidth: i32 = 60;
pub const topBarMenuItemHeight: i32 = 30;

pub const fontSize: i32 = 20;
pub const lineHeight: i32 = fontSize;
pub const colWidth: i32 = fontSize / 2;

pub const scrollBarHeight: i32 = 80;
pub const scrollBarHeightF: f32 = 80.0;

pub const colorBackground: rl.Color = rl.Color.init(25, 25, 25, 255);
pub const colorCodeBackground: rl.Color = rl.Color.init(10, 10, 10, 245);

pub const colorLines: rl.Color = rl.Color.dark_gray;
pub const colorSelectHighlight: rl.Color = rl.Color.init(75, 75, 75, 255);
pub const colorHighlightedColumn: rl.Color = rl.Color.init(50, 50, 50, 255);

pub const colorUiFont: rl.Color = rl.Color.gray;
pub const colorCodeFont: rl.Color = rl.Color.init(240, 240, 240, 255);
