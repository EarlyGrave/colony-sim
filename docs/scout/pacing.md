# Scout: difficulty presets and threat pacing (+ expedition value)
Problem: waves are paced by pollution only, so presets (wave_strength_mult 0.6/1.0/1.15) change
squad size but not wave COUNT or cadence. Harder preset = same number of waves, more deaths.

## Sources
- RimWorld (verified live, rimworldwiki Storyteller pages): storyteller = pacing curve, difficulty =
  separate scale; inputs are wealth, colonist count, time since last big event. Cassandra = build/release,
  Phoebe = long calm after a hit. Idea: preset changes the RHYTHM (gap + calm), not just strength.
- Factorio (verified live, forums/Steam): evolution = time + pollution + spawner kills, summed;
  difficulty tunes each coefficient separately. Idea: several independent clocks, preset scales each.
- Mindustry / They Are Billions / Frostpunk (from memory, not re-verified): fixed wave timer with a
  visible countdown (Mindustry); one big scripted final assault + "doom clock" (TAB); scheduled
  harsh-law/cold snaps (Frostpunk). Idea: floor of pressure that pollution cannot buy out.

## 1. Three-clock wave pacing (our version) - cost M
Wave points = max(pollution_pts, floor_pts) per wave; wave count driven by three clocks, all in balance.json:
- Pollution clock (today): contamination thresholds -> "the planet reacts".
- Sentence clock: wardens' audit every N days (preset: short 6d / standard 4d / hard 3d) spawns a
  small "audit patrol" independent of pollution. Even a clean colony meets it (floor), so
  hard preset = more waves, not only bigger ones.
- Essence clock: stockpiled essence_ore / refined essence attracts creatures (hoard = wealth in RimWorld).
  Points += k * essence_held above a free allowance. Rich colonies get visited.
Preset table: wave_interval_days, floor_pts_per_day, essence_k, calm_after_hit_days (Phoebe style).
Why fits: pillar "mining safe, refining dangerous" stays (pollution dominates), but presets bite.
Deterministic: all via sim.rng and tick counts; goldens regenerate once.

## 2. Calm-after-hit and countdown UI - cost S
After a wave that kills a colonist or breaks a link, storyteller grants calm_after_hit_days
(short 2x, standard 1x, hard 0.4x). Hud shows "Next audit in Nd" (Mindustry countdown) so hard
is fair; pollution waves stay unannounced but have the existing forecast.

## 3. Tribute / debt scaling per preset - cost S
Hard presets raise Parole Review demands slightly (debt +, waves-repelled +1) so the waves-repelled
ramp finally differs by preset (open item in PROGRESS). Short stay: -1 wave required.

## 4. Expeditions worth sending (outposts, map 2+) - lightweight
a) Outpost = pollution sink + wave decoy (cost S): each clean outpost adds a "sentence clock" audit
   target elsewhere: audit patrols split between maps (hard: patrol hits the outpost first), so an
   outpost buys the home map one skipped audit. Reuses analytic autopilot.
b) Essence vein tax (cost S): outposts have richer biome ores (cinder/prism/bog_resin already exist)
   AND essence stockpile there does NOT count for essence clock until recalled. Safe vault = reason to go.
c) Parole credit (cost S): Review needs "1 outpost holding N days" on standard/hard, free on short.
   Turns expedition into a quest step, not a sidegrade.
d) Cargo run bonus (cost M): party returning with cargo reduces pollution by hand-cleaning
   (clean-outpost bonus exists; extend to "ash scrubbed" = -X contamination per day away).
Recommend order: 2 -> 1 (floor+audit only, essence clock behind flag) -> 3 -> 4c -> 4a.

## Acceptance / tuning
- tools/combat_model.gd table: waves by day 21 per preset, targets ~ short 4, standard 6, hard 8 (bot numbers
  before merge, per rule 8); clean-colony run still gets >= 1 audit by d10 on hard.
- Seed 3 planet_dead d21 must not worsen on standard.
