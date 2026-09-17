// Отрисовка плашки в буфер ARGB8888 (в памяти little-endian: B, G, R, A;
// альфа предумножена, как требует wl_shm). Фигуры — через SDF скруглённого
// прямоугольника с 1px сглаживанием, текст и иконки — растеризация fontdue.

use std::env;
use std::fs;
use std::io;

use fontdue::{Font, FontSettings};

use crate::control::{Kind, Level};

// Nord (lib/nord.nix)
const NORD1: u32 = 0x3b4252;
const NORD3: u32 = 0x4c566a;
const NORD4: u32 = 0xd8dee9;
const NORD8: u32 = 0x88c0d0;
const NORD11: u32 = 0xbf616a;
// «nord3 bright» — цвет комментариев в официальных темах Nord
const NORD3_BRIGHT: u32 = 0x616e88;

// Логические размеры (до масштаба выхода)
pub const WIDTH: u32 = 300;
pub const HEIGHT: u32 = 40;
const RADIUS: f32 = 8.0; // как у плашек waybar
const PADDING: f32 = 14.0;
const GAP: f32 = 12.0;
const ICON_PX: f32 = 20.0;
const TEXT_PX: f32 = 14.0; // как font-size waybar
const BAR_HEIGHT: f32 = 6.0;

// Material Design Icons из Symbols Nerd Font
const ICON_VOLUME_OFF: char = '\u{f0581}';
const ICON_VOLUME_LOW: char = '\u{f057f}';
const ICON_VOLUME_MEDIUM: char = '\u{f0580}';
const ICON_VOLUME_HIGH: char = '\u{f057e}';
const ICON_BRIGHTNESS_LOW: char = '\u{f00de}';
const ICON_BRIGHTNESS_MEDIUM: char = '\u{f00df}';
const ICON_BRIGHTNESS_HIGH: char = '\u{f00e0}';

pub struct Fonts {
    text: Font,
    icon: Font,
}

fn load_font(var: &str) -> io::Result<Font> {
    // пути к шрифтам из nix store подставляет обёртка (home-manager/modules/niri.nix)
    let path =
        env::var(var).map_err(|_| io::Error::other(format!("не задана переменная {var}")))?;
    let data = fs::read(&path).map_err(|e| io::Error::other(format!("{path}: {e}")))?;
    Font::from_bytes(data, FontSettings::default())
        .map_err(|e| io::Error::other(format!("{path}: {e}")))
}

impl Fonts {
    pub fn load() -> io::Result<Fonts> {
        Ok(Fonts {
            text: load_font("WOSD_TEXT_FONT")?,
            icon: load_font("WOSD_ICON_FONT")?,
        })
    }
}

fn rgb(color: u32) -> [f32; 3] {
    [(color >> 16) as u8, (color >> 8) as u8, color as u8].map(|c| c as f32 / 255.0)
}

struct Canvas {
    width: usize,
    height: usize,
    data: Vec<u8>,
}

impl Canvas {
    // «source over» с предумноженной альфой
    fn blend(&mut self, x: usize, y: usize, color: u32, alpha: f32) {
        if x >= self.width || y >= self.height || alpha <= 0.0 {
            return;
        }
        let [r, g, b] = rgb(color);
        let px = &mut self.data[(y * self.width + x) * 4..][..4];
        for (i, src) in [b, g, r, 1.0].into_iter().enumerate() {
            let dst = px[i] as f32 / 255.0;
            px[i] = ((src * alpha + dst * (1.0 - alpha)) * 255.0).round() as u8;
        }
    }

    fn rounded_rect(&mut self, x: f32, y: f32, w: f32, h: f32, radius: f32, color: u32) {
        if w <= 0.0 || h <= 0.0 {
            return;
        }
        let r = radius.min(w / 2.0).min(h / 2.0);
        let (cx, cy) = (x + w / 2.0, y + h / 2.0);
        let (hx, hy) = (w / 2.0 - r, h / 2.0 - r);
        let y0 = y.floor().max(0.0) as usize;
        let x0 = x.floor().max(0.0) as usize;
        for py in y0..(y + h).ceil() as usize {
            for px in x0..(x + w).ceil() as usize {
                let qx = (px as f32 + 0.5 - cx).abs() - hx;
                let qy = (py as f32 + 0.5 - cy).abs() - hy;
                let outside = qx.max(0.0).hypot(qy.max(0.0));
                let inside = qx.max(qy).min(0.0);
                let dist = outside + inside - r;
                self.blend(px, py, color, (0.5 - dist).clamp(0.0, 1.0));
            }
        }
    }

