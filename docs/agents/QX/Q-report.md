# QX reconcile report
- Q1 (QuestClerkNote) and Q2 (Q2Pilgrims, sim.q2_pilgrims) are QuestLog modules (`register_module`, only when q_enabled): one daily poll(),
  answers via Simulation.answer_quest -> module.resolve(), state_parts hashed once inside QuestLog rows. Q1 uses set_mod_until. QuestLog.start()
  on a module id only marks it active; modules call `finish(id)`. Module ids are skipped by the data trigger poll.
- Mods wired: refine_mult (BuildingSystem.work, refining recipes), audit_parts_mult (MilestoneSystem.required), petition_fee_mult
  (PetitionSystem.required). fine_pct unused by any quest (Q6 uses debt_pct), left unwired.
- balance.json q_enabled = true. Debt cuts clamped (Q0 <=2% colony; Q1 min(10% inmate, 2% colony)).
- Q2 fix: Brother Oto owes no Warden debt (else colony debt total grew and audit demands slipped 3-8 days).
- HUD leak fix: _q0_bind drops the old QuestSheet (bus connections grew on restart).
- Tests: tests/test_quest_qx.gd (registration, mid-quest replay same hash, audit/petition/refine mods). Goldens regenerated once
  (contamination_crisis only). 814 passed x2, web_smoke PASS, sim_contract.md 248 lines.
- Bot (factory_bot) answers quests with q6 tour / q2 silence / q1 ignore; eval prints fired quests + audit days.

Acceptance (10 seeds, 60 d, after merging PG economy):
| | q off | q on |
|---|---|---|
| audit tier2 | 6/10 | 5/10 (seed 2 colonists dead) |
| P1 | 1/10 | 2/10 |
| quests fired | - | Q2 9/10, Q1 10/10, Q6 5/10 |
Pillar d21 (5 seeds): baseline 6.8 waves, throttle 4.2, mining 4.0 (throttle -2.6).
Screenshot: docs/agents/QX/quest_sheet.png (tools/screenshot.gd --panel=quest).
- Screenshot note: the sheet shows the raw quest id ('q6_auditor:') as a title and the demo shot shows no option buttons yet (Q6 announce beat only); polish for a later pass.
