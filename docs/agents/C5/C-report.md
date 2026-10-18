# C5 report: squad touch UI, forecast, militia, QA
Branch `c5-squad-ui` (C1 `c1-squads` merged in; no push). Screenshots at 844x390 logical (scale 2.55): scratchpad `c5_banners.png`, `c5_ability_radial.png`, `c5_forecast.png`.
- `view/panels/squad_bar.gd` bottom bar (all buttons >= 64 px): banners per squad, Form squad (auto roles via `squads.suggest_roles`), Disband (selected), Wave (opens forecast sheet). Tap banner = select; then ground tap = one `squad_hold`, enemy tap = one `squad_focus` (`GameController._squad_tap`, region C5, runs before `_combat_tap`; single-inmate drafting unchanged when no banner is selected). Long-press (0.45 s) = `view/ability_radial.gd` (extends RadialMenu, 3 slots 72 px, ready/cooldown text); time x0.3 while open.
- `view/panels/forecast_panel.gd` (registered as panel "forecast"): ETA, side, strength, possible raid types + expected head-count; pure read, no sim state (hash unchanged, tested).
- `sim/squads/militia.gd` + `Simulation.militia` (region C5) + rule `militia_rally` (hidden, default on) + `data/roles.json` key `militia`: on alarm idle healthy inmates outside squads draft and walk to the nearest banner (hold cell), flee below `flee_hp_fraction`, released on alarm off. No-op without squads.
- Exact API calls used (all via `has_method`/`get` guards): `sim.form_squad(ids, roles:Array)`, `disband_squad(sid)`, `squad_hold(sid, cell)`, `squad_focus(sid, enemy_id)`, `sim.squads.list/suggest_roles`, `sim.use_ability(sid, id)` (C2, id taunt/volley/stabilise), `sim.abilities.cooldown_left(sid, id)` or `sim.squads.cooldown_left` (C2, optional; default 0 = ready). Until C2 lands the radial slots show but `use_ability` is a no-op.
- Layout: bar sits on the bottom row left of the thumb cluster, the legend/toast stack moves up by 68 px; no overlap with tutorial slot, cluster, column; map area >= 60% at 844x390 (test_squad_ui).
- Tests: `tests/test_squad_ui.gd` (13), `tests/test_militia.gd` (6), helper `tests/squad_stub.gd`. Screenshot tool `tools/c5_shot.gd`.
## QA table (`tools/combat_report.gd`, 25 d x seeds 1-5, 2 turrets, real C1 squads, no C2 abilities; ACTUAL, not tuned)
| | waves | repelled | colonists dead | down s | taint% sum | essence spent |
|---|---|---|---|---|---|---|
| no squad | 19 | 10 | 20 | 488.5 | 109.1 | 0 |
| squad (3 roles, hold+focus) | 24 | 17 | 43 | 1169.5 | 214.3 | 0 |
Target (>= 30% fewer deaths) NOT met: deaths +115%. Not a fair read: no-squad games end early by `hq_destroyed` (hiding inmates) while squad games last longer (24 vs 19 waves, 17 vs 10 repelled, more taint) and then end by `colonists_dead`; shiv/rifle inmates take melee fights. Needs C2 abilities, C4 rescue and a better bot (hold behind turrets) before a verdict.
