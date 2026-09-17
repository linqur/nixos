// uki-install — установщик загрузчика (boot.loader.external) и отметка
// удачной загрузки. Схема и обоснование решений — tasks/uki.md.
//
//   uki-install <toplevel>   switch/boot/nixos-install: собрать UKI поколения,
//                            подписать ключами sbctl, положить в BOOTX64.EFI
//   uki-install mark-good    юнит после multi-user.target: скопировать
//                            загрузившийся BOOTX64.EFI в last-good.efi
//
// Состояние — только gcroot'ы: default указывает на toplevel в BOOTX64.EFI,
// good — в last-good.efi. UKI не самодостаточен (init= в cmdline ведёт
// в store), поэтому без gcroot'а GC сломал бы его. Каждый переход идёт
// через .tmp + rename, хвосты обрыва разбираются при следующем запуске.
//
// Вход — только boot.json поколения (bootspec): секция org.nixos.bootspec.v1
// даёт kernel, initrd, init и kernelParams, секция io.github.linqur.uki
// из loader.nix — пути к утилитам и точку монтирования ESP. PATH не нужен,
// версии утилит всегда от того же поколения.

use std::ffi::{OsStr, OsString};
use std::fs::{self, DirBuilder, File};
use std::io;
use std::os::fd::AsRawFd;
use std::os::unix::fs::{DirBuilderExt, MetadataExt, symlink};
use std::path::{Path, PathBuf};
use std::process::{Command, ExitCode};

use serde::Deserialize;

const USAGE: &str = "usage: uki-install <toplevel> | uki-install mark-good";
const LOCK: &str = "/run/uki-install.lock";
// tmpfs: собранный и подписанный UKI не пишется на диск до копии на ESP
const WORK: &str = "/run/uki-install";
const GCROOTS: &str = "/nix/var/nix/gcroots/uki";
const BOOTED: &str = "/run/booted-system";
const SBCTL_KEYS: &str = "/var/lib/sbctl/keys";
const ATTEMPTS: u32 = 3;
// stub, .osrel, .cmdline, .sbat и подпись поверх ядра и initrd
const OVERHEAD: u64 = 1 << 20;

type Result<T> = std::result::Result<T, String>;

