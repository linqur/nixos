{
  programs.bash.promptInit = ''
    PS1='\[\e[36m\][\u@\h \W]\$\[\e[0m\] '
  '';

  # общая история между всеми консолями и tty
  programs.bash.interactiveShellInit = ''
    HISTFILE=~/.bash_history
    HISTSIZE=500
    HISTFILESIZE=500
    HISTCONTROL=ignoreboth:erasedups
    shopt -s histappend
    # после каждой команды: дописать в файл, перечитать новые строки из других сессий
    PROMPT_COMMAND="history -a; history -n''${PROMPT_COMMAND:+; $PROMPT_COMMAND}"
  '';
}
