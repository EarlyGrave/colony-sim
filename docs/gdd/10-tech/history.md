# Batch history (plans are history, not design)

Each `docs/*_plan.md` is the prompter's one-wave plan for a batch; worker reports live in
`docs/agents/<ID>/`. Details of outcomes: `PROGRESS.md`; decisions: `DECISIONS.md`; main merges:
`docs/rollback_points.md`.

## Stages E0-E11 (sessions 1-2, no plan files)
Skeleton, map & camera, colonists & jobs, mining & stockpiles, refining, waste & contamination, creature
waves, wear & repair, HUD, storyteller, rules, balance; generated pixel art.

## Plan files, in merge order (one line each)
| plan | batch | result |
|---|---|---|
| `batch3_identity_plan.md` | Prison-planet identity (rules, warning arrow, deconstruct, balance) | merged s2 |
| (prompter inbox §9-12) | RimWorld-like batch: work givers, skills, health, needs, farming, construction, drafting, bills, raids, mood, save/load | merged s2 |
| `graphics_batch_plan.md` | G1 pseudo-3D polish (sheets, blocks, sky, camera) | merged s4 |
| `perf_batch_plan.md` | P1-P5b 250x250 / 300 creatures | merged s4 |
| `automation_batch_plan.md` | A1/A2 nodes, machines, belts, ports, save v2, English text | merged s4 |
| `research_batch_plan.md` | R1 sim contract + R2 research tree, audit tiers, goldens | merged s4 |
| `r3_batch_plan.md` | R3 threat model v2, decoys, line damage, chips, ecology nests | merged s4 |
| `expeditions_batch_plan.md` | R4 campaign of maps, biomes, sling, save v3 | merged s4 |
| `r5_batch_plan.md` | R5 Warden's Orientation, presets, phone layout, radial menu | merged s4 |
| `combat_batch_plan.md` | C squads, abilities, telegraphs, injury bands, combat UI | merged s4 |
| (`optimization_strategy.md`) | W1a-e / W2a-e optimisation waves, web smoke | merged s4 |
| `flavor_batch_plan.md` | FL flavor.json, kill feed, PA, barks, records, juice | merged s4 |
| `logistics2_batch_plan.md` | L splitters, mergers, power | main 837a421 |
| `design_b_batch_plan.md` (from `design_review_s4.md`) | B pacing, pollution decay, reviews, hand_plate, wave report | main 757cd8e |
| `pacing_batch_plan.md` | K audit patrols, calm-after-hit, pollution cadence, flow BFS | main 96cbe52 |
| `endgame_batch_plan.md` | E petition phases, sector dispatch, reviews 4-5 | main 6de577e |
| `shuttle_batch_plan.md` | S release shuttle, penance beacons, shuttle bot | main c24980b |
| `hud_batch_plan.md` | U declutter, notifications, modal style, real factory bot | main 3e3fb16 |
| `economy_batch_plan.md` | Y nitrogen at home, map guarantees, real economy | main dff9db7 |
| `debt_batch_plan.md` | D debt pacing, compactor, factory bot, factory_eval | main a5d87c3 |
| (PL / PG passes) | plates/progression, petition progression, map rings | main d4129cf / f1bbfa2 |
| `quest_batch_plan.md` | Q quest log + Q1/Q2/Q6, then QX quests on | main 53b561c |
| (DB/PX) + `ngplus_batch_plan.md` | debt redesign, NG+ Next Sentence, quest sheet | main 984dbc1 |
| `batch_r_plan.md` | R quests Q3/Q8/Q10/Q11/Q12, mimic, sheet overlap | main 8d46b68 |
| `inmates_batch_plan.md` | I blocks/Standing, Informant Q13, contraband (off) | main 38d9f1e |
| `society_quests_plan.md` | SQ S1-S3 | main 53f63b0 |
| (CD/RF/SP/PM, CS, PL, OS/SR/HM, RP/FC) | refinery diagnosis, clean smelting, plates, ore supply, first bot launch | main 3ddda77 .. 42247d1 |
| `docs/design/*.md` (5 Fable leads + GDD) | night sprint 10-19/20: threats TW, equipment E1-E5, progression PW, society N1-N4, endings EN1-EN4, revelation RV, ending panel EV, bot knobs F1b | main 6671d79 (with F2) |
| `f1a_plan.md` | F1a balance restore (SK/TH stopped by owner; LA launch chain continued) | partial |
| `next_batches.md` F2 | Metropolis live, Fight loop, gear loot, ending screens | main 6671d79 |
| `next_batches.md` F3 | start gear, craft-gear economy, traits read, branch tests | main 50fd7cb |
| `next_batches.md` F4 | Escape numbers, NG+ carry per ending, revelation polish, last trait stats | main 2bce7ab |
| `f5_plan.md` | Standing Orders (off), petition waivers, Fixation (off), r4 story lines | main 8dee64a |
| `f6_plan.md` | quest beat gating, r4 PA in feed, story echoes | main c68d72e |
| `f7_plan.md` | dump-zone tint, regulation/fixation signals, petition_pace tool | main 4e64c98 |
| `f8_plan.md` | gear screen: icons, grid inventory, item card | main 1a71dac |
| F9 | path effects, socket cost, gear wear flag OFF + repair | main 0f11434 |
| F10 | contextual hints + SeenFlags, late-game perf budget, NEW badges | main ad385e1 |
| traits v3 + passives v2 | traits v3 module (66 traits), passive board r2 + icons r3, side-quest/events v2 GDD; all flags OFF | main 5877880 |
| `f11_plan.md` | traits v3 + passives v2 integration (sim wiring, rule guards, Record board, bot); flags OFF | main (2026-10-23, see `docs/rollback_points.md`) |

Other docs: `docs/roadmap_after_automation.md`, `docs/prompter_inbox.md`, `docs/design_review_s4.md`,
`docs/batch_rimworld_constraints.md`, `docs/handoff/` (session 2026-10-17 files).
