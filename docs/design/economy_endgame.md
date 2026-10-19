# Economy & endgame design — debt, refining, parts, shuttle, Next Sentence (2026-10-19)
Author: game designer (Fable). Status: proposal for the prompter; no code. Hard stop 2026-10-20 00:50 UTC.
Baseline (factory_eval, 10 seeds, 60 d): launch 1/10, alive>=8 9/10, audit 8, P1 5, P3 3; real refined 228-582/60 d.

## Problems (what makes d25-d60 a grind)
P1. One currency, seven sinks, zero choice. Refined essence pays installments, research, turrets, machine_parts,
    AI chips, P4 (60) and release parts (24). Every sink is "deliver N at a terminal"; the only decision is order.
P2. Debt is a tax, not a goal. It is unpayable by design (8 x 120-280 = ~1600 vs ~400 refined/60 d) and the shuttle
    ignores it ("debt unpaid, sentence ended"). So paying is just despair management; petitions cut % invisibly.
P3. The shuttle is a shopping list. 24 identical parts (2 plate + 1 refined + 1 fuel cell) + gantry. No reason to
    launch early, no reason not to wait forever; the siege is the only drama and it ignores everything the
    player did (debt, pollution barely: 0.5 speedup).
P4. The pillar bites once. With clean smelting (owner rule) pollution only comes from refine_essence; the late
    game needs plates/parts/nitrogen, which are all clean, so the last 30 days are a logistics puzzle (copper
    stuck in rock miners, one broken iron miner) rather than a dirty-vs-clean dilemma.
P5. Next Sentence changes numbers, not the shape of the run (25% debt, +1 preset, veteran). Q9's 3-way Dossier
    and "the colony was used before" (Q11) are flavor only.

## Design: "The escape is paid with the same pollution that wakes the planet" (bible), made literal
C1. Dirty fuel (S). Second recipe `fuel_cell_dirty`: essence_ore 6 + refined_essence 1 -> fuel_cell 1 + waste 3,
    station refinery/smelter, `pollutes: true`, work 60 (clean cell stays nitrogen 2 + plate 1, bench 90).
    Unlock: research `bulk_refining` (currently unlocks nothing). Shuttle needs 24 cells: the player picks
    nitrogen chain (clean, slow, needs clean_power) or the refinery (fast, waves). Hooks: data/recipes.json,
    data/research.json unlocks.recipes, Defs.validate already enforces waste for polluting recipes.
C2. Asset Recovery siege (M). The Company sieges to recover its property; strength = unpaid debt share.
    `siege_mult = 1 + debt_mult * unpaid_frac + sentence_mult * (sentence-1)`, applied to ThreatSystem.start_wave
    via a new optional `strength_mult` arg (threats region only, default 1.0). Paying debt / petitions now buy a
    softer launch; a zero-debt colony gets the base siege. Data: shuttle.json `siege_debt_mult` 1.5,
    `siege_sentence_mult` 0.25. Letter at launch states the recovery claim ("Property leaving. Recovery filed.").
C3. Manifest: seats, not parts (M). `parts_need` becomes `seats` = colonists aboard (default: all alive, player
    may unseat via `set_manifest(colonist_id, aboard)`); one release part per seat (preset-scaled min 6). Unseated
    colonists stay as the "Continue" colony (bible ending 2) with `freedman` thought, and their debt stays in the
    unpaid share (C2). Fewer seats = cheaper, faster launch, bigger siege, less legacy (per_prisoner_freed).
    Hooks: sim/shuttle/shuttle_system.gd, Simulation command, Legacy.summarize (freed/stayed counts).
C4. Launch window (S). After P4 the Warden files "Recovery Notices" every `notice_days` (8): each raises the
    ambient wave_mult by `notice_wave_step` (0.1, cap 1.5) until launch. A visible clock replaces "wait forever".
    Hooks: shuttle.json, ShuttleSystem.tick (uses existing threats wave_mult modifier path), letter per notice.
C5. P4 alternative path (S). Petition IV accepts `refined_essence: 60` OR `alt_parts: {fuel_cell: 6, parts: 20}`
    (industrial proof). Clean players progress without the refinery; dirty players pay less time.
    Hooks: data/petitions.json `alt_parts`, PetitionSystem.required/remaining/deliver (choose the set that is
    closer to complete), terminal UI shows both (view: 1 label).
