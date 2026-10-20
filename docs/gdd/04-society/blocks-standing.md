# Cell blocks, Standing, the Informant

## Blocks `[BUILT]` — `sim/society/block_system.gd`, `data/blocks.json`, `view/panels/blocks_panel.gd`
Five blocks (= bible archetypes): lifer, clerk, zealot, informant, fresh_fish, assigned at generation in
`assign_order`; Informant block only from 6 inmates. Each block has a colony-wide **Standing 0-100**
(start 50, regresses 1/day toward the middle):
- +6 when the installment is paid on time, -0.2/day per missed day, -6 when a member dies, -5 when docked.
- Standing scales despair: <= 30 -> x1.2, >= 70 -> x0.9 (mild on purpose; stronger tuning doubled riots).
- Thoughts `block_proud` / `block_shamed`; quiet block >= 55 for 6 days -> the Warden bills a "Cohesion fee" (S1).
- Trait `standing_gain` (Loud Mouth) scales gains; `block_only` traits (Done Time, Ledger Eye).

## Leaning and the vote `[BUILT]`
`blocks.json leaning` maps each block to a path (lifer Submit, clerk Escape, zealot Fight, informant
Metropolis, fresh_fish majority). Q14's `path` verb shifts Standing `leaning_delta` +-15 (aligned/opposed);
the hint quotes the real cost ("Lifers +15, Zealots -15"). Opposing the strongest block is the designed
memorable decision. Q14b "Amended Form" changes the path once (20 refined, -20 Standing all).

## Emergent moments `[BUILT]` (N3) — `block_system.gd`, `debt_system.gd` region N3
| moment | trigger | effect |
|---|---|---|
| M1 Debt of the Dead | an inmate dies | his open installment moves to his block (+1 % each, cap kept), Standing -6; Fight path waives it |
| M2 Informant Succession | the Informant dies/transfers | the Warden appoints one from the highest-Standing block (-10), once per run |
| M3 Walkout | a block <= 15 Standing for 3 days | ultimatum letter (pay in 2 d; Fight: stop the refinery); unmet -> 2 highest-despair members try the dock; met -> +20, `block_proud` |
Report tool: `tools/block_report.gd` (Standing spread > 0 on 8/10 seeds, <= 1 walkout per seed).

## The Informant `[BUILT]` — `sim/society/informant_mod.gd`, `data/quests_q13.json`
One per run (bible #4). Reports to the Warden PA every 3 days (`pa.informant_report`), petition fee
x1.1-1.3 while he reports (`petition_fee_mult`). Q13 options: tolerate / feed false info (needs a Clerk) /
transfer him (removes a worker). S3 Whisper Network extends it (decoy, bait the Warden, cut him off).
Suspicion gain doubles while the Informant is alive (contraband). `informant_standing` quest verb.
Known: the Blocks panel reads a private field of the informant mod (HANDOFF §3).

## How the player sees it `[BUILT]` (N4)
Blocks panel (HUD overflow row): per block name, living members, Standing bar + trend, leaning icon after
Q14, last society letter; Informant row (reports, fee); after contraband on: stash + suspicion; after Q15:
"Creatures: former inmates (confirmed)". Inspector line "Block: Lifers (Standing 42, leans Submit)".
Standing changes >= 10 push a notification. Fits 844x390 (phone layout test).

## Not built
- Veteran Network NG+ (S5 sets the veteran's block +10 via `standing` verb `[BUILT]`; a pre-revealed quest
  hint `[IDEA]`).
- Two-meter policy sheet (Hope/Compliance) `[IDEA]` -> became Standing Orders (regulations, flag OFF).
- Per-pair relationships: deliberately never (scout rule).
