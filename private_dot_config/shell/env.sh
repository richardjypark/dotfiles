#!/bin/sh
# Security: Set restrictive umask (files: 644, dirs: 755)
umask 022

# Language
export LANG=en_US.UTF-8

# Editor settings
if command -v nvim >/dev/null 2>&1; then
  export EDITOR='nvim'
elif command -v vim >/dev/null 2>&1; then
  export EDITOR='vim'
else
  export EDITOR='vi'
fi
export VISUAL="$EDITOR"

# Terminal settings
alias terminfo='echo "➜ echo \$TERM" && echo $TERM'

# Custom SSH function
ssh() {
    TERM=xterm-256color command ssh "$@"
}

# Java (Homebrew OpenJDK 17)
if [[ -d "/opt/homebrew/opt/openjdk@17" ]]; then
  export JAVA_HOME="/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home"
fi
