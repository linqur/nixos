// Окно OSD: layer-shell поверхность сверху по центру, без фокуса и без ввода.
// Живёт, пока приходят обновления по сокету, и закрывается через HIDE_AFTER
// после последнего — процесс при этом завершается, в фоне ничего не остаётся.

use std::io::{self, BufRead, BufReader, Write};
use std::os::fd::AsFd;
use std::os::unix::net::UnixListener;
use std::time::{Duration, Instant};

use rustix::event::{PollFd, PollFlags, Timespec, poll};
use rustix::fs::{MemfdFlags, memfd_create};
use wayland_client::globals::{GlobalListContents, registry_queue_init};
use wayland_client::protocol::{
    wl_buffer::{self, WlBuffer},
    wl_compositor::WlCompositor,
    wl_region::WlRegion,
    wl_registry::WlRegistry,
    wl_shm::{self, WlShm},
    wl_shm_pool::WlShmPool,
    wl_surface::WlSurface,
};
use wayland_client::{Connection, Dispatch, QueueHandle, delegate_noop};
use wayland_protocols::wp::fractional_scale::v1::client::{
    wp_fractional_scale_manager_v1::WpFractionalScaleManagerV1,
    wp_fractional_scale_v1::{self, WpFractionalScaleV1},
};
use wayland_protocols::wp::viewporter::client::{
    wp_viewport::WpViewport, wp_viewporter::WpViewporter,
};
use wayland_protocols_wlr::layer_shell::v1::client::{
    zwlr_layer_shell_v1::{Layer, ZwlrLayerShellV1},
    zwlr_layer_surface_v1::{self, Anchor, KeyboardInteractivity, ZwlrLayerSurfaceV1},
};

use crate::control::Level;
use crate::draw::{self, Fonts};
use crate::ipc;

const HIDE_AFTER: Duration = Duration::from_millis(1200);
// как struts niri: с exclusive_zone 0 плашка встаёт под waybar, а не поверх
const MARGIN_TOP: i32 = 5;

struct State {
    shm: WlShm,
    surface: WlSurface,
    viewport: WpViewport,
    fonts: Fonts,
    level: Level,
    // масштаб в 1/120, как в wp_fractional_scale_v1
    scale120: u32,
    configured: bool,
    closed: bool,
}

impl State {
    fn redraw(&self, qh: &QueueHandle<State>) {
        if !self.configured {
            return;
        }
        let (w, h, pixels) = draw::render(&self.fonts, &self.level, self.scale120 as f32 / 120.0);
        let buffer = match self.create_buffer(w, h, &pixels, qh) {
            Ok(buffer) => buffer,
            Err(err) => {
                eprintln!("wosd: не удалось создать буфер: {err}");
                return;
            }
        };
        self.surface.attach(Some(&buffer), 0, 0);
        self.surface.damage_buffer(0, 0, w as i32, h as i32);
        self.viewport
            .set_destination(draw::WIDTH as i32, draw::HEIGHT as i32);
        self.surface.commit();
    }

    // Новый memfd на каждый кадр: обновления редкие, а так не нужно следить,
    // отпустил ли композитор предыдущий буфер. Буфер уничтожается по release.
    fn create_buffer(
        &self,
        w: u32,
        h: u32,
        pixels: &[u8],
        qh: &QueueHandle<State>,
    ) -> io::Result<WlBuffer> {
        let fd = memfd_create("wosd-buffer", MemfdFlags::CLOEXEC)?;
        let mut file = std::fs::File::from(fd);
        file.write_all(pixels)?;
        let pool = self
            .shm
            .create_pool(file.as_fd(), pixels.len() as i32, qh, ());
        let buffer = pool.create_buffer(
            0,
            w as i32,
            h as i32,
            w as i32 * 4,
            wl_shm::Format::Argb8888,
            qh,
            (),
        );
        pool.destroy();
        Ok(buffer)
    }
}

