# Contract: touch UI for stages E10-E21

Status: draft v1 (ui agent). Commands marked (proposed) do not exist yet; the owning sim agent must add them
to `Simulation` under that name or tell the orchestrator a different one. Existing today: `designate_mine`,
`set_zone`, `place_building`, `set_alarm`, `set_rule` (see `view/hud.gd`, `view/game_controller.gd`).

## 1. Panels

All panels are `Control` scenes/scripts in `view/panels/`, opened from the HUD. Each panel only READS sim state
and SENDS commands through `Simulation` methods. No panel touches system internals (`sim.jobs._x`, etc.).

| # | Panel | Reads (sim state) | Sends (commands) |
|---|---|---|---|
| 1 | Build menu (categories: production, storage, power/utility, defense, furniture) | `Defs.buildings` (category, cost, size), `sim.items` stock totals for affordability, research unlocked set (`sim.research`) | `place_building(id, cell, rotation)`, `cancel_build(cell)` (proposed), `demolish(cell)` (proposed) |
| 2 | Colonist card (needs, skills, equipment, inventory) | `colonist.needs`, `colonist.skills` (level, passion), `colonist.equipment` slots, `colonist.inventory` stacks, current job + mood text | `equip(colonist_id, item_ref)` / `unequip(colonist_id, slot)` (proposed), `drop_item(colonist_id, item_ref)` (proposed) |
| 3 | Building panel (recipe, order queue, buffers, wear) | `building.recipe`, `building.orders[]`, input/output buffers, `building.wear`, `broken`, power state | `set_recipe(building_id, recipe_id)` (proposed), `add_order(building_id, recipe_id, mode, n)` with mode `make` or `maintain` (proposed), `remove_order(building_id, idx)` / `move_order(...)` (proposed), `repair(building_id)` (proposed), `set_building_enabled(id, bool)` (proposed) |
| 4 | Work priorities table (colonists x job types, 0-4) | `Defs.jobs`, `colonist.priorities`, `colonist.can_do(job)` (disabled cells) | `set_priority(colonist_id, job_id, value)` (proposed); global presets via `set_rule` |
| 5 | Research tree | `sim.research.tree` (nodes, prereqs, cost), `.done`, `.current`, `.progress` | `start_research(node_id)` (proposed), `cancel_research()` (proposed) |
| 6 | Event journal + alerts | `sim.journal.entries[]` (tick, kind, text key + params, severity), `sim.storyteller` next-event hint (optional), active alarms | `set_alarm(on)`; `ack_alert(id)` (proposed, optional) |
| 7 | Combat mode (draft, pick target/cell) | `colonist.drafted`, `colonist.weapon`, `sim.threats.enemies`, hit-chance preview (read-only helper in sim) | `draft(colonist_ids, bool)` (proposed), `order_move(colonist_ids, cell)` (proposed), `order_attack(colonist_ids, enemy_id)` (proposed), `set_hold_fire(bool)` (proposed) |
| 8 | Storage zone filter/priority | zone rect, `zone.filter` (item categories + item ids), `zone.priority`, fill level | `set_zone(rect, kind)` (existing), `set_zone_filter(zone_id, filter)` (proposed), `set_zone_priority(zone_id, p)` (proposed) |

HUD (always visible, existing): speed buttons, alarm button, rule toggles, tool selection, threat text.

## 2. Rules

1. **Read model.** The view reads sim state each frame (`_process`) or on bus signals; it never mutates sim
   state and never calls underscore-prefixed members. All writes are `Simulation` commands. A command may be
   refused: it returns `bool`/error code, the panel shows the reason via `tr()`.
2. **Determinism.** Panels must not call `randi()`/`randf()` for anything that affects sim; cosmetic only.
3. **i18n.** Every user-visible string goes through `tr("key")`. Key scheme: `ui.<panel>.<element>[.<variant>]`,
   e.g. `ui.build.category.production`, `ui.colonist.need.hunger`, `ui.work.job.mining`, `ui.research.cost`.
   Content keys come from data: `item.<id>.name`, `building.<id>.name`, `recipe.<id>.name`, `event.<id>.text`,
   `job.<id>.name`, `skill.<id>.name`. Parameters use `tr("key").format({n = 3})` with `{name}` placeholders
   (never string concatenation; word order differs in ru). Plurals: keys `..._one/_few/_many` (ru) or
   `tr_n()` with `ngettext` rules.
   Proposed layout:
   ```
   translations/
     ui.csv        # keys,en,ru   (panels, HUD, buttons)
     content.csv   # item/building/recipe/job/skill names and descriptions
     events.csv    # storyteller + journal texts
   ```
   CSV header `keys,en,ru`; Godot imports each to `*.en.translation`/`*.ru.translation`, registered in
   `project.godot` `[internationalization]`. Default locale from `OS.get_locale_language()`, fallback `en`;
   a `settings` toggle sets `TranslationServer.set_locale()`. A test (`tests/test_i18n.gd`) checks that
   every key referenced in `data/*.json` (`name_key`, `text_key`) exists in both languages and that no
   `.gd` file under `view/` contains a raw literal passed to `Label.text`/`Button.text` (grep-based).
   Data JSON stores keys (`"name_key"`), not display text.
