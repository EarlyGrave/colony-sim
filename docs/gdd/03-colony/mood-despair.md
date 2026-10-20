# Mood, breaks, despair

## Mood `[BUILT]` — `sim/mood/mood_system.gd`, `mood.gd`, `break_job.gd`, `data/mood.json`
Base 50 + thoughts (data: injured, colonist_died, wave_survived, planet_doomed, slept_on_floor, ate_raw,
left_to_ledger, despair_1/2, riot_witness, letter_home, escape_rumors, inspection_praise, freedman,
block_proud/shamed, leveled_up, fixation_done/failed, clerk_reported, quest_uneasy/cheer, silenced_prayer).
Checked every 30 ticks; below 35 minor break (wander), below 15 extreme break (sabotage a machine), each
50 % chance per check. Traits scale `break_chance`, `mood_base`, `thought_<id>`; quests add `mood` /
`mood_block` verbs. Owner (session 2): basic version only; no stress spirals in combat (scout rule).

## Despair (from the quota) `[BUILT]` — `sim/debt/debt_state.gd`, `data/debt.json`
Separate 0-100 scalar per inmate driven by missed installments (+4/day), relief on payment, decays 10/day.
mid 33 / high 66; break threshold 50 -> riot (damages buildings in r 12 for 200 ticks) or dock escape
(600 ticks walk; caught -> relief 30; gone -> `leave_reward` 15 and 1 legacy point; a colonist whose debt
is paid off stays as a `freedman` with a thought and `stay_work_speed`). Multipliers: block Standing 1.2x..0.9x,
quest `despair_mult` mods (S1 Pay), traits (`despair_mult`), path (Fight: missed installments no longer
count as missed — `[BUILT]` in `debt_system.gd`).
Riots and escapes are the way a colony that stops paying ends; the bot pays installments first.

## Records, nicknames, barks `[BUILT]` (view-only flavour) — `view/flavor_picker.gd`, `data/flavor.json`, `data/names.json`
Kill feed with puns, Warden PA banner, inmate barks (working/fleeing/idle/hungry/low_mood/refining/wave_won),
earned nicknames by stat thresholds (`balance.flavor`), rap sheets, epitaphs, 14 tips, game-over lines.
Flavour never changes balance; the picker is deterministic from sim facts.

## Standing Orders (regulations) `[BUILT, flag OFF: balance.reg_enabled]` — `sim/regulations/`, `data/regulations.json`
At d15 / d30 / d45 the Warden posts a form; pick one of three (2-day timeout): e.g. Shift Policy:
Overtime (refining +25 %, waste +25 %) / Standard / Night Watch (waves -10 %, despair +15 %); Audit Stance
(grease / comply / ...); slot 3. `choose_regulation` command, regulation card UI, 9 PA lines. OFF because
option set 3 dropped the bot to alive 4/10 (F5). Owner question 2.

## Fixation (strange mood) `[BUILT, flag OFF: balance.fixation_enabled]` — `sim/fixation/`, `data/fixation.json`
Once per game (d25+) a crafter L3+ demands 6 plates + 2 refined + a workbench within 3 days; success = a
named legendary masterwork (ilvl 10, 5 bases) with an epilogue line; failure = break and the materials are
lost. Decline is free. OFF: accept-always bot alive 4/10. Owner question 3.

## Known gaps
- `data/mood.json` thresholds were tuned once (RimWorld batch) and not revisited; `Resigned` is the only
  long-despair valve.
- Standing/mood links are mild on purpose (a stronger tuning doubled riots and was rejected).
