// OSD громкости и яркости для niri. Каждый вызов (бинд, в т.ч. автоповтор
// при зажатой клавише) меняет значение и передаёт его окну. Окна нет —
// процесс сам становится им и живёт, пока идут обновления (см. osd.rs).
//
//   wosd volume up|down|mute
//   wosd brightness up|down

mod control;
mod draw;
mod ipc;
mod osd;

use std::io;
use std::process::ExitCode;

use control::{Level, STEP};

const USAGE: &str = "использование: wosd volume up|down|mute | wosd brightness up|down";
// попытки на случай, если окно закрылось между bind и send
const ATTEMPTS: usize = 3;

fn apply(args: &[String]) -> Option<io::Result<Level>> {
    let args: Vec<&str> = args.iter().map(String::as_str).collect();
    Some(match args.as_slice() {
        ["volume", "up"] => control::volume_change(STEP),
        ["volume", "down"] => control::volume_change(-STEP),
        ["volume", "mute"] => control::volume_toggle_mute(),
        ["brightness", "up"] => control::brightness_change(STEP),
        ["brightness", "down"] => control::brightness_change(-STEP),
        _ => return None,
    })
}

fn show(level: Level) -> io::Result<()> {
    for _ in 0..ATTEMPTS {
        if let Some(listener) = ipc::bind()? {
            let fonts = draw::Fonts::load()?;
            return osd::run(listener, fonts, level);
        }
        if ipc::send(&level).is_ok() {
            return Ok(());
        }
    }
    Err(io::Error::other(
        "не удалось ни открыть окно, ни передать значение",
    ))
}

fn main() -> ExitCode {
    let args: Vec<String> = std::env::args().skip(1).collect();
    let Some(result) = apply(&args) else {
        eprintln!("{USAGE}");
        return ExitCode::from(2);
    };
    match result.and_then(show) {
        Ok(()) => ExitCode::SUCCESS,
        Err(err) => {
            eprintln!("wosd: {err}");
            ExitCode::FAILURE
        }
    }
}
