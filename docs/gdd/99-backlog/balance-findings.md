# Balance findings (what the bots say, 2026-10-20)

Owner (2026-10-20): balance tuning is premature while content/mechanics are moving; one balance pass after
the content batches. Main bar until then: full suite green + web_smoke PASS + alive>=8 >= 6/10. This file
collects what that pass must start from.

## Headline numbers (`factory_eval` 10 seeds / 60 d, standard_term, default bot)
| when | alive>=8 | audit T2 | P1 | P3 | launch | pillar gap (d21) |
|---|---|---|---|---|---|---|
| morning 10-19 (main 42247d1) | 9/10 | 8 | 5 | 3 | 1 | 2.2 |
| after the night sprint (skills L0=0.3x, traits, lockdown) | 7/10 | 5 | 3 | 2 | 0 | 1.6 -> 2.2 (dirty_mult 0.28) |
| after F2 (bot skips tutorial at d6 -> earlier waves) | 6/10 | 3 | 1 | 1 | 0 | 2.2 |
| after F4 / F5 | 6/10 | 6 | 1 / 0 | — | 0 | 2.2 |
| after FX5 (bot equip fixed) / F6-F8 | **7/10** | 6 | 0 | — | 0 | 2.2 |

## Petition pace (`tools/petition_pace.gd`, F7 W2; 60 d, 10 seeds, default bot)
**P1 is never delivered on any seed.** Blockers by seed: P1 plate short (4), no terminal (3), audit T2 plate
short (2), audit T2 parts short (1). -> **Plates are the main brake (6/10)**; refined is plentiful but goes to
installments. The balance pass should start with **plate production and the early terminal -> audit chain**,
not with late petition amounts. Earlier walls, now fixed: copper stuck in rock-bound miners (LA: no longer
the wall), refinery duty cycle under the taint cap (clean smelting fixed it), haul to workbench (PL).

## Launch chain (`tools/la_diag.gd`, LA)
Launch 0/10 at 60 d: P4 lands ~d60 and the shuttle needs ~20 more days; P4 short 60-76 refined on seeds
1/6. Hoard knob (`la_hoard_day` 25 + copper first): 8/6/2/2/0 vs baseline 7/5/3/2/0.

## Survival levers tried (BL, night sprint)
- "skills 2-4 + XP x1.5": alive 8/10 but pillar gap 0.8 -> rejected (breaks pillar 1).
- "dirty_mult 0.35 -> 0.28 only": gap 2.2, alive 7/10 -> applied.
- Rejected row "skills 2-4 + XP x1.5 + lo/hi .28/.45": alive 8/10, audit 8, gap 2.0 but breaks test_waves
  (dies on wave 4) and test_k5_power.
- Likeliest survival cost: skill curve L0 = 0.3x (fresh inmates ~3x slower) + trait hunger; owner wants
  the curve (question 7).

## Flags that hurt when ON (keep OFF until their own pass)
| flag | ON vs OFF |
|---|---|
| `threat.raid_objectives` | alive 5/10 vs 7/10 (F1c) |
| `haul_blocked_fix` | alive 4/10 vs 9/10 (I4) |
| `repair_rock_fix` | 6/10 alive (LA) |
| `reg_enabled` (Standing Orders, option set 3) | alive 4/10 (F5) |
| `fixation_enabled` (accept-always) | alive 4/10 (F5) |
| `use_alt` bot knob (petition waivers) | 60 d alive 6->4/10 (noisy); 90 d P1 2/6 -> 5/6 |
| `first_wave_gate_days` > 0 | broke wave-pacing tests (F1d not done) |
| `contraband.enabled` | inconclusive (bot never reaches despair 40/25) |
| `metro.enabled` | ON: no-path bot 0 raids (fine); fight bot colony dies |

## Other observations for the pass
- Seeds 1/6/8 get **zero creature waves** in 60 d with the current bot -> check the threat clock
  (scent/dormancy interaction).
- Hard preset reaches 7.2-7.8 waves by d21 (target 8); deaths flat across presets at d21.
- Threats bench 2.1-2.2 ms vs 2.0 budget at 300 enemies / 250x250.
- Squads: per repelled wave only -11 % deaths (target 30 %).
- Fight path: Collector win 0/5 — the colony starves of refined; needs its own economy knob.
- Gear: a vest per inmate costs 5-9 % refined (24 % on poor seeds) and 15-30 % of debt paid.
- Web jsheap grew 123 -> 167 -> ~150 MB (watch).
- Rule: every balance claim comes from a table (`kx_pillar_table`, `factory_eval`, `combat_model`,
  `skill_model`, `debt_model`, `petition_pace`), never by eye.
