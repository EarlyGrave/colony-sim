# F11W4 UI report
Commits: `STUB F11W2 (drop on merge)` (sim/perks/passive_system.gd, bus signals, Simulation `passives` + 4 commands), then the UI commit.
- `view/panels/passive_board.gd` (new, `PassiveBoard`): full-screen sheet (meta `full_screen` + `wide_sheet`, opaque ModalStyle). Left column: inmate, < > X,
  marks free, keystones n/2 + icons, 6 detail chips. Card canvas 352x404: 3x6 grid of 64 px nodes + left/right seam bridges (17 nodes). Right sheet: name/tier,
  desc, Rule/Drawback, effect lines, one line per rule flag, requirement copy from the reason code, cost; Allocate / Undo / Respec (two-tap).
  Commands only: `sim.allocate_passive / undo_passive / respec_passives`. Allocate is disabled iff `sim.passives.can_allocate != ""`.
- `view/panels/trait_sheet.gd` (new, `TraitSheet`): v3 badge row (HFlow of 60x64 buttons, 32 px `trait_*.png` icons, category tint); tap toggles an info sheet
  (name/category/rarity, desc, effects, "Since day N" from `bio.trait_log`). v2 text list kept as fallback (flag off / no `sim.traits_v3`).
- `colonist_section.gd` (region F11W4): trait row via TraitSheet; "Record" button (NEW +n when marks_free > 0) and one line per rule flag, only when
  `sim.passives.enabled()`. Flag off: unchanged.
- `panel_registry.gd`: `passives` entry (bar button forced hidden). `hud.gd` (region F11W4): hide button, `open_panel_for` branch, `full_screen` layout
  (a 6-row card needs ~420 px; the normal sheet area is ~376), Warden letter on keystone `passive_allocated`.
- `game.gd` (region F11W4): web-only `?passives=1` debug switch (flag on, 3 marks, opens the board); `tools/web_smoke.py` runs a third pass with it.
- `tools/f11w4_shot.{gd,tscn}`: board + colonist-sheet screenshots at 2532x1170 @2.55 (= 844x390 DPR3). Result: `docs/agents/F11W4/board.png`.
- Icons: all 90 passive_* and 66 trait_* sprites already exist; gen_art.py untouched.
- Tests: `tests/test_passive_ui.gd` (9), `test_phone_layout` +2 (board fits 993x459 and 1280x720, nodes >= 64, Warden letter, bar button hidden).

Merge notes: drop the stub commit when W2 lands. The UI uses `sim.passives.{enabled,state_of,can_allocate}`, the 3 commands, and its own read-only
`PassiveTreeV2` for data / can_undo / respec_cost. Trait badge width is 60 (not 64) so 5 fit the ~310 px inspector; height is 64. At 844x390 with
scale 1.0 (not a real phone size) the board scrolls; the overflow check runs only at >= 440 logical px height. web_smoke was not run here (no export).
