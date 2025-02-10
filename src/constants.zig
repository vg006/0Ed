const rl = @import("raylib");

pub const scrollIncrement: f32 = 2.0;
pub const scrollVelocityMultiplier: f32 = 10.0;

pub const keyPressRepeatFrameNb: usize = 30;

pub const paddingSize: i32 = 10;

pub const fontSize: i32 = 20;
pub const lineHeight: i32 = fontSize;
pub const colWidth: i32 = fontSize / 2;

pub const scrollBarHeight: i32 = 80;
pub const scrollBarHeightF: f32 = 80.0;

pub const colorBackground: rl.Color = rl.Color.init(0, 0, 0, 255);
pub const colorCodeBackground: rl.Color = rl.Color.init(0, 0, 0, 245);

pub const colorLines: rl.Color = rl.Color.dark_gray;
pub const colorSelectHighlight: rl.Color = rl.Color.init(60, 75, 140, 255);
pub const colorHighlightedColumn: rl.Color = rl.Color.init(50, 50, 50, 255);

pub const colorUiFont: rl.Color = rl.Color.gray;
pub const colorCodeFont: rl.Color = rl.Color.light_gray;
