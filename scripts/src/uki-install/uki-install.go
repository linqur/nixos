// uki-install — установщик загрузчика для system.build.installBootLoader.
//
// switch-to-configuration (nixos-rebuild boot/switch, nixos-install) вызывает
// его с единственным аргументом — toplevel ставящегося поколения. Из него
// собирается UKI, подписывается ключами sbctl и раскладывается на ESP:
//
//	EFI/BOOT/BOOTX64.EFI              — дефолтный путь, firmware грузит его
//	                                    сама, без записей в NVRAM;
//	EFI/Linux/nixos-generation-N.efi  — архив для ручного выбора в Boot
//	                                    Manager: 3 последних + текущее.
//
// Вход — только $1/boot.json (bootspec, RFC 0125), а не раскладка файлов
// внутри toplevel: bootspec — контракт между NixOS и установщиками
// загрузчика, раскладка — внутреннее устройство. Секция
// org.nixos.bootspec.v1 даёт kernel, initrd, init и kernelParams.
// Секция io.github.linqur.uki кладётся туда же из loader.nix через
// boot.bootspec.extensions и даёт пути к stub, ukify, sbctl и os-release.
// Их знает Nix при сборке, поэтому PATH (при switch-to-configuration
// и nixos-install он не гарантирован) не нужен, а версии утилит всегда
// совпадают со ставящимся поколением.
package main

import (
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"io/fs"
	"os"
	"os/exec"
	"path/filepath"
	"slices"
	"strconv"
	"strings"
	"syscall"
)

const (
	esp       = "/boot"
	profile   = "/nix/var/nix/profiles/system"
	sbctlKeys = "/var/lib/sbctl/keys"
	keep      = 3
	genPrefix = "nixos-generation-"
	genSuffix = ".efi"
)

// bootspec — нужная часть boot.json. Остальные поля (label, system,
// toplevel, специализации) не читаются: неизвестные ключи encoding/json
// пропускает, так что новые версии схемы разбор не ломают.
type bootspec struct {
	V1 struct {
		Kernel        string   `json:"kernel"`
		Initrd        string   `json:"initrd"`
		InitrdSecrets string   `json:"initrdSecrets"`
		Init          string   `json:"init"`
		KernelParams  []string `json:"kernelParams"`
	} `json:"org.nixos.bootspec.v1"`
	UKI struct {
		Stub      string `json:"stub"`
		Ukify     string `json:"ukify"`
		Sbctl     string `json:"sbctl"`
		OSRelease string `json:"osRelease"`
	} `json:"io.github.linqur.uki"`
}

func main() {
	// Вся работа в run, чтобы defer (удаление временного каталога)
	// срабатывал и при ошибке: os.Exit его пропускает.
	if err := run(os.Args[1:]); err != nil {
		fmt.Fprintln(os.Stderr, "uki-install:", err)
		os.Exit(1)
	}
}

func run(args []string) error {
	if len(args) != 1 {
		return errors.New("usage: uki-install <toplevel>")
	}
	toplevel, err := filepath.EvalSymlinks(args[0])
	if err != nil {
		return err
	}

	gen, err := generation(toplevel)
	if err != nil {
		return err
	}
	spec, err := readBootspec(toplevel)
	if err != nil {
		return err
	}
	if err := checkESP(); err != nil {
		return err
	}
	if err := ensureKeys(spec.UKI.Sbctl); err != nil {
		return err
	}

	tmp, err := os.MkdirTemp("", "uki-install-")
	if err != nil {
		return err
	}
	defer os.RemoveAll(tmp)
	uki := filepath.Join(tmp, "uki.efi")

	if err := buildUKI(spec, uki); err != nil {
		return err
	}
	if err := runCmd(spec.UKI.Sbctl, "sign", uki); err != nil {
		return err
	}

	// Сначала архив, потом дефолт: при обрыве между ними дефолт остаётся
	// старым и рабочим, а новое поколение уже лежит в архиве.
	linuxDir := filepath.Join(esp, "EFI", "Linux")
	archive := filepath.Join(linuxDir, genPrefix+strconv.Itoa(gen)+genSuffix)
	if err := install(uki, archive); err != nil {
		return err
	}
	if err := install(uki, filepath.Join(esp, "EFI", "BOOT", "BOOTX64.EFI")); err != nil {
		return err
	}
	fmt.Printf("uki-install: generation %d installed\n", gen)

	return prune(linuxDir, gen)
}

