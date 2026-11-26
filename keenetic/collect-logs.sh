#!/bin/sh
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -d "/opt/dpi-bypass" ]; then
    BASE_DIR="/opt/dpi-bypass"
else
    BASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
fi

OUT_DIR="${1:-$BASE_DIR/logs}"
mkdir -p "$OUT_DIR"

LATEST_DIR="$BASE_DIR/logs/latest"
rm -rf "$LATEST_DIR"
mkdir -p "$LATEST_DIR"

VER="unknown"
if [ -f "$BASE_DIR/VERSION" ]; then
    VER="$(tr -d ' \r\n' < "$BASE_DIR/VERSION")"
fi

STAMP="$(date +%Y%m%d-%H%M%S)"
ARCHIVE="$OUT_DIR/dpi-bypass-keenetic-logs-$STAMP.tar.gz"

{
    echo "dpi-bypass Keenetic log bundle"
    echo "Generated : $(date)"
    echo "Version   : $VER"
    echo "Base dir  : $BASE_DIR"
    echo "Kernel    : $(uname -a)"
    echo "Uptime    : $(uptime 2>/dev/null || true)"
} > "$LATEST_DIR/summary.txt"

{
    echo "=== nfqws2 processes ==="
    ps | grep '[n]fqws2' || echo "Not running"
    echo ""
    echo "=== pidfile ==="
    if [ -f /var/run/nfqws2.pid ]; then
        cat /var/run/nfqws2.pid
    else
        echo "No pidfile"
    fi
} > "$LATEST_DIR/processes.txt"

{
    echo "=== iptables mangle POSTROUTING / PREROUTING ==="
    iptables -t mangle -L POSTROUTING -v -n 2>&1 || true
    iptables -t mangle -L PREROUTING -v -n 2>&1 || true
    echo ""
    echo "=== iptables mangle DPI_BYPASS / DPI_BYPASS_IN ==="
    iptables -t mangle -L DPI_BYPASS -v -n 2>&1 || true
    iptables -t mangle -L DPI_BYPASS_IN -v -n 2>&1 || true
    echo ""
    echo "=== ip route ==="
    ip route 2>&1 || true
} > "$LATEST_DIR/firewall.txt"

if [ -f "$BASE_DIR/lists/domains-auto.txt" ]; then
    cp -f "$BASE_DIR/lists/domains-auto.txt" "$LATEST_DIR/domains-auto.txt"
fi

if [ -f "$BASE_DIR/logs/hostlist-auto.log" ]; then
    tail -n 5000 "$BASE_DIR/logs/hostlist-auto.log" > "$LATEST_DIR/hostlist-auto.log" 2>/dev/null || true
fi

if command -v logread >/dev/null 2>&1; then
    logread 2>/dev/null | tail -n 150 > "$LATEST_DIR/syslog-tail.log" || true
fi

tar -czf "$ARCHIVE" -C "$LATEST_DIR" .
echo "[OK] Unified logs : $LATEST_DIR"
echo "[OK] Exported     : $ARCHIVE"
