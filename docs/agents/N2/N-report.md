# N2 report: Next Sentence UI
Done: WinScreen third button "Next Sentence" (+ `next_sentence_pressed`, `next_button`, carry lines), new `view/panels/dossier_card.gd`, NewGameDialog "Next Sentence" row (dossier + "Start fresh instead" toggle, hidden w/o carry), MetaScreen "Sentence history" (scroll, last 20), game.gd `# region NG` (`_ng_next_sentence`). tests/test_ng_ui.gd (fixture); updated button counts 2->3 in test_s3_view, test_u3_modal.
Checks: phone layout world-visible 55.6%; web_smoke PASS; sharded suite green except the 2 button-count tests, fixed after (re-run filter green). Screenshots: docs/agents/N2/win.png (dialog.png shows no dossier row until N1 adds `ng`). Tool: tools/n2_shot.tscn.

Assumed N1 names (all accessed defensively via get()/has_method):
- `MetaState.ng` Dictionary: sentence, carry_debt, dossier{name, skills{}, perk_id}, techs[], history[{n,seed,days,debt_paid,preset,result}]
- `MetaState.finish_sentence(summary: Dictionary)`; summary keys I pass: days, debt_paid, colonists, pollution, result="shuttle". (N1 may need debt_left; stats has none, add in game.gd region NG if needed.)
- `MetaState.make_ng_opts() -> Dictionary` with "seed" key.
- Win screen "Balance carried forward" shows `meta.balance` (legacy) as a placeholder; switch to ng carry_debt if preferred.
- Dialog start uses make_ng_opts() when ng.sentence > 1 and "Start fresh" is off.