// generation возвращает N из профиля system -> system-N-link и проверяет,
// что профиль указывает именно на ставящийся toplevel. Запуск
// switch-to-configuration из ./result мимо профиля или рассинхрон дают
// ошибку, а не файл на ESP под чужим номером.
func generation(toplevel string) (int, error) {
	link, err := os.Readlink(profile)
	if err != nil {
		return 0, err
	}
	n, ok := parseNumber(filepath.Base(link), "system-", "-link")
	if !ok {
		return 0, fmt.Errorf("%s -> %s: not a system-N-link", profile, link)
	}
	target, err := filepath.EvalSymlinks(profile)
	if err != nil {
		return 0, err
	}
	if target != toplevel {
		return 0, fmt.Errorf("%s points to %s, not to %s", profile, target, toplevel)
	}
	return n, nil
}

// checkESP проверяет, что в /boot смонтирована отдельная ФС. Иначе UKI
// молча ляжет в каталог на корне, и firmware его не увидит.
func checkESP() error {
	var boot, root syscall.Stat_t
	if err := syscall.Stat(esp, &boot); err != nil {
		return fmt.Errorf("%s: %w", esp, err)
	}
	if err := syscall.Stat("/", &root); err != nil {
		return err
	}
	if boot.Dev == root.Dev {
		return fmt.Errorf("%s is not a separate mount, ESP not mounted?", esp)
	}
	return nil
}

// readBootspec читает boot.json поколения и проверяет, что в нём есть
// всё, без чего UKI не собрать. Пустое поле — ошибка сразу, а не
// невнятный отказ ukify посреди установки.
func readBootspec(toplevel string) (*bootspec, error) {
	path := filepath.Join(toplevel, "boot.json")
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("%w (boot.bootspec.enable disabled?)", err)
	}
	var spec bootspec
	if err := json.Unmarshal(data, &spec); err != nil {
		return nil, fmt.Errorf("%s: %w", path, err)
	}

	required := []struct{ key, val string }{
		{"org.nixos.bootspec.v1.kernel", spec.V1.Kernel},
		{"org.nixos.bootspec.v1.init", spec.V1.Init},
		{"io.github.linqur.uki.stub", spec.UKI.Stub},
		{"io.github.linqur.uki.ukify", spec.UKI.Ukify},
		{"io.github.linqur.uki.sbctl", spec.UKI.Sbctl},
		{"io.github.linqur.uki.osRelease", spec.UKI.OSRelease},
	}
	for _, f := range required {
		if f.val == "" {
			return nil, fmt.Errorf("%s: %s is missing", path, f.key)
		}
	}
	// initrdSecrets — скрипт, который дописывает секреты в initrd на
	// этапе установки. Здесь он не вызывается, и молча собранный без
	// секретов UKI не загрузится, поэтому лучше отказать.
	if spec.V1.InitrdSecrets != "" {
		return nil, fmt.Errorf("%s: boot.initrd.secrets is not supported", path)
	}
	return &spec, nil
}

// ensureKeys создаёт ключи Secure Boot при первой установке. enroll-keys
// сознательно не делается: запись ключей в firmware — ручной шаг
// в Setup Mode.
func ensureKeys(sbctl string) error {
	_, err := os.Stat(sbctlKeys)
	if err == nil {
		return nil
	}
	if !errors.Is(err, fs.ErrNotExist) {
		return err
	}
	return runCmd(sbctl, "create-keys")
}

