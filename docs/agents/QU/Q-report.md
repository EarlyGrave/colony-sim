# QU quest sheet report
- view/quest_sheet.gd rewritten: ModalStyle panel, scrollable (0.66 viewport height), per quest: data title | "Beat n/m" | "Warden: <beat text>";
  option buttons >= 64 px with label + hint line; disabled options show "Needs 30 plate" from `requires`. Header collapses; shows "N to answer".
- Notification: QuestSheet.choice_posted -> HUD pushes a "warn" toast "Dispatch: <title> awaits your answer" (region QU in hud.gd).
- Data: added `title` to q1/q2/q6 and per-option `hint` (data/quests_q*.json; files reformatted by the JSON dump).
- Q1/Q2 offers render too (hints looked up from beats.offer.options / top-level options).
- BUG FOUND+FIXED in data: q6_auditor had no "start" key, QuestLog.start defaulted to beat "start" -> quest finished instantly and never offered.
  Added "start":"announce"; also added engine keys `n` (items) and `pct` (debt_pct) beside the old `count`/`value`. Q6 now really runs (behavior change in Q6 only; goldens unchanged, suite green).
- Announce beat has no options by design (then -> inspect after 1 day); the sheet shows its text + "Beat 1/2".
- tools/screenshot.gd: --panel=quest | quest_announce | quest_q1 | quest_q2. Shots (use --w=2532 --h=1170 --scale=2.55) in docs/agents/QU/.
- Tests: tests/test_quest_sheet.gd (4). Full suite 818 passed 0 failed; web_smoke PASS; world-visible >= 55% unaffected (sheet hidden without quests).
