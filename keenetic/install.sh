#!/bin/sh
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
INSTALL_DIR="/opt/dpi-bypass"
INIT_SCRIPT="/opt/etc/init.d/S99zz-dpi-bypass"
NDM_HOOK="/opt/etc/ndm/netfilter.d/100-dpi-bypass.sh"

ARCH="$(uname -m)"
case "$ARCH" in
    mips|mipsel)
        BIN_SRC="$REPO_DIR/bin/linux-mipsel/nfqws2"
        ;;
    aarch64|arm64)
        BIN_SRC="$REPO_DIR/bin/linux-arm64/nfqws2"
        ;;
    *)
        echo "[ERROR] Unsupported architecture: $ARCH"
        exit 1
        ;;
esac

if [ ! -f "$BIN_SRC" ]; then
    echo "[ERROR] Binary not found: $BIN_SRC"
    exit 1
fi

WAN_IF="$(ip route show default 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="dev") print $(i+1)}' | head -n 1)"
if [ -z "$WAN_IF" ]; then
    WAN_IF="eth3"
    echo "[WARN] Could not auto-detect WAN interface, defaulting to $WAN_IF"
else
    echo "[INFO] Detected WAN interface: $WAN_IF"
fi

mkdir -p "$INSTALL_DIR/bin" "$INSTALL_DIR/lua" "$INSTALL_DIR/files/fake" "$INSTALL_DIR/lists"
mkdir -p /opt/etc/init.d /opt/etc/ndm/netfilter.d

