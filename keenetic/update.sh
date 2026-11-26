#!/bin/sh
set -e

REPO="MaxRekkim/win-dpi-bypass"
INSTALL_DIR="/opt/dpi-bypass"
TMP_DIR="/opt/tmp/win-dpi-bypass-update"
LOCAL_VER="none"
if [ -f "$INSTALL_DIR/VERSION" ]; then
    LOCAL_VER="$(tr -d ' \r\n' < "$INSTALL_DIR/VERSION")"
fi

AUTH_HEADER=""
if [ -n "$GITHUB_TOKEN" ]; then
    AUTH_HEADER="Authorization: Bearer $GITHUB_TOKEN"
fi

echo "[INFO] Local version: $LOCAL_VER"
API_JSON="$(curl -fsSL ${AUTH_HEADER:+-H "$AUTH_HEADER"} -H "User-Agent: keenetic-dpi-updater" "https://api.github.com/repos/$REPO/releases/latest")" || {
    echo "[ERROR] Failed to query GitHub Releases API (if repo is private, export GITHUB_TOKEN)."
    exit 1
}

LATEST_TAG="$(printf '%s\n' "$API_JSON" | grep -m1 '"tag_name"' | sed 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')"
TAR_URL="$(printf '%s\n' "$API_JSON" | grep -m1 '"tarball_url"' | sed 's/.*"tarball_url"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')"

if [ -z "$LATEST_TAG" ] || [ -z "$TAR_URL" ]; then
    echo "[ERROR] Could not parse latest release tag or tarball_url."
    exit 1
fi

echo "[INFO] Latest release: $LATEST_TAG"
if [ "$LOCAL_VER" = "$LATEST_TAG" ]; then
    echo "[OK] Already up to date ($LATEST_TAG)."
    exit 0
fi

AUTO_BAK="/tmp/domains-auto.txt.bak"
if [ -f "$INSTALL_DIR/lists/domains-auto.txt" ]; then
    cp -f "$INSTALL_DIR/lists/domains-auto.txt" "$AUTO_BAK"
fi

rm -rf "$TMP_DIR"
mkdir -p "$TMP_DIR"
echo "[INFO] Downloading $TAR_URL..."
curl -fsSL ${AUTH_HEADER:+-H "$AUTH_HEADER"} -H "User-Agent: keenetic-dpi-updater" "$TAR_URL" -o "$TMP_DIR/release.tar.gz"
tar -xzf "$TMP_DIR/release.tar.gz" -C "$TMP_DIR" --strip-components=1

chmod +x "$TMP_DIR"/keenetic/*.sh
"$TMP_DIR/keenetic/install.sh"

if [ -f "$AUTO_BAK" ]; then
    cp -f "$AUTO_BAK" "$INSTALL_DIR/lists/domains-auto.txt"
    rm -f "$AUTO_BAK"
fi
rm -rf "$TMP_DIR"
echo "[OK] Keenetic updated to $LATEST_TAG"
