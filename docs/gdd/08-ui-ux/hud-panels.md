# HUD and panels

## Layout at 844x390 (landscape phone) `[BUILT]` (R5 + U batches)
- Left column 72 px: inmate portraits (3 visible, scroll) with needs/health bands.
- Top strip: resources, contamination + forecast ticker, scent/dormancy ticker, wave timer / "Next audit in
  N d" chip, petition chip, speed pause/1x/2x/3x, clock.
- Bottom-right thumb cluster: Build, Orders, Zones, Alarm (64 px), "More" sheet; automation strip only with
  a build/belt tool (docked). Compact layout below 500 logical px height.
- Notification stack top-right (max 2, +N chip, dedupe, tap to dismiss); wave report card and toasts go
  there; hides when it would overlap the quest sheet. PA banner for Warden lines; kill/event feed ticker.
- World visible >= 55 % (asserted; 61 % measured). Sheets slide from the right, one at a time, with a scrim.
- Tutorial card top-centre (2 lines + one 64 px button) with a pulsing non-blocking highlight; hidden while a
  side sheet leaves < 420 px.

## Panel registry (`view/panels/panel_registry.gd`) — all `[BUILT]`
| panel | purpose |
|---|---|
| inspector (+ sections: colonist, building, cell, zone, bills, debt, health, mood, mutation, perks, record) | tap target details; block line; "Open gear" |
| work_panel / work_tab | per-colonist work priorities 0-4 |
| draft_panel, squad_bar, ability_radial | drafting, squads, abilities |
| research_panel | tree, queue, essence cost |
| automation_panel, splitter_panel, power_panel | belts/machines, splitter filters, nets |
| contracts_panel, dispatch_panel, petition_panel, shuttle_panel, reviews_panel, beacon_panel | the quota spine |
| blocks_panel | society (Standing, Informant, contraband) |
| gear_panel, gear_screen, item_card | equipment (F8) |
| letters_panel / letter_log, quest_sheet, event_choice, regulation_card | narrative surface |
| expedition_panel, map_switcher, campaign view | outposts |
| forecast_panel, wave_report_card, alert_center | threat readability |
| perk_panel, health_panel, dossier_card | progression / NG+ |
| meta_screen, win_screen, ending_panel, new_game_dialog, save_panel, handbook_panel, tutorial_card | meta, endings, save/load (browser autosave daily, command replay), handbook of read lessons |
Modal style: opaque cards, scrim, filled primary buttons, contrast test (U3). Game-over modal.

## Warden's Orientation (tutorial) `[BUILT]` — `sim/tutorial/tutorial_system.gd`, `data/tutorial.json`
12 sim-side steps (intake, dig, storage, haul, tool, dirty hands, research, belt, forecast, audit raid,
decoy, release), skip step / skip all, each with a reason line; scripted `tutorial_audit` raid (2 crawlers,
pod immune); normal waves held until the audit step; tier-2 audit pre-approved. New-game dialog with the
tutorial toggle (ON for a fresh profile), presets as sentences (Short Stay / Standard Term / Hard Time with
hint density full / new / off). Tutorial bot: all 12 steps, 0 deaths, d11-12. Situational lesson queue
(`data/lessons.json`) `[IDEA]` (not built; handbook lists tutorial steps).

## Owner feedback loop
Phone screenshot + one blunt sentence -> one task (CLAUDE.md 9). F8 ("grid inventory + icons") is the
latest such request shipped.

## Contextual hints + "NEW" badges `[BUILT]` (F10)
- `view/hint_director.gd` + `data/hints.json`: one-time toasts for first gear, damaged gear (<50 %), petition alt
  available, Q14 path choice, first drone raid. Respect hint density (Off: none; New: gear_first + drone_raid only),
  silent while a tutorial step is active, max 1 per 10 s. Read-only (state hash unchanged).
- `view/seen_flags.gd` (`user://seen_flags.json`, in-memory fallback) remembers what the player has seen.
- `view/new_badge.gd`: red "NEW" tag (26x14) on the Gear entry, petition alt, Orders (only if `reg_enabled`) and the
  More button; cleared when the panel is opened (`badge.<panel>` seen flag). Density Off shows no badges.
- Gear screen (F8): paper-doll + 4-column grid + ItemCard, see [../06-items-gear/gear-ui.md](../06-items-gear/gear-ui.md).
