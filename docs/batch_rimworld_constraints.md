# Batch "RimWorld-like" — global constraints for every agent

Repo root = your working directory (git worktree). Godot 4.7.2, GDScript, headless (`godot` on PATH).
Read first: CLAUDE.md, PROGRESS.md, DECISIONS.md.
Goal of the batch: make mechanics close to RimWorld (owner will de-RimWorld later). Do NOT implement stress/mood. "Storage" enemy target stays = capsule (hq).
Rules: sim/ is plain RefCounted, no Node/autoload/Time/randi/randf; all randomness via sim.rng; iterate arrays or insertion-ordered dicts. Cross-system signals go in autoload/event_bus.gd. Player actions are Simulation command methods; view never mutates systems. All gameplay numbers/content in data/*.json (via Defs). Static typing, tabs, English code/comments. Touch-first UI: buttons >= 64 px, no hover, no right click.
Work in your worktree; never push. Commit with message ending `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Run `godot --headless --path . --import` after adding class_name, then `godot --headless --path . res://tests/run_tests.tscn`; must be green before you finish. Add tests/test_<feature>.gd (extend TestCase; make_sim()/peaceful_defs()).
Shared-file policy: prefer NEW files. Edit shared files only inside `# region <agent>` / `# endregion` blocks, appending; never reformat/reorder existing code.
- simulation.gd: one var, one init line in _init_systems, one tick line in step(), commands in your region.
- event_bus.gd: append signals in your region.
- hud.gd/game.gd: only agent D (UI). Others: new files view/panels/<name>.gd + one line in view/panels/panel_registry.gd.
- data/*.json: new entries/keys for your feature only; prefer new data/<feature>.json + loader line in defs.gd region.
- colonist.gd: one var per component object; logic in your own files.
Final report (<300 words): files changed, new bus signals, new commands, test count, known gaps, commit hash + branch. Do not edit PROGRESS.md.

## WAVE 2 start (MANDATORY first step)
Your worktree may be based on an old commit. Before anything else run:
`git reset --hard claude/colony-sim-godot-4jftsm` (local branch in the shared repo), then `godot --headless --path . --import` and the test suite (should be green, ~97 tests).
Wave-1 systems now exist: work givers (sim/jobs/givers/*, giver_registry.gd, data/work.json, skills), health (sim.health.apply_damage/tend/add_illness, downed), UI registry (view/panels/panel_registry.gd with "# slot N" markers; GamePanel; InspectorSection).
Owner decisions: basic mood/stress yes; research/trade later; food = growing + stove; enemies = creatures only (no armed humans); save/load yes; colonist death permanent.

## PERKS batch (start: `git reset --hard claude/colony-sim-godot-4jftsm`, import, tests ~173 green)
- Perk data only in data/perks.json (loader in defs.gd region perks). Effects are read ONLY via
  `sim.perks.mod(c, stat, ctx := {}) -> float` (additive sum, 0.0 if none) and `sim.perks.has(c, perk_id)`.
  Never read c.perks from other systems.
- Choosing/using perks are Simulation commands (learn_perk, use_perk, respec_perks) with `_record(...)` first line.
  Cooldowns in ticks. No randomness outside sim.rng.
- Colonist holds one `c.perks` (ColonistPerks: learned, cooldowns, buffs). Logic only in sim/perks/*.
- Signals: perk_learned, perk_used, perk_point_available. UI via panel_registry, buttons >= 64 px.
- Decisions D23 in DECISIONS.md (caps: waste/contamination reduction total <= 40%).
