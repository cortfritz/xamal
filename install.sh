#!/usr/bin/env bash
set -euo pipefail

REPO="dmkenney/xamal"
INSTALL_DIR="${XAMAL_INSTALL_DIR:-$HOME/.local/bin}"
VERSION="${1:-}"

# Detect download command
if command -v curl &>/dev/null; then
  fetch() { curl -fsSL "$1"; }
  download() { curl -fsSL -o "$1" "$2"; }
elif command -v wget &>/dev/null; then
  fetch() { wget -qO- "$1"; }
  download() { wget -qO "$1" "$2"; }
else
  echo "Error: curl or wget is required" >&2
  exit 1
fi

# Resolve version
if [ -z "$VERSION" ]; then
  VERSION=$(fetch "https://api.github.com/repos/${REPO}/releases/latest" \
    | grep '"tag_name"' | head -1 | cut -d'"' -f4)
  if [ -z "$VERSION" ]; then
    echo "Error: could not determine latest release" >&2
    exit 1
  fi
fi

echo "Installing xamal ${VERSION}..."

# Download
mkdir -p "$INSTALL_DIR"
download "${INSTALL_DIR}/xamal" \
  "https://github.com/${REPO}/releases/download/${VERSION}/xamal"
chmod +x "${INSTALL_DIR}/xamal"

echo "Installed xamal to ${INSTALL_DIR}/xamal"

# PATH check
case ":${PATH}:" in
  *":${INSTALL_DIR}:"*) ;;
  *)
    echo ""
    echo "Warning: ${INSTALL_DIR} is not on your PATH."
    echo "Add this to your shell profile:"
    echo ""
    echo "  export PATH=\"${INSTALL_DIR}:\$PATH\""
    ;;
esac
