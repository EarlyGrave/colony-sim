# HANDOFF — read this first (written 2026-10-20 ~00:40 UTC, before the weekly usage reset)

A fresh session: read `CLAUDE.md`, then this file, then `PROGRESS.md` tail and `DECISIONS.md` tail, then start the
autonomous loop (section 5). Talk to the owner in Russian (informal "ты", he/him); code/commits/in-game text in English.

## 1. Where things are
- Repo `/home/user/colony-sim`, Godot 4.7.2, GDScript. Dev branch `claude/colony-sim-godot-4jftsm`; Pages deploys `main`.
- Rollback points: `docs/rollback_points.md` (no git tags — proxy refuses tag pushes).
- Design (source of truth, newest first):
  - `docs/design/owner_notes_2026-10-19.md` — owner's own notes (Russian): story, 3 endings, combat, items, skills, traits.
  - `docs/design/GDD.md` — master design doc integrating everything; section 15 = open owner questions.
  - `docs/design/{economy_endgame,society_narrative,threats_pacing,combat_items,progression_traits}.md` — the five
    Fable lead docs, each with a worker breakdown. `docs/story/bible.md` = story canon v2.
- Worker reports: `docs/agents/<ID>/*.md` (some workers could not write files; their reports were relayed in chat and
  summarised in PROGRESS.md).

## 2. Game state (end of 2026-10-19 night sprint)
Shipped to `main` earlier on 10-19: inmate society (blocks/Standing, Informant Q13, contraband (disabled)), society
quests S1-S3, clean smelting (owner rule: ONLY essence refining pollutes; recipe flag `pollutes`), refinery/plates/ore
fixes, shelter ration, map guarantees, first bot shuttle launch (1/10 at 60 d).

Night sprint (on dev; see section 3 for main status), all from the owner's notes via Fable design leads:
- Threats: raid objectives (gorge/wreck, flag `threat.raid_objectives`), scent clock + dormancy (flag `scent.enabled`),
  district lockdown (`threat.json lockdown_radius` 36) + `mine_hut` shelter, storyteller threat hooks + scout_sighting/molt,
  Metropolis drone raid skeleton (`sim/threats/metro_track.gd`, `metro.enabled=false`, defiance clock, energy drones).
- Combat/equipment: `sim/equipment/` StatBlock + `CombatSystem.resolve_hit` (LoL armor curve, flat before %, pen %,
  min 1, phys+energy), EquipmentSystem (slots head/hands/legs/torso_outer/torso_inner/weapon, durability never destroys),
  PoE-style affixes (`data/affixes.json`), burst/magazine/reload, melee crit, read-only gear panel.
  Perf answer: 224 inmates × 6 legendary items vs 300 enemies → combat bucket 0.66 ms/tick desktop (~6-7 ms web est.);
  the big-battle cost is jobs + movement, not gear (`tools/equip_bench.gd`, `tests/test_equip_perf.gd`).
- Progression: skill efficiency curve 0.30/0.60/0.80/1.00/1.10…2.20 + XP table ×1.6 (`data/skills.json`),
  `ProgressionSystem.award` single level-up path, milestones 3/6/10; Traits v2 (`sim/colonists/trait_system.gd`,
  20 traits + 3 acquired "scars", rarity/excludes/effects); NG+ dossier carries traits.
- Story/society: Q14 "Three Forms" (path choice), Q14b path change, S4a/S4b (contraband on, black market clue), S5;
  block leaning per path, moments M1 Debt of the Dead / M2 Informant Succession / M3 Walkout; covert trade
  (`covert_sale`, escape_credit, suspicion, inspections); Blocks panel (phone).
- Endings: `sim/endings/` path()/set_path/PoNR/ending_won; Submit = seats manifest + madness siege + "New Names" flag;
  Fight = Uplink Array + Collector assault; Escape = bandit fee + extraction; dirty fuel cell (pollutes); Ending panel.

Late-night additions: Ending panel (EV), equip/unequip/socket UI + craft_gear recipes + drone drops (E5), Fight relay
win + Remission (`endings.json remission.enabled=false`) (EN4), revelation quests Q15 "Roll Call" / Q16 "Lifer's
Receipt" + epilogues + 20 Warden lines (RV; first-wave gate `threat.first_wave_gate_days` ships 0 = off), skill
branches at level 5 via `choose_branch` (PW4), bot knobs for path/sales/endgame/equip/branches + eval columns (F1b,
all default off). Next plan: **docs/design/next_batches.md** (Fable coherence review + batches F1-F4 + owner questions).

Bot baseline on dev (60 d, 10 seeds, F1c): alive>=8 7/10, audit 5, P1 3, P3 2, launch 0. raid_objectives ON was
worse (alive 5/10) → stays OFF. BL balance attempts (branch `worktree-agent-a9f274b41e4c31a6c`): survival vs pillar
pull against each other — "dirty_mult .28 + old skills" = pillar gap 2.2 / alive 7/10; "skills 2-4 + XP×1.5" =
alive 8/10 but gap 0.8 (rejected: breaks the core pillar). FINAL (applied on dev 00:10 UTC): only `dirty_mult` 0.35→0.28 → pillar gap 2.2, alive>=8 7/10, audit 5, P1 3, P3 2, launch 0. Full suite 1037 green. Still below the main bar (alive>=8 ≥8/10, launch ≥1) → **main stays at 42247d1**; batch F1a in next_batches.md is the next job. The rejected 'skills 2-4 + XP×1.5 + lo/hi .28/.45' row reached alive 8/10 + audit 8 + gap 2.0 but breaks test_waves (dies on wave 4) and test_k5_power.

