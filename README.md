<div align="center">

# <a href="https://github.com/MaxRekkim/win-dpi-bypass">MaxRekkim/win-dpi-bypass</a>

Автономный обход DPI для **Windows** (`winws2`) и роутеров **Keenetic** (`nfqws2` под OPKG/Entware) на базе Lua-стратегий.

</div>

> [!WARNING]
> ### Антивирусы (Windows)
> `bin\win\WinDivert64.sys` почти наверняка вызовет срабатывание антивируса (`WinDivert` / `RiskTool.Multi.WinDivert`). Это драйвер перехвата пакетов, без которого на Windows ничего работать не будет — добавьте папку в исключения, иначе драйвер сразу улетит в карантин.

## Как это работает

Вместо одной жёстко зашитой стратегии используется оркестратор `circular` на Lua: если на конкретном домене текущая стратегия не проходит или рвётся, движок сам переключает этот домен на следующий вариант по кругу (`nld=2`, быстрый сброс зависших сокетов `reset`) без перезапуска процесса и не трогая остальные сайты.

Набор стратегий рассчитан на разные типы ТСПУ у разных провайдеров:
* Динамическое клонирование реального `ClientHello` (`tls_client_hello_clone` + `ip_autottl=-2,3-20`)
* Перемешанные фейки и реальные сегменты (`fakeddisorder` с `badsum` + `tcp_md5`)
* Случайный сдвиг sequence (`custom_fool_randseq`) + `multisplit` (`seqovl=652`, `tls_mod=rnd,rndsni,dupsid`)
* `multidisorder` с `badseq` и `ip_id=zero` (YouTube / Google)
* `hostfakesplit` с `tcp_ts=-600000` и белый SNI `sberbank_ru` + `badsum`
* Для QUIC (`UDP 443`) и голоса Discord (`UDP 19294-19344, 50000-50100`) — `fake` с `ip_autottl` и автоматический фолбэк на IP-фрагментацию UDP (`ipfrag2` + `ipfrag_disorder`).

Новые заблокированные домены, которых ещё нет в списке, автоматически дописываются в `lists/domains-auto.txt`.

> [!NOTE]
> Решение обходит только DPI-фильтрацию. Если провайдер рубит ресурс жёстко по IP ещё на `TCP SYN`, локальный обход на уровне пакетов не поможет.

## Windows

1. Включите Secure DNS (DoH) в браузере или в Windows 11 (например `https://dns.google/dns-query`, не «по умолчанию от провайдера»).
2. Скачайте готовый архив со страницы [**Releases**](https://github.com/MaxRekkim/win-dpi-bypass/releases/latest) или склонируйте репозиторий в путь без кириллицы (например `C:\win-dpi-bypass`).
3. Запустите [`run-smart.bat`](./run-smart.bat) **от имени администратора** (или [`run-debug.bat`](./run-debug.bat) для полного лога пакетов в `logs\winws2.log`). Автоматически найденные домены и лог срабатываний пишутся в `logs\hostlist-auto.log`.
4. Поставить в автозапуск службой: [`service-install.bat`](./service-install.bat) (удалить — [`service-remove.bat`](./service-remove.bat)).
5. Диагностика и проверка реальной скорости (результат пишется в `logs\diagnose.log`):
   ```powershell
   powershell -ExecutionPolicy Bypass -File scripts\diagnose.ps1
   ```
6. Сбор всех логов в единую папку `logs\latest\` и экспорт zip-архива на Рабочий стол (или на выбранный диск):
   - Двойной клик по [`collect-logs.bat`](./collect-logs.bat) — сохранит `win-dpi-bypass-logs-YYYYMMDD-HHMMSS.zip` на **Рабочий стол** (учитывает OneDrive).
   - Сохранить в другую папку / на другой диск: `collect-logs.bat D:\logs` (или создать файл `logs-export.path` с путём, либо задать переменную `DPI_LOGS_DIR`).
   - В архив попадают `diagnose.log`, `network-and-service.txt`, `hostlist-auto.log`, `winws2.log`, `update.log`, `lists\domains-auto.txt` и хвост RTC-логов Discord (если он установлен).
7. Автообновление до свежего релиза с GitHub (сохраняет `lists\domains-auto.txt`, `logs-export.path` и перезапускает службу, если она работала): запустите [`update.bat`](./update.bat) от имени администратора.

## Keenetic (OPKG / Entware)

Требуется установленный OPKG и компоненты системы **«Модули ядра Netfilter»** (`NFQUEUE`). В `bin/` уже лежат сборки под `linux-mipsel` и `linux-arm64`.

1. Скопируйте папку проекта на роутер (например в `/opt/tmp/win-dpi-bypass`).
2. Запустите установку по SSH:
   ```sh
   chmod +x /opt/tmp/win-dpi-bypass/keenetic/install.sh
   /opt/tmp/win-dpi-bypass/keenetic/install.sh
   ```
3. Сбор всех логов роутера (`summary.txt`, `processes.txt`, `iptables`, `domains-auto.txt`, `hostlist-auto.log`, `syslog`) в `.tar.gz`:
   ```sh
   /opt/dpi-bypass/collect-logs.sh
   # или на внешний USB-диск:
   /opt/dpi-bypass/collect-logs.sh /tmp/mnt/USB/logs
   ```
4. Обновление с GitHub Releases: `/opt/tmp/win-dpi-bypass/keenetic/update.sh` (или с `GITHUB_TOKEN`, если репозиторий приватный).
5. Удаление: `/opt/tmp/win-dpi-bypass/keenetic/uninstall.sh`.

*(Если обход включён на роутере — на ПК и телефонах в этой сети локальный обход нужно выключить.)*

## Файлы

* [`run-smart.bat`](./run-smart.bat) / [`run-debug.bat`](./run-debug.bat) — запуск на Windows (обычный и с отладкой в `logs\`)
* [`collect-logs.bat`](./collect-logs.bat) / [`scripts/collect-logs.ps1`](./scripts/collect-logs.ps1) — сбор всех логов в `logs\latest\` и экспорт zip-архива на Рабочий стол или указанный диск
* [`service-install.bat`](./service-install.bat) / [`service-remove.bat`](./service-remove.bat) — служба автозапуска Windows
* [`update.bat`](./update.bat) / [`scripts/update.ps1`](./scripts/update.ps1) — обновление с GitHub (`git pull` или скачивание последнего релиза)
* [`scripts/diagnose.ps1`](./scripts/diagnose.ps1) / [`scripts/test-strategies.ps1`](./scripts/test-strategies.ps1) — диагностика конфликтов, IPv6 и проверка скорости (лог в `logs\diagnose.log`)
* [`keenetic/install.sh`](./keenetic/install.sh) / [`keenetic/collect-logs.sh`](./keenetic/collect-logs.sh) / [`keenetic/update.sh`](./keenetic/update.sh) / [`keenetic/uninstall.sh`](./keenetic/uninstall.sh) — установка, сбор логов, обновление и удаление на Keenetic
* [`lua/custom-dpi.lua`](./lua/custom-dpi.lua) — свои Lua-функции (`custom_fool_randseq`, IPv4/IPv6-условия, логгер)
* [`lists/domains-google.txt`](./lists/domains-google.txt) / [`lists/domains-bypass.txt`](./lists/domains-bypass.txt) / [`lists/domains-exclude.txt`](./lists/domains-exclude.txt) — списки доменов и исключений (`domains-auto.txt` пополняется сам)
