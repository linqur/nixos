{
  programs.bash.promptInit = ''
    PS1='\[\e[36m\][\u@\h \W]\$\[\e[0m\] '
  '';

  # общая история между всеми консолями и tty
  # рабочая копия живёт в tmpfs ($XDG_RUNTIME_DIR), в ~/.bash_history сохраняется при выходе из шелла
  programs.bash.interactiveShellInit = ''
    __hist_persist=~/.bash_history
    HISTSIZE=500
    HISTFILESIZE=500
    HISTCONTROL=ignoreboth:erasedups
    shopt -s histappend

    if [ -n "$XDG_RUNTIME_DIR" ] && [ -O "$XDG_RUNTIME_DIR" ]; then
      HISTFILE=$XDG_RUNTIME_DIR/bash_history
      # первый шелл в сессии: поднять историю с диска
      [ -e "$HISTFILE" ] || cp "$__hist_persist" "$HISTFILE" 2>/dev/null || touch "$HISTFILE"

      __hist_save() {
        local tmp
        tmp=$(mktemp "$__hist_persist.XXXXXX") || return
        cp "$HISTFILE" "$tmp" && mv "$tmp" "$__hist_persist" || rm -f "$tmp"
      }
      trap __hist_save EXIT
    else
      HISTFILE=$__hist_persist
    fi

    # убрать дубли из файла (оставить последнее вхождение) и перечитать его
    __hist_dedup() {
      local tmp
      tmp=$(mktemp "$HISTFILE.XXXXXX") || return
      tac "$HISTFILE" | awk '!seen[$0]++' | tac > "$tmp" && mv "$tmp" "$HISTFILE" || rm -f "$tmp"
      history -c; history -r
    }

    # после каждой команды: дописать в файл, почистить дубли, подтянуть команды из других сессий
    PROMPT_COMMAND="history -a; __hist_dedup''${PROMPT_COMMAND:+; $PROMPT_COMMAND}"

    # Alt+M в TTY — запустить niri (Super в консоли ядра не доходит до readline)
    # без exec: после выхода из niri вернёмся в этот же шелл, а EXIT-трап истории отработает как обычно
    if [ "$TERM" = linux ]; then
      bind -x '"\em": niri-session'
    fi
  '';
}
