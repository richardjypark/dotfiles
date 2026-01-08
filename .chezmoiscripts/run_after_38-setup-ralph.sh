#!/bin/sh
set -e

# Quiet mode by default
VERBOSE=${VERBOSE:-false}
vecho() {
    if [ "$VERBOSE" = "true" ]; then
        echo "$@"
    fi
}
eecho() { echo "$@"; }

vecho "Setting up Ralph for Claude Code..."

# Paths
RALPH_HOME="$HOME/.ralph"
RALPH_SOURCE="$HOME/.local/share/ralph-claude-code"
INSTALL_DIR="$HOME/.local/bin"

# Fast exit if ralph is already installed and working
if command -v ralph >/dev/null 2>&1; then
    if ralph --help >/dev/null 2>&1; then
        vecho "Ralph is already installed"
        exit 0
    else
        vecho "Ralph binary found but not working, reinstalling..."
    fi
fi

# Check that source exists (cloned by chezmoi external)
if [ ! -d "$RALPH_SOURCE" ]; then
    eecho "Warning: Ralph source not found at $RALPH_SOURCE"
    eecho "Run 'chezmoi apply --refresh-externals' to clone the repository"
    exit 0
fi

# Check dependencies
missing_deps=""
command -v jq >/dev/null 2>&1 || missing_deps="$missing_deps jq"
command -v git >/dev/null 2>&1 || missing_deps="$missing_deps git"

if [ -n "$missing_deps" ]; then
    eecho "Warning: Missing dependencies:$missing_deps"
    eecho "Install them before using Ralph"
fi

# Create directories
vecho "Creating Ralph directories..."
mkdir -p "$RALPH_HOME/templates/specs"
mkdir -p "$RALPH_HOME/lib"
mkdir -p "$INSTALL_DIR"

# Copy templates
if [ -d "$RALPH_SOURCE/templates" ]; then
    vecho "Copying templates..."
    cp -r "$RALPH_SOURCE/templates/"* "$RALPH_HOME/templates/" 2>/dev/null || true
fi

# Copy lib files
if [ -d "$RALPH_SOURCE/lib" ]; then
    vecho "Copying lib files..."
    cp -r "$RALPH_SOURCE/lib/"* "$RALPH_HOME/lib/" 2>/dev/null || true
fi

# Copy main scripts to RALPH_HOME
for script in ralph_loop.sh ralph_monitor.sh ralph_import.sh setup.sh; do
    if [ -f "$RALPH_SOURCE/$script" ]; then
        vecho "Installing $script..."
        cp "$RALPH_SOURCE/$script" "$RALPH_HOME/$script"
        chmod +x "$RALPH_HOME/$script"
    fi
done

# Create wrapper scripts in ~/.local/bin
vecho "Creating command wrappers..."

# ralph wrapper
cat > "$INSTALL_DIR/ralph" << 'EOF'
#!/bin/sh
exec "$HOME/.ralph/ralph_loop.sh" "$@"
EOF
chmod +x "$INSTALL_DIR/ralph"

# ralph-monitor wrapper
cat > "$INSTALL_DIR/ralph-monitor" << 'EOF'
#!/bin/sh
exec "$HOME/.ralph/ralph_monitor.sh" "$@"
EOF
chmod +x "$INSTALL_DIR/ralph-monitor"

# ralph-setup wrapper
cat > "$INSTALL_DIR/ralph-setup" << 'EOF'
#!/bin/sh
exec "$HOME/.ralph/setup.sh" "$@"
EOF
chmod +x "$INSTALL_DIR/ralph-setup"

# ralph-import wrapper
cat > "$INSTALL_DIR/ralph-import" << 'EOF'
#!/bin/sh
exec "$HOME/.ralph/ralph_import.sh" "$@"
EOF
chmod +x "$INSTALL_DIR/ralph-import"

# Verify installation
if command -v ralph >/dev/null 2>&1; then
    eecho "Ralph installed successfully"
    if [ "$VERBOSE" = "true" ]; then
        ralph --help 2>/dev/null | head -5 || true
    fi
else
    vecho "Ralph installation complete. You may need to restart your shell."
fi

vecho "Ralph setup complete!"
