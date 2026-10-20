# Unscheduled ideas (all `[IDEA]` unless noted)

| idea | source | our twist | cost | why it waits |
|---|---|---|---|---|
| **Creature haze** (fog of war option D) | [docs/design/fog_of_war.md](../../design/fog_of_war.md) | terrain always visible; creatures outside sensor range (inmates r 6, turrets r 6, Watchtower r 16) drawn as scent blobs at last-known cells; sight radius shrinks with contamination ("Haze: sight -40 %"); info-only phase, goldens unchanged, flag off | M | owner 2026-10-20: backlog; no `sim/fog`; rank 6/6 for the mid-game loop; open questions (content hidden? Watchtower manned?) |
| Survey fog / LoS fog | same | rejected: map is 99 % open ground; LoS fog breaks pillar 2 | — | re-open only if the generator grows caves/ruins |
| **Reclamation Scrubber** | [scout midgame_loop.md #3](../../scout/midgame_loop.md) | building eats raw waste + power -> `reclaimed_slag`; 5 slag -> 1 refined at a loss or 3 slag -> -1 % debt; lowers local contamination | M | could trivialise pillar 1: gate behind T3, cap throughput, pillar table >= 2.0 before merge |
| **Slag Heap decoy** | scout midgame_loop.md #5 | dump waste in a kill zone; scent pulls the wave origin/target there; raises local hunger bank; a raid objective to re-feed | M | needs raid objectives ON (currently hurt survival) |
| Essence hoard clock | [scout pacing.md](../../scout/pacing.md) | stockpiled essence attracts creatures above a free allowance | M | third clock; pillar risk low; balance pass first |
| Nest objective (burrower digs into a miner) | threats_pacing.md A | fortify remote spur or accept an idle miner | S | objectives OFF |
| Broadcast ending | GDD §15 | ship the lab report to the capital; political win | L | owner question 1 (vs Remission) |
| Q17 Reversal, Q4 Gantry Signal, Q5 Outpost 7 | story docs | Remission entry; crate of voices; mimic survivors | M each | Q17 waits on Q1 decision; Q4/Q5 not scheduled |
| Dossier pick Veteran / Archivist / Debtor; 5th-loop Warden screen | quests.md Q9 | NG+ identity choice | S/M | after endings have bot numbers |
| Repair gear job; upgrade crafting cost; trade value sink | combat_items.md | durability never destroys -> maintenance job | S/M | gear loop first |
| Tainted gear (offence affixes + contamination puff on crit), enemy affixes, dodge affix | combat_items.md | loot rarity already scales with pollution | S | after gear balance |
| Operating branches (Refiner / Filter-tech), Monk calm | progression_traits.md | pillar tie-in for the refiner skill | S | branches batch done at 5 skills |
| Several covert buyers; `contracts.json buyers` | economy_endgame.md C5 | each buyer pays credits and adds suspicion differently | M | Escape has one buyer and a number already |
| Metropolis goods pickup during the Submit siege | economy_endgame.md E1 | two drone shuttles loot during the countdown | S | flavour; after balance |
| Situational lesson queue + handbook replay | scout onboarding | ~25 lessons on bus signals | M | tutorial is enough for now |
| Heavy turret / ammo tiers, inserters | E9 contracts | — | M | economy already wide |
| Creature behaviour tags (`provoke_at`), dirty-ground species, scarred tiles | scout threat/ecology | passive species until a threshold; scavengers on clean soil | L | ecology v2 |
| Prisoner roster draft 1-of-3 on arrival | scout research_expeditions_ecology #18 | arrivals already offer a choice dialog `[PARTIAL]` | S | — |
| Time slow while a radial/telegraph picker is open | scout combat_system | Bad North feel | S | phone perf unknown |

## Deliberately never
Per-pair relationships, body-part hit tables/limb loss, cover %, mental-break spirals in combat,
RimWorld storyteller names, fog that hides the wave arrow/lockdown ring (they are forms).