#[derive(Deserialize)]
struct Bootspec {
    #[serde(rename = "org.nixos.bootspec.v1")]
    v1: V1,
    #[serde(rename = "org.nixos.specialisation.v1", default)]
    specialisations: serde_json::Map<String, serde_json::Value>,
    #[serde(rename = "io.github.linqur.uki")]
    uki: Uki,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct V1 {
    kernel: PathBuf,
    // нет при boot.initrd.enable = false
    initrd: Option<PathBuf>,
    initrd_secrets: Option<PathBuf>,
    init: PathBuf,
    kernel_params: Vec<String>,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct Uki {
    ukify: PathBuf,
    stub: PathBuf,
    sbctl: PathBuf,
    sbverify: PathBuf,
    os_release: PathBuf,
    efi_sys_mount_point: PathBuf,
}

// секция из `ukify inspect --json`; text есть только у текстовых
#[derive(Deserialize)]
struct Section {
    size: u64,
    text: Option<String>,
}

fn main() -> ExitCode {
    let args: Vec<String> = std::env::args().skip(1).collect();
    let res = match args.as_slice() {
        [cmd] if cmd == "mark-good" => mark_good(),
        [toplevel] => install(Path::new(toplevel)),
        _ => Err(USAGE.into()),
    };
    match res {
        Ok(()) => ExitCode::SUCCESS,
        Err(e) => {
            eprintln!("uki-install: {e}");
            ExitCode::FAILURE
        }
    }
}

fn install(toplevel: &Path) -> Result<()> {
    let toplevel = fs::canonicalize(toplevel).ctx(toplevel)?;
    let spec = read_bootspec(&toplevel)?;
    let esp = Esp::new(&spec.uki.efi_sys_mount_point)?;
    let _lock = lock()?;

    let uki_dst = esp.default();
    let uki_tmp = tmp(&uki_dst);
    let root = gcroot("default");
    let root_tmp = tmp(&root);

    // хвосты прошлого обрыва: default.tmp ставится после записи .tmp,
    // поэтому по паре файлов видно, на каком шаге остановились
    match (exists(&root_tmp)?, exists(&uki_tmp)?) {
        // rename BOOTX64 прошёл, осталось перевесить gcroot
        (true, false) => {
            rename(&root_tmp, &root)?;
            sync_dir(GCROOTS)?;
            println!("uki-install: finished interrupted install");
        }
        // оборвались до rename BOOTX64: он старый, default ему соответствует
        (true, true) => {
            remove(&uki_tmp)?;
            remove(&root_tmp)?;
        }
        (false, true) => remove(&uki_tmp)?,
        (false, false) => {}
    }

    // быстрая оценка до сборки, чтобы не собирать впустую
    let mut estimate = size(&spec.v1.kernel)? + OVERHEAD;
    if let Some(initrd) = &spec.v1.initrd {
        estimate += size(initrd)?;
    }
    check_space(&esp.root, estimate)?;

    ensure_keys(&spec.uki.sbctl)?;
    let work = Workdir::new()?;
    let uki = work.0.join("uki.efi");
    build(&spec, &uki)?;
    inspect(&spec, &uki)?;
    run(&spec.uki.sbctl, [OsStr::new("sign"), uki.as_os_str()])?;
    verify(&spec.uki.sbverify, &uki)?;

    check_space(&esp.root, size(&uki)?)?;
    fs::create_dir_all(parent(&uki_dst)).ctx(parent(&uki_dst))?;
    write_verified(&uki, &uki_tmp, &spec.uki.sbverify)?;

    // gcroot на новый toplevel — до rename: с этого момента он защищён,
    // даже если обрыв случится сразу после rename BOOTX64
    set_link(&root_tmp, &toplevel)?;
    rename(&uki_tmp, &uki_dst)?;
    sync_dir(parent(&uki_dst))?;
    rename(&root_tmp, &root)?;
    sync_dir(GCROOTS)?;

    println!("uki-install: installed {}", toplevel.display());
    Ok(())
}

fn mark_good() -> Result<()> {
    let _lock = lock()?;

    let default_root = gcroot("default");
    let Some(default) = read_link(&default_root)? else {
        println!("uki-install: no default gcroot, nothing to mark");
        return Ok(());
    };
    // загрузились из last-good или установка оборвалась перед переносом
    // gcroot'а: в обоих случаях BOOTX64 не тот, что загрузился
    let booted = fs::canonicalize(BOOTED).ctx(BOOTED)?;
    if booted != default {
        println!("uki-install: booted system is not default, skipping");
        return Ok(());
    }
    // установка не закончена: BOOTX64 мог уже смениться на непроверенный
    if exists(&tmp(&default_root))? {
        println!("uki-install: interrupted install pending, skipping");
        return Ok(());
    }
    let root = gcroot("good");
    let root_tmp = tmp(&root);
    if read_link(&root)?.as_ref() == Some(&default) {
        return Ok(());
    }

    let spec = read_bootspec(&booted)?;
    let esp = Esp::new(&spec.uki.efi_sys_mount_point)?;
    let good = esp.good();
    let good_tmp = tmp(&good);

    if exists(&good_tmp)? {
        // оборвались до rename last-good: он старый, good ему соответствует
        remove(&good_tmp)?;
        if exists(&root_tmp)? {
            remove(&root_tmp)?;
        }
    } else if exists(&root_tmp)? {
        // rename last-good прошёл, осталось перевесить gcroot
        rename(&root_tmp, &root)?;
        sync_dir(GCROOTS)?;
        println!("uki-install: finished interrupted mark-good");
        if read_link(&root)?.as_ref() == Some(&default) {
            return Ok(());
        }
    }

    let src = esp.default();
    check_space(&esp.root, size(&src)?)?;
    write_verified(&src, &good_tmp, &spec.uki.sbverify)?;

    // пока шла копия, старый last-good защищал старый good; после rename
    // новый защищён default (тот же toplevel), а затем и good
    set_link(&root_tmp, &default)?;
    rename(&good_tmp, &good)?;
    sync_dir(parent(&good))?;
    rename(&root_tmp, &root)?;
    sync_dir(GCROOTS)?;

    println!("uki-install: marked good {}", default.display());
    Ok(())
}

struct Esp {
    root: PathBuf,
}

impl Esp {
    // ESP должна быть отдельной ФС, иначе UKI молча ляжет в каталог
    // на корне и firmware его не увидит
    fn new(root: &Path) -> Result<Esp> {
        let dev = fs::metadata(root).ctx(root)?.dev();
        if dev == fs::metadata(parent(root)).ctx(parent(root))?.dev() {
            return Err(format!("{} is not a separate mount, ESP not mounted?", root.display()));
        }
        Ok(Esp { root: root.to_owned() })
    }

    fn default(&self) -> PathBuf {
        self.root.join("EFI/BOOT/BOOTX64.EFI")
    }

    fn good(&self) -> PathBuf {
        self.root.join("EFI/last-good.efi")
    }
}

fn read_bootspec(toplevel: &Path) -> Result<Bootspec> {
    let path = toplevel.join("boot.json");
    let data = fs::read(&path).ctx(&path)?;
    let spec: Bootspec = serde_json::from_slice(&data).map_err(|e| format!("{}: {e}", path.display()))?;
    // меню нет, выбирать специализацию негде
    if !spec.specialisations.is_empty() {
        return Err(format!("{}: specialisations are not supported", path.display()));
    }
    // скрипт дописывает секреты в initrd при установке; здесь он не
    // вызывается, а UKI без секретов не загрузится
    if spec.v1.initrd_secrets.is_some() {
        return Err(format!("{}: boot.initrd.secrets is not supported", path.display()));
    }
    Ok(spec)
}

fn cmdline(spec: &Bootspec) -> String {
    let mut parts = vec![format!("init={}", spec.v1.init.display())];
    parts.extend(spec.v1.kernel_params.iter().cloned());
    parts.join(" ")
}

fn build(spec: &Bootspec, out: &Path) -> Result<()> {
    let mut args: Vec<OsString> = vec!["build".into(), "--linux".into(), spec.v1.kernel.clone().into()];
    if let Some(initrd) = &spec.v1.initrd {
        args.extend(["--initrd".into(), initrd.clone().into()]);
    }
    let mut osrel = OsString::from("@");
    osrel.push(&spec.uki.os_release);
    args.extend([
        "--cmdline".into(),
        cmdline(spec).into(),
        "--os-release".into(),
        osrel,
        "--stub".into(),
        spec.uki.stub.clone().into(),
        "--output".into(),
        out.into(),
    ]);
    run(&spec.uki.ukify, args).map(drop)
}

// секции собранного UKI совпадают с тем, что в него клали
fn inspect(spec: &Bootspec, uki: &Path) -> Result<()> {
    // файл — сразу после inspect, иначе ukify его не принимает
    let out = run(&spec.uki.ukify, [OsStr::new("inspect"), uki.as_os_str(), OsStr::new("--json=short")])?;
    let sections: serde_json::Map<String, serde_json::Value> =
        serde_json::from_slice(&out).map_err(|e| format!("ukify inspect: {e}"))?;
    let section = |name: &str| -> Result<Section> {
        let v = sections.get(name).ok_or_else(|| format!("{}: no {name} section", uki.display()))?;
        Section::deserialize(v).map_err(|e| format!("{}: {name}: {e}", uki.display()))
    };
    let check = |name: &str, ok: bool| {
        if ok { Ok(()) } else { Err(format!("{}: {name} section does not match", uki.display())) }
    };

    check(".linux", section(".linux")?.size == size(&spec.v1.kernel)?)?;
    if let Some(initrd) = &spec.v1.initrd {
        check(".initrd", section(".initrd")?.size == size(initrd)?)?;
    }
    check(".cmdline", section(".cmdline")?.text == Some(cmdline(spec)))?;
    let osrel = fs::read_to_string(&spec.uki.os_release).ctx(&spec.uki.os_release)?;
    check(".osrel", section(".osrel")?.text == Some(osrel))
}

// enroll сознательно не делается: это ручной шаг install.sh в Setup Mode
fn ensure_keys(sbctl: &Path) -> Result<()> {
    if exists(&Path::new(SBCTL_KEYS).join("db/db.key"))? {
        return Ok(());
    }
    run(sbctl, ["create-keys"])?;
    println!("uki-install: created Secure Boot keys in {SBCTL_KEYS}");
    Ok(())
}

// sbctl verify проверяет только ESP целиком, отдельный файл — через sbverify
fn verify(sbverify: &Path, file: &Path) -> Result<()> {
    let cert = Path::new(SBCTL_KEYS).join("db/db.pem");
    run(sbverify, [OsStr::new("--cert"), cert.as_os_str(), file.as_os_str()]).map(drop)
}

// Каждая неудачная попытка — warning, даже если следующая прошла:
// деградация носителя должна быть видна. После всех неудач .tmp удаляется,
// целевой файл не тронут.
fn write_verified(src: &Path, dst: &Path, sbverify: &Path) -> Result<()> {
    for attempt in 1..=ATTEMPTS {
        if exists(dst)? {
            remove(dst)?;
        }
        match copy_verified(src, dst, sbverify) {
            Ok(()) => return Ok(()),
            Err(e) => eprintln!("uki-install: warning: {}: attempt {attempt}/{ATTEMPTS}: {e}", dst.display()),
        }
    }
    if exists(dst)? {
        remove(dst)?;
    }
    Err(format!("{}: write failed {ATTEMPTS} times, target untouched", dst.display()))
}

// подпись проверяется по тому, что на носителе: после fsync страницы
// чистые, DONTNEED выкидывает их из кеша, и sbverify читает с диска
fn copy_verified(src: &Path, dst: &Path, sbverify: &Path) -> Result<()> {
    let mut input = File::open(src).ctx(src)?;
    let mut out = File::create(dst).ctx(dst)?;
    io::copy(&mut input, &mut out).ctx(dst)?;
    out.sync_all().ctx(dst)?;
    let rc = unsafe { libc::posix_fadvise(out.as_raw_fd(), 0, 0, libc::POSIX_FADV_DONTNEED) };
    if rc != 0 {
        return Err(format!("{}: fadvise: {}", dst.display(), io::Error::from_raw_os_error(rc)));
    }
    drop(out);
    verify(sbverify, dst)
}

// размер округляется до кластера: FAT выделяет место ими
fn check_space(dir: &Path, need: u64) -> Result<()> {
    let mut st: libc::statvfs = unsafe { std::mem::zeroed() };
    let cpath = std::ffi::CString::new(dir.as_os_str().as_encoded_bytes()).map_err(|e| e.to_string())?;
    if unsafe { libc::statvfs(cpath.as_ptr(), &mut st) } != 0 {
        return Err(format!("{}: statvfs: {}", dir.display(), io::Error::last_os_error()));
    }
    let cluster = st.f_frsize as u64;
    let need = need.div_ceil(cluster) * cluster;
    let free = st.f_bavail as u64 * cluster;
    if free < need {
        return Err(format!(
            "{}: not enough space: need {} MiB, free {} MiB",
            dir.display(),
            need.div_ceil(1 << 20),
            free >> 20
        ));
    }
    Ok(())
}

// install и mark-good не должны идти одновременно: оба трогают default
fn lock() -> Result<File> {
    let f = File::options().create(true).truncate(false).write(true).open(LOCK).ctx(LOCK)?;
    if unsafe { libc::flock(f.as_raw_fd(), libc::LOCK_EX) } != 0 {
        return Err(format!("{LOCK}: flock: {}", io::Error::last_os_error()));
    }
    Ok(f)
}

// рабочий каталог в tmpfs; остаток прошлого обрыва удаляется (под lock)
struct Workdir(PathBuf);

impl Workdir {
    fn new() -> Result<Workdir> {
        if exists(Path::new(WORK))? {
            fs::remove_dir_all(WORK).ctx(WORK)?;
        }
        DirBuilder::new().mode(0o700).create(WORK).ctx(WORK)?;
        Ok(Workdir(WORK.into()))
    }
}

impl Drop for Workdir {
    fn drop(&mut self) {
        let _ = fs::remove_dir_all(&self.0);
    }
}

fn run<I, S>(prog: &Path, args: I) -> Result<Vec<u8>>
where
    I: IntoIterator<Item = S>,
    S: AsRef<OsStr>,
{
    let args: Vec<OsString> = args.into_iter().map(|a| a.as_ref().to_owned()).collect();
    let out = Command::new(prog).args(&args).output().ctx(prog)?;
    if !out.status.success() {
        let name = prog.file_name().unwrap_or(prog.as_os_str()).to_string_lossy();
        let args: Vec<_> = args.iter().map(|a| a.to_string_lossy()).collect();
        return Err(format!(
            "{name} {}: {}\n{}{}",
            args.join(" "),
            out.status,
            String::from_utf8_lossy(&out.stdout),
            String::from_utf8_lossy(&out.stderr)
        ));
    }
    Ok(out.stdout)
}

fn gcroot(name: &str) -> PathBuf {
    Path::new(GCROOTS).join(name)
}

// fsync каталога: без него при обрыве симлинк может не дожить до rename
// BOOTX64, и новый toplevel окажется без защиты от GC
fn set_link(link: &Path, target: &Path) -> Result<()> {
    fs::create_dir_all(GCROOTS).ctx(GCROOTS)?;
    if exists(link)? {
        remove(link)?;
    }
    symlink(target, link).ctx(link)?;
    sync_dir(GCROOTS)
}

fn read_link(link: &Path) -> Result<Option<PathBuf>> {
    match fs::read_link(link) {
        Ok(p) => Ok(Some(p)),
        Err(e) if e.kind() == io::ErrorKind::NotFound => Ok(None),
        Err(e) => Err(format!("{}: {e}", link.display())),
    }
}

fn tmp(path: &Path) -> PathBuf {
    let mut s = path.as_os_str().to_owned();
    s.push(".tmp");
    s.into()
}

fn parent(path: &Path) -> &Path {
    path.parent().unwrap_or(Path::new("/"))
}

fn exists(path: &Path) -> Result<bool> {
    match fs::symlink_metadata(path) {
        Ok(_) => Ok(true),
        Err(e) if e.kind() == io::ErrorKind::NotFound => Ok(false),
        Err(e) => Err(format!("{}: {e}", path.display())),
    }
}

fn size(path: &Path) -> Result<u64> {
    Ok(fs::metadata(path).ctx(path)?.len())
}

fn remove(path: &Path) -> Result<()> {
    fs::remove_file(path).ctx(path)
}

fn rename(from: &Path, to: &Path) -> Result<()> {
    fs::rename(from, to).map_err(|e| format!("rename {} -> {}: {e}", from.display(), to.display()))
}

fn sync_dir(dir: impl AsRef<Path>) -> Result<()> {
    let dir = dir.as_ref();
    File::open(dir).ctx(dir)?.sync_all().ctx(dir)
}

trait Ctx<T> {
    fn ctx(self, what: impl AsRef<Path>) -> Result<T>;
}

impl<T> Ctx<T> for io::Result<T> {
    fn ctx(self, what: impl AsRef<Path>) -> Result<T> {
        self.map_err(|e| format!("{}: {e}", what.as_ref().display()))
    }
}
