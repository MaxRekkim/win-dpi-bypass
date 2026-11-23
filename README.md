<div align="center">

# <a href="https://github.com/MaxRekkim/win-dpi-bypass">MaxRekkim/win-dpi-bypass</a>

Сборка и набор стратегий обхода DPI для Windows на базе [**bol-van/zapret2**](https://github.com/bol-van/zapret2) (`winws2` + Lua).  
Оригинальный разработчик ядра: [**bol-van**](https://github.com/bol-van/zapret2)

</div>

> [!IMPORTANT]
> Все исполняемые и системные файлы (`winws2.exe`, `WinDivert.dll`, `WinDivert64.sys`, базовые Lua-модули и фейки) загружаются скриптом [`scripts/setup.ps1`](./scripts/setup.ps1) напрямую из официального релиза [**bol-van/zapret2**](https://github.com/bol-van/zapret2/releases) (`v1.0.7`). Сторонние перепакованные бинарники в репозитории не хранятся.

> [!WARNING]
> ### АНТИВИРУСЫ
> `WinDivert` может вызывать реакцию антивируса. Это системный драйвер перехвата и фильтрации трафика, необходимый для работы `winws2` — сам по себе он не является вирусом, но антивирусы часто относят его к категории PUA/RiskTool (`WinDivert` / `Not-a-virus:RiskTool.Multi.WinDivert`).
>
> Добавьте папку с проектом в исключения антивируса, иначе `WinDivert64.sys` или `winws2.exe` будут удалены в карантин.

---

## Зачем это нужно

Автономное средство противодействия DPI для Windows без сторонних серверов и VPN.  
В отличие от классического `zapret1` (`winws.exe`), где логика стратегий жёстко зашита в C-код, движок **`zapret2` (`winws2.exe`)** переносит сценарии модификации пакетов в **Lua**.

В этой сборке используется оркестратор **`circular`** из `zapret-auto.lua`: для каждого домена из списка `winws2` отслеживает успешность соединения и при сбое/блокировке автоматически переключает проблемный домен на следующую стратегию по кругу без перезапуска процесса:

1. **Стратегия 1:** `fake` + `multisplit` (`seqovl=652`, `tcp_ts=-600000`) — для Cloudflare / Discord / X.
2. **Стратегия 2:** `fake` + `multidisorder` (`pos=1,midsld`, `tcp_seq=-10000`) — для YouTube / Google.
3. **Стратегия 3:** `hostfakesplit` (`host=www.google.com`, `tcp_ts=-600000`).
4. **Стратегия 4:** `fake` (`sberbank_ru`) + `multisplit` (`pos=1,midsld`, `tcp_seq=-10000`).

Отдельные профили настроены для **QUIC (UDP 443)** и голосовых серверов **Discord (UDP `19294-19344, 50000-50100`, `ip_ttl=7`)**.

> [!NOTE]
> `winws2` обходит только **DPI-фильтрацию** (HTTP/TLS/QUIC/UDP). Если провайдер блокирует ресурс жёстко по IP на уровне сброса TCP `SYN` (например, подсети Telegram на некоторых провайдерах), никакие локальные стратегии `zapret2` это не пробьют — в таком случае нужен туннель или локальный прокси.

---

## ⚙️ Использование

1. **Включите Безопасный DNS (Secure DNS / DoH):**
   * В браузере (Chrome / Edge / Firefox) выберите провайдера DNS, отличного от «Поставщик по умолчанию» (например, `https://dns.google/dns-query`).
   * Либо включите DoH в настройках Windows 11.
2. **Распакуйте или склонируйте репозиторий в путь без кириллицы и спецсимволов** (например, `C:\win-dpi-bypass`).
3. **Запустите [`run-smart.bat`](./run-smart.bat) от имени администратора.**
   * При первом запуске скрипт сам скачает официальный архив `zapret2 v1.0.7` и разложит нужные файлы в `bin/`, `lua/` и `files/fake/`.
4. **Проверьте работу и реальную скорость:**
   ```powershell
   powershell -ExecutionPolicy Bypass -File scripts\test-strategies.ps1
   ```

---

## ℹ️ Описание файлов

* [**`run-smart.bat`**](./run-smart.bat) — основной запуск `winws2.exe` с `circular`-ротацией стратегий и профилями под TCP/QUIC/Discord Voice.
* [**`lua/custom-dpi.lua`**](./lua/custom-dpi.lua) — пользовательский Lua-модуль для доработки и отладки собственных сценариев поверх `zapret-lib.lua` / `zapret-antidpi.lua`.
* [**`lists/domains-bypass.txt`**](./lists/domains-bypass.txt) — список доменов, для которых применяется обход (`YouTube`, `Discord`, `X` и др.).
* [**`lists/domains-exclude.txt`**](./lists/domains-exclude.txt) — домены-исключения (локальные и российские сервисы).
* [**`scripts/setup.ps1`**](./scripts/setup.ps1) — загрузка и распаковка официальных бинарников `zapret2` с GitHub Releases.
* [**`scripts/test-strategies.ps1`**](./scripts/test-strategies.ps1) — проверка `YouTube`, `Discord App` и `X` не только по HTTP-коду `200`, но и по реальному объёму и скорости скачивания.

---

## ☑️ Частые проблемы

* **Ничего не открывается / блокировка остаётся:**
  * Убедитесь, что `run-smart.bat` запущен от имени администратора и антивирус не удалил `bin\WinDivert64.sys`.
  * Проверьте, что не запущен второй экземпляр `winws.exe` / `winws2.exe` или старая служба `zapret` (`sc query zapret`).
  * Сбросьте сетевой стек в командной строке от администратора:
    ```cmd
    netsh winsock reset
    netsh int ip reset all
    netsh winhttp reset proxy
    ipconfig /flushdns
    ```
