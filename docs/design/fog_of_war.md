> Superseded by docs/gdd/ (2026-10-20): current design + status tags live in docs/gdd/README.md; this file is kept for history and worker breakdowns.

# Design note: fog of war? (Fable design lead, 2026-10-20)

Question: should "Sentence Ended" have fog of war as a gameplay constraint? Short answer: **no terrain
fog; a small, sim-side "creature haze" (option D-lite) is worth one S/M wave, flag off by default.**
Everything below is measured against the pillars (mining safe / refining dangerous; legible on a phone;
deterministic, bot-measurable) and against what the code already does.

## 1. What neighbours do (checked live 2026-10-20 where a source was found)
- **RimWorld**: no line-of-sight fog. Only a `FogGrid`: mountain interiors / ancient dangers are hidden until
  a pawn opens them (modders reference the fog+roof grids; "Real Fog of War" is a mod).
- **Factorio**: chart memory. Radar/player charts chunks; a chunk stays live for 10 s, then freezes to its
  last image ("fog"), last vehicle positions stay drawn; chart updates are throttled to 2 chunks/tick (wiki).
- **Against the Storm**: glades = forest under fog; you only learn what is inside by cutting trees; three
  danger tiers; opening one is a timed decision (TechRaptor guide, Steam threads).
- **Oxygen Not Included**: unrevealed tiles (dig or stand near to reveal, some behind doors); fog is not
  recomputed every slice, only a radius around dupes (Klei forum reading of the code).
- **Dwarf Fortress**: hidden underground until dug (classic unrevealed-rock model). From memory.
- **They Are Billions / XCOM**: classic RTS/tactics fog, units reveal, enemies invisible outside sight;
  ambushes are the point. From memory (no primary source in this session). **Songs of Syx / Frostpunk**: the
  settlement is fully visible; exploration lives on the world map (scouts). From memory.
Pattern: colony sims hide *content* (what is in the rock / glade), RTS hide *enemies*. Nobody phone-first
hides both.

## 2. Options, twisted to our pillars
A) **None** (today). Information already flows through forms: forecast ticker, scent ticker, 200-tick wave
   warning with an origin arrow (`wave_incoming`), `scout_sighting`, district lockdown radius 36.
B) **Survey fog** (content hidden): the Warden hands you a survey of the landing site only; unsurveyed cells
   show ground but no deposits/nodes/nests; surveyed by walking inmates (r 8) or a Survey Mast (r 20,
   power). Twist: unsurveyed land is a form ("SURVEY PENDING"), surveying a nest files a sighting.
C) **Live line-of-sight fog** (enemies hidden): inmates/turrets/lamps are eyes; creatures invisible outside.
   Twist: contamination haze shrinks sight.
D) **Creature haze (hybrid-lite)**: terrain always visible; creatures outside *sensor* coverage (inmates r 6,
   turrets r 6, Watchtower r 16, lamps at night later) are drawn as drifting scent blobs at their last
   known cell (Factorio-style memory), not sprites. Twist: haze radius is `r * (1 - haze_k * contamination
   fraction)` — the dirtier you refine, the blinder you are (pillar 1, quoted in the hint: "Haze: sight -40%").
   The wave-warning arrow, lockdown and dormancy stay fully visible (they are forms, not sight).

## 3. Gameplay weighing
| | adds | takes away | verdict |
|---|---|---|---|
| A | nothing new; all info legible | no discovery beat | fine today |
| B | early pacing (find ore), Survey Mast as a decision, "glade" moments at nests | **map is 99% open ground**: at 250x250 only 0.8% rock, 2.5% at 128 (16 clusters regardless of size, probe 2026-10-20); nothing to discover but distance; bots and belts plan from `node_cells()` and would need surveying; expeditions/outposts already own "new land" | no, unless the generator grows caves/ruins |
| C | ambush tension | breaks pillar 2: phone shows ~70x40 cells at zoom 1, fog hides again inside that; contradicts the warning arrow / scout_sighting / lockdown radius that we just made legible; XCOM frustration without XCOM controls | no |
| D | a reason to build eyes (Watchtower, lamps), a *visible* price of pollution, "unseen hit" letters, ghost blobs read as the lore ("they smell it before you see them") | some readability on 64 maps where the whole map is on screen; needs blob art; one more ticker line | yes, small, flag off |
Interactions (D): raid objectives/lockdown unchanged (sim never reads fog). `scout_sighting` becomes the
free reveal (all creatures visible for a day). Dormant nests are drawn as known. Expedition outposts get
their own fog array (per map). `tools/factory_bot.gd` only reads `wave_index` for turret count, so it keeps
playing; it should still switch to `sim.fog.known_enemies()` so bot numbers mean "what a player could know".
Determinism: fog lives in `sim/` (PackedByteArray, tick-driven, no RNG) so quests, bot and tests can read
it; phase 1 is **information-only** (no AI reads it) => goldens stay byte-identical even with the flag on.

