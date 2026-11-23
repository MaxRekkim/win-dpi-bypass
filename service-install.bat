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

set "BASE=%~dp0"
set "ARGS=--wf-tcp-out=80,443,2053,2083,2087,2096,8443 --wf-tcp-in=80,443,2053,2083,2087,2096,8443 --wf-udp-out=443,19294-19344,50000-50100 --lua-init=@%BASE%lua/zapret-lib.lua --lua-init=@%BASE%lua/zapret-antidpi.lua --lua-init=@%BASE%lua/zapret-auto.lua --lua-init=@%BASE%lua/custom-dpi.lua --blob=fake_tls_google:@%BASE%files/fake/tls_clienthello_www_google_com.bin --blob=fake_tls_sber:@%BASE%files/fake/tls_clienthello_sberbank_ru.bin --blob=fake_quic_google:@%BASE%files/fake/quic_initial_www_google_com.bin --blob=fake_discord_udp:@%BASE%files/fake/discord-ip-discovery-with-port.bin --filter-udp=443 --hostlist=%BASE%lists/domains-google.txt --hostlist=%BASE%lists/domains-bypass.txt --hostlist-exclude=%BASE%lists/domains-exclude.txt --out-range=-n4 --payload=quic_initial --lua-desync=fake:blob=fake_quic_google:repeats=6 --new --filter-udp=19294-19344,50000-50100 --filter-l7=discord,stun --out-range=-n8 --lua-desync=fake:blob=fake_discord_udp:ip_ttl=7:repeats=6 --new --filter-tcp=443 --hostlist=%BASE%lists/domains-google.txt --out-range=-s34228 --in-range=-s5556 --lua-desync=circular:fails=1:retrans=1 --in-range=x --payload=tls_client_hello --lua-desync=fake:blob=fake_tls_google:tcp_seq=-10000:ip_id=zero:repeats=8:strategy=1 --lua-desync=multidisorder:pos=1,midsld:tcp_seq=-10000:ip_id=zero:strategy=1 --lua-desync=hostfakesplit:host=www.google.com:tcp_ts=-600000:strategy=2 --new --filter-tcp=80,443,2053,2083,2087,2096,8443 --hostlist=%BASE%lists/domains-bypass.txt --hostlist-exclude=%BASE%lists/domains-exclude.txt --out-range=-s34228 --in-range=-s5556 --lua-desync=circular:fails=1:retrans=1 --in-range=x --payload=tls_client_hello --lua-desync=fake:blob=fake_tls_google:tcp_ts=-600000:repeats=4:strategy=1 --lua-desync=multisplit:pos=2:seqovl=652:tcp_ts=-600000:strategy=1 --lua-desync=fake:blob=fake_tls_google:tcp_seq=-10000:repeats=8:strategy=2 --lua-desync=multidisorder:pos=1,midsld:tcp_seq=-10000:strategy=2 --lua-desync=hostfakesplit:host=www.google.com:tcp_ts=-600000:strategy=3 --lua-desync=fake:blob=fake_tls_sber:tcp_seq=-10000:repeats=6:strategy=4 --lua-desync=multisplit:pos=1,midsld:tcp_seq=-10000:strategy=4 --payload=http_req --lua-desync=multisplit:pos=method+2:strategy=1 --lua-desync=multisplit:pos=host:strategy=2 --lua-desync=hostfakesplit:host=www.google.com:strategy=3 --lua-desync=http_methodeol:strategy=4"

sc stop "win-dpi-bypass" >nul 2>&1
sc delete "win-dpi-bypass" >nul 2>&1
sc create "win-dpi-bypass" binPath= "\"%BASE%bin\win\winws2.exe\" %ARGS%" DisplayName= "win-dpi-bypass" start= auto
sc description "win-dpi-bypass" "Local DPI bypass based on zapret2 winws2"
sc start "win-dpi-bypass"
pause