cp -f "$BIN_SRC" "$INSTALL_DIR/bin/nfqws2"
chmod +x "$INSTALL_DIR/bin/nfqws2"
cp -f "$REPO_DIR"/lua/*.lua "$INSTALL_DIR/lua/"
cp -f "$REPO_DIR"/files/fake/* "$INSTALL_DIR/files/fake/"
cp -f "$REPO_DIR"/lists/*.txt "$INSTALL_DIR/lists/"
if [ -f "$REPO_DIR/VERSION" ]; then
    cp -f "$REPO_DIR/VERSION" "$INSTALL_DIR/VERSION"
fi
touch "$INSTALL_DIR/lists/domains-auto.txt"
chmod 666 "$INSTALL_DIR/lists/domains-auto.txt"

cat > "$INIT_SCRIPT" << EOF
#!/bin/sh

PATH=/opt/bin:/opt/sbin:/sbin:/bin:/usr/sbin:/usr/bin
NFQWS2="$INSTALL_DIR/bin/nfqws2"
LUA="$INSTALL_DIR/lua"
FAKE="$INSTALL_DIR/files/fake"
LISTS="$INSTALL_DIR/lists"
QNUM=200
WAN_IF="$WAN_IF"

load_modules() {
    for m in nfnetlink_queue xt_NFQUEUE xt_connbytes xt_multiport; do
        insmod /lib/modules/\$(uname -r)/\${m}.ko 2>/dev/null || true
    done
}

add_firewall() {
    iptables -t mangle -N DPI_BYPASS 2>/dev/null || true
    iptables -t mangle -F DPI_BYPASS 2>/dev/null || true
    iptables -t mangle -A DPI_BYPASS -p tcp -m multiport --dports 80,443,2053,2083,2087,2096,8443 -m connbytes --connbytes 1:12 --connbytes-mode packets --connbytes-dir original -j NFQUEUE --queue-num \$QNUM --queue-bypass
    iptables -t mangle -A DPI_BYPASS -p udp -m multiport --dports 443,19294:19344,50000:50100 -m connbytes --connbytes 1:8 --connbytes-mode packets --connbytes-dir original -j NFQUEUE --queue-num \$QNUM --queue-bypass

    iptables -t mangle -N DPI_BYPASS_IN 2>/dev/null || true
    iptables -t mangle -F DPI_BYPASS_IN 2>/dev/null || true
    iptables -t mangle -A DPI_BYPASS_IN -p tcp -m multiport --sports 80,443,2053,2083,2087,2096,8443 -m connbytes --connbytes 1:8 --connbytes-mode packets --connbytes-dir reply -j NFQUEUE --queue-num \$QNUM --queue-bypass
    iptables -t mangle -A DPI_BYPASS_IN -p udp -m multiport --sports 443,19294:19344 -m connbytes --connbytes 1:4 --connbytes-mode packets --connbytes-dir reply -j NFQUEUE --queue-num \$QNUM --queue-bypass

    iptables -t mangle -C POSTROUTING -o \$WAN_IF -j DPI_BYPASS 2>/dev/null || iptables -t mangle -A POSTROUTING -o \$WAN_IF -j DPI_BYPASS
    iptables -t mangle -C PREROUTING -i \$WAN_IF -j DPI_BYPASS_IN 2>/dev/null || iptables -t mangle -A PREROUTING -i \$WAN_IF -j DPI_BYPASS_IN
}

del_firewall() {
    while iptables -t mangle -D POSTROUTING -o \$WAN_IF -j DPI_BYPASS 2>/dev/null; do :; done
    while iptables -t mangle -D PREROUTING -i \$WAN_IF -j DPI_BYPASS_IN 2>/dev/null; do :; done
    iptables -t mangle -F DPI_BYPASS 2>/dev/null || true
    iptables -t mangle -X DPI_BYPASS 2>/dev/null || true
    iptables -t mangle -F DPI_BYPASS_IN 2>/dev/null || true
    iptables -t mangle -X DPI_BYPASS_IN 2>/dev/null || true
}

start() {
    echo "Starting dpi-bypass (nfqws2)..."
    load_modules
    killall -q nfqws2 2>/dev/null || true
    \$NFQWS2 --daemon --qnum=\$QNUM --pidfile=/var/run/nfqws2.pid --user=nobody \\
      --lua-init=@\$LUA/zapret-lib.lua \\
      --lua-init=@\$LUA/zapret-antidpi.lua \\
      --lua-init=@\$LUA/zapret-auto.lua \\
      --lua-init=@\$LUA/custom-dpi.lua \\
      --blob=fake_tls_google:@\$FAKE/tls_clienthello_www_google_com.bin \\
      --blob=fake_tls_sber:@\$FAKE/tls_clienthello_sberbank_ru.bin \\
      --blob=fake_quic_google:@\$FAKE/quic_initial_www_google_com.bin \\
      --blob=fake_discord_udp:@\$FAKE/discord-ip-discovery-with-port.bin \\
      --filter-udp=443 --hostlist=\$LISTS/domains-google.txt --hostlist=\$LISTS/domains-bypass.txt --hostlist-exclude=\$LISTS/domains-exclude.txt \\
        --out-range=-n8 --in-range=-n4 --lua-desync=circular:fails=2:udp_out=4:udp_in=1 \\
        --in-range=x --payload=quic_initial \\
        --lua-desync=fake:blob=fake_quic_google:ip_autottl=-2,3-20:ip_ttl=5:repeats=6:strategy=1 \\
        --lua-desync=send:ipfrag=ipfrag2:ipfrag_pos_udp=8:ipfrag_disorder:strategy=2 \\
        --lua-desync=drop:strategy=2 --new \\
      --filter-udp=50000-50100 --filter-l7=discord,stun \\
        --out-range=-n8 --lua-desync=fake:blob=fake_discord_udp:ip_autottl=-2,3-20:ip_ttl=5:repeats=6 --new \\
      --filter-udp=19294-19344 \\
        --out-range=-n12 --in-range=-n4 --lua-desync=circular:fails=2:udp_out=4:udp_in=1 \\
        --in-range=x \\
        --lua-desync=fake:blob=fake_quic_google:ip_autottl=-2,3-20:ip_ttl=5:repeats=6:strategy=1 \\
        --lua-desync=send:ipfrag=ipfrag2:ipfrag_pos_udp=8:ipfrag_disorder:strategy=2 \\
        --lua-desync=drop:strategy=2 --new \\
      --filter-tcp=443 --hostlist=\$LISTS/domains-google.txt \\
        --out-range=-s34228 --in-range=-s5556 --lua-desync=circular:fails=2:retrans=2:reset:nld=2:time=60 \\
        --in-range=x \\
        --payload=tls_client_hello \\
        --lua-desync=fake:blob=fake_tls_google:tls_mod=rnd,dupsid:tcp_seq=-10000:ip_id=zero:repeats=8:strategy=1 \\
        --lua-desync=multidisorder:pos=1,midsld:ip_id=zero:strategy=1 \\
        --lua-desync=fakeddisorder:pos=midsld:tcp_seq=-10000:ip_id=zero:strategy=2 \\
        --lua-desync=tls_client_hello_clone:blob=fake_cloned:sni_del:sni_first=www.google.com:fallback=fake_tls_google:strategy=3 \\
        --lua-desync=fake:blob=fake_cloned:ip_autottl=-2,3-20:ip_ttl=5:repeats=4:strategy=3 \\
        --lua-desync=multisplit:pos=1,midsld:strategy=3 \\
        --lua-desync=fakeddisorder:pos=2:seqovl=1:badsum:tcp_md5:strategy=4 \\
        --lua-desync=hostfakesplit:host=www.google.com:tcp_ts=-600000:strategy=5 --new \\
      --filter-tcp=80,443,2053,2083,2087,2096,8443 --hostlist=\$LISTS/domains-bypass.txt --hostlist-auto=\$LISTS/domains-auto.txt --hostlist-auto-fail-threshold=2 --hostlist-auto-retrans-threshold=2 --hostlist-exclude=\$LISTS/domains-exclude.txt \\
        --out-range=-s34228 --in-range=-s5556 --lua-desync=circular:fails=2:retrans=2:reset:nld=2:time=60 \\
        --in-range=x \\
        --payload=tls_client_hello \\
        --lua-desync=tls_client_hello_clone:blob=fake_cloned:sni_del:sni_first=www.google.com:fallback=fake_tls_google:strategy=1 \\
        --lua-desync=fake:blob=fake_cloned:ip_autottl=-2,3-20:ip_ttl=5:repeats=4:strategy=1 \\
        --lua-desync=multisplit:pos=1,midsld:strategy=1 \\
        --lua-desync=fakeddisorder:pos=2:seqovl=1:badsum:tcp_md5:strategy=2 \\
        --lua-desync=fake:blob=fake_tls_google:tls_mod=rnd,rndsni,dupsid:fool=custom_fool_randseq:repeats=6:strategy=3 \\
        --lua-desync=multisplit:pos=2:seqovl=652:strategy=3 \\
        --lua-desync=fake:blob=fake_tls_google:tls_mod=rnd,dupsid:tcp_seq=-10000:ip_id=zero:repeats=8:strategy=4 \\
        --lua-desync=multidisorder:pos=1,midsld:ip_id=zero:strategy=4 \\
        --lua-desync=hostfakesplit:host=www.google.com:tcp_ts=-600000:strategy=5 \\
        --lua-desync=fake:blob=fake_tls_sber:badsum:repeats=6:strategy=6 \\
        --lua-desync=multisplit:pos=1,midsld:strategy=6 \\
        --payload=http_req \\
        --lua-desync=multisplit:pos=method+2:strategy=1 \\
        --lua-desync=fakeddisorder:pos=host:badsum:strategy=2 \\
        --lua-desync=multisplit:pos=host:strategy=3 \\
        --lua-desync=multidisorder:pos=host:strategy=4 \\
        --lua-desync=hostfakesplit:host=www.google.com:strategy=5 \\
        --lua-desync=http_methodeol:strategy=6
    add_firewall
}

stop() {
    echo "Stopping dpi-bypass (nfqws2)..."
    del_firewall
    killall -q nfqws2 2>/dev/null || true
    rm -f /var/run/nfqws2.pid
}

case "\$1" in
    start) start ;;
    stop) stop ;;
    restart) stop; sleep 1; start ;;
    firewall) add_firewall ;;
    *) echo "Usage: \$0 {start|stop|restart|firewall}" ;;
esac
EOF
chmod +x "$INIT_SCRIPT"

cat > "$NDM_HOOK" << EOF
#!/bin/sh
if [ "\$table" = "mangle" ]; then
    $INIT_SCRIPT firewall >/dev/null 2>&1
fi
EOF
chmod +x "$NDM_HOOK"

"$INIT_SCRIPT" restart
echo "[OK] Installed and started on $WAN_IF ($ARCH)"
