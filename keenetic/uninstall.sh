#!/bin/sh
INIT_SCRIPT="/opt/etc/init.d/S99zz-dpi-bypass"
NDM_HOOK="/opt/etc/ndm/netfilter.d/100-dpi-bypass.sh"

if [ -x "$INIT_SCRIPT" ]; then
    "$INIT_SCRIPT" stop 2>/dev/null || true
fi

rm -rf /opt/dpi-bypass "$INIT_SCRIPT" "$NDM_HOOK"
echo "[OK] Removed dpi-bypass from Keenetic"
