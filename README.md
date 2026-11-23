<div align="center">

# <a href="https://github.com/MaxRekkim/win-dpi-bypass">MaxRekkim/win-dpi-bypass</a>

Сборка под Windows на базе [**bol-van/zapret2**](https://github.com/bol-van/zapret2) (`winws2` + Lua).

</div>

> [!IMPORTANT]
> Все бинарники (`winws2.exe`, `WinDivert.dll`, `WinDivert64.sys`), базовые Lua-скрипты и фейки качаются скриптом [`scripts/setup.ps1`](./scripts/setup.ps1) напрямую из официального релиза [**bol-van/zapret2**](https://github.com/bol-van/zapret2/releases) (`v1.0.7`). В самом репо лежит только обвязка, списки и конфиг запуска.

> [!WARNING]
> ### Антивирусы
> `WinDivert64.sys` почти наверняка вызовет срабатывание антивируса (`WinDivert` / `RiskTool.Multi.WinDivert`). Это драйвер перехвата пакетов, без которого `winws2` на Windows не работает.
>
> Добавьте папку с проектом в исключения антивируса, иначе драйвер сразу улетит в карантин.

## Зачем это

В обычном `zapret1` (`winws.exe`) все стратегии зашиты в C-код — если на каком-то провайдере выбранный `.bat` начинает отваливаться, приходится вручную перебирать пресеты.

Здесь используется `zapret2` (`winws2.exe` + Lua) и встроенный оркестратор `circular`. Если какая-то стратегия на конкретном домене не проходит или соединение рвётся, `winws2` сам переключает этот домен на следующий вариант по кругу, не трогая остальные сайты и не перезапуская процесс:

1. `fake` + `multisplit` (`seqovl=652`, `tcp_ts=-600000`) — основной вариант под Cloudflare / Discord / X
2. `fake` + `multidisorder` (`pos=1,midsld`, `tcp_seq=-10000`) — под YouTube / Google
3. `hostfakesplit` (`www.google.com`, `tcp_ts=-600000`)
4. `fake` (`sberbank_ru`) + `multisplit` (`pos=1,midsld`, `tcp_seq=-10000`)

Для QUIC (`UDP 443`) и голоса Discord (`UDP 19294-19344, 50000-50100`, `ip_ttl=7`) стоят отдельные правила.

> [!NOTE]
> `zapret2` обходит только DPI. Если провайдер рубит ресурс жёстко по IP ещё на `TCP SYN` (как часто бывает с подсетями Telegram или Meta), локальный обход не поможет — тут нужен туннель или прокси.

## Использование

1. Включите Secure DNS (DoH) в браузере или в Windows 11 (например `https://dns.google/dns-query`, не «по умолчанию от провайдера»).
2. Склонируйте или распакуйте папку в путь без кириллицы (например `C:\win-dpi-bypass`).
3. Запустите [`run-smart.bat`](./run-smart.bat) **от имени администратора** — при первом запуске он сам скачает `zapret2 v1.0.7` в `bin/`.
4. Проверить, что сайты реально грузятся, а не просто отдают `200` и виснут на первых килобайтах:
   ```powershell
   powershell -ExecutionPolicy Bypass -File scripts\test-strategies.ps1
   ```

## Файлы

* [`run-smart.bat`](./run-smart.bat) — запуск `winws2.exe` с `circular`-ротацией
* [`lua/custom-dpi.lua`](./lua/custom-dpi.lua) — место под свои Lua-хелперы
* [`lists/domains-bypass.txt`](./lists/domains-bypass.txt) / [`lists/domains-exclude.txt`](./lists/domains-exclude.txt) — списки доменов и исключений
* [`scripts/setup.ps1`](./scripts/setup.ps1) — загрузка официального `zapret2` с GitHub
* [`scripts/test-strategies.ps1`](./scripts/test-strategies.ps1) — проверка HTTP-кода, размера и скорости скачивания

## Если не работает

* Убедитесь, что `run-smart.bat` запущен от администратора, `bin\WinDivert64.sys` на месте и не висит старая служба `zapret` (`sc query zapret`).
* Если сетевой стек залип, в `cmd` от администратора:
  ```cmd
  netsh winsock reset
  netsh int ip reset all
  netsh winhttp reset proxy
  ipconfig /flushdns
  ```
