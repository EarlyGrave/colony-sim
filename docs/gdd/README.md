# "Sentence Ended" — Game Design Document (organised tree, v2, 2026-10-20)

This folder is the **single entry point** for the design. Every file here is <= 350 lines; every
mechanic carries a status tag verified against the code and data on dev branch
`claude/colony-sim-godot-4jftsm` (main `1a71dac`, F8). Older design prose lives in `docs/design/`,
`docs/story/`, `docs/scout/` and is linked, not copied. Where an old doc and the code disagree, the
section says so in one line and the **code wins**.

## Pitch
A phone-first colony sim ("RimWorld meets Factorio") on a far prison planet. Death-row lifers who chose
hard labour over execution must deliver a quota of refined Essence to the Metropolis' pickup shuttle.
**Mining is safe, refining is dangerous**: refining waste poisons the land and drives the planet's
creatures (former animals and former people) mad; the faster you refine, the harder they come. The
Metropolis needs the Essence for Lull, a euphoric that keeps its cities quiet, which is why the work is
done far away by the condemned. When the colony learns that, it picks a path: Submit, Fight, Escape, or
(on trial) Remission. Tone: bureaucratic dark comedy over real dread; everything awful arrives as a form.

## Pillars (every feature serves at least one; none may break #1)
1. **Mining safe, refining dangerous.** Measured: `tools/kx_pillar_table.gd` baseline minus throttle
   >= 2 waves by day 21 (today 2.2).
2. **Legible on a phone.** Big buttons (>= 64 px), one number per decision, cost quoted in the hint.
3. **Deterministic, data-driven, bot-measured.** `sim/` is RefCounted, numbers in `data/*.json`,
   `tools/factory_eval.sh` before every merge to main.
4. **Everything awful arrives as a form.** Warden PA voice; all in-game text English, <= 70 chars/line.
5. **The colony is people.** Blocks, Standing, traits, the Informant make the society visible.

## Status legend
| tag | meaning |
|---|---|
| `[BUILT]` | in code/data on dev, default on |
| `[BUILT, flag OFF: x]` | in code, switched off by data flag `x` (grep `data/balance.json` etc.) |
| `[PARTIAL]` | some of the design exists; the gap is named |
| `[PLANNED]` | agreed design with a worker breakdown, no code |
| `[IDEA]` | scout/story proposal, not scheduled |
Each mechanic has a "where" line pointing at the owning `sim/`, `view/`, `data/` or `tools/` file.

## Map of sections
| # | folder | what is in it |
|---|---|---|
| 01 | [01-vision/](01-vision/README.md) | pitch, pillars, tone, core loop, story canon summary |
| 02 | [02-economy/](02-economy/README.md) | resources & chains, refining/contamination, quota (debt), petition & shuttle, research & audits, contracts |
| 03 | [03-colony/](03-colony/README.md) | colonists, needs, jobs, skills & branches, traits & scars, mood & despair, health |
| 04 | [04-society/](04-society/README.md) | cell blocks & Standing, Informant, contraband & suspicion, quests & story lines (incl. r4), revelation arc |
| 05 | [05-threats-combat/](05-threats-combat/README.md) | creatures, waves, scent/dormancy, lockdown, Metropolis drones, combat math, squads, turrets |
| 06 | [06-items-gear/](06-items-gear/README.md) | gear slots, rarity, affixes, sockets, durability, crafting, loot, gear UI |
| 07 | [07-endings-meta/](07-endings-meta/README.md) | paths & points of no return, four endings, epilogues, NG+ carry, legacy |
| 08 | [08-ui-ux/](08-ui-ux/README.md) | touch rules, HUD, panels, phone layout, tutorial |
| 09 | [09-world/](09-world/README.md) | map generation, biomes, expeditions/campaign, ecology nests, power |
| 10 | [10-tech/](10-tech/README.md) | architecture summary, contracts, sim contract, tools, batch history |
| 99 | [99-backlog/](99-backlog/README.md) | unscheduled ideas (fog haze, scrubber, slag decoy...) and balance-pass findings |

