#!/bin/sh
set -e

# Change shell to zsh if it's not already
if [ "$SHELL" != "$(which zsh)" ]; then
    echo "Changing default shell to zsh..."
    chsh -s "$(which zsh)"
fi

echo "Shell setup complete!"
