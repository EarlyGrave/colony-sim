# Q1 Clerk's Margin Note - report
Files: data/quests_q1.json, sim/quests_q1/clerk_note.gd (QuestClerkNote), tests/test_quest_q1.gd,
`# region Q1` in sim/colonists/generator.gd (tag), sim/core/simulation.gd (`q1_clerk`), thought `clerk_reported` in data/mood.json.

Design: self-contained driver, gated by balance `q_enabled` (default false -> never registers, no hash rows,
generator tag skipped, goldens untouched). Clerk = newcomer with `bio["tag"]="Clerk"` (id % 3 == 0, no rng).
Trigger: Clerk alive with debt paid >= 1 -> letter "Clause 14(c)..." -> next day `offer` (3 options) ->
answer -> payoff after delay. Loophole: that inmate's total -10% AND <= 2% of colony total debt (min of both);
audit_parts_mult 1.2 for 12 d; Clerk removed 50% (sim.rng). Report: +10 refined dropped, Clerk mood -10,
30% escapes. Ignore: flag `clue_clause`, clue letter after 5 d.

Assumed QuestLog names (Q0 must match or orchestrator renames in clerk_note.gd):
- `sim.quests` (read via sim.get), `is_enabled()`, `start(id)`, `offer(quest_id, beat_id, text, options[{id,label}])`,
  `set_flag(id)`, `mod(name)`, and NEW `set_mod(name, value, expiry_tick)` (plan only listed read getters; fallback
  = driver-local `mods` dict if absent).
- Bus signal `quest_resolved(id, option)` -> `QuestClerkNote.on_resolved`. Connected only if signal exists.
- Not used: data/quests.json loader (driver reads data/quests_q1.json itself), `schedule`, effects verbs.
- TODO for orchestrator: add `q1_clerk.state_parts()` to hashing/save (empty until started); stage/next_day/choice
  need save round-trip.
- Wire `q_enabled: false` into balance.json if Q0 does not.

Tests: tests/test_quest_q1.gd (10): disabled, trigger gating, offer once, debt cap, removal determinism and forced
removal, report effects, escape, ignore clue, generator tagging. Uses a stub log. Full suite: see commit message.
