#!/bin/sh
# Bootstrap installer for Windows Auto Installer by Dems

set -e

WINDOWS_SH_URL="https://github.com/demsdivo11/installer-windows-for-digitalocean/raw/refs/heads/main/windows.sh"
WINDOWS_SH_FILE="windows.sh"

echo "[*] Downloading windows.sh..."
curl -fsSL "$WINDOWS_SH_URL" -o "$WINDOWS_SH_FILE"

echo "[*] Normalizing line endings (CRLF -> LF)..."
sed -i 's/\r$//' "$WINDOWS_SH_FILE"

echo "[*] Setting executable permission..."
chmod +x "$WINDOWS_SH_FILE"

echo "[*] Starting Windows installer..."
exec bash "$WINDOWS_SH_FILE"
