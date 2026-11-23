# win-dpi-bypass

Инструмент обхода DPI для Windows на базе движка **`zapret2` (`winws2` + Lua)** с автоматическим подбором стратегии на лету (`circular`) под каждый домен.

## Как устроено
* `run-smart.bat` — запускает `winws2.exe` с `circular`-оркестратором: если текущая стратегия на конкретном домене не проходит или рвётся, `zapret2` автоматически переключает этот домен на следующую стратегию без перезапуска всего сервиса:
  1. **Strategy 1:** `fake` + `multisplit` (`seqovl=652`, `tcp_ts`) — быстрый обход Cloudflare/Discord/X.
  2. **Strategy 2:** `fake` + `multidisorder` (`pos=1,midsld`, `badseq`) — для YouTube/Google.
  3. **Strategy 3:** `hostfakesplit` (`www.google.com`, `tcp_ts`).
  4. **Strategy 4:** `fake` (`sberbank_ru`) + `multisplit` (`badseq`).
* `lua/custom-dpi.lua` — пользовательские Lua-хелперы.
* `scripts/setup.ps1` — автоматическая загрузка официальных бинарников `zapret2 v1.0.7` (`winws2.exe`, `WinDivert64.sys`, базовые Lua-модули).
* `scripts/test-strategies.ps1` — проверка не только кода `200`, но и реального объёма/скорости загрузки (`YouTube`, `Discord`, `X`).

## Быстрый старт на Windows
1. Запустить `run-smart.bat` **от имени администратора** (при первом запуске сам скачает `zapret2` в `bin/`).
2. Проверить скорость и доступность:
   ```powershell
   powershell -ExecutionPolicy Bypass -File scripts\test-strategies.ps1
   ```
