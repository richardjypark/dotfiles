#!/bin/sh
set -e

# colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "${BLUE}Setting up asdf and Elixir...${NC}"

# Make sure asdf is cloned
if [ -d "$HOME/.asdf" ]; then
  # Source asdf
  . "$HOME/.asdf/asdf.sh"
  
  # Install or update asdf-elixir plugin
  if asdf plugin list | grep -q "elixir"; then
    echo "${GREEN}Updating asdf-elixir plugin...${NC}"
    asdf plugin update elixir
  else
    echo "${GREEN}Installing asdf-elixir plugin...${NC}"
    asdf plugin add elixir
  fi
  
  # Install latest Elixir version
  latest_elixir=$(asdf list all elixir | grep -v "rc\|alpha\|beta" | tail -1)
  
  if ! asdf list elixir | grep -q "$latest_elixir"; then
    echo "${GREEN}Installing Elixir $latest_elixir...${NC}"
    asdf install elixir "$latest_elixir"
    asdf global elixir "$latest_elixir"
  else
    echo "${GREEN}Elixir $latest_elixir is already installed${NC}"
  fi
  
  # Install Erlang plugin if not already installed (required for Elixir)
  if ! asdf plugin list | grep -q "erlang"; then
    echo "${GREEN}Installing asdf-erlang plugin...${NC}"
    asdf plugin add erlang
    
    # Install latest Erlang version
    latest_erlang=$(asdf list all erlang | grep -v "rc\|alpha\|beta" | tail -1)
    echo "${GREEN}Installing Erlang $latest_erlang...${NC}"
    asdf install erlang "$latest_erlang"
    asdf global erlang "$latest_erlang"
  fi
  
  echo "${GREEN}asdf and Elixir setup complete!${NC}"
else
  echo "Error: asdf is not installed. Please check .chezmoiexternal.toml configuration."
  exit 1
fi 