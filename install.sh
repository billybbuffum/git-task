#!/bin/bash
set -euo pipefail

# git-task installer
# Usage: curl -fsSL https://raw.githubusercontent.com/billybbuffum/git-task/main/install.sh | bash

REPO="billybbuffum/git-task"
INSTALL_DIR="${INSTALL_DIR:-$HOME/.local/bin}"

echo "Installing git-task..."

# Create install directory
mkdir -p "$INSTALL_DIR"

# Download script
curl -fsSL "https://raw.githubusercontent.com/$REPO/main/git-task" -o "$INSTALL_DIR/git-task"
chmod +x "$INSTALL_DIR/git-task"

echo "Installed to $INSTALL_DIR/git-task"

# Check if in PATH
if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
    echo ""
    echo "Add to your PATH by adding this to ~/.zshrc or ~/.bashrc:"
    echo "  export PATH=\"\$PATH:$INSTALL_DIR\""
fi

echo ""
echo "Done! Run 'git task help' to get started."
