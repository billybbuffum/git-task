#!/bin/bash
set -euo pipefail

# git-task installer
# Usage: curl -fsSL https://raw.githubusercontent.com/billybbuffum/git-task/main/install.sh | bash
# Force install: curl -fsSL ... | bash -s -- --force

REPO="billybbuffum/git-task"
INSTALL_DIR="${INSTALL_DIR:-$HOME/.local/bin}"
FORCE=""

# Parse arguments
for arg in "$@"; do
    case "$arg" in
        --force|-f) FORCE="1" ;;
    esac
done

# Check for copy-on-write filesystem support
check_cow_support() {
    if [[ "$(uname)" == "Darwin" ]]; then
        # macOS APFS supports CoW
        return 0
    fi

    # Linux: test reflink support
    local test_file=$(mktemp .cow_test_XXXXXX 2>/dev/null)
    if [[ -z "$test_file" ]]; then
        return 1
    fi

    local test_copy="${test_file}_copy"
    if cp --reflink=always "$test_file" "$test_copy" 2>/dev/null; then
        rm -f "$test_file" "$test_copy"
        return 0
    else
        rm -f "$test_file" "$test_copy"
        return 1
    fi
}

echo "Installing git-task..."
echo ""

# Check CoW support unless forced
if [[ -z "$FORCE" ]]; then
    if ! check_cow_support; then
        echo "Your filesystem does not support copy-on-write (reflinks)."
        echo ""
        echo "git-task relies on CoW cloning for fast, space-efficient task creation."
        echo "Without CoW support, git-task will fall back to full directory copies,"
        echo "which may be slow and use significant disk space for large repositories."
        echo ""
        echo "Recommended options:"
        echo "  • Use a CoW-capable filesystem (btrfs, XFS with reflink=1)"
        echo "  • Use 'git worktree' instead for your workflow"
        echo "  • Install anyway with: curl ... | bash -s -- --force"
        echo ""
        echo "Installation cancelled."
        exit 1
    fi
else
    if ! check_cow_support; then
        echo "Note: Installing without CoW support (--force). Performance may be degraded."
        echo ""
    fi
fi

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
