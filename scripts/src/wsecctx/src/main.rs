// Регистрирует в композиторе слушающий сокет через wp_security_context_v1:
// клиенты, подключённые к нему, композитор помечает как изолированные (niri
// скрывает от них снимки экрана, data-control, виртуальный ввод, список окон).
//
// Использование: wsecctx <путь-сокета> <sandbox-engine> [app-id] < <close-fd>
//
// Процесс не висит: после commit сокет принадлежит композитору и слушается,
// пока на stdin не придёт POLLHUP — то есть пока не закроются все пишущие
// концы. Обёртка держит пишущий конец FIFO и тем самым — время жизни сокета.

use std::os::fd::AsFd;
use std::os::unix::net::UnixListener;
use std::process::ExitCode;

use wayland_client::globals::{registry_queue_init, GlobalListContents};
use wayland_client::protocol::wl_registry::{self, WlRegistry};
use wayland_client::{delegate_noop, Connection, Dispatch, QueueHandle};
use wayland_protocols::wp::security_context::v1::client::{
    wp_security_context_manager_v1::WpSecurityContextManagerV1,
    wp_security_context_v1::WpSecurityContextV1,
};

struct AppState;

impl Dispatch<WlRegistry, GlobalListContents> for AppState {
    fn event(
        _state: &mut Self,
        _registry: &WlRegistry,
        _event: wl_registry::Event,
        _data: &GlobalListContents,
        _conn: &Connection,
        _qh: &QueueHandle<Self>,
    ) {
    }
}

delegate_noop!(AppState: ignore WpSecurityContextManagerV1);
delegate_noop!(AppState: ignore WpSecurityContextV1);

fn run(socket: &str, engine: &str, app_id: Option<&str>) -> Result<(), String> {
    let conn = Connection::connect_to_env().map_err(|e| format!("нет Wayland: {e}"))?;
    let (globals, mut queue) =
        registry_queue_init::<AppState>(&conn).map_err(|e| format!("реестр: {e}"))?;
    let qh = queue.handle();
    let manager: WpSecurityContextManagerV1 = globals
        .bind(&qh, 1..=1, ())
        .map_err(|e| format!("композитор не поддерживает wp_security_context_v1: {e}"))?;

    let listener = UnixListener::bind(socket).map_err(|e| format!("{socket}: {e}"))?;
    let stdin = std::io::stdin();
    let context = manager.create_listener(listener.as_fd(), stdin.as_fd(), &qh, ());
    context.set_sandbox_engine(engine.to_owned());
    if let Some(app_id) = app_id {
        context.set_app_id(app_id.to_owned());
    }
    context.commit();
    context.destroy();
    // roundtrip: дождаться, что композитор принял сокет, и получить ошибку протокола, если она есть
    queue.roundtrip(&mut AppState).map_err(|e| format!("композитор отклонил сокет: {e}"))?;
    Ok(())
}

fn main() -> ExitCode {
    let args: Vec<String> = std::env::args().skip(1).collect();
    let (socket, engine, app_id) = match args.as_slice() {
        [s, e] => (s, e, None),
        [s, e, a] => (s, e, Some(a.as_str())),
        _ => {
            eprintln!("использование: wsecctx <путь-сокета> <sandbox-engine> [app-id] < <close-fd>");
            return ExitCode::from(2);
        }
    };
    match run(socket, engine, app_id) {
        Ok(()) => ExitCode::SUCCESS,
        Err(e) => {
            eprintln!("wsecctx: {e}");
            ExitCode::FAILURE
        }
    }
}
