#!/bin/sh
# Custom agnoster theme configuration
# This file customizes the agnoster theme to use generic hostnames

# Only run if we're in zsh and agnoster theme is loaded
[ -n "$ZSH_VERSION" ] || return

# Function to override the default agnoster prompt_context function
# This function is called by agnoster to display the user@hostname part
prompt_context() {
  # Always show the context with generic names (remove the DEFAULT_USER check)
  # Determine generic username and hostname
  local generic_user
  local generic_host

  # Check if current user is root - hide user if root, show actual user otherwise
  if [[ "$USER" == "root" ]] || [[ "$EUID" -eq 0 ]]; then
    generic_user=""  # Hide user for root
  else
    generic_user="$USER"  # Show actual username for non-root users
  fi

  if [[ -n "$SSH_CLIENT" ]] || [[ -n "$SSH_TTY" ]] || [[ -n "$SSH_CONNECTION" ]]; then
    # Remote connection - use server1, server2, etc. based on actual hostname hash
    local host_hash=$(echo "$HOSTNAME" | md5sum 2>/dev/null | cut -c1-1 || echo "1")
    case $host_hash in
      [0-3]) generic_host="server1" ;;
      [4-7]) generic_host="server2" ;;
      [8-b]) generic_host="server3" ;;
      *) generic_host="server4" ;;
    esac
  else
    # Local connection - use localhost
    generic_host="localhost"
  fi

  # Display user@host or just host if user is root
  local display_text
  if [[ -n "$generic_user" ]]; then
    display_text="$generic_user@$generic_host"
  else
    display_text="$generic_host"
  fi

  # Display with agnoster styling, highlight in yellow if root
  prompt_segment "${AGNOSTER_CONTEXT_BG:-black}" "${AGNOSTER_CONTEXT_FG:-default}" "%(!.%{%F{${AGNOSTER_STATUS_ROOT_FG:-yellow}}%}.)$display_text"
}

# Set a default user to hide username when it matches
# You can customize this to your preferred username
export DEFAULT_USER="user"

# Inline virtualenv segment that appears after the path segment
env_inline() {
  if [[ -n "$VIRTUAL_ENV" ]]; then
    local envname="${${VIRTUAL_ENV:t}#.}"
    # Space-prefixed, magenta colored, with snake emoji and wrapped in parentheses
    echo " %{%F{magenta}%}🐍(${envname})%{%f%}"
  fi
}


# Override the agnoster theme's prompt_context function after Oh My Zsh loads
# This ensures our custom function takes precedence
if [[ "$ZSH_THEME" == "agnoster" ]]; then
  # The function will be available after the theme loads
  autoload -U add-zsh-hook
  
  # Hook to apply our customization after the theme is loaded
  _apply_agnoster_customization() {
    # Only apply if agnoster theme is actually loaded
    if typeset -f prompt_context >/dev/null 2>&1; then
      # Our custom function is already defined above, it will override the theme's version
      true
    fi
    
    # Override the PROMPT to add env name inline (after path) and a newline before the cursor
    if typeset -f build_prompt >/dev/null 2>&1; then
      PROMPT='%{%f%b%k%}$(build_prompt)$(env_inline)
%{%F{blue}%}❯%{%f%} '
    fi

    # Disable the original left-hand virtualenv segment from agnoster
    prompt_virtualenv() { : }

    # No right prompt for virtualenv anymore
    RPROMPT=''

  }
  
  # Apply customization when the prompt is first set up
  add-zsh-hook precmd _apply_agnoster_customization
fi 