## 3. Open problems (do these first)
1. **Balance regression from the night merges** (skill curve L0=0.3x, trait hunger, lockdown): pillar gap
   (`tools/kx_pillar_table.gd`) fell to ~1.6 (need ≥2) and factory_eval alive>=8 to ~6-7/10 (was 9/10). Worker BL was
   restoring it via data only — check `docs/agents/BL/` / PROGRESS for its table; if not merged, redo it.
   **main was NOT updated with the night sprint until balance is restored** (see rollback_points.md for the last main SHA).
2. Shuttle win still rare (1/10 at 60 d); copper/parts chain; `repair_rock_fix` and `haul_blocked_fix` flags stay OFF.
3. Flags/half-features: contraband data-disabled (S4a quest turns it on), metro off, scent/raid objectives off,
   Remission ending not built, Collector win condition (`collector_relay`) missing, escape credit not wired to legacy,
   manifest `freed/stayed` not read by legacy, informant panel reads a private field.
4. Owner questions (full list with defaults: docs/design/next_batches.md §3; GDD §15): 4th ending (Remission vs
   Broadcast); Fight path — does the quota shuttle still land?; confirm "no evasion stat" + pre-summed affixes;
   NG+ after Submit keeps colonists or only the dossier; lockdown_radius 36 OK?; first-wave gate on?; traits can
   emerge as "scars" (decided without owner, review).
   Design question from RV: contamination is one global number — "first monsters come from the dump side" needs
   per-area pollution or a dump-zone marker.
5. Owner TODO (keep reminding): delete stray `/b1.txt /b3.txt`.

## 4. Agents and roles (CLAUDE.md "Working mode" is binding)
- Orchestrator (main session): talks to owner, merges, runs suites, updates docs, commits/pushes. Does not implement.
- Fable design leads (model `fable`, background, docs only): one per aspect, write `docs/design/<aspect>.md` (≤150 lines)
  with a worker breakdown. Used tonight for economy+endings+GDD, society+story, threats, combat+items, progression+traits.
- Prompter (Sonnet): plan `docs/<batch>_plan.md` ≤60 lines when no Fable doc exists.
- Workers (Sonnet, `isolation: worktree`, background): start with `git reset --hard claude/colony-sim-godot-4jftsm`
  (local ref works for unpushed merges), `godot --headless --path . --import`, `# region <ID>` in shared files,
  quick tests only (`tools/run_tests_quick.sh claude/colony-sim-godot-4jftsm`), factory_eval `--jobs≤3`, commit, never push.
  Subagents often cannot write report files → ask them to put the report in the reply; relay into PROGRESS.
- Mechanics scout and Story writer (Sonnet, docs only) as in CLAUDE.md.
- Host has **4 cores**: keep ≤5 workers at once; never let workers run the full suite.

## 5. Autonomous loop
- Keep a self check-in with `send_later` (10-15 min). On each: read notifications; merge finished workers (quick tests);
  when a batch is merged run the full `tools/run_tests_sharded.sh 4`, push dev, `tools/web_smoke.py`, merge `main`,
  append `docs/rollback_points.md`, update PROGRESS/DECISIONS. Never push red; never merge half a batch to main.
- Merge pitfalls seen tonight: golden conflicts → take either side then `tools/make_golden.gd --regen` from merged code;
  `docs/sim_contract.md` must stay ≤250 newlines (join prose lines); every recorded command needs a contract row;
  new buildings need a 3D model or `FLAT_FALLBACK` entry (`view/building_3d.gd`); new enemies need sprite sheets
  (`tools/gen_art.py`); `.uid` files appear after `--import` — commit them; two workers adding the same const → parse error.
- Next batches (in order): BL balance restore → main; Collector relay + Remission ending; equip UI (equip/unequip/socket
  from the gear panel) + loot sources for gear; turn on contraband/metro/scent/objectives one at a time with bot numbers;
  skill specialization branches; story writer round 4 on the revelation beats.

## 6. Next 5 tasks (in order)
1. F1a balance (next_batches.md): get alive>=8 ≥8/10 and launch ≥1 at 60 d while pillar gap stays ≥2 (current dev: 7/10, 0, 2.2); then full suite + web_smoke → merge main + rollback row.
2. F1d first-wave gate ON with the pacing tests fixed (`threat.first_wave_gate_days`).
3. F2: metro raids live with bot numbers; Fight loop end to end (uplink + relay).
4. F3: gear economy (start gear, bot equips, craft cost vs quota), all trait stats consumed.
5. F4: Escape numbers + legacy payout, Submit → "New Names" NG+, Remission trial (owner decision first).
Commands: see CLAUDE.md "Commands" (quick tests, sharded full suite, make_golden --regen, web_smoke, factory_eval --jobs≤3, kx_pillar_table).
