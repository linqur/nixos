// Минимальный Wayland-клиент для zwlr_gamma_control_unstable_v1: один раз
// выставляет фиксированную цветовую температуру на все выходы и дальше
// просто держит соединение открытым (без него композитор по протоколу
// сбрасывает гамму обратно на дефолт — см. обсуждение в tasks/arch-migration.md).

use std::io::{Seek, SeekFrom, Write};
use std::os::fd::{AsFd, OwnedFd};

use rustix::fs::{memfd_create, MemfdFlags};
use wayland_client::protocol::{
    wl_output::{self, WlOutput},
    wl_registry::{self, WlRegistry},
};
use wayland_client::{Connection, Dispatch, EventQueue, Proxy, QueueHandle};
use wayland_protocols_wlr::gamma_control::v1::client::{
    zwlr_gamma_control_manager_v1::ZwlrGammaControlManagerV1,
    zwlr_gamma_control_v1::{Event as GammaEvent, ZwlrGammaControlV1},
};

const TEMPERATURE_K: f64 = 4000.0;

// Выдавать gamma-control сразу по глобалу — рискованно: композитор может
// ещё не закончить первичный burst свойств выхода. wlsunset ждёт
// wl_output::done, прежде чем просить gamma-control — повторяем это здесь.
struct OutputEntry {
    output: WlOutput,
    done: bool,
    requested: bool,
}

struct AppState {
    manager: Option<ZwlrGammaControlManagerV1>,
    outputs: Vec<OutputEntry>,
}

impl AppState {
    fn maybe_request_controls(&mut self, qh: &QueueHandle<Self>) {
        let Some(manager) = &self.manager else { return };
        for entry in &mut self.outputs {
            if entry.done && !entry.requested {
                manager.get_gamma_control(&entry.output, qh, ());
                entry.requested = true;
            }
        }
    }
}

impl Dispatch<WlRegistry, ()> for AppState {
    fn event(
        state: &mut Self,
        registry: &WlRegistry,
        event: wl_registry::Event,
        _data: &(),
        _conn: &Connection,
        qh: &QueueHandle<Self>,
    ) {
        let wl_registry::Event::Global { name, interface, version } = event else {
            return;
        };

        match interface.as_str() {
            "wl_output" => {
                let output = registry.bind::<WlOutput, _, _>(name, version.min(4), qh, ());
                state.outputs.push(OutputEntry { output, done: false, requested: false });
            }
            "zwlr_gamma_control_manager_v1" => {
                let manager = registry.bind::<ZwlrGammaControlManagerV1, _, _>(name, version, qh, ());
                state.manager = Some(manager);
                state.maybe_request_controls(qh);
            }
            _ => {}
        }
    }
}

impl Dispatch<WlOutput, ()> for AppState {
    fn event(
        state: &mut Self,
        output: &WlOutput,
        event: wl_output::Event,
        _: &(),
        _: &Connection,
        qh: &QueueHandle<Self>,
    ) {
        if let wl_output::Event::Done = event {
            if let Some(entry) = state.outputs.iter_mut().find(|e| e.output == *output) {
                entry.done = true;
            }
            state.maybe_request_controls(qh);
        }
    }
}

impl Dispatch<ZwlrGammaControlManagerV1, ()> for AppState {
    fn event(
        _: &mut Self,
        _: &ZwlrGammaControlManagerV1,
        _event: <ZwlrGammaControlManagerV1 as Proxy>::Event,
        _: &(),
        _: &Connection,
        _: &QueueHandle<Self>,
    ) {
        // у zwlr_gamma_control_manager_v1 нет событий
    }
}

impl Dispatch<ZwlrGammaControlV1, ()> for AppState {
    fn event(
        _: &mut Self,
        control: &ZwlrGammaControlV1,
        event: GammaEvent,
        _: &(),
        _conn: &Connection,
        _qh: &QueueHandle<Self>,
    ) {
        match event {
            GammaEvent::GammaSize { size } => apply_gamma(control, size, TEMPERATURE_K),
            GammaEvent::Failed => {
                eprintln!("wgamma: композитор отказал в управлении гаммой для одного из выходов");
            }
            _ => {}
        }
    }
}

// Коэффициенты R/G/B для чёрного тела по Танеру Хелланду (tannerhelland.com,
// алгоритм общеизвестный и используется в т.ч. другими фильтрами синего).
fn kelvin_to_rgb_factors(temp_k: f64) -> (f64, f64, f64) {
    let temp = (temp_k / 100.0).clamp(10.0, 400.0);

    let red = if temp <= 66.0 {
        255.0
    } else {
        (329.698_727_446 * (temp - 60.0).powf(-0.133_204_759_2)).clamp(0.0, 255.0)
    };

    let green = if temp <= 66.0 {
        (99.470_802_586_1 * temp.ln() - 161.119_568_166_1).clamp(0.0, 255.0)
    } else {
        (288.122_169_528_3 * (temp - 60.0).powf(-0.075_514_849_2)).clamp(0.0, 255.0)
    };

    let blue = if temp >= 66.0 {
        255.0
    } else if temp <= 19.0 {
        0.0
    } else {
        (138.517_731_223_1 * (temp - 10.0).ln() - 305.044_792_730_7).clamp(0.0, 255.0)
    };

    (red / 255.0, green / 255.0, blue / 255.0)
}

fn apply_gamma(control: &ZwlrGammaControlV1, size: u32, temp_k: f64) {
    let (r_factor, g_factor, b_factor) = kelvin_to_rgb_factors(temp_k);
    let size = size as usize;

    let mut buf = Vec::<u8>::with_capacity(size * 3 * 2);
    for factor in [r_factor, g_factor, b_factor] {
        for i in 0..size {
            let value = i as f64 / (size - 1).max(1) as f64;
            let gamma = (value * factor * 65535.0).round().clamp(0.0, 65535.0) as u16;
            buf.extend_from_slice(&gamma.to_ne_bytes());
        }
    }

    match write_memfd(&buf) {
        Ok(fd) => control.set_gamma(fd.as_fd()),
        Err(err) => eprintln!("wgamma: не удалось создать буфер гамма-таблицы: {err}"),
    }
}

fn write_memfd(data: &[u8]) -> std::io::Result<OwnedFd> {
    let fd = memfd_create("wgamma-ramp", MemfdFlags::empty())?;
    let mut file = std::fs::File::from(fd);
    file.write_all(data)?;
    // Позиция файла — часть file description, она переживёт передачу fd
    // через SCM_RIGHTS. niri читает с текущей позиции (File::read_exact),
    // не с начала — без перемотки получит EOF и пришлёт failed.
    file.seek(SeekFrom::Start(0))?;
    Ok(OwnedFd::from(file))
}

fn main() {
    let conn = Connection::connect_to_env()
        .expect("нет подключения к Wayland (переменная WAYLAND_DISPLAY не задана?)");

    let mut event_queue: EventQueue<AppState> = conn.new_event_queue();
    let qh = event_queue.handle();

    let mut state = AppState { manager: None, outputs: Vec::new() };

    let display = conn.display();
    display.get_registry(&qh, ());

    event_queue
        .roundtrip(&mut state)
        .expect("не удалось получить список Wayland-объектов от композитора");

    if state.manager.is_none() {
        eprintln!("wgamma: композитор не поддерживает zwlr_gamma_control_unstable_v1");
        std::process::exit(1);
    }

    loop {
        event_queue
            .blocking_dispatch(&mut state)
            .expect("соединение с Wayland-композитором прервано");
    }
}
