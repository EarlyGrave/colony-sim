# The four endings

Canon (owner notes): Submit = bad, Fight = good, Escape = grey/economic, "more win variants (?)". Rule:
before Q14 all paths are one game; after it each path has its own mid-game pressure, endgame structure and
epilogue. Ending screen `[BUILT]` (EV/F2d): `view/panels/win_screen.gd`, `ending_panel.gd` show the won
path's epilogue + r4 echo lines; Continue keeps playing (S batch decision).

## E1 Submit (bad) `[BUILT]` — `sim/shuttle/shuttle_system.gd`, `data/shuttle.json`
Petitions I-IV = the jailers' Compliance Deal; P4 unlocks the Extraction Platform (`release_gantry`);
24 release parts (2 plate + 1 refined + 1 fuel cell each), seats per colonist aboard (`set_manifest`
leaves people behind as the Continue colony), 2-day countdown siege x (1 + pollution_frac) "madness peak".
Win: "Sentence Ended", Submit epilogue ("Case closed. Cause: silence."), planet burned in text,
Next Sentence "New Names" (Dossier only, renamed, debt 0). Not built: 2 drone-shuttles of goods pickup
during the siege `[IDEA]`. Detail: [02-economy/petition-shuttle.md](../02-economy/petition-shuttle.md).
Bot: launch 0-1/10 at 60 d (plates/petition pace), sieges won 4/4 when reached (scripted supply).

## E2 Fight (good) `[BUILT]` (EN3/EN4/F2b/F2e) — `sim/endings/fight_escape.gd`, `metro_track.gd`, `endings.json fight`
Refuse the shuttle -> defiance -> drone raids every 3 d, escalating 25 %; at defiance 60 the Collector
drops a `collector_relay` (its own `relay_hp`, burns 400/day while the Uplink holds; repairs cannot undo
the burn). Build the **Uplink Array** (tier 3, unique, power factor >= 0.5), then `start_assault`: 3 scripted
raids in 2 days (x1.0 / x1.5 / x2.0); win -> `ending_won("fight")`, Collector gone, drops/raids stop,
free-colony sandbox, legacy x2, no NG+ carry. Epilogue "Collector offline. Quota: unresolved."
Numbers (fight bot, 90 d): Uplink 1/5, relay 1/5, **Collector win 0/5** — the fight colony starves of
refined and turrets. Owner question 4 (shuttle landing on Fight).

## E3 Escape (grey) `[BUILT]` (EN3/F4a) — `fight_escape.gd`, `sim/society/contraband.gd`, `endings.json escape`
Covert sales (credits + suspicion) -> after 3 sales `contact_bandits` (PoNR) -> pay `bandit_fee` 60 credits
(`pay_bandit_fee`) -> `start_extraction`: colonists walk to a world-map point (radius 4) under a 1-day
countdown with a pursuit wave x1.5; `ending_won("escape")` when enough reach it. Legacy 25 per extracted
colonist + 0.5 per credit (cap 40). NG+ "New Sector": 25 % debt + 10 % credits carried. Epilogue
"Transfer complete. Destination: not on file." Bot (sell every 6 d, 90 d): won 4/10, suspicion peak <= 84.
Design doc differences: "walk to a campaign sling target" became a point near the map edge; suspicion lives
in the contraband module, not ContractSystem; the Ferry is one buyer (several buyers `[IDEA]`).

## E4 Remission (proposed 4th, "stay") `[BUILT, flag OFF: endings.json remission.enabled]` — `sim/endings/remission.gd`
The monsters were people: `cure` (2 refined + 1 bog_resin, workbench) fed to powered **Decontamination
Pylons** (`decon_pylon`, power factor >= 0.5) lowers contamination 3 per cure; contamination below 10 % of max
for 15 days in a row while the quota is still met -> `ending_won("remission")`. Creatures calm; "remitted"
inmates joining as a colonist source `[PLANNED]`; entry quest Q17 `[PLANNED]`. The only ending that rewards
refining less. Epilogue "Form 0-R approved. By nobody." Carry = Escape without credits.
Blocked on owner question 1: Remission vs **Broadcast** (ship the lab report to the capital; political
win; nothing built). F4c acceptance when tried: bot `path=remission` reaches < 0.1 for 15 d on >= 2/10 at 90 d.

## Loss conditions `[BUILT]`
`hq_destroyed` (capsule lost), `colonists_dead`, `planet_dead` (contamination 100). Game-over modal with
flavour lines; legacy is still awarded (`min_days_for_award` 1).

## Cut list (GDD §14) if time is short
Remission, skill branches (built anyway), affix UI (built). Never cut pillar measurement.