## Source documents (kept, linked from the sections)
- Owner's own notes (Russian, verbatim, canon): [docs/design/owner_notes_2026-10-19.md](../design/owner_notes_2026-10-19.md)
- Story bible / revelation / quests / society / round 4: [docs/story/](../story/)
- Mechanics scout notes: [docs/scout/](../scout/)
- Process rules: `CLAUDE.md`; decisions log `DECISIONS.md`; progress log `PROGRESS.md`; handoff `docs/HANDOFF.md`.
- Old lead docs (superseded, kept for the worker breakdowns): [docs/design/](../design/)

## Current numbers that matter (dev, 2026-10-20)
- Bot (`tools/factory_eval.sh`, 10 seeds, 60 d, standard_term): alive>=8 **7/10**, audit tier 2 **6/10**,
  P1 **0/10**, launch **0/10**. Main bar (owner 2026-10-20): full suite green + web_smoke PASS +
  alive>=8 >= 6/10. Precise balance is postponed to one pass after the content batches.
- Pillar gap (`kx_pillar_table`, d21): **2.2** waves (baseline ~6.2 vs throttle ~4.0).
- Petition pace (`tools/petition_pace.gd`): P1 is never delivered in 60 d; **plates are the brake**
  (see [99-backlog/balance-findings.md](99-backlog/balance-findings.md)).
- Tests: 1186 green (sharded ~2 min); web smoke PASS at 844x390.

## Open owner questions (one line each; defaults in brackets are what the code does today)
1. **Fourth ending**: Remission (stay, cure the land; built behind `endings.json remission.enabled=false`)
   or "Broadcast" (ship the lab report to the capital, political win; not built)? [Remission on trial, OFF]
2. **Standing Orders** (`balance.json reg_enabled`): switch on? Bot with option set 3 dropped alive to 4/10. [OFF]
3. **Fixation** strange mood (`balance.json fixation_enabled`): switch on? Accept-always bot alive 4/10. [OFF]
4. **Fight path**: does the quota shuttle still land (lootable) after the first refusal, or stop coming? [stops; no landing on fight]
5. **NG+ after Submit**: same people under new names, or only the Dossier? [Dossier only + renamed veteran, decided without owner]
6. **Combat**: confirm no evasion stat and affixes pre-summed per unit (no per-hit rolls). [both yes]
7. **Fresh inmates** start at L0 (30 % efficiency) or L1-L4? [init 1-4]
8. **Bot auto-equip** / "Equip best" button, or equipping always manual? [button + bot auto ON]
9. **Metropolis drones**: energy damage only or mixed? (decides whether kevlar helps vs drones) [per drone def, mixed]
10. **First-wave gate** (`threat.first_wave_gate_days`): wave the night after shipment 1 even if the tutorial shifts ~1 day? [OFF = 0]
11. **Dump-side first wave** (`threat.spawn_at_pollution_peak`): needs per-area pollution; ship it? [OFF]
12. **Lockdown radius** 36 cells (24 broke wave balance) — OK? [36]
13. **Traits as scars** (Hardened / Resigned / Settled, max 1 acquired) — decided without owner, review. [ON]
14. **Raid objectives** (gorge/wreck/nest; `threat.raid_objectives`): ON cost alive 7->5/10; rebalance or drop? [OFF]
15. **Contraband** (`contraband.json enabled`): data OFF, quest S4a turns it on in-game — keep that on-ramp? [OFF]
16. **Creature haze** (fog of war, option D): creatures only or also content; Watchtower passive or manned; default on? [backlog]
17. **Balance pass**: when, and does it start with plate production / early terminal as `petition_pace` suggests? [postponed]
18. Story: Remission entry quest Q17 "Reversal" and Q4/Q5 (gantry crate, Outpost 7) — build, or cut? [not built]
