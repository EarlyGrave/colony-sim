# F3 report: inmate record
- Counters: plain Dictionaries in `ColonistSystem.records` (id -> kills by species, ore_mined, refined, repairs, belts_repaired, downs, waves_survived, nick_stat). Hooks in mine_job, repair_job, building_system (operator), health_system (downed), threat_system.damage_enemy(by), bus wave_ended. Rebuilt by replay, not in state_hash.
- Why not an object on Colonist: golden part dumps serialise every Colonist property and print instance ids; any new property/script in the sim shifted the "storyteller" part. `ColonistRecord` (sim/colonists/colonist_record.gd) is therefore view/test-side only (rap sheet, nickname, mix).
- Nickname: first stat to cross `balance.flavor.nick_*` (order in nick_order), permanent; text from names.json `nicknames`, stable by colonist id.
- Rap sheet: Crime/Sentence/Complaint/Last words from names.json `rapsheet`, seeded by id; view/panels/sections/record_section.gd (mounted in panel_registry, region F3).
- Barks: view/bark_layer.gd, 90 s game-time cooldown/colonist, max 2 bubbles, 2 s; polls 1/s; tries F1 FlavorPicker `barks.<state>` if present, else names.json `barks`.
- Commendations (milestones.json `commendations`, 5): letter_received once per run on day_started (silent while replaying); NOT persisted in MetaState (deviation).
- Display name is unchanged; nickname shown on the record card only.
- Tests: tests/test_record.gd (7). Sharded suite x2: 608 passed, 0 failed both; goldens unchanged.
- Screenshot: scratchpad f3_rapsheet.png (tools/f3_shot.gd mounts the Record section alone; live inspector scroll would not cooperate headless).