    // Битмап глифа с левым верхним углом в (x, y)
    fn glyph(&mut self, font: &Font, ch: char, px: f32, x: f32, y: f32, color: u32) {
        let (m, coverage) = font.rasterize(ch, px);
        let (x, y) = (x.round() as i64, y.round() as i64);
        for gy in 0..m.height {
            for gx in 0..m.width {
                let (tx, ty) = (x + gx as i64, y + gy as i64);
                if tx >= 0 && ty >= 0 {
                    let alpha = coverage[gy * m.width + gx] as f32 / 255.0;
                    self.blend(tx as usize, ty as usize, color, alpha);
                }
            }
        }
    }
}

fn text_width(font: &Font, text: &str, px: f32) -> f32 {
    text.chars()
        .map(|c| font.metrics(c, px).advance_width)
        .sum()
}

fn icon_for(level: &Level) -> char {
    match level.kind {
        Kind::Volume if level.muted || level.percent == 0 => ICON_VOLUME_OFF,
        Kind::Volume if level.percent < 34 => ICON_VOLUME_LOW,
        Kind::Volume if level.percent < 67 => ICON_VOLUME_MEDIUM,
        Kind::Volume => ICON_VOLUME_HIGH,
        Kind::Brightness if level.percent < 34 => ICON_BRIGHTNESS_LOW,
        Kind::Brightness if level.percent < 67 => ICON_BRIGHTNESS_MEDIUM,
        Kind::Brightness => ICON_BRIGHTNESS_HIGH,
    }
}

// Рисует плашку при масштабе `scale`; возвращает размер буфера и пиксели
pub fn render(fonts: &Fonts, level: &Level, scale: f32) -> (u32, u32, Vec<u8>) {
    let width = (WIDTH as f32 * scale).round() as usize;
    let height = (HEIGHT as f32 * scale).round() as usize;
    let mut c = Canvas {
        width,
        height,
        data: vec![0; width * height * 4],
    };

    let s = |v: f32| v * scale;
    let (w, h) = (width as f32, height as f32);
    let cy = h / 2.0;

    // приглушённый звук: красная иконка, уровень остаётся виден, но серым
    let (icon_color, fill_color, text_color) = if level.muted {
        (NORD11, NORD3_BRIGHT, NORD3_BRIGHT)
    } else {
        (NORD8, NORD8, NORD4)
    };

    c.rounded_rect(0.0, 0.0, w, h, s(RADIUS), NORD1);

    // иконка: центр её битмапа — в центре квадрата ICON_PX
    let icon_px = s(ICON_PX);
    let icon = icon_for(level);
    let m = fonts.icon.metrics(icon, icon_px);
    let icon_x = s(PADDING) + (icon_px - m.width as f32) / 2.0;
    c.glyph(
        &fonts.icon,
        icon,
        icon_px,
        icon_x,
        cy - m.height as f32 / 2.0,
        icon_color,
    );

    // число справа; место под «100%», чтобы полоска не прыгала
    let text_px = s(TEXT_PX);
    let text = format!("{}%", level.percent);
    let reserved = text_width(&fonts.text, "100%", text_px);
    let lm = fonts
        .text
        .horizontal_line_metrics(text_px)
        .expect("в шрифте нет горизонтальных метрик");
    let baseline = cy + (lm.ascent + lm.descent) / 2.0;
    let mut pen = w - s(PADDING) - text_width(&fonts.text, &text, text_px);
    for ch in text.chars() {
        let gm = fonts.text.metrics(ch, text_px);
        let top = baseline - gm.height as f32 - gm.ymin as f32;
        c.glyph(
            &fonts.text,
            ch,
            text_px,
            pen + gm.xmin as f32,
            top,
            text_color,
        );
        pen += gm.advance_width;
    }

    // полоска
    let bar_x = s(PADDING) + icon_px + s(GAP);
    let bar_w = w - s(PADDING) - reserved - s(GAP) - bar_x;
    let bar_h = s(BAR_HEIGHT);
    let bar_y = cy - bar_h / 2.0;
    c.rounded_rect(bar_x, bar_y, bar_w, bar_h, bar_h / 2.0, NORD3);
    let fill = bar_w * level.percent as f32 / 100.0;
    c.rounded_rect(bar_x, bar_y, fill, bar_h, bar_h / 2.0, fill_color);

    (width as u32, height as u32, c.data)
}
