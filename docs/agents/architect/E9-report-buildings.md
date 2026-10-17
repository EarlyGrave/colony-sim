# Отчёт architect: контракт зданий, рецептов и строительства (E12-E14)

## Что сделано
- Написан контракт `docs/contracts/recipes-buildings.md`: схемы рецептов и зданий, строительство через чертежи
  (blueprints), производственные заказы, заглушки подсистем power/logistics, открытые вопросы.
- Код и существующие документы не менялись. Прочитаны `data/recipes.json`, `data/buildings.json`,
  `sim/buildings/*` (только публичный API и поля).

## Принятые решения
| Тема | Решение |
|---|---|
| Рецепты | Добавлены `building`, `skill`, опц. `power_kw`; множитель навыка берётся из `balance.json`, не из рецепта |
| Здания | Новые поля: `category`, `recipes`, `power_use_kw`, `power_gen_kw`, `walkable`, `sprite`, `build_ticks` |
| Миграция | `recipe` (строка) -> `recipes` (массив); `Building.recipe_id` остаётся выбранным рецептом; legacy-ключ принимается один релиз |
| Чертежи | Владелец `BuildingSystem`; состояния planned -> delivering -> building -> done; отмена возвращает материалы |
| Разборка | Возврат `floor(cost * refund_fraction)` из `balance.json`, остальное уничтожается через `Ledger` |
| Ledger | Доставка в чертёж - перенос; расход материалов при завершении - `destroy("construction")` |
| Задачи | `HaulToBlueprintJob`, `ConstructJob`, `DeconstructJob` |
| Сигналы | `blueprint_placed`, `blueprint_cancelled`, `building_completed`, `building_deconstructed` |
| Заказы | Хранятся в `Building.orders`, режимы `count` / `maintain` / `forever`; без заказов и с одним рецептом - как сейчас |
| Команды | `place_blueprint`, `cancel_blueprint`, `deconstruct`, `set_building_recipe`, `set_production_order` в `Simulation` |

## Файлы
- `docs/contracts/recipes-buildings.md`
- `docs/agents/architect/E9-report-buildings.md`

## Заглушки и долги
- `sim/power/` и `sim/logistics/` описаны только именами интерфейсов, не проектировались.
- Нет конкретных чисел: `refund_fraction`, `build_ticks`, кривая навыка - значения-предложения.
- Не проверено на реальном коде: порядок тика для `ConstructJob`, влияние чертежей на `occupancy` и `Pathfinder`.
- Документ написан в спешке (дедлайн), возможны неточности в деталях сигналов и Ledger-причин.

## Запросы
- Оркестратору: ответить на 7 открытых вопросов в конце контракта (особенно Q2, Q4, Q6).
- Нужно решение: глобальные "заказы" (bills) или per-building; от этого зависит наличие `sim/production/`.
