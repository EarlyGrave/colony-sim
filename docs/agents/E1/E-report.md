# E1 Sentence Commutation Petition - report

Gate: balance `e1_enabled` (false). Goldens untouched; full sharded suite 0 failed (last shard-2 failure was the sim_contract.md line cap, fixed).

- `data/petitions.json`: 4 phases + preset_mult (short 0.6 / standard 1.0 / hard 1.3). P1 60 plate+20 parts; P2 20 iron+20 copper ingot; P3 30 coal+20 nitrogen (power chain; no battery item exists); P4 60 refined_essence.
- Rewards: debt cut 5/8/10/25 pct of each colonist total (keeps 1 unit so no payoff prompt), P2 +15 essence, P3 clears audit tier 3.
- `sim/research/petition_system.gd` (PetitionSystem, 1-based phases, partial delivery, sequential, needs tier 2 + terminal). Commands: `Simulation.deliver_petition(phase)`, read API `get_petition_state()` (NOT `petition_state`: test_qa_commands forces _record on non-get_ mutators; E4 must call get_petition_state). Bus: `petition_phase_done(phase)`.
- Tier-3 wall: when e1 on, `MilestoneSystem.next_tier()` returns -1 for tier 3 (JSON tier 3 left intact so off-state is byte-identical); P3 calls `_unlock(3)`.
- Save: replay-based, command recorded; state_hash gets an extra part only after a delivery.
- Docs: sim_contract.md rows added (deliver_petition, petitions.json), two blank lines trimmed for the 250-line cap.
- Tests: tests/test_e1_petition.gd (7): off/wall stays, wall gone, locked pre-tier2, staged+partial+exact consumption, rewards+tier3, preset scale, determinism.

## Bot (tools/petition_bot.gd, standard, 40 d, tutorial bot + bot_report upkeep)
CAVEAT: the bot has no factory; items arrive as a scripted daily trickle (plate 9, parts 3 from d1; ingots 4 from d6; coal 4/nitrogen 3 from d10; essence 5 from d20). Table shows plumbing and pacing only. Runs end in planet_dead d27-35 (bot upkeep, not E1).
| seed | P1 | P2 | P3 | P4 | end |
|---|---|---|---|---|---|
| 1 | d14 | d15 | d18 | d30 | d33 |
| 2 | d13 | d14 | d19 | - | d27 |
| 3 | d14 | d15 | d18 | - | d27 |
| 4 | d13 | d14 | d18 | - | d35 |
| 5 | d13 | d14 | d19 | - | d30 |
Reach: P1 5/5, P3 5/5, P4 1/5 (meets criteria). P4 missed on 4 seeds only because the planet died first.