// buildUKI собирает kernel, initrd, cmdline и os-release поколения
// в один PE-файл на systemd-stub.
func buildUKI(spec *bootspec, out string) error {
	cmdline := strings.Join(append([]string{"init=" + spec.V1.Init}, spec.V1.KernelParams...), " ")
	args := []string{"build",
		"--linux", spec.V1.Kernel,
		"--cmdline", cmdline,
		"--os-release", "@" + spec.UKI.OSRelease,
		"--stub", spec.UKI.Stub,
		"--output", out,
	}
	// В bootspec initrd необязателен: его нет при boot.initrd.enable = false.
	if spec.V1.Initrd != "" {
		args = append(args, "--initrd", spec.V1.Initrd)
	}
	return runCmd(spec.UKI.Ukify, args...)
}

func runCmd(name string, args ...string) error {
	cmd := exec.Command(name, args...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("%s %s: %w", filepath.Base(name), strings.Join(args, " "), err)
	}
	return nil
}

// install кладёт src в dst через временный файл рядом с dst и rename.
// У vfat нет журнала и порядка записи, поэтому данные сбрасываются fsync
// до rename, а каталог — после. При обрыве питания на месте dst остаётся
// целый старый или целый новый файл, в худшем случае рядом лежит .tmp.
func install(src, dst string) error {
	if err := os.MkdirAll(filepath.Dir(dst), 0o755); err != nil {
		return err
	}
	tmp := dst + ".tmp"
	if err := copyFile(src, tmp); err != nil {
		return err
	}
	if err := os.Rename(tmp, dst); err != nil {
		return err
	}
	return syncDir(filepath.Dir(dst))
}

func copyFile(src, dst string) error {
	in, err := os.Open(src)
	if err != nil {
		return err
	}
	defer in.Close()

	out, err := os.OpenFile(dst, os.O_WRONLY|os.O_CREATE|os.O_TRUNC, 0o644)
	if err != nil {
		return err
	}
	if _, err := io.Copy(out, in); err != nil {
		out.Close()
		return err
	}
	if err := out.Sync(); err != nil {
		out.Close()
		return err
	}
	return out.Close()
}

func syncDir(dir string) error {
	d, err := os.Open(dir)
	if err != nil {
		return err
	}
	defer d.Close()
	return d.Sync()
}

// prune удаляет архивные UKI сверх keep последних по номеру. Под шаблон
// попадают только nixos-generation-N.efi, так что rescue.efi и остатки
// .tmp не трогаются.
func prune(dir string, current int) error {
	entries, err := os.ReadDir(dir)
	if err != nil {
		return err
	}
	var gens []int
	for _, e := range entries {
		if n, ok := parseNumber(e.Name(), genPrefix, genSuffix); ok && e.Type().IsRegular() {
			gens = append(gens, n)
		}
	}
	for _, n := range toPrune(gens, current, keep) {
		p := filepath.Join(dir, genPrefix+strconv.Itoa(n)+genSuffix)
		if err := os.Remove(p); err != nil {
			return err
		}
		fmt.Println("uki-install: removed", p)
	}
	return syncDir(dir)
}

// toPrune выбирает номера на удаление: всё, кроме keep старших. Текущее
// поколение не удаляется никогда: после --rollback оно может быть старше
// тройки последних, но именно оно сейчас в BOOTX64.EFI.
func toPrune(gens []int, current, keep int) []int {
	gens = slices.Clone(gens)
	slices.Sort(gens)
	gens = slices.Compact(gens)
	if len(gens) <= keep {
		return nil
	}
	var out []int
	for _, n := range gens[:len(gens)-keep] {
		if n != current {
			out = append(out, n)
		}
	}
	return out
}

// parseNumber разбирает имена вида <prefix>N<suffix>. Принимается только
// каноничная запись числа (без знака и ведущих нулей): prune собирает имя
// обратно из номера, и оно должно совпасть с именем на диске.
func parseNumber(name, prefix, suffix string) (int, bool) {
	s, ok := strings.CutPrefix(name, prefix)
	if !ok {
		return 0, false
	}
	s, ok = strings.CutSuffix(s, suffix)
	if !ok {
		return 0, false
	}
	n, err := strconv.Atoi(s)
	if err != nil || n <= 0 || strconv.Itoa(n) != s {
		return 0, false
	}
	return n, true
}
