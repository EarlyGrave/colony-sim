# T1 report: English-only game text
Branch: t1-english (base c037bec). Not pushed.
- Translated all Cyrillic in view/**, sim/** (job labels, storyteller/contract letters, build errors, names), data/*.json (incl. perks, events, crises, meta, names, rules, traits, skills, zones, quality, health).
- items/buildings/recipes/balance: only string values changed, no reformatting (balance.json had no Russian).
- Compass side_name now returns north/south/east/west ("Creatures coming from the north!"); test_wave_warning updated.
- Tests updated: test_ui_batch3 (Hide/Stay), test_ui_shell, test_wave_warning. Crisis option "Hold the line".
- Colonist names: English prisoner nicknames (Vera, Thunder, Fox, ...), both in colonist_system.gd and names.json.
- Grep [А-Яа-яЁё] (LC_ALL=C.UTF-8) in view sim data autoload tests: zero leftovers.
- Screenshot docs/agents/T1/t1.png reviewed: no clipped labels except colonist bar "debt ..." (pre-existing truncation).
- Tests: see final summary in handback.