4. **Touch.** Min tap target 64 px physical (CLAUDE.md); list rows >= 64 px high; spacing between targets
   >= 8 px. No hover, no right click, no tooltips as the only information carrier; long-press (>= 400 ms) is
   allowed only as a shortcut to something also reachable by tap. Drag = pan, pinch = zoom. Ignore mouse events
   with `device == InputEvent.DEVICE_ID_EMULATION` in world input. UI scale: `content_scale_factor =
   devicePixelRatio * 0.85` in `GameController._apply_ui_scale` (do not set other scale in panels).
5. **Layout.** Test resolutions: **390x844** (phone portrait) and **1024x768** (tablet/desktop). On phone: one
   panel open at a time (opening another closes the current one), panels are bottom sheets <= 60% height or
   full-screen for tables (work priorities, research); close button top-right >= 64 px; safe-area margins.
   On 1024x768 a side panel (<= 40% width) may coexist with the map. No horizontal page scroll; tables scroll
   inside a `ScrollContainer` with pinned first column.
6. **Modes.** Tool/command modes (build placement, designate, combat target pick) show a persistent banner with
   a >= 64 px "Cancel" button; one tap on the map confirms (no drag required except area designation).
7. **Tests.** Headless UI smoke tests instantiate each panel with `make_sim()`, assert it builds at both
   resolutions (no engine errors, all `Button.custom_minimum_size >= 64`), and that a button press leads to the
   expected command effect in sim state. Strings test per rule 3.

## 3. Polling vs bus

| Panel | Mode | Why |
|---|---|---|
| Colonist card (needs bars) | poll while visible, throttled to 4 Hz | continuous values, no per-tick signal |
| Building panel buffers/wear/progress | poll while visible, 4 Hz | continuous |
| Storage zone fill level | poll while visible, 2 Hz | continuous |
| Build menu affordability | poll on open + on `stock_changed` bus signal | cheap, but avoid per-frame rebuild |
| Work priorities table | build on open; rebuild on `colonist_added/removed` signals; cell values poll (cheap) | structure changes rarely |
| Research tree | build on open; refresh on `research_started/finished` signals; progress bar polls | structure changes on events |
| Event journal + alerts | **bus signals required** (`journal_entry_added`, `alert_raised`, `alert_cleared`) | events are discrete; polling would miss/duplicate; toast must fire once |
| Combat mode | poll positions/HP at frame rate; **signals** `colonist_drafted`, `enemy_spawned/died`, `command_rejected` | selection state must update immediately |
| Alarm / game over / wave warning | bus signals | one-shot |

Rule: lists are rebuilt only on structural signals, never every frame; poll only updates text/bars of existing
nodes. Panels hidden = no polling (`set_process(false)`).

## 4. Open questions for the orchestrator

1. Command names/signatures marked (proposed) in section 1: who owns them (colonists/buildings/research
   agents) and where is the canonical list? Suggest one `docs/contracts/commands.md`.
2. Is there a `sim.journal` (ring buffer of entries with text key + params) or does the view build it from
   bus signals? UI needs entries to survive a panel being closed.
3. Is `sim.research` part of E10-E21 and with what state shape (tree, current, progress)?
4. Equipment/inventory: addressing of an item inside a stack (`item_ref`)? One stack per cell is documented for
   the map, not for inventories.
5. Work priority range and semantic (0 = off, 1 = highest, as RimWorld, or 1-4)? Per colonist only, or also
   global presets?
6. Languages: confirm ru + en only; default locale; do we need the font to cover Cyrillic in the Web export
   (default font OK, custom font must include it)?
7. Does sim expose hit-chance / path preview helpers for combat mode, or is combat mode UI only a draft toggle
   plus target pick?
8. Can the view call read-only query helpers on sim (e.g. `sim.can_afford(building_id)`,
   `colonist.can_do(job)`) - or should those be precomputed fields? Proposal: read-only helpers are allowed.
9. Bottom-sheet vs full-screen preference per panel is a proposal; the owner may want a different feel.
