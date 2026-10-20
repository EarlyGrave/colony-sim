# Paths and points of no return

Status: `[BUILT]` (EN1) — `sim/endings/ending_system.gd`, `data/endings.json`, commands `set_path`, `ending_won`.

## The path flag
Q14 verb `path {id}` sets quest flag `path_<id>` (submit / fight / escape / remission). Systems read it only
through `sim.path()` (nobody greps flags). Before Q14 `path() == ""` and every system behaves as before
(tutorial and goldens unchanged). Q14b changes the path once until the PoNR; `set_path` is refused after
`path_locked`.

## Points of no return (`endings.json ponr_flags`, `submit_ponr_petition_phase` 1)
| path | PoNR | then |
|---|---|---|
| Submit | deliver petition phase 1 (accept the Compliance Deal) | petitions continue; non-Submit paths refuse petition deliveries once locked |
| Fight | first refused pickup after Q14 (`ponr_fight`) | shuttle stops; defiance climbs; metro raids every 3 d |
| Escape | `contact_bandits` after 3 covert sales (`contact_sales`) | bandit fee 60 credits; countdown + pursuit |
| Remission | `ponr_remission` (flag; path OFF today) | pylons + cure; quota still met |

## What each path changes mid-game `[BUILT]` unless noted
- Submit: launch-window notices (+0.1 wave mult / 8 d), seats manifest, madness siege x (1 + pollution).
  Path effects `[BUILT]` (F9): `wave_mult` ×1.2 and debt grace +5 d (`data/endings.json path_effects`,
  read via `EndingSystem.effect()` in threat_system `_o3_mult` and debt_system grace).
- Fight: missed installments no longer count as missed (debt_system), Debt of the Dead waived, Walkout
  demands a refinery stop instead of payment, metro raids escalate, r4 "Drone Toll".
- Escape: `covert_sale` unlocked, suspicion meter live, r4 "Quiet Freight". Petition fee ×0.8 on
  Escape `[BUILT]` (F9, `path_effects.escape.petition_fee_mult`, product with the quest mod, min 1).
- Remission: Q17 not built; `path_remission` can only be set by command/tests today.
- Block Standing shifts +-15 by leaning on the choice; Warden letter per path (`pa.path_*`).

## Bot knobs (`tools/factory_bot.gd`, F1b + F2/F3/F4) and eval columns
`path` (submit|fight|escape; 3 = escape in the escape bot), `sell_every`, `equip` (default ON), `branch_pick`,
`use_alt` (petition waivers, OFF), `la_hoard_day` (OFF); columns path, suspicion_peak, metro_raids, ending,
ending_day, gear_equipped. Bots skip the tutorial on the fight path / at day 6.

## Design doc differences
- GDD §6 lists Escape's PoNR as "bandit contact": built as a command after 3 sales (not a quest beat).
- economy_endgame.md C2 `strength_mult` on `start_wave`: `[BUILT]` and used by siege/assault/pursuit.
