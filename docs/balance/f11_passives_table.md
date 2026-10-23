# F11 passives balance table (F11W5)
Source: `godot --headless --path . -s tools/combat_model.gd` (section 4, analytic) and `tools/factory_eval.sh --seeds=1-3 --days=60` with
`PASSIVES_V2=1 TRAITS_V3=1`. Assumptions: skill 3, distance 5, squad of 8 equal inmates, full kit = underlay+helmet+vest+greaves+gloves.
Tags: [MODEL] = pure data/formula, valid now. [STUB] = depends on the F11W2 stub (marks from skill milestones only, no deeds, no rule
consumers) -> orchestrator re-runs after the real W2/W1/W3 merge.

## Keystone rows [MODEL] (ratio vs same inmate without the keystone)
| keystone | offence | defence | net power | not modelled |
|---|---|---|---|---|
| Dead Man Walking | dps x1.24 (hit +0.15) | survive x1.43 (-30% dmg) | x1.77 | no flee/no downed (upside), heal -50%, mood -10 |
| Short Fuse mood 20 / 50 / 80 | dmg x1.30 / x1.00 / x0.75 | - | - | breaks x2 (mood 20 is a break risk) |
| Armourer's Pride vs crawler / burrower / mimic | dps x1.22 (shiv vs rifle) | survive x1.03 / x2.56 / x2.05 | x1.25 / x3.12 / x2.50 | no ranged; no shooting XP |
| Full Auto (squad of 8) | dps x1.25, ammo 0 | taken x1.78 (target weight x2) | x0.70 | creatures x2 attraction |
Reading: Armourer's Pride is the outlier (x3.1 vs burrowers) because the shiv out-DPSes the rifle at range 5 (no range penalty), so
"melee only" costs nothing; Full Auto is the only keystone below 1.0 before ammo savings. Proposed tune (not applied): Armourer's Pride
armour x1.5 instead of x2 (survive vs burrower about x1.9), or give melee-only a -15% damage drawback.

## Passives > 1.5x their school (detail card) median value per mark [MODEL], 19 of 90
Value = sum(polarity x effect x scale) / cost; scales in `combat_model.gd` F11_SCALE. Ratio to the card median:
| card | passive (ratio) |
|---|---|
| pit | The Mule 1.75, Mole 2.50 |
| stacks | Valve Feel 2.00, Nose Plug 2.00, Lead Apron 2.25, Fume Tolerance 3.00 |
| shop | True Edge 1.67, Steady File 1.50, Jury Rig 3.00 |
| yard | Shiv Grip 1.88, Brawler 4.06, Fast Hands 1.88, Count Shots 1.88, Scar Tissue 4.06, Marksman 1.56 |
| infirmary | Thick Blood 1.62, Field Surgeon 2.00 |
| ledger | Block Voice 2.00, Shot Caller 1.67 |
Yard Brawler / Scar Tissue (x4.06), stacks Fume Tolerance and shop Jury Rig (x3.0) are the first to trim. Rule flags are not priced by the
model, so ratios on rule-heavy cards (yard, ledger) are upper bounds.

## Bot, flags ON (TRAITS_V3=1 PASSIVES_V2=1, 60 days, seeds 1-3) [STUB]
| seed | marks earned / spent | spent % | keystones | allocated |
|---|---|---|---|---|
| 1 | 40 / 36 | 90 | 0 | 31 |
| 2 | 58 / 58 | 100 | 0 | 47 |
| 3 | 71 / 67 | 94 | 0 | 54 |
Total 169 earned, 161 spent = 95% (target >= 80%). 0 keystones: the stub earns marks from skill milestones only (about 3 marks per inmate
by day 60), so a 10-mark keystone path is not reachable; re-run after W2 adds deeds/quests. The stub has no consumers, so alive/audit/launch
equal flag OFF except seed 3, where `TRAIT_ASSIGN` (crew ordered by `sim.traits.mod(c,"work_speed")`) changes who builds.
Flag OFF: `factory_bot_report` seeds 1-3 output is byte-identical to 9ad44f4.
