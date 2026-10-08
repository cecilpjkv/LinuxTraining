# LinuxTraining terminal hooks (sourced from /etc/bashrc in the technician's interactive shells only): at every
# prompt, an invisible terminal escape sequence reports the last command, its exit code and the directory. The
# platform strips these from the screen and keeps them as the attempt's command history.
if [ -n "${LT_SESSION:-}" ] && [ -n "${PS1:-}" ] && [ -z "${__LT_HOOKED:-}" ]; then
  __LT_HOOKED=1
  HISTCONTROL=
  HISTTIMEFORMAT=
  __lt_last=$(HISTTIMEFORMAT= builtin history 1 2>/dev/null | sed -n 's/^ *\([0-9]*\).*/\1/p')
  __lt_end() {
    local e=$? line num cmd
    line=$(HISTTIMEFORMAT= builtin history 1 2>/dev/null)
    num=$(printf '%s' "$line" | sed -n '1s/^ *\([0-9]*\).*/\1/p')
    if [ -n "$num" ] && [ "$num" != "$__lt_last" ]; then
      __lt_last=$num
      cmd=$(printf '%s' "$line" | sed '1s/^ *[0-9]* *//')
      printf '\033]777;lt;e;%s;%s;%s\007' "$e" "$(printf '%s' "$PWD" | base64 -w0)" "$(printf '%s' "$cmd" | base64 -w0)"
    fi
    return $e
  }
  PROMPT_COMMAND="__lt_end${PROMPT_COMMAND:+;$PROMPT_COMMAND}"
  PS0=$'\033]777;lt;s\007'
fi
