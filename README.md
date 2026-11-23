<div align="center">

# <a href="https://github.com/MaxRekkim/win-dpi-bypass">MaxRekkim/win-dpi-bypass</a>

Автономный обход DPI для **Windows** (`winws2`) и роутеров **Keenetic** (`nfqws2` под OPKG/Entware) на базе Lua-стратегий.

</div>

> [!WARNING]
> ### Антивирусы (Windows)
> `bin\win\WinDivert64.sys` почти наверняка вызовет срабатывание антивируса (`WinDivert` / `RiskTool.Multi.WinDivert`). Это драйвер перехвата пакетов, без которого на Windows ничего работать не будет — добавьте папку в исключения, иначе драйвер сразу улетит в карантин.

## Как это работает

Вместо одной жёстко зашитой стратегии используется оркестратор `circular` на Lua: если на конкретном домене текущая стратегия не проходит или соединение рвётся, движок сам переключает этот домен на следующий вариант по кругу без перезапуска процесса и не трогая остальные сайты:

1. `fake` + `multisplit` (`seqovl=652`, `tcp_ts=-600000`) — основной вариант под Cloudflare / Discord / X
2. `fake` + `multidisorder` (`pos=1,midsld`, `tcp_seq=-10000`) — под YouTube / Google
3. `hostfakesplit` (`www.google.com`, `tcp_ts=-600000`)
4. `fake` (`sberbank_ru`) + `multisplit` (`pos=1,midsld`, `tcp_seq=-10000`)

Для QUIC (`UDP 443`) и голоса Discord (`UDP 19294-19344, 50000-50100`, `ip_ttl=7`) стоят отдельные правила.

> [!NOTE]
> Решение обходит только DPI-фильтрацию. Если провайдер рубит ресурс жёстко по IP ещё на `TCP SYN`, локальный обход на уровне пакетов не поможет.

## Windows

1. Включите Secure DNS (DoH) в браузере или в Windows 11 (например `https://dns.google/dns-query`, не «по умолчанию от провайдера»).
2. Склонируйте или распакуйте папку в путь без кириллицы (например `C:\win-dpi-bypass`). Все бинарники уже внутри `bin\win\`.
3. Запустите [`run-smart.bat`](./run-smart.bat) **от имени администратора** (или [`run-debug.bat`](./run-debug.bat) для лога в `logs\winws2.log`).
4. Проверить реальную скорость и загрузку:
   ```powershell
   powershell -ExecutionPolicy Bypass -File scripts\test-strategies.ps1
   ```
5. Поставить в автозапуск службой: [`service-install.bat`](./service-install.bat) (удалить — [`service-remove.bat`](./service-remove.bat)).

## Keenetic (OPKG / Entware)

Требуется установленный OPKG и компоненты системы **«Модули ядра Netfilter»** (`NFQUEUE`). В `bin/` уже лежат сборки под `linux-mipsel` и `linux-arm64`.

1. Скопируйте папку проекта на роутер (например в `/opt/tmp/win-dpi-bypass`).
2. Запустите установку по SSH:
   ```sh
   chmod +x /opt/tmp/win-dpi-bypass/keenetic/install.sh
   /opt/tmp/win-dpi-bypass/keenetic/install.sh
   ```
   Скрипт сам определит архитектуру (`mipsel`/`arm64`) и WAN-интерфейс, положит файлы в `/opt/dpi-bypass`, создаст автозапуск `/opt/etc/init.d/S99zz-dpi-bypass` и хук фаервола `/opt/etc/ndm/netfilter.d/100-dpi-bypass.sh`.
3. Удаление: `/opt/tmp/win-dpi-bypass/keenetic/uninstall.sh`.

*(Если обход включён на роутере — на ПК и телефонах в этой сети локальный обход нужно выключить, чтобы не было двойной нарезки пакетов.)*

## Файлы

* [`run-smart.bat`](./run-smart.bat) / [`run-debug.bat`](./run-debug.bat) — запуск на Windows (обычный и с отладкой)
* [`service-install.bat`](./service-install.bat) / [`service-remove.bat`](./service-remove.bat) — служба автозапуска Windows
* [`keenetic/install.sh`](./keenetic/install.sh) / [`keenetic/uninstall.sh`](./keenetic/uninstall.sh) — установка и удаление на Keenetic
* [`lua/custom-dpi.lua`](./lua/custom-dpi.lua) — свои Lua-хелперы
* [`lists/domains-bypass.txt`](./lists/domains-bypass.txt) / [`lists/domains-exclude.txt`](./lists/domains-exclude.txt) — списки доменов и исключений
* [`scripts/test-strategies.ps1`](./scripts/test-strategies.ps1) — проверка HTTP-кода, размера и скорости скачивания
