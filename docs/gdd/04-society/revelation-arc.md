# The revelation arc (landing -> truth -> path)

Full text and lines: [docs/story/revelation.md](../../story/revelation.md). Shape: landing -> first pickup ->
first wave (the pillar, felt) -> clues -> the inmates learn the creatures were people -> Lull reveal ->
the Procurator's deal -> path -> endgame -> epilogue. Rule: before Q14 every path is the same game.

## Beats and status
| beat | mechanic | status / where |
|---|---|---|
| Landing letter "Intake", PA "the air is breathable" | start letter | `[BUILT]` tutorial/start texts |
| First wave the night after shipment 1 | `threat.first_wave_gate_days` | `[BUILT, flag OFF: first_wave_gate_days=0]` (broke pacing tests; owner Q10) |
| First wave from the dump side | `threat.spawn_at_pollution_peak` (mutation-field max cell) | `[BUILT, flag OFF]`; needs per-area pollution to read well (owner Q11) |
| C1 Yield (Auditor manifest, "calm units") | Q6 show everything -> `clue_manifest` | `[BUILT]` |
| C2 Handwriting (mimic hums an ID) | Q8 study -> `clue_survey_tag` | `[BUILT]` |
| C3 The slip (PA leaks "LULL") | Q10 respect -> `clue_warden_quota` | `[BUILT]` |
| C4 The buyer ("the calm stuff") | S4b let it ride -> `clue_buyer` | `[BUILT]` (needs contraband on-ramp) |
| C5 The dead return (mimic wears your dead) | Q15 Roll Call -> `clue_our_dead`; `Enemy.name_of_dead`; inspect toast + kill-feed line | `[BUILT]` (F4d/F4f) |
| C6 Lifer's receipt | Q16 -> `clue_receipt` | `[BUILT]` |
| Q14 Three Forms | `clues_held >= 2` + d30; Procurator lands, small print, choose; Standing shifts | `[BUILT]` |
| Q14b Amended Form | change the path once (d+10, 20 refined, -20 Standing) until the PoNR | `[BUILT]` |
| Q17 Reversal (Remission entry) | first `cure` bill + contamination falling 3 d; sets `path_remission` | `[PLANNED]`, blocked on owner question 1 |
| Epilogues (4) + r4 echo lines | `flavor.json epilogue.*`, `epilogue_echo.*`; win screen per path | `[BUILT]` (F2d, F6) |
| 20 Warden PA lines | `flavor.json warden_lines` | `[BUILT]` |
| Fifth loop Warden quota screen | — | `[IDEA]` |

## Design questions still open (from the story writer / RV worker)
- Contamination is one global number; "from the dump side" needs per-area pollution or a dump-zone
  marker. The mutation field already exists per cell — the flag uses its max; the view tints the dump zone (F7).
- Remission is deliberately not a Q14 button (keeps three buttons on a phone); it opens via Q17 later.
- The Submit hint should quote the deal verbatim ("Deliver 3 more pickups. Receive: components, seats,
  new names. Keep: nothing.") — text-only, check `data/quests_q14.json` before the next story pass.
