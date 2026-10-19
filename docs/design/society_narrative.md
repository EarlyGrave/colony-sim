# Society & Story design pass (2026-10-19) - canon v2 (owner notes), lead: Fable
Source of truth: docs/design/owner_notes_2026-10-19.md; bible rewritten (docs/story/bible.md). Numbers are
directions, not balance. Traits: referenced only (docs/design/progression_traits.md). No code here.

## 1. Diagnosis
Blocks, Informant and contraband exist but are modifiers the player never sees and the bot never moves
(Standing sits at ~50; contraband needs despair 40 the bot never reaches). Quests S1-S3 fire but change
numbers, not stories. Goal: society = *who the colony becomes* when the truth lands, and the player SEES it.

## 2. Spine: revelation -> path -> endings
- Clues are flags that already exist (clue_manifest Q6, clue_survey_tag Q8, clue_warden_quota Q10) plus
  new `clue_buyer` (S4). Each clue letter ends with one line of the Lull truth (bible "revelation").
- **Q14 Three Forms** [M, data quest, new `data/quests_q14.json`]: trigger `clues_held >= 2` (new cond,
  counts the 4 clue flags) + min_day 30. Beats: (1) Procurator lands: "Form 3-S: continued service";
  (2) Clerk reads the small print (Lull); (3) choice posted with each block's leaning shown in the hint.
  Options: `submit` / `fight` / `escape` -> verb `path {id}` (N3): sets flag `path_<id>`, shifts Standing
  per blocks.json `leaning` (+15 aligned, -15 opposed), letter from the Warden per path. Hints quote the
  real cost: "Lifers +15, Zealots -15. Zealots at 12 will break." (Standing is the vote; opposing the
  highest-Standing block is the memorable decision).
- Path consequences wired to existing systems via mods/flags (no new ending code this batch; the final
  battles/Collector are a later batch): submit -> `wave_mult 1.2`, quota grace +5 d; fight -> installments
  stop counting as missed (DebtSystem reads `path_fight`), raids +25% every 10 d (`wave_mult` step);
  escape -> covert sales unlocked (sec. 3), petition fee x0.8, suspicion meter live.
- Path is reversible once (Q14b "Amended Form", day +10): costs 20 refined and -20 Standing all blocks.

## 3. Contraband's fate: re-aimed as covert trade (decision)
Keep the code, change the trigger and the meaning. Data flag stays `enabled:false` (goldens untouched);
contraband runs when `sim.quests.flag("contraband_on")` OR data enabled.
- Skim trigger: an inmate skims when his installment is **missed** (DebtState past deadline) OR despair >=
  despair_min (lowered 40 -> 25). Missed installments are the bot's real stress signal (pays <=29% by d60).
