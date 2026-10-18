# Scout: combat system (prison planet identity)
Verified live: Into the Breach shows enemy intent each turn (informed choices); Bad North = max 4 units, ~90% positioning, time slows on formation select, one-screen map; ONI: dupes fight only via an Attack errand/tool, most critters are passive unless attacked. Everything else is [memory].
Current state: drafting + melee/ranged (data/weapons.json), 4 body parts in data/health.json, threat model v2 (data/threat.json), essence_rounds ammo. Goal: simplify the player-facing layer, add roles + telegraphs.

## Mechanics (10-14)
1. **Wardens of the Line (squad roles)** - MMO tank/healer/dps + Bad North squads. Drafted inmates join a Squad (max 4) with one role each: Bulwark (tank), Lancer (dps), Medic (support). Role = gear + auto-behaviour, not micro. Cost M. Data: `data/squads.json` {roles:{bulwark:{threat_mult,taunt_radius,dmg_taken_mult,weapon},lancer:{...},medic:{heal_rate,range}}, max_size}.
2. **Taunt (Hold the Line)** - MMO taunt + our threat tanking. Bulwark ability: for N ticks his `threat` x`taunt_mult`; creatures in radius retarget him (stick 0.7 applies). Costs essence charge. Cost S (hook into ThreatModel colonist_mod). Data: roles.bulwark.taunt {mult:4, ticks:150, cooldown, essence}.
3. **Phone control in 2-3 taps** - Bad North + Kingdom. Tap squad banner -> tap ground = "Hold here" (squad forms around anchor: Bulwark front, Lancer behind, Medic rear). Tap an enemy = focus fire. Long-press banner = ability radial (taunt/volley/rally). No per-inmate orders. Cost M. Data: squads.json formation offsets.
4. **Telegraphed strikes** - Into the Breach. Every creature wind-ups before a big attack: a red tile/line shows target cell and a shrinking ring for `windup_ticks`. Player answers with one tap: Bulwark taunt/shield-up, move banner, or sound alarm. Cost M. Data: enemies.json `telegraph:{windup_ticks, shape:"cell|line|cone|aoe", dmg_mult}`; brute slam = aoe, spitter = line, burrower = erupts under a marked cell.
5. **Dodge-by-position, not accuracy rolls** - replaces RimWorld per-shot odds: telegraphed hits always land if you stay; no cover %. Cover = real walls/slag blocks blocking line of fire. Cost S. Data: remove hit_base curve for enemies, keep for inmates.
6. **Essence gear (charged)** - our twist on weapon mods. Gear slots take Essence Cells: Lancer "essence volley" (x2 damage burst), Bulwark "slag plate" (damage absorb shield). Each use drops a contamination puff at the user's cell (data-driven) - fighting dirty vs clean-and-slow. Cost M. Data: `abilities` in weapons.json {essence_cost, contam_puff, cooldown}.
7. **Loud guns = attention** - Mindustry/OxygenNotIncluded noise idea: firing already x2 threat; essence abilities add a one-off `burst` (x3, exists in state_mod). Using abilities pulls the next wave target to the squad, so a squad can be a mobile decoy. Cost S (data only).
8. **Three-state injuries** - replace part tables for player view: Fit -> Wounded (slower, -dmg) -> Down (bleeding timer, needs rescue); Down + timer = dies. Keep internal hp pool per inmate (sum of parts hidden). Medic stabilises Down inmates in range; infirmary bed heals. Cost M. Data: health.json `states:{wounded_below:0.6, down_below:0.0, bleedout_ticks}`.
9. **Rescue/carry, not triage** - Down inmates get a green "pickup" ring; any idle inmate auto-carries to bed (existing job system). Zero micro. Cost S.
10. **Inmate sentence combat traits** - prison identity: criminal record gives role affinity (Brawler->Bulwark, Sniper->Lancer, Ex-medic->Medic), shown on portrait. Auto-suggest role on drafting. Cost S. Data: traits.json `role_affinity`.
11. **Decoy placement as defence** - Kingdom Two Crowns indirect defence + They Are Billions turtling. Bait structures (scrap totems, loud generators) get `threat` and cheap hp; squads fight at the bait with turrets nearby. Already in threat v2; add "Bait" build category with ghost range ring. Cost S.
12. **Rally from the wall** - Kingdom-style: unassigned inmates auto-run to the nearest banner when alarm is on, as militia (weak, no role). Flee threshold exists (flee_hp_fraction). Cost S.
13. **Pre-wave scouting report** - Into the Breach foresight: warning panel lists wave composition + approach side + ETA; fed by ForecastModel/ecology. Cost S.
14. **Creature behaviour tags** - ONI passive critters: some species ignore you unless provoked by contamination thresholds ("restless" -> "raiding"); squad can avoid fights by cleaning. Cost M. Data: enemies.json `provoke_at`.

## Phone UI sketch
Bottom bar: [Squad 1][Squad 2] banners (>=64 px) + one ability button per role that lights when ready. Time slows to 0.3x while a radial/telegraph picker is open (Bad North). Telegraphs auto-pause-nudge on first sight only.

## What NOT to copy from RimWorld
- Body-part hit tables, limb loss, prosthetics, per-part infection chains.
- Cover percentage and per-shot accuracy/shooting-skill formula as the main fight driver.
- Mental breaks / mood spirals during combat; recruit/prisoner-conversion loops.
- Manual draft-and-micro every pawn; fire-at-will toggles per pawn; melee dodge/parry stat stacks.
- Raid "points" budget wording and storyteller names (Cassandra-style); our waves stay contamination/ecology-driven.
- Apparel layer/armor-rating stacks; quality-tier pawn gear tables.

## Suggested order
S first: taunt, bait category, forecast panel, affinities. Then squads+banners (M), telegraphs (M), 3-state injuries (M), essence abilities (M).
