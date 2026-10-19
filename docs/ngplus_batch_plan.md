# NG+ batch plan: "Next Sentence" (Q9). One wave, 3 parallel workers
Owner answer 2026-10-19: after shuttle win -> Continue or NG+; debt almost unpayable (carry-over debt is flavour + pressure, not a win condition).
Verified names: `sim/meta/meta_state.gd` (MetaState: to_dict/load_dict version 1, make_opts, record_run, make_next_batch), `sim/meta/start_opts.gd` (StartOpts.apply/preset_opts/merge_preset), `sim/meta/legacy.gd` (summarize), `view/meta_store.gd` (user://meta.json IO), `view/panels/win_screen.gd` (signals continue_pressed/new_run_pressed; game.gd `_sx_*`, `_o3_open_dialog`), `view/panels/new_game_dialog.gd`, `view/panels/meta_screen.gd`, `data/presets.json` (order short_stay, standard_term, hard_time), `data/perks.json`, `data/meta.json`, `tools/factory_bot.gd` + `factory_bot_report.gd`.
Existing meta file is reused: NO second file. Extend MetaState to `version: 2` with an `ng` block; v1 loads with defaults.

## N1 sim/meta core (owner of sim/meta/*, view/meta_store.gd, data/meta.json, tests/test_ng_meta.gd)
- `ng` block in MetaState: `sentence` (int, 1 = fresh), `carry_debt` (int), `dossier` {name, skills{}, perk_id}, `techs` Array[String], `history` Array of {n, seed, days, debt_paid, preset, result} (cap 20).
- `MetaState.finish_sentence(summary)`: called on shuttle win; computes carry_debt = round(debt_left * data/meta.json ng.debt_carry_frac [0.5]); picks the best colonist (highest skill sum, tie -> lowest id) as the veteran with one earned perk; stores up to `ng.tech_carry` (3) unlocked techs, sorted by tier then id.
- `MetaState.make_ng_opts()`: seed = hash-derive `(prev_seed * 1103515245 + sentence * 12345 + 1) & 0x7fffffff` (pure int math, no Time/randi); preset steps up one in presets.json `order` (clamped at hard_time; at hard_time add `ng.extra_wave_mult` per sentence, cap 3). Emits new StartOpts keys: `carry_debt`, `veteran` {skills, perk_id, name}, `start_techs`; applied only inside `# region NG` in `StartOpts.apply` (+ DebtSystem reads carry_debt at start). Keys absent => behaviour identical, so StartOpts default is unchanged and golden files must NOT be regenerated.
- Atomic write (tmp file + rename) in meta_store; corrupt/unknown version -> safe defaults, never crash.
- Tests: round-trip v2 and v1->v2 migration, same inputs => same seed/opts (run twice), carry_debt fraction, veteran pick tie-break, techs subset valid ids, start with ng opts gives veteran + techs + debt, run with empty opts byte-identical to current golden.
- Acceptance: full suite green with unchanged tests/golden.

## N2 UI (owner of view/panels/win_screen.gd, new_game_dialog.gd, meta_screen.gd, new view/panels/dossier_card.gd, game.gd `# region NG`; tests/test_ng_ui.gd)
- Win screen: third button "Next Sentence" (>= 64 px) beside Continue/New Run; new signal `next_sentence_pressed`; shows "Balance carried forward: N" and the veteran name + perk. Calls N1 `finish_sentence` then starts game with `make_ng_opts()`.
- New-game dialog: "Next Sentence" row (visible only when ng.sentence > 1 or a saved carry exists) with a Dossier card (name, top skills, perk, carried debt, techs) and a "Start fresh instead" option.
- Meta screen: "Sentence history" list (n, preset, days, result), scrollable, last 20.
- Phone-first (844x390 landscape): no overflow, ScrollContainer for lists, no hover. Tests: card text from fixture dict, button visibility rules, signal emission. Run `tools/web_smoke.py` plus a screenshot of win screen.
- Depends on N1 API names above; stub with a fixture dict until merge.

## N3 balance + bot + flavor (owner of tools/ng_chain_report.gd, tools/factory_bot*.gd NG hooks, data/balance.json NG keys, data/flavor.json, data/letters*.json, tests/test_ng_balance.gd)
- New `tools/ng_chain_report.gd`: factory_bot plays run 1 to shuttle/end, calls finish_sentence + make_ng_opts, plays run 2; 10 seeds; prints survival days, deaths, debt left. Tune `ng` numbers in data/meta.json ONLY via a request to N1's keys (document values in report; N3 may edit the 4 ng.* numbers after N1 merge).
- Target: run 2 survival (seeds surviving) within 2 seeds of run 1; run 2 clearly harder (more raid pressure or higher debt) but not hopeless. Tune from the model/table, not by eye.
- Flavor (English): Warden letters keyed by sentence N (2, 3, 4+): "Your release has been processed. Your debt has been rolled over.", "Welcome back. You were never here.", quota notice scaled with N; veteran arrival letter; flavor.json entries only, with a test that every sentence >= 2 key resolves.
- Tests: chain determinism (same seed twice => same result), flavor keys present, report smoke on 2 seeds.

## Shared rules
- Golden: N1 only, and only if unavoidable (prefer none). Others must not touch tests/golden.
- Shared files only inside `# region <agent>` blocks. sim/ deterministic; meta only feeds StartOpts.
- Start with `git reset --hard claude/colony-sim-godot-4jftsm`; commit often; never push; report <= 30 lines in docs/agents/<agent>/ngplus-report.md.
- Never pkill broadly, leave no background runs, use `mktemp -d` for temp output.