- **S4 The Stash Inventory** [S, data `quests_s4.json`] now two-part: (a) trigger `installment_missed` +
  min_day 20: Dispatch "Unaccounted essence" -> sets `contraband_on` (the Warden turning it on is the joke:
  the skim is pre-booked). (b) `contraband_stash_over 6`: Squad shakedown (flag shaken_down, recover) /
  Let it ride (first black market -> flag `clue_buyer`, letter "They asked for the calm stuff.") / Turn it
  in (flag warden_favor, grace +1 d, skimmers' block -15).
- **Covert sale** (escape path): command `Simulation.covert_sale(n)` sells n refined to the Ferry: +`escape_credit`
  (counts toward the shuttle fee at 1:1), +`suspicion` (0-100, +2 per unit, decays 1/day; Informant alive
  doubles the gain). suspicion >= 60: Warden "inspection" = audit_parts_mult 1.3 + one shakedown by the
  Warden (stash and 10 refined confiscated); >= 90: raid. Shakedowns by the player lower suspicion -10.
- Measurable: skim <= 3% refined (kept); S4a fires >= 6/10 real-bot seeds by d45; black market >= 1 in >= 4/10;
  aggregate alive over 10 seeds not lower than contraband-off by more than 3.

## 4. Emergent moments (society writes its own stories)
- **M1 Debt of the Dead** [S]: when an inmate dies, his open installment moves to his block (debt_pct +1 each,
  cap kept) and Standing -6 -> letter "Inmate 4471 died. His installment did not." Fight path: waived.
- **M2 Informant Succession** [S]: when the Informant dies/transfers, the Warden appoints a new one from the
  highest-Standing block (letter "Promotion: confidential."). That block -10. Once per run (flag).
- **M3 Walkout** [M]: a block at Standing <= 15 for 3 days issues an ultimatum letter (pay its installments
  in 2 days); unmet -> its 2 highest-despair members attempt a dock escape together, met -> Standing +20
  and thought `block_proud`. Fight path: the ultimatum demands a refinery stop instead.

## 5. S5 Old Cells, New Faces (NG+) [S, data `quests_s5.json`]
As in society.md; the veteran's block starts +10 via the start beat (`standing` verb), not a block_system
preset. Adds: if the previous run ended in Submit, the veteran's letter reads "You were renamed. It did not take."

## 6. How the player sees the society (phone-first)
- **Blocks panel** (new side sheet, button in the HUD overflow row, registered in panel_registry): 5 rows:
  block name, living members, Standing bar 0-100 with trend arrow, leaning icon after Q14 opens, last
  society letter (1 line). Informant row: "Reports: N, fee x1.2". After contraband_on: "Stash: n, suspicion m".
  Tap a row -> highlights members on the map. Row height >= 64 px; fits 390 px width.
- Colonist inspector: one line "Block: Lifers (Standing 42, leans Submit)".
- PA banner already shows letters; Standing changes >= 10 push a short notification.

## 7. Workers (one wave, disjoint files; all tests extend TestCase; `sim/` deterministic)
**N1 Story data** - owns `data/quests_q14.json`, `data/quests_s4.json`, `data/quests_s5.json`, `data/flavor.json`
(region N1: pa.path_* lines), `tests/test_story_paths.gd`. Needs from N2/N3: conds `clues_held`,
`installment_missed`, verb `path`; stub them in tests if absent (pattern of test_society_s2). Accept: Q14
fires 10/10 seeds with forced clues; each path sets its flag and Standing shifts; S4a/S4b each option; S5 in
sentence 2; all text <= 70 chars (test). defs.gd fallback list via the existing `quests_s*`/`quests_q*` loader.
**N2 Covert trade** - owns `sim/society/contraband.gd`, `data/contraband.json`, `tests/test_contraband.gd`,
`tools/contraband_scenario.gd`; regions N2 in `sim/core/simulation.gd` (command `covert_sale`),
`sim/society/society_conds.gd` (conds `installment_missed`, `suspicion_over`), `sim/core/save_game.gd` (hash
part only once suspicion > 0). Accept: trigger by missed installment; skim cap; suspicion math; sale blocked
without `path_escape`; replay hash; scenario 10 seeds/30 d prints S4a day, black markets, suspicion peak.
**N3 Society moments** - owns `sim/society/block_system.gd`, `data/blocks.json` (leaning per block, M1-M3
numbers), `tests/test_society_moments.gd`, `tools/block_report.gd`; regions N3 in `sim/debt/debt_system.gd`
(M1 on `_remove`, path_fight missed rule), `sim/quests/quest_log.gd` (verb `path`, cond `clues_held`).
Accept: M1 moves <= cap; M2 once; M3 ultimatum -> escape or +20 (both branches forced); `path` shifts
Standing exactly per data; goldens unchanged (nothing fires before a death/flag); block_report 10 seeds/60 d
shows Standing spread > 0 in 8/10 and <= 1 walkout per seed on average.
**N4 Blocks UI** - owns `view/panels/blocks_panel.gd`, `tests/test_blocks_panel.gd`; regions N4 in
`view/panels/panel_registry.gd`, `view/hud.gd` (button), `view/panels/inspector_panel.gd` (block line).
Reads `sim.blocks`, `sim.contraband`, `sim.quests` only. Accept: panel opens at 844x390 DPR3 without overlap
(test_phone_layout case), rows update on `block_standing_changed`, informant row toggles, web_smoke tap passes.
Orchestrator: merge N3 -> N2 -> N1 -> N4; quick tests after each; full suite + web_smoke before main; append
DECISIONS "canon v2: Metropolis/Lull; contraband re-aimed as covert trade; path flags" (review by owner).
Cost: N1 M, N2 M, N3 M, N4 M. Later batches: Submit/Fight endgames (final waves, Collector), Ferry map point.
