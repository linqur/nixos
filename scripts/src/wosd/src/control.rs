// Изменение громкости и яркости. Значения храним в целых процентах и сами
// считаем следующее: `wpctl set-volume 1%+` копит ошибку округления float,
// а у подсветки шаг в «сырых» единицах зависит от max_brightness.

use std::fs;
use std::io;
use std::path::PathBuf;
use std::process::Command;

pub const STEP: i32 = 1;
// 0% у подсветки на многих панелях — полностью чёрный экран
const MIN_BRIGHTNESS: i32 = 1;
const SINK: &str = "@DEFAULT_AUDIO_SINK@";

#[derive(Clone, Copy, PartialEq)]
pub enum Kind {
    Volume,
    Brightness,
}

#[derive(Clone, Copy)]
pub struct Level {
    pub kind: Kind,
    pub percent: u8,
    pub muted: bool,
}

impl Level {
    // Строка протокола между процессами: «volume 45 1»
    pub fn encode(&self) -> String {
        let kind = match self.kind {
            Kind::Volume => "volume",
            Kind::Brightness => "brightness",
        };
        format!("{kind} {} {}\n", self.percent, self.muted as u8)
    }

    pub fn decode(line: &str) -> Option<Level> {
        let mut parts = line.split_whitespace();
        let kind = match parts.next()? {
            "volume" => Kind::Volume,
            "brightness" => Kind::Brightness,
            _ => return None,
        };
        let percent = parts.next()?.parse::<u8>().ok()?.min(100);
        let muted = parts.next()? == "1";
        Some(Level {
            kind,
            percent,
            muted,
        })
    }
}

fn run(cmd: &str, args: &[&str]) -> io::Result<String> {
    let out = Command::new(cmd).args(args).output()?;
    if !out.status.success() {
        let stderr = String::from_utf8_lossy(&out.stderr);
        return Err(io::Error::other(format!("{cmd}: {}", stderr.trim())));
    }
    Ok(String::from_utf8_lossy(&out.stdout).into_owned())
}

// «Volume: 0.45» или «Volume: 0.45 [MUTED]»
fn volume_get() -> io::Result<Level> {
    let out = run("wpctl", &["get-volume", SINK])?;
    let value = out
        .split_whitespace()
        .nth(1)
        .and_then(|v| v.parse::<f64>().ok())
        .ok_or_else(|| io::Error::other(format!("wpctl: неожиданный вывод «{}»", out.trim())))?;
    Ok(Level {
        kind: Kind::Volume,
        percent: (value * 100.0).round().clamp(0.0, 100.0) as u8,
        muted: out.contains("[MUTED]"),
    })
}

pub fn volume_change(delta: i32) -> io::Result<Level> {
    let mut level = volume_get()?;
    let target = (level.percent as i32 + delta).clamp(0, 100);
    if target != level.percent as i32 {
        run(
            "wpctl",
            &["set-volume", SINK, &format!("{:.2}", target as f64 / 100.0)],
        )?;
        level.percent = target as u8;
    }
    Ok(level)
}

pub fn volume_toggle_mute() -> io::Result<Level> {
    run("wpctl", &["set-mute", SINK, "toggle"])?;
    volume_get()
}

struct Backlight {
    name: String,
    current: i32,
    max: i32,
}

fn read_int(path: PathBuf) -> io::Result<i32> {
    fs::read_to_string(&path)?
        .trim()
        .parse()
        .map_err(|_| io::Error::other(format!("{}: не число", path.display())))
}

// Первое устройство в /sys/class/backlight (на ноутбуке оно одно)
fn backlight() -> io::Result<Backlight> {
    let mut names: Vec<String> = fs::read_dir("/sys/class/backlight")?
        .filter_map(|e| e.ok()?.file_name().into_string().ok())
        .collect();
    names.sort();
    let name = names
        .into_iter()
        .next()
        .ok_or_else(|| io::Error::other("нет устройств в /sys/class/backlight"))?;
    let dir = PathBuf::from("/sys/class/backlight").join(&name);
    Ok(Backlight {
        current: read_int(dir.join("brightness"))?,
        max: read_int(dir.join("max_brightness"))?.max(1),
        name,
    })
}

fn to_percent(raw: i32, max: i32) -> i32 {
    (raw as f64 * 100.0 / max as f64).round() as i32
}

pub fn brightness_change(delta: i32) -> io::Result<Level> {
    let bl = backlight()?;
    let percent = to_percent(bl.current, bl.max);
    let target = (percent + delta).clamp(MIN_BRIGHTNESS, 100);
    let mut raw = (target as f64 * bl.max as f64 / 100.0).round() as i32;
    // при max_brightness < 100 соседние проценты могут дать то же сырое значение
    if raw == bl.current && target != percent {
        raw = (bl.current + delta.signum()).clamp(0, bl.max);
    }

    if raw != bl.current {
        // sysfs-файл пишет только root; logind разрешает SetBrightness
        // активной сессии без udev-правил и групп
        run(
            "busctl",
            &[
                "call",
                "org.freedesktop.login1",
                "/org/freedesktop/login1/session/auto",
                "org.freedesktop.login1.Session",
                "SetBrightness",
                "ssu",
                "backlight",
                &bl.name,
                &raw.to_string(),
            ],
        )?;
    }

    Ok(Level {
        kind: Kind::Brightness,
        percent: to_percent(raw, bl.max).clamp(0, 100) as u8,
        muted: false,
    })
}
