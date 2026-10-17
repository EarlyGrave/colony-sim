# План тестов: этап E10 (предметы, стаки, инвентарь, склады)

Статус: (draft, unfinished). По контракту `docs/contracts/items-inventory.md` прочитаны только заголовки и имена API; детали разделов 1, 2, 4 и 7 нужно сверить перед реализацией.

Идиомы: `TestCase`, `make_sim(seed)`, `peaceful_defs()` для тестов не о существах, `sim.run_ticks(n)`, `sim.ledger.balance_of(id)`, `sim.items.count_world(id)`, `sim.items.count_stored(id)`, `sim.ledger.get_count(key)`.

## Таблица тестов

| Файл | Тест | Setup (кратко) | Assertion |
|---|---|---|---|
| tests/test_items.gd | test_stack_limit_splits_pile | 2×stack_max+1 предметов сбросить в одну клетку | Занято ceil((2×max+1)/max) клеток, каждая ≤ stack_max, сумма сохранена |
| tests/test_items.gd | test_drop_merges_same_id_then_spills | Клетка с неполным стаком того же id | Досыпано до space_for, остаток на соседних клетках, без потерь |
| tests/test_items.gd | test_drop_without_room_records_lost | Все клетки вокруг заняты | `ledger` пишет "lost" на весь непоместившийся объём |
| tests/test_storage.gd | test_haul_low_to_high_priority | Зоны p1 и p3, предмет на полу | Предмет переносится в клетку p3; `find_storage_for(id, from_priority=1)` возвращает клетку p3 |
| tests/test_storage.gd | test_filtered_zone_refuses_wrong_category | Зона с filter=["food"], предмет категории "ore" | `can_accept` = false; `find_storage_for` возвращает Vector2i(-1,-1) для этой зоны |
| tests/test_storage.gd | test_priority_range_validated | `set_storage_priority(zone, 4)` и `(zone, -1)` | Возвращают false; значения 0..3 принимаются |
| tests/test_storage.gd | test_set_filter_rejects_unknown_category | `set_storage_filter(zone, ["no_such_cat"])` | Возвращает false, фильтр зоны не меняется |
| tests/test_storage.gd | test_nearest_tiebreak_is_deterministic | Два равноприоритетных склада на равном расстоянии | Выбор по (y, x) из контракта, одинаковый при повторе |
| tests/test_colonist_inventory.gd | test_carry_weight_limit_respected | Колонист с лимитом веса, подбор тяжёлого предмета | Переносимый вес ≤ лимита на каждом тике; лишнее остаётся на полу |
| tests/test_colonist_inventory.gd | test_equip_swap_returns_old_to_ground | Экипировка A в слот, затем B в тот же слот (`equip_item`) | A лежит на клетке колониста, B в слоте; ledger не меняется (если E10b) |
| tests/test_colonist_inventory.gd | test_drop_inventory_spills_to_ground | Колонист с несколькими предметами, `drop_inventory` | Все предметы на полу у колониста, `count_world` растёт на переносимое |
| tests/test_conservation.gd | test_ledger_invariant_10000_ticks_new_items | Сид, добыча + хауль + новые предметы, 10 000 тиков шагами по 500 | Для каждого id из items.json: `count_world(id) == ledger.balance_of(id)` на каждом шаге |
| tests/test_conservation.gd | test_transfer_emits_item_moved | `transfer(from, to, n)` | Возвращённое n совпадает с фактом; сигнал `item_moved` ровно один раз с n; сумма сохранена |
| tests/test_determinism_items.gd | test_same_seed_same_items_state | Сиды 21 и 22, каждый запускается дважды, по 3000 тиков | Для каждого сида хэш позиций предметов и ledger совпадает; сид 21 и 22 дают разные состояния |

## Покрытие критериев приёмки E10

- Стаки и деление пачек: тесты 1–3.
- Хауль с низкого приоритета на высокий: тест 4.
- Фильтр категорий: тест 5.
- Четыре приоритета: тест 6.
- Лимит веса и слоты экипировки: тесты 9–11.
- Закон сохранения: тесты 12–13.
- Детерминизм на двух сидах: тест 14.

## Запросы к оркестратору

1. Где задан лимит веса переноски: `data/balance.json` или `data/items.json`? Нужен точный ключ для теста 9.
2. E10b (экипировка и drop_inventory) в контракте помечен как optional. Входит ли он в этот этап, или тесты 10–11 переносятся?
3. Событие `item_moved` эмитится на каждый `transfer` или агрегируется по тику? Это влияет на assertion теста 13.
