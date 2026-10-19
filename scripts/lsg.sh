# ls: сначала папки, потом файлы, потом симлинки; внутри групп сортировка eza по умолчанию
base=("--time-style=+%d.%m.%Y %H:%M:%S")
opts=()
paths=()
all=0

for a in "$@"; do
  case $a in
    -R|--recurse|-T|--tree) exec eza --group-directories-first "${base[@]}" "$@" ;;
    --all) all=1; opts+=("$a") ;;
    --*) opts+=("$a") ;;
    -*) [[ $a == *a* ]] && all=1; opts+=("$a") ;;
    *) paths+=("$a") ;;
  esac
done

# Несколько путей, файл вместо папки и т.п. отдаём eza как есть
if (( ${#paths[@]} > 1 )) || { (( ${#paths[@]} == 1 )) && [[ ! -d ${paths[0]} ]]; }; then
  exec eza --group-directories-first "${base[@]}" "$@"
fi

cd -- "${paths[0]:-.}"

# Стандартный порядок задаёт eza, дальше только раскладываем имена по группам.
# eza печатает симлинки как "имя -> цель", поэтому строки сопоставляются с реальными именами
shopt -s nullglob
if (( all )); then shopt -s dotglob; fi
declare -A real
for e in *; do
  if [[ -L $e ]]; then real["$e -> $(readlink -- "$e")"]=$e; else real["$e"]=$e; fi
done

list=(-1 --no-quotes)
if (( all )); then list+=(--all); fi
mapfile -t lines < <(eza "${list[@]}" .)

dirs=() files=() links=()
for line in "${lines[@]}"; do
  e=${real[$line]:-$line}
  if [[ -L $e ]]; then links+=("$e")
  elif [[ -d $e ]]; then dirs+=("$e")
  else files+=("$e")
  fi
done

ordered=("${dirs[@]}" "${files[@]}" "${links[@]}")

# Итоговый вывод одним вызовом, чтобы колонки выровнялись
if (( ${#ordered[@]} )); then
  eza "${base[@]}" "${opts[@]}" -d --sort=none -- "${ordered[@]}"
fi