C6. Next Sentence shape (M). Sentence >= 2: (a) Dossier pick from Q9 at the win screen - Veteran (today's) /
    Archivist (forecast revealed + `clue_loop` flag) / Debtor (carry_debt x2, start refined +40);
    (b) "Previous Tenant's gantry": map starts with a release_gantry at 30% hp, `deconstructible false`, so NG+
    is about repairing and feeding, not re-earning tier 3; (c) C2 sentence term. Data: meta.json `ng.dossier_kinds`,
    `ng.ruined_gantry_hp 0.3`; StartOpts applies it; MetaState.finish_sentence stores the pick.

## Bot-measurable acceptance (tools/factory_eval.sh 1-10, 60 d, jobs=3; kx_pillar_table for pillar)
- launch >= 3/10 at 60 d (stretch 5/10 at 90 d); alive>=8 >= 8/10; audit tier 2 >= 7; P1 >= 5; P3 >= 3.
- Pillar gap (standard_term d21, baseline vs throttle) stays >= 2.0; dirty-fuel runs show waste > clean-fuel runs.
- Siege win rate (s5_shuttle_bot `min_siege_win_rate` 0.5) holds with C2 on; a debt-free scripted colony's
  siege strength == base (unit test), 100% unpaid == base x 2.5.
- NG+ chain (test_ng_balance style, 2 runs): run 2 launch day <= run 1 launch day on the same seed family.
- Goldens: regen expected only for scenarios that build a gantry (none today); any other hash change = bug.

## Worker breakdown (one wave, disjoint files; all start from claude/colony-sim-godot-4jftsm)
W1 "Fuel & petition data" (S) - C1 + C5. Owns: data/recipes.json, data/research.json (bulk_refining unlocks),
    data/petitions.json, sim/research/petition_system.gd, tests/test_e1_petition.gd, new tests/test_dirty_fuel.gd.
    Accept: fuel_cell_dirty refines at a refinery, emits batch_refined + waste, counted by ContaminationSystem;
    clean recipe unchanged; P4 completes by either set, never both charged; preset scaling applies to alt_parts;
    Defs.validate passes; goldens unchanged (make_golden prints 0 changed ticks).
W2 "Shuttle manifest & siege" (M) - C2 + C3 + C4. Owns: sim/shuttle/shuttle_system.gd, data/shuttle.json,
    sim/threats/threat_system.gd (only `start_wave(strength_mult := 1.0)` in a `# region SH` block),
    sim/core/simulation.gd (`# region SH`: set_manifest command, recorded for replay), sim/meta/legacy.gd
    (freed/stayed), tests/test_s1_shuttle.gd, new tests/test_shuttle_manifest.gd.
    Accept: seats default = alive colonists, min from data; unseating lowers need and raises unpaid_frac; siege
    strength formula unit-tested at 0% / 50% / 100% unpaid and sentence 1 vs 3; notices raise wave_mult stepwise
    and stop at launch; save/load/replay round-trip of manifest + notice count; determinism test green.
W3 "Factory bot endgame" (M, tools only) - make the bot use C1/C3/C5. Owns: tools/factory_bot.gd (region EG),
    tools/shuttle_bot.gd, tools/factory_eval_summary.py (new columns: seats, fuel_dirty, siege_mult, launch_day),
    tests/test_u4_factory_bot.gd. Behaviour: after P3 reserve refined for parts; queue bulk_refining and run a
    dirty-fuel bill when nitrogen stock < 2x need; hand-haul output of rock-bound copper miners (walk to
    best_adjacent, same trick RP used) so make_parts gets copper; unseat downed/sick colonists when a notice lands.
    Accept: the numbers in the acceptance block above; report per-seed launch day and fuel path chosen.
W4 "Next Sentence shape" (M) - C6. Owns: data/meta.json, sim/meta/meta_state.gd, sim/meta/start_opts.gd,
    sim/meta/ng_flavor.gd (letters for the three Dossiers), view/win_screen.gd (3-button Dossier pick only),
    tests/test_ng_meta.gd, tests/test_ng_balance.gd. Accept: make_ng_opts carries `dossier_kind`; StartOpts places
    the ruined gantry on a free 4x4 near the HQ (deterministic, never on ore), hp 30%, not deconstructible; Debtor
    doubles carry_debt and adds refined; Archivist sets forecast revealed + flag; v2 meta loads with Veteran default;
    two-run chain test: run 2 reaches phase "building" before run 1 did.
Orchestrator: merge W1 -> W2 -> W4 -> W3 (bot last, measured against the merged sim), run kx_pillar_table +
    factory_eval before main; log C2/C3 numbers in DECISIONS.md as "decided without owner, review".

## Not now (keep the door open)
Essence allocation slider (rules.json) once C1-C5 are measured; Penance beacons as a post-win sink (scout #3);
trade/factions (out of scope). If W2 slips, C4 alone (data + 15 lines) still fixes "wait forever".
