> Superseded by docs/gdd/ (2026-10-20): current design + status tags live in docs/gdd/README.md; this file is kept for history and worker breakdowns.

# Next batches — coherence review + 4 worker-ready waves (Fable, 2026-10-19 ~23:35 UTC)
Inputs: owner notes, GDD, five lead docs, revelation.md, HANDOFF, git log -80, reports TW2/TW4, E1-E5, PW2-PW4, N1-N4,
EN1-EN4, MT, RV, EV, FX, CU (BL/MT/RV/EV wrote no files; their state is read from code/HANDOFF). Numbers = direction.
Baseline before tonight (main 42247d1): alive>=8 9/10, audit 8, P1 5, P3 3, launch 1/10, pillar gap 2.2.
Dev tip today (TW2/E5 tables): gap 1.6 (standard_term 2.4 in E5's run — the two tools disagree, see A1), alive>=8 6-7/10.

## 1. Coherence review — ranked by player impact (what exists but does not connect)
A1 **Balance regression, no agreed number.** Skill L0=0.3x + trait hunger + lockdown 36 + scent on dropped survival; TW2 and E5
   report different pillar gaps from the same tool (seeds/days differ). No BL report exists. main is frozen on 42247d1 until fixed.
A2 **Nothing from tonight is reachable by the player or the bot.** Flags OFF: raid_objectives, metro, contraband (data), remission,
   first_wave_gate=0 (commit 1c7fa6b: it broke wave-pacing tests). The bot has no `path`/`covert_sale`/`equip`/`choose_branch`/
   `start_assault` knobs, and factory_eval_summary prints no path/suspicion/ending columns — so no ending has a bot number.
A3 **Endings are three dead ends on screen.** Submit: manifest UI exists (EV) but Legacy counts freed/stayed from debt outcomes,
   not the manifest; `ng_new_names` flag is set and read by nobody. Fight: EN4 relay win exists but metro is off, so the assault
   can never be dropped; Escape: `escape_credit` is not a legacy source; "New Sector" NG+ carry not built. Epilogues (RV) are in
   data; check the win screen shows the per-path one (EV/RV merged in parallel — likely not wired).
A4 **Gear economy has no loop.** craft_gear recipes exist (E5) and drone drops need metro (off); equipment never enters a normal
   run: no start gear (E2 skipped it for goldens), no creature loot, no repair. Equip/unequip/socket via UI exists (E5) but the bot
   never equips, so the combat model and bot survival ignore armour. Refined essence budget: craft_gear costs vs quota — untested.
A5 **Skill curve vs survival.** L0=0.3x makes fresh inmates ~3x slower than before; init 1-4 softens it but XP ×1.6 means L3
   (100%) arrives late. No `skill_model.gd` table was produced; this is the likeliest cause of A1 together with trait hunger.
A6 **Traits half-read.** Consumed: hunger, mood_base, break_chance, despair_mult, flee_threshold, thought_*. Unread: carry,
   xp_mult_*, hit, night/day work, mutation_risk, standing_gain, flat armor. Essence Nose / Jittery / Loud Mouth are thus text only.
A7 **Branches (PW4)** have effects data and sheet buttons; verify consumers in combat/jobs and that `branch_level` 5 ≠ doc's 6.
A8 **Revelation arc gaps**: Q15 needs mimic `name_of_dead` (check), Q17 Reversal not built (remission off), dump-side first-wave
   spawn not built, Warden PA lines added but `pa.path_*` keys — confirm FeedDirector keys exist (FX removed the fallback bank).
A9 **Storyteller hooks** (TW4) read `threats.raid_objective_next` which only exists with objectives on; molt extends dormancy
   only with scent on (on). CU: haul/repair flags stay off; copper still blocks parts on 4/10 seeds (launch 1/10).
A10 UI: no HUD surface for scent/dormancy beyond the ticker; Blocks panel "Creatures: former inmates" line after Q15 — check.

## 2. Next four batches (one wave each, 3-4 Sonnet workers, disjoint files, bot numbers before main)
Acceptance floor for every batch (G): `factory_eval 10 seeds/60 d` alive>=8 >= 8/10, audit >= 7, P1 >= 4, P3 >= 3, launch >= 1;
`kx_pillar_table --days=21 --seeds=5` standard_term gap >= 2.0, baseline >= 6; full suite green; web_smoke PASS.

### Batch F1 "Restore the floor, then flags on one at a time" (A1, A2, A5, A9)
F1a **Balance restore (data only)** — owns data/skills.json, data/traits.json, data/threat.json, data/balance.json (scent block),
    tools/skill_model.gd (new: days to L3/L6/L10 full-time, 3 seeds). Levers in order: init level_min 2 / efficiency L0 0.45,
    trait hunger ±, lockdown_radius 36→28, scent per_refine. Accept: G met; a table per lever in the report; goldens regen once.
F1b **Bot knobs + eval columns** — owns tools/factory_bot.gd (region F1), tools/factory_eval_summary.py, tools/factory_bot_report.gd,
    tests/test_u4_factory_bot.gd. Knobs: `path` (submit|fight|escape), `sell_every` (covert_sale cadence), `equip` (equip best stored
    gear daily), `branch_pick` (first listed at branch level). Columns: path, suspicion_peak, metro_raids, ending, ending_day, gear_equipped.
    Accept: default run byte-identical to today's numbers; each knob changes exactly its column.
F1c **Raid objectives ON** — owns data/raids.json, data/balance.json `threat.raid_objectives`, tests/test_raid_objectives.gd,
    tools/balance_report.gd. Accept: objmet >= 50% of 0-turret waves, G met with objectives on; else ship off + table.
F1d **First-wave gate ON** — owns data/balance.json `first_wave_gate_days`, sim/threats/threat_system.gd region RV only,
    tests/test_waves.gd + test_wave_pacing fixes (tests must assert "night after first departure or timer", not a fixed tick).
    Accept: first wave on 10/10 seeds within 1 d of first `shuttle_phase(departed)` or at day 3.5+gate; G met.
Merge F1b → F1a → F1c → F1d; main + rollback row after F1a alone if F1c/F1d miss their numbers.

### Batch F2 "Metropolis live + Fight has a number" (A2, A3-Fight, A9)
F2a **metro.enabled=true pass** — owns data/balance.json `metro`, data/metro.json, data/raids.json metro rows, tests/test_metro.gd.
    Accept: real bot (submit/no path) 0 metro raids by d60 on 10/10; `path=fight` bot >= 2 metro raids by d60, alive>=8 >= 7/10; pillar unchanged.
F2b **Fight loop wiring** — owns sim/endings/fight_escape.gd, sim/threats/metro_track.gd (region F2), data/endings.json `fight`,
    tests/test_fight_ending.gd. Accept: with fight bot + Uplink built, relay drops after `final_after_raids`; Collector win >= 1/10 at 90 d;
    Uplink built >= 3/10 at 90 d (bot builds it when path=fight and tier 3).
F2c **Drone loot + creature loot** — owns data/enemies.json (`loot` block), sim/threats/threat_system.gd region F2 (drop on death via
    `equipment.drop_at`), data/gear.json ilvl by day, tests/test_gear_loot.gd. Twist: rarity weight scales with pollution_frac
    (tainted gear: +offence tier, contamination puff on crit later). Accept: 60 d real bot sees >= 3 gear drops on 8/10 seeds; goldens
    unchanged (loot roll uses a child rng drawn only when `loot` present).
F2d **Ending screen per path** — owns view/panels/win_screen.gd, view/panels/ending_panel.gd (region F2), data/flavor.json epilogue keys,
    tests/test_s3_view.gd. Accept: win screen shows the path's epilogue (4 cases forced in test); phone layout test; web_smoke.

### Batch F3 "Gear and skills in the economy" (A4, A5, A6, A7)
F3a **Start gear + equip bot + combat model** — owns sim/colonists/colonist_system.gd region E2 (start shiv as GearItem, goldens regen
    once), tools/combat_model.gd (armour columns from gear.json), tools/factory_bot.gd region F3 (equip rule default ON if F1b shows
    gain). Accept: `combat_model` table prints TTK with/without vest for crawler/burrower/mimic; survival not lower than F1 floor.
F3b **Craft-gear economy** — owns data/recipes.json craft_gear_* costs, data/research.json gating, tests/test_gear_craft.gd,
    tools/gear_budget.gd (new: refined/plates spent on gear vs quota per seed). Accept: bot that crafts one vest per inmate by d40 still
    launches >= 1/10 and pays installments on 8/10; table in report.
F3c **Traits fully read** — owns sim/colonists/trait_system.gd, hook lines (`# region traits`) in haul_job (carry), progression_system
    (xp_mult_*), combat_system (hit, flat armor into def resum), block_system (standing_gain), mutation (mutation_risk), needs (night/day),
    tests/test_traits.gd. Accept: each stat has one unit test; 500-inmate generation unchanged; goldens unchanged except seeds with the
    affected traits (listed).
F3d **Branch consumers + skill table** — owns data/skills.json branches, sim/perks/* region PW4, tools/skill_model.gd columns per branch,
    tests/test_skill_branches.gd. Accept: each branch effect read by its system (unit test per branch); bot `branch_pick` changes a column.

### Batch F4 "Escape + Submit close the loop; Remission on trial" (A3, A8)
F4a **Escape path numbers** — owns sim/society/contraband.gd region F4, data/contraband.json (`enabled` stays false; S4a turns it on),
    sim/meta/legacy.gd (escape_credit, per-colonist extracted), tests/test_escape_economy.gd. Accept: bot `path=escape sell_every=6`:
    suspicion never 100 on >= 7/10; bandit fee on >= 2/10 at 90 d; legacy pts from extraction.
F4b **Submit → New Names** — owns sim/meta/meta_state.gd, sim/meta/start_opts.gd, sim/meta/ng_flavor.gd, data/meta.json (per-ending carry
    table from GDD §6), sim/meta/legacy.gd freed/stayed from the manifest, tests/test_ng_meta.gd. Accept: Submit win → sentence 2 renames
    the dossier, debt 0; Escape → credits 10%; Fight → no carry, legacy x2.
F4c **Remission trial** — owns data/endings.json `remission`, data/recipes.json `cure`, data/buildings.json pylon, sim/endings/remission.gd,
    data/quests_q17.json, tests/test_remission.gd. Accept: bot knob `path=remission` reaches contamination < 0.1 for 15 d on >= 2/10
    at 90 d; ships `enabled` only with that number, else stays off with the table.
F4d **Revelation polish** — owns data/quests_q15.json/q16, sim/threats/enemy.gd `name_of_dead` region RV, threat spawn hint (dump-side
    first wave, `spawn_at_pollution_peak` flag), view/panels/blocks_panel.gd Q15 line, tests/test_story_paths.gd. Accept: Q15 fires on
    10/10 forced seeds; first wave spawns within 6 cells of the max-pollution tile when flag on; all text <= 70 chars.

## 3. Open owner questions (one line each)
1. 4th ending: Remission (stay, cure the land) or Broadcast (ship the lab report, political win)? — default: Remission on trial (F4c).
2. Fight path: does the quota shuttle still land (lootable) or stop coming after the first refusal? — default: stops after 2 refusals.
3. Confirm: no evasion stat; affixes pre-summed per unit (no per-hit rolls). — default: yes, both.
4. NG+ after Submit: same people under new names, or only the Dossier? — default: dossier + renamed veteran.
5. Should fresh inmates start at L0 (30%) or L1-L2? Balance says L0 costs ~2 survival seeds; owner's curve says L0. — default: init 1-4.
6. May the bot auto-equip gear (player gets a "Equip best" button) or is equipping always a manual decision? — default: button + auto for bot.
7. Metropolis raids: energy damage only, or mixed? (affects whether kevlar is useless vs drones.) — default: 70% energy.
8. First wave gated to the night after shipment 1 (story) — accept even if it shifts the tutorial by ~1 day? — default: yes.
9. Delete stray `/b1.txt /b3.txt` from the repo root? — default: yes, next docs commit.
