@echo off
chcp 65001 > nul
cd /d "%~dp0"

if not exist "bin\win\winws2.exe" (
    echo [ERROR] bin\win\winws2.exe not found!
    pause
    exit /b 1
)

net session >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Run this script as Administrator!
    pause
    exit /b 1
)

if not exist "logs" mkdir logs
echo [INFO] Starting winws2 with debug log -> logs\winws2.log
"bin\win\winws2.exe" ^
 --debug=@logs\winws2.log ^
 --wf-tcp-out=80,443,2053,2083,2087,2096,8443 ^
 --wf-tcp-in=80,443,2053,2083,2087,2096,8443 ^
 --wf-udp-out=443,19294-19344,50000-50100 ^
 --wf-udp-in=443,19294-19344,50000-50100 ^
 --lua-init=@lua/zapret-lib.lua ^
 --lua-init=@lua/zapret-antidpi.lua ^
 --lua-init=@lua/zapret-auto.lua ^
 --lua-init=@lua/custom-dpi.lua ^
 --blob=fake_tls_google:@files/fake/tls_clienthello_www_google_com.bin ^
 --blob=fake_tls_sber:@files/fake/tls_clienthello_sberbank_ru.bin ^
 --blob=fake_quic_google:@files/fake/quic_initial_www_google_com.bin ^
 --blob=fake_discord_udp:@files/fake/discord-ip-discovery-with-port.bin ^
 --filter-udp=443 --hostlist=lists/domains-google.txt --hostlist=lists/domains-bypass.txt --hostlist-exclude=lists/domains-exclude.txt ^
   --out-range=-n8 --in-range=-n4 --lua-desync=circular:fails=2:udp_out=4:udp_in=1 ^
   --in-range=x --payload=quic_initial ^
   --lua-desync=fake:blob=fake_quic_google:ip_autottl=-2,3-20:ip_ttl=5:repeats=6:strategy=1 ^
   --lua-desync=send:ipfrag=ipfrag2:ipfrag_pos_udp=8:ipfrag_disorder:strategy=2 ^
   --lua-desync=drop:strategy=2 --new ^
 --filter-udp=50000-50100 --filter-l7=discord,stun ^
   --out-range=-n8 --lua-desync=fake:blob=fake_discord_udp:ip_autottl=-2,3-20:ip_ttl=6:repeats=6 --new ^
 --filter-udp=19294-19344 ^
   --out-range=-n12 --in-range=-n4 --lua-desync=circular:fails=2:udp_out=4:udp_in=1 ^
   --in-range=x ^
   --lua-desync=fake:blob=fake_quic_google:ip_autottl=-2,3-20:ip_ttl=6:repeats=6:strategy=1 ^
   --lua-desync=send:ipfrag=ipfrag2:ipfrag_pos_udp=8:ipfrag_disorder:strategy=2 ^
   --lua-desync=drop:strategy=2 --new ^
 --filter-tcp=443 --hostlist=lists/domains-google.txt ^
   --out-range=-s34228 --in-range=-s5556 --lua-desync=circular:fails=2:retrans=2:reset:nld=2:time=60 ^
   --in-range=x ^
   --payload=tls_client_hello ^
   --lua-desync=fake:blob=fake_tls_google:tls_mod=rnd,dupsid:tcp_seq=-10000:ip_id=zero:repeats=8:strategy=1 ^
   --lua-desync=multidisorder:pos=1,midsld:ip_id=zero:strategy=1 ^
   --lua-desync=fakeddisorder:pos=midsld:tcp_seq=-10000:ip_id=zero:strategy=2 ^
   --lua-desync=hostfakesplit:host=www.google.com:tcp_ts=-600000:strategy=3 --new ^
 --filter-tcp=80,443,2053,2083,2087,2096,8443 --hostlist=lists/domains-bypass.txt --hostlist-auto=lists/domains-auto.txt --hostlist-auto-fail-threshold=2 --hostlist-auto-retrans-threshold=2 --hostlist-exclude=lists/domains-exclude.txt ^
   --out-range=-s34228 --in-range=-s5556 --lua-desync=circular:fails=2:retrans=2:reset:nld=2:time=60 ^
   --in-range=x ^
   --payload=tls_client_hello ^
   --lua-desync=tls_client_hello_clone:blob=fake_cloned:sni_del:sni_first=www.google.com:fallback=fake_tls_google:strategy=1 ^
   --lua-desync=fake:blob=fake_cloned:ip_autottl=-2,3-20:ip_ttl=5:repeats=4:strategy=1 ^
   --lua-desync=multisplit:pos=1,midsld:strategy=1 ^
   --lua-desync=fakeddisorder:pos=2:seqovl=1:badsum:tcp_md5:strategy=2 ^
   --lua-desync=fake:blob=fake_tls_google:tls_mod=rnd,rndsni,dupsid:fool=custom_fool_randseq:repeats=6:strategy=3 ^
   --lua-desync=multisplit:pos=2:seqovl=652:strategy=3 ^
   --lua-desync=hostfakesplit:host=www.google.com:tcp_ts=-600000:strategy=4 ^
   --payload=http_req ^
   --lua-desync=multisplit:pos=method+2:strategy=1 ^
   --lua-desync=fakeddisorder:pos=host:badsum:strategy=2 ^
   --lua-desync=multisplit:pos=host:strategy=3 ^
   --lua-desync=hostfakesplit:host=www.google.com:strategy=4
