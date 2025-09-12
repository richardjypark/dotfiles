#!/bin/sh
# Language
export LANG=en_US.UTF-8

# Editor settings
if [[ -n $SSH_CONNECTION ]]; then
  export EDITOR='vim'
else
  export EDITOR='vim'
fi

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