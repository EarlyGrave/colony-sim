# W2 report: S3 Whisper Network + informant PA
- NEW data/quests_s3.json (s3_whisper_network): trigger q13 done + tier 2 + cond informant_alive (W1 registers it; tests stub it). Options decoy / bait / cut.
- Defs: region W2 loads quests_s* files and lists quests_s3.json in the export fallback.
- quest_log.gd region W2: requires `tag_alive` (Clerk alive; decoy option disabled otherwise, evaluated at offer time),
  effect verb `informant_standing {delta}` (blocks._change on his block), `remove_colonist how:"transfer"` (debt._remove "transferred"),
  who "informant" resolves via q13 module / blocks.informant_id() / Informant tag.
- gamble now also accepts `p` (win probability). Reason: existing `chance` on a gamble effect is pre-rolled by the generic
  chance check (skips the whole gamble on failure; q12 is affected, left untouched). S3 uses `p`. Orchestrator: consider fixing q12.
- InformantMod region W2: every 3rd day while he lives emits letter_received("Warden", pa.informant_report line, picked by day), silent under pa_silent.
  Reads data/flavor.json directly (sim has no flavor bank). 3 lines added to pa.informant_report (<=70 chars).
- sim_contract.md: 1 row added, 1 blank line removed (250 lines).
- tests/test_society_s3.gd: 8 tests (fires 10 seeds >=7, no tier/informant, decoy needs clerk+parts, bait both outcomes,
  cut-off fee 1.0 + transferred, PA emitted/silenced, determinism hash). Quick suite, test_quest*, test_informant, test_flavor green.
- Note: option `enabled` is computed when offered, so decoy needs parts in stock at that moment.
