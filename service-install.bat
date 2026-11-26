@echo off
chcp 65001 > nul
cd /d "%~dp0"

if not exist "bin\win\winws2.exe" (
    echo [ERROR] bin\win\winws2.exe not found!
    if /i "%~1" neq "--nopause" pause
    exit /b 1
)

net session >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Run this script as Administrator!
    if /i "%~1" neq "--nopause" pause
    exit /b 1
)

if not exist "logs" mkdir logs
set "BASE=%~dp0"
set "ARGS=--hostlist-auto-debug=%BASE%logs/hostlist-auto.log --wf-tcp-out=80,443,2053,2083,2087,2096,8443 --wf-tcp-in=80,443,2053,2083,2087,2096,8443 --wf-udp-out=443,19294-19344,50000-50100 --wf-udp-in=443,19294-19344,50000-50100 --lua-init=@%BASE%lua/zapret-lib.lua --lua-init=@%BASE%lua/zapret-antidpi.lua --lua-init=@%BASE%lua/zapret-auto.lua --lua-init=@%BASE%lua/custom-dpi.lua --blob=fake_tls_google:@%BASE%files/fake/tls_clienthello_www_google_com.bin --blob=fake_tls_sber:@%BASE%files/fake/tls_clienthello_sberbank_ru.bin --blob=fake_quic_google:@%BASE%files/fake/quic_initial_www_google_com.bin --blob=fake_discord_udp:@%BASE%files/fake/discord-ip-discovery-with-port.bin --filter-udp=443 --hostlist=%BASE%lists/domains-google.txt --hostlist=%BASE%lists/domains-bypass.txt --hostlist-exclude=%BASE%lists/domains-exclude.txt --out-range=-n8 --in-range=-n4 --lua-desync=circular:fails=2:udp_out=4:udp_in=1 --in-range=x --payload=quic_initial --lua-desync=fake:blob=fake_quic_google:ip_autottl=-2,3-20:ip_ttl=5:repeats=6:strategy=1 --lua-desync=send:ipfrag=ipfrag2:ipfrag_pos_udp=8:ipfrag_disorder:strategy=2 --lua-desync=drop:strategy=2 --new --filter-udp=50000-50100 --filter-l7=discord,stun --out-range=-n8 --lua-desync=fake:blob=fake_discord_udp:ip_autottl=-2,3-20:ip_ttl=6:repeats=6 --new --filter-udp=19294-19344 --out-range=-n12 --in-range=-n4 --lua-desync=circular:fails=2:udp_out=4:udp_in=1 --in-range=x --lua-desync=fake:blob=fake_quic_google:ip_autottl=-2,3-20:ip_ttl=6:repeats=6:strategy=1 --lua-desync=fake:blob=fake_discord_udp:ip_autottl=-2,3-20:ip_ttl=7:repeats=6:strategy=2 --lua-desync=send:ipfrag=ipfrag2:ipfrag_pos_udp=8:ipfrag_disorder:strategy=3 --lua-desync=drop:strategy=3 --new --filter-tcp=443 --hostlist=%BASE%lists/domains-google.txt --out-range=-s34228 --in-range=-s5556 --lua-desync=circular:fails=2:retrans=2:reset:nld=2:time=60 --in-range=x --payload=tls_client_hello --lua-desync=fake:blob=fake_tls_google:tls_mod=rnd,dupsid:tcp_seq=-10000:ip_id=zero:repeats=8:strategy=1 --lua-desync=multidisorder:pos=1,midsld:ip_id=zero:strategy=1 --lua-desync=fakeddisorder:pos=midsld:tcp_seq=-10000:ip_id=zero:strategy=2 --lua-desync=tls_client_hello_clone:blob=fake_cloned:sni_del:sni_first=www.google.com:fallback=fake_tls_google:strategy=3 --lua-desync=fake:blob=fake_cloned:ip_autottl=-2,3-20:ip_ttl=5:repeats=4:strategy=3 --lua-desync=multisplit:pos=1,midsld:strategy=3 --lua-desync=fakeddisorder:pos=2:seqovl=1:badsum:tcp_md5:strategy=4 --lua-desync=hostfakesplit:host=www.google.com:tcp_ts=-600000:strategy=5 --new --filter-tcp=80,443,2053,2083,2087,2096,8443 --hostlist=%BASE%lists/domains-bypass.txt --hostlist-auto=%BASE%lists/domains-auto.txt --hostlist-auto-fail-threshold=2 --hostlist-auto-retrans-threshold=2 --hostlist-exclude=%BASE%lists/domains-exclude.txt --out-range=-s34228 --in-range=-s5556 --lua-desync=circular:fails=2:retrans=2:reset:nld=2:time=60 --in-range=x --payload=tls_client_hello --lua-desync=tls_client_hello_clone:blob=fake_cloned:sni_del:sni_first=www.google.com:fallback=fake_tls_google:strategy=1 --lua-desync=fake:blob=fake_cloned:ip_autottl=-2,3-20:ip_ttl=5:repeats=4:strategy=1 --lua-desync=multisplit:pos=1,midsld:strategy=1 --lua-desync=fakeddisorder:pos=2:seqovl=1:badsum:tcp_md5:strategy=2 --lua-desync=fake:blob=fake_tls_google:tls_mod=rnd,rndsni,dupsid:fool=custom_fool_randseq:repeats=6:strategy=3 --lua-desync=multisplit:pos=2:seqovl=652:strategy=3 --lua-desync=fake:blob=fake_tls_google:tls_mod=rnd,dupsid:tcp_seq=-10000:ip_id=zero:repeats=8:strategy=4 --lua-desync=multidisorder:pos=1,midsld:ip_id=zero:strategy=4 --lua-desync=hostfakesplit:host=www.google.com:tcp_ts=-600000:strategy=5 --lua-desync=fake:blob=fake_tls_sber:badsum:repeats=6:strategy=6 --lua-desync=multisplit:pos=1,midsld:strategy=6 --payload=http_req --lua-desync=multisplit:pos=method+2:strategy=1 --lua-desync=fakeddisorder:pos=host:badsum:strategy=2 --lua-desync=multisplit:pos=host:strategy=3 --lua-desync=multidisorder:pos=host:strategy=4 --lua-desync=hostfakesplit:host=www.google.com:strategy=5 --lua-desync=http_methodeol:strategy=6"

sc stop "win-dpi-bypass" >nul 2>&1
sc delete "win-dpi-bypass" >nul 2>&1
sc create "win-dpi-bypass" binPath= "\"%BASE%bin\win\winws2.exe\" %ARGS%" DisplayName= "win-dpi-bypass" start= auto
sc description "win-dpi-bypass" "Local DPI bypass based on zapret2 winws2"
sc start "win-dpi-bypass"
if /i "%~1" neq "--nopause" pause
