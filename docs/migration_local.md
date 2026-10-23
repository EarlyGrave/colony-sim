# План миграции: локальная работа + подключение из облака

Цель: основная работа идёт на компе владельца (максимальная скорость: тесты, бот, сборка, живая игра в окне),
а из облака/телефона можно подключиться к той же работе.

## 1. Что переносить
Всё нужное уже в git (`EarlyGrave/colony-sim`): код, `data/`, `docs/` (планы, отчёты агентов, GDD),
`CLAUDE.md`, `PROGRESS.md`, `DECISIONS.md`, `docs/rollback_points.md`. Рабочая ветка — `claude/colony-sim-godot-4jftsm`,
Pages собирается из `main`. Ничего вручную копировать не нужно, достаточно `git clone`.
Не переносим (пересоздаётся само): `.godot/` (кэш импорта), `build/` (экспорт), `.claude/worktrees/` (копии воркеров).

## 2. Установка на компе
| что | зачем | как |
|---|---|---|
| git | синхронизация | уже есть / пакетный менеджер |
| Godot 4.7.2-stable (+ export templates) | игра, тесты, веб-сборка | README «Local setup»; на Windows/macOS — свой бинарник с godotengine.org той же версии |
| Python 3 + `pip install playwright==1.56.0` + `playwright install chromium` | `tools/web_smoke.py` | локально `playwright install` можно (запрет только для облака) |
| Claude Code CLI | оркестратор/воркеры, Remote Control | `npm i -g @anthropic-ai/claude-code`, вход тем же аккаунтом |

ОС:
- **Linux** — всё работает как в облаке.
- **macOS** — bash 3.2 без `wait -n`, нет `nproc` и `timeout`: `brew install bash coreutils` (или патч скриптов, п. 5).
- **Windows** — рекомендую WSL2 (Ubuntu): все `tools/*.sh` на bash. Тесты/бот гоняем Linux-Godot внутри WSL,
  играть можно Windows-Godot из той же папки (`\\wsl$\...`) или через WSLg.

## 3. Первый запуск (проверка паритета)
```bash
git clone https://github.com/EarlyGrave/colony-sim && cd colony-sim
git checkout claude/colony-sim-godot-4jftsm
godot --headless --path . --import
tools/run_tests_sharded.sh $(nproc)          # шардов = ядер; ожидаем тот же зелёный итог, что в облаке
godot --headless --path . res://tests/run_tests.tscn -- --filter=test_perf_budget   # на нормальном железе должен пройти
godot --path .                               # живая игра в окне
```

## 4. Подключение из облака / телефона
- **Remote Control** (основной способ): в папке проекта `claude remote-control` — локальная сессия появляется в
  приложении Claude / claude.ai/code; управляешь с телефона, а работа идёт на компе. Комп должен быть включён и не спать.
- **Облачные сессии** остаются запасным вариантом (комп выключен): работают с той же веткой через GitHub.
  Правило: в один момент пишет один оркестратор; в начале сессии `git pull`, после каждого шага `git push` (уже в CLAUDE.md).
  Облачная сессия до компа не дотягивается — синхронизация только через GitHub.

## 5. Что поправить в репозитории (одним коммитом перед переездом)
- Скрипты: `nproc` -> фолбэк `getconf _NPROCESSORS_ONLN`; `timeout` -> `gtimeout` если есть; `wait -n` — требовать bash 4+ с понятной ошибкой.
- `tools/web_smoke.py`: `/opt/pw-browsers` только если папка существует, иначе путь playwright по умолчанию.
- `CLAUDE.md`: раздел «Local mode»: правило 8 (check-in через `send_later`) локально = `/loop 5m` или просто живая сессия;
  шардов тестов = число ядер; `xvfb-run` для скриншотов локально не нужен (есть дисплей).
- README: установка Godot для macOS/Windows(WSL2).

## 6. Порядок переезда
1. Облако: закрыть батч F11 (мерж, тесты, push), остановить check-ins, записать точку в PROGRESS.
2. Комп: шаги 2–3, сверить число тестов и результат с облаком.
3. Комп: `claude remote-control` в папке проекта, проверить, что сессия видна в приложении.
4. Облако: архивировать старую сессию. Дальше облако — только когда комп выключен.