## 4. Performance (250x250 = 62,500 cells; desktop numbers, web ~3x)
Baselines today: sim 1.56 ms/tick with 300 enemies (threats 1.47), total budget 4 / p95 10; static memory
87 MB at 250 (lazy chunks); units are MultiMesh billboards 0.6-0.9 ms/frame; ground chunks already
camera-culled (`_update_view_rect`), so the renderer never draws the whole 250 map anyway.
- **Sim, option D (radius stamp, no LoS)**: sources = 4-30 inmates + 10-50 turrets/towers; disc r 6-8 =
  113-201 cells; full recompute = ~8k byte writes ≈ 0.6-1.0 ms in GDScript. Run it every 10 ticks (same
  cadence as `threat.json recompute_ticks`) => **0.06-0.1 ms/tick** (web 0.2-0.3). Incremental variant
  (re-stamp only sources whose cell changed, clear via native `fill(0)` + re-stamp) ≈ 0.05 ms/tick.
  Enemy visibility test = one `PackedByteArray` read per enemy: 300 x ≈ 0.02 ms. Never loop 62.5k cells in
  GDScript per tick (≈ 5 ms): write explored and visible in the same stamp.
- **Sim, option C (shadowcasting LoS)**: 3-5x the stamp cost, 0.3-0.5 ms/tick at 10-tick cadence; occluders
  would be walls/buildings only (rock is 0.8%). Not worth it.
- **Sim, option B**: stamp once per moved inmate (explored only), ≈ 0.02 ms/tick; plus `node_cells()` filter.
- **Memory**: visible 62.5 KB + explored 62.5 KB + last-seen dict (300 x ~40 B) per map; view image L8
  62.5 KB (RGBA 250 KB). Total < 0.5 MB per map vs 87 MB today: irrelevant.
- **View**: one map-sized L8 `ImageTexture` updated with `update()` when the sim flags dirty (2/s at 3x,
  <0.3 ms), sampled by the ground material or one translucent quad over the ground plane (+1 draw call) —
  the exact pattern `update_field_texture()` already uses for contamination. Hidden enemies are skipped in
  `UnitLayer.push`: at 300 enemies saves ≤ 0.3 ms/frame, blobs cost about the same back. Ground chunks /
  rock blocks: no change (already culled by camera).
- **Net**: fog **does not save** phone time. The big-battle cost is jobs + movement + combat in the sim, and
  hidden enemies still move. Expect +0.1-0.3 ms/tick web and ±0 ms/frame. Acceptable; needs a bench:
  `tools/perf_bench --fog=1` and a `perf_budget.json` entry `fog {avg 0.15, p95 0.5}`.
- **Web single-thread**: no threads needed; keep the stamp inside `ThreatSystem` tick slot or its own
  system after threats; never allocate per tick (preallocate discs as `PackedInt32Array` offsets per radius).

## 5. Recommendation
**No** to terrain/LoS fog (A over B and C). **Yes, conditional** to D "creature haze" as a one-wave,
flag-off feature (`data/fog.json enabled=false`), cost **M** (S sim, S view, S data/tools), because it is
the only variant that makes refining *cost sight* (pillar 1) without hiding the forms we rely on (pillar 2).
Re-open B only if a future map batch adds caves/ruins/nest chambers worth surveying (then B rides on the
same `FogSystem` arrays: `explored` is already there).

Worker breakdown (one wave, disjoint files, flags default off, tests + bot numbers to accept):
- **W1 sim**: `sim/fog/fog_system.gd` (RefCounted: `visible`, `explored` PackedByteArray, `last_seen`
  Dictionary, `recompute_every`, `sense_radius(source)` with haze shrink, `is_visible(cell)`,
  `known_enemies()`), `data/fog.json`, `Simulation` region FG (tick after threats), `tests/test_fog.gd`.
  Accept: same seed => identical arrays; enemy 20 cells from any source is unknown; contamination 0.5 shrinks
  radius by `haze_k`; recompute ≤ 1 ms per call at 250 with 60 sources; goldens byte-identical with flag on.
- **W2 view**: `view/fog_layer.gd` (L8 texture + quad in `WorldView3D` region FG), ghost blobs for
  `last_seen` enemies, `UnitLayer` skip of hidden enemies, Hud ticker "Haze: sight -N%" region FG.
  Accept: screenshot at 844x390 with fog on; `web_smoke.py` PASS; unit script ≤ today's ms/frame.
- **W3 data + tools**: `buildings.json` `sense_radius` (turret 6, new `watchtower` 16, 1x1, 6 plate),
  `balance.json "fog"` colonist radius, `events.json scout_sighting` adds `reveal_days: 1`,
  `tools/factory_bot.gd` region FG (`known_enemies()`), `factory_eval_summary.py` column `unseen_hits`
  (inmate damage from an enemy not visible that tick, ledger `hit:unseen`).
  Accept: `factory_eval --days=60` unchanged within noise (alive>=8 ≥ 9/10); `unseen_hits` printed.
- **W4 bench**: `tools/perf_bench` `--fog=1`, `perf_budget.json fog` entry, `mem_probe` prints fog bytes,
  `test_perf_budget` row. Accept: fog avg ≤ 0.15 ms/tick desktop, p95 ≤ 0.5, memory delta < 1 MB.
Merge order W4 -> W1 -> W3 -> W2. DECISIONS entry: "creature haze, info-only, flag off (decided without
owner, review)". Reversible: `fog.enabled=false` restores today's game exactly.

## 6. Owner questions
1. Do you want *content* hidden at all (ore, nests, ruins — needs a richer map generator first), or only
   creatures in haze? (This note assumes creatures only.)
2. Should the wave-warning arrow and lockdown ring stay visible under haze? (We say yes: they are forms.)
3. Watchtower: passive powered sensor, or needs an inmate standing in it (one more job)?
4. Default on for new games once benched, or keep it a Next Sentence / difficulty option?