pub fn run(listener: UnixListener, fonts: Fonts, level: Level) -> io::Result<()> {
    let conn = Connection::connect_to_env()
        .map_err(|e| io::Error::other(format!("нет подключения к Wayland: {e}")))?;
    let (globals, mut queue) =
        registry_queue_init::<State>(&conn).map_err(|e| io::Error::other(e.to_string()))?;
    let qh = queue.handle();

    let missing =
        |name: &'static str| move |e| io::Error::other(format!("композитор не даёт {name}: {e}"));
    let compositor: WlCompositor = globals
        .bind(&qh, 4..=6, ())
        .map_err(missing("wl_compositor"))?;
    let shm: WlShm = globals.bind(&qh, 1..=1, ()).map_err(missing("wl_shm"))?;
    let layer_shell: ZwlrLayerShellV1 = globals
        .bind(&qh, 1..=4, ())
        .map_err(missing("zwlr_layer_shell_v1"))?;
    let viewporter: WpViewporter = globals
        .bind(&qh, 1..=1, ())
        .map_err(missing("wp_viewporter"))?;
    let fractional: Option<WpFractionalScaleManagerV1> = globals.bind(&qh, 1..=1, ()).ok();

    let surface = compositor.create_surface(&qh, ());
    let viewport = viewporter.get_viewport(&surface, &qh, ());
    if let Some(fractional) = &fractional {
        fractional.get_fractional_scale(&surface, &qh, ());
    }
    // пустая область ввода: клики проходят сквозь плашку
    let region = compositor.create_region(&qh, ());
    surface.set_input_region(Some(&region));
    region.destroy();

    // без output — niri покажет на выходе в фокусе
    let layer =
        layer_shell.get_layer_surface(&surface, None, Layer::Overlay, "wosd".into(), &qh, ());
    layer.set_anchor(Anchor::Top);
    layer.set_size(draw::WIDTH, draw::HEIGHT);
    layer.set_margin(MARGIN_TOP, 0, 0, 0);
    layer.set_exclusive_zone(0);
    layer.set_keyboard_interactivity(KeyboardInteractivity::None);
    surface.commit();

    let mut state = State {
        shm,
        surface,
        viewport,
        fonts,
        level,
        scale120: 120,
        configured: false,
        closed: false,
    };

    listener.set_nonblocking(true)?;
    let mut deadline = Instant::now() + HIDE_AFTER;

    while !state.closed {
        let now = Instant::now();
        if now >= deadline {
            break;
        }

        queue
            .dispatch_pending(&mut state)
            .map_err(|e| io::Error::other(e.to_string()))?;
        conn.flush().map_err(|e| io::Error::other(e.to_string()))?;
        let Some(guard) = queue.prepare_read() else {
            continue;
        };

        let left = deadline - now;
        let timeout = Timespec {
            tv_sec: left.as_secs() as _,
            tv_nsec: left.subsec_nanos() as _,
        };
        let (wayland_ready, ipc_ready) = {
            let wayland_fd = guard.connection_fd();
            let mut fds = [
                PollFd::new(&wayland_fd, PollFlags::IN),
                PollFd::new(&listener, PollFlags::IN),
            ];
            match poll(&mut fds, Some(&timeout)) {
                Ok(_) | Err(rustix::io::Errno::INTR) => {}
                Err(e) => return Err(e.into()),
            }
            (!fds[0].revents().is_empty(), !fds[1].revents().is_empty())
        };

        if wayland_ready {
            if let Err(e) = guard.read() {
                // WouldBlock — ложное пробуждение, остальное — разрыв соединения
                if !matches!(&e, wayland_client::backend::WaylandError::Io(io) if io.kind() == io::ErrorKind::WouldBlock)
                {
                    return Err(io::Error::other(e.to_string()));
                }
            }
        } else {
            drop(guard);
        }

        if ipc_ready && let Some(level) = accept_updates(&listener) {
            state.level = level;
            deadline = Instant::now() + HIDE_AFTER;
            state.redraw(&qh);
        }
    }

    // Сначала закрываем сокет: клиенты, успевшие подключиться, получат разрыв
    // вместо подтверждения и сами поднимут новое окно (см. main.rs).
    drop(listener);
    layer.destroy();
    state.surface.destroy();
    let _ = conn.flush();
    Ok(())
}

// Забирает всех ждущих клиентов, возвращает последнее значение
fn accept_updates(listener: &UnixListener) -> Option<Level> {
    let mut latest = None;
    while let Ok((stream, _)) = listener.accept() {
        if !ipc::same_user(&stream) {
            continue;
        }
        let _ = stream.set_nonblocking(false);
        let _ = stream.set_read_timeout(Some(ipc::TIMEOUT));
        let mut line = String::new();
        if BufReader::new(&stream).read_line(&mut line).is_err() {
            continue;
        }
        if let Some(level) = Level::decode(&line) {
            latest = Some(level);
            let _ = (&stream).write_all(ipc::ACK);
        }
    }
    latest
}

impl Dispatch<WlRegistry, GlobalListContents> for State {
    fn event(
        _: &mut Self,
        _: &WlRegistry,
        _: <WlRegistry as wayland_client::Proxy>::Event,
        _: &GlobalListContents,
        _: &Connection,
        _: &QueueHandle<Self>,
    ) {
        // список глобалов не меняется за время жизни окна
    }
}

impl Dispatch<ZwlrLayerSurfaceV1, ()> for State {
    fn event(
        state: &mut Self,
        layer: &ZwlrLayerSurfaceV1,
        event: zwlr_layer_surface_v1::Event,
        _: &(),
        _: &Connection,
        qh: &QueueHandle<Self>,
    ) {
        match event {
            zwlr_layer_surface_v1::Event::Configure { serial, .. } => {
                layer.ack_configure(serial);
                state.configured = true;
                state.redraw(qh);
            }
            zwlr_layer_surface_v1::Event::Closed => state.closed = true,
            _ => {}
        }
    }
}

impl Dispatch<WpFractionalScaleV1, ()> for State {
    fn event(
        state: &mut Self,
        _: &WpFractionalScaleV1,
        event: wp_fractional_scale_v1::Event,
        _: &(),
        _: &Connection,
        qh: &QueueHandle<Self>,
    ) {
        if let wp_fractional_scale_v1::Event::PreferredScale { scale } = event
            && scale != state.scale120
        {
            state.scale120 = scale;
            state.redraw(qh);
        }
    }
}

impl Dispatch<WlBuffer, ()> for State {
    fn event(
        _: &mut Self,
        buffer: &WlBuffer,
        event: wl_buffer::Event,
        _: &(),
        _: &Connection,
        _: &QueueHandle<Self>,
    ) {
        if let wl_buffer::Event::Release = event {
            buffer.destroy();
        }
    }
}

delegate_noop!(State: WlCompositor);
delegate_noop!(State: WlRegion);
delegate_noop!(State: WlShmPool);
delegate_noop!(State: ZwlrLayerShellV1);
delegate_noop!(State: WpViewporter);
delegate_noop!(State: WpViewport);
delegate_noop!(State: WpFractionalScaleManagerV1);
delegate_noop!(State: ignore WlShm);
delegate_noop!(State: ignore WlSurface);
