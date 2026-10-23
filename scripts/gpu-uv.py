"""gpu-uv: undervolt dGPU NVIDIA через NVML — сдвиг кривой V/F, потолок частоты, лимит мощности, лог.

  gpu-uv status                                  текущее состояние
  sudo gpu-uv set [--offset МГц] [--max МГц] [--power Вт]
  sudo gpu-uv reset                              сброс к заводским
  gpu-uv log [файл.csv] [--interval с]           лог раз в интервал, Ctrl+C — стоп

Напряжение GeForce драйвер не отдаёт: undervolt виден как меньше ватт при той же частоте.
"""

import argparse
import csv
import sys
import time

import pynvml as n

REASONS = [
    (n.nvmlClocksEventReasonGpuIdle, "idle"),
    (n.nvmlClocksEventReasonUserDefinedClocks, "user_clocks"),  # потолок от -lgc / --max
    (n.nvmlClocksEventReasonSwPowerCap, "power_cap"),
    (n.nvmlClocksEventReasonHwSlowdown, "hw_slowdown"),
    (n.nvmlClocksEventReasonHwThermalSlowdown, "hw_thermal"),
    (n.nvmlClocksEventReasonHwPowerBrakeSlowdown, "hw_power_brake"),
    (n.nvmlClocksEventReasonSwThermalSlowdown, "sw_thermal"),
    (n.nvmlClocksEventReasonSyncBoost, "sync_boost"),
    (n.nvmlClocksEventReasonDisplayClockSetting, "display"),
]


def handle():
    n.nvmlInit()
    return n.nvmlDeviceGetHandleByIndex(0)


def reasons(h):
    mask = n.nvmlDeviceGetCurrentClocksEventReasons(h)
    return "|".join(name for bit, name in REASONS if mask & bit) or "none"


def _offset_info(h, pstate=n.NVML_PSTATE_0):
    s = n.c_nvmlClockOffset_t()
    s.version = n.nvmlClockOffset_v1
    s.type = n.NVML_CLOCK_GRAPHICS
    s.pstate = pstate
    n.nvmlDeviceGetClockOffsets(h, s)
    return s


# Новый API (ClockOffsets) на ноутбуке отдаёт диапазон 0…0, старый (GpcClkVfOffset) — ±1000 МГц.
# Берём новый, если он что-то разрешает, иначе старый.
def get_offset(h):
    s = _offset_info(h)
    if s.maxClockOffsetMHz or s.minClockOffsetMHz:
        return s.clockOffsetMHz
    return n.nvmlDeviceGetGpcClkVfOffset(h)


def set_offset(h, mhz):
    s = _offset_info(h)
    if s.maxClockOffsetMHz or s.minClockOffsetMHz:
        s.clockOffsetMHz = mhz
        n.nvmlDeviceSetClockOffsets(h, s)
    else:
        n.nvmlDeviceSetGpcClkVfOffset(h, mhz)


def sample(h):
    return {
        "time": time.strftime("%H:%M:%S"),
        "pstate": f"P{n.nvmlDeviceGetPerformanceState(h)}",
        "gr_mhz": n.nvmlDeviceGetClockInfo(h, n.NVML_CLOCK_GRAPHICS),
        "mem_mhz": n.nvmlDeviceGetClockInfo(h, n.NVML_CLOCK_MEM),
        "power_w": round(n.nvmlDeviceGetPowerUsage(h) / 1000, 1),
        "limit_w": round(n.nvmlDeviceGetEnforcedPowerLimit(h) / 1000, 1),
        "temp_c": n.nvmlDeviceGetTemperature(h, n.NVML_TEMPERATURE_GPU),
        "util": n.nvmlDeviceGetUtilizationRates(h).gpu,
        "offset": get_offset(h),
        "reasons": reasons(h),
    }


def cmd_status(h, _):
    lo, hi = n.nvmlDeviceGetGpcClkMinMaxVfOffset(h)
    plo, phi = n.nvmlDeviceGetPowerManagementLimitConstraints(h)
    print(f"{n.nvmlDeviceGetName(h)}, драйвер {n.nvmlSystemGetDriverVersion()}")
    print(f"макс. частота {n.nvmlDeviceGetMaxClockInfo(h, n.NVML_CLOCK_GRAPHICS)} МГц, "
          f"offset {lo}…{hi} МГц, лимит мощности {plo / 1000:.0f}…{phi / 1000:.0f} Вт")
    for k, v in sample(h).items():
        print(f"  {k:8} {v}")


def cmd_set(h, a):
    if a.offset is not None:
        set_offset(h, a.offset)
    if a.max is not None:
        n.nvmlDeviceSetGpuLockedClocks(h, 0, a.max)
    if a.power is not None:
        n.nvmlDeviceSetPowerManagementLimit(h, int(a.power * 1000))
    cmd_status(h, a)


def cmd_reset(h, a):
    set_offset(h, 0)
    n.nvmlDeviceResetGpuLockedClocks(h)
    n.nvmlDeviceSetPowerManagementLimit(h, n.nvmlDeviceGetPowerManagementDefaultLimit(h))
    cmd_status(h, a)


def cmd_log(h, a):
    out = open(a.file, "w", newline="") if a.file else sys.stdout
    w = None
    try:
        while True:
            row = sample(h)
            if w is None:
                w = csv.DictWriter(out, fieldnames=row.keys())
                w.writeheader()
            w.writerow(row)
            out.flush()
            if a.file:  # в файл пишем молча, на экран — короткая строка
                print(" ".join(f"{k}={v}" for k, v in row.items()), flush=True)
            time.sleep(a.interval)
    except KeyboardInterrupt:
        pass


def main():
    p = argparse.ArgumentParser(prog="gpu-uv", description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = p.add_subparsers(dest="cmd", required=True)
    sub.add_parser("status").set_defaults(fn=cmd_status)
    s = sub.add_parser("set")
    s.add_argument("--offset", type=int, help="сдвиг кривой V/F, МГц (+ = undervolt)")
    s.add_argument("--max", type=int, help="потолок частоты GPU, МГц")
    s.add_argument("--power", type=float, help="лимит мощности, Вт")
    s.set_defaults(fn=cmd_set)
    sub.add_parser("reset").set_defaults(fn=cmd_reset)
    lg = sub.add_parser("log")
    lg.add_argument("file", nargs="?")
    lg.add_argument("--interval", type=float, default=1.0)
    lg.set_defaults(fn=cmd_log)
    a = p.parse_args()
    try:
        a.fn(handle(), a)
    except n.NVMLError as e:
        hint = " (нужен sudo)" if isinstance(e, n.NVMLError_NoPermission) else ""
        sys.exit(f"gpu-uv: NVML: {e}{hint}")


if __name__ == "__main__":
    main()
