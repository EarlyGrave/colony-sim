# Scout: threat, tanking, belt raids, AI-chip operators, pollution ecology (batch R3)
Live-checked (WebSearch): Factorio pollution/spawners (wiki.factorio.com/Pollution), They Are Billions noise = hidden per-tile "activity"
(they-are-billions.fandom.com; community says walls far from others make little noise, soldiers are loudest, snipers get priority targeting).
Mindustry, ONI, RimWorld mechanoids, Riftbreaker, Creeper World: search returned nothing useful -> marked [memory]; WoW threat [memory].
Format: Source | OUR version | Why | Cost | Data fields.

## Threat formula (data-driven, proposal)
`score(t) = (base[type] + sum(mod[state]) + pollution_here * k_poll + colonist_noise) * wall_mult / (1 + (dist/d0)^2) * (1 - hidden)`
- Every building/colonist has `threat` = base by type + state mods (working, idle, broken, firing, carrying essence).
- Creature picks argmax score among targets in `sense_radius`; sticky: keeps target while score >= 0.7 * best (hysteresis, no ping-pong).
- WoW-like pull: a new target must beat the current one by `pull_ratio` (1.1 melee / 1.3 ranged) [memory].
- Deterministic: ties broken by id; no randomness except sim.rng spawn jitter. Result cached per region, recomputed every N ticks.
- JSON `data/threat.json`: {"d0":8,"k_poll":0.02,"pull_ratio":1.1,"stick":0.7,"base":{"colonist":2,"belt":1,"smelter":6,"turret":5,"beacon":..},
  "state_mod":{"working":3,"broken":-4,"firing":4},"species_bias":{"chewer":{"belt":2.0},"brute":{"turret":1.5}}}. Building def gets `threat`, `threat_mods`.

## Mechanics (12)
1. **Noise tiles** | They Are Billions activity | OURS "Dread map": each working machine emits dread into a per-region field (separate from pollution; decays 5%/tick-batch). Creatures walk up the gradient. Fit: cheap, readable overlay. M. Fields: `dread_emit`, `dread_decay`.
2. **Threat table + hysteresis** | WoW threat [memory] | OURS: the warden-AI "watches" the loudest asset; creatures fixate. Colonists add threat when carrying essence (loot lure). Fit: uses formula above. M. Fields: pull_ratio, stick.
3. **Beacon of Penance (tank)** | WoW taunt + TD bait | OURS: cheap-to-build, fortified high-base-threat structure. Variants: *Ash Beacon* (threat 20, 300 hp, burns waste to stay lit -> adds small pollution); *Penitent Wall* (threat 8, 800 hp, passive, no cost to run); *Mourning Bell* (burst: x3 threat for 30 s, 2-min cooldown, costs essence = debt). Tank dies -> repair costs ore. Fit: lures waves from belts. M. Fields: `threat`, `hp`, `active_cost`, `cooldown`.
4. **Pollution-fed spawners** | Factorio spawners absorb chunk pollution, spend it on units of cost 200/1000/4000 | OURS: nests per region (R3b) have a `hunger` bank filled by local pollution; spend to muster waves; wave composition = bank size. Clean map = starved nests. Fit: creatures react to SMOKE not wealth. M. Fields: absorb_rate, unit_cost per species.
5. **Rally and launch** | Factorio muster | OURS: creatures gather at a visible rally tile for T ticks -> HUD warning shows direction; players get a decision window (build Beacon, move turret). S. Fields: `rally_ticks`.
6. **Evolution by emission** | Factorio evolution (time, pollution, spawner kills) | OURS: tier shift per ecology region: cumulative local pollution -> mutants; cleanup slowly reverts (hysteresis). S. Fields: `mutation_curve`.
7. **Belt chewing** | Factorio biters hit anything polluting | OURS: chewer species bites belts/inserter-like links: belt `hp`, damaged belt slows then stalls; broken tile shown with a gap. Prefers belts carrying ore/waste (carry-weight threat). M. Fields: `hp`, `bite_dmg`, `stall_at_hp`.
8. **Repair loop** | RimWorld repair / Satisfactory rebuild | OURS: damage creates a Repair job with scrap cost; colonists prioritise per `repair_priority` rule; repair drones (mech 9) only for belts. Wear stays separate from raids. S. Fields: `repair_cost`, `repair_ticks`.
9. **Decay gradient on lines** | Tower defense lane priority (Kingdom Rush "first/strongest/last") | OURS: turret targeting mode rule (nearest / most-threatening / weakest) set via `set_rule`; touch toggle on turret. S. Fields: `target_mode`.
10. **AI-chip operator** | Factorio/ONI automation, Satisfactory robots [memory] | OURS: "Warden Chip" slotted into a bench replaces the colonist AT the bench; costs essence upkeep (+debt), emits threat x2 while working, outputs -20% speed and +waste (it cuts corners). Chips are fragile: a chip in a destroyed/broken bench drops. Colonists stay needed for: hauling, repair, chip slotting/recalibration every N days (skill-gated), mining-hand work, defence. Fit: hand->automation, with price. M-L. Fields: `chip_slots`, `chip_speed`, `chip_waste_mult`, `chip_upkeep`, `calibration_days`.
11. **Mech raiders as late wave** | RimWorld mechanoids [memory] | OURS: warden "Auditor" constructs show up only when essence stockpile is huge (not pollution): counter-pressure against hoarding, targets high-essence containers. L. Fields: `essence_threat_per_unit`.
12. **Scorched calm** | Creeper World: creeper recedes where you build sinks | OURS: Scrubber/Ash Beacon clears dread in radius so the safe zone is visible; combining with Beacon makes a "kill pocket". S. Fields: `dread_clear_radius`.
(Open: Mindustry flyer-vs-ground target rules unverified; skip until checked.)

## Anti-dominance guards
- Tank threat capped: `cap_per_region` so one mega-Beacon cannot hold every wave; tank decoys beyond range are ignored.
- Chips only at benches (not mines); chip colonies raise ecology pressure x1.3 so automation-heavy runs do not exceed baseline survival 1.3x (R3 acceptance).
- Sim stays deterministic: threat cache keyed by tick; creature iteration in id order.

## Suggested order
1) threat.json + formula (M) 2) belt hp/chew/repair (M) 3) Beacon variants (M) 4) nest hunger bank (M) 5) rally warning (S) 6) AI chips (M-L, after R3c).
