# Drafting, squads, abilities, turrets

## Drafting `[BUILT]` — `sim/jobs/draft_job.gd`, `fight_job.gd`, `retreat_job.gd`; commands `set_drafted`, `order_move`, `order_attack`
Single-inmate control stays (owner 2026-10-18: both squads and direct drafting). Undrafted inmates fight
back within `fight_back_range` 1.5 and flee below `flee_hp_fraction` 0.35 (traits shift the threshold).

## Squads "Wardens of the Line" `[BUILT]` — `sim/squads/`, `data/roles.json`, `data/weapons.json abilities`, `view/panels/squad_bar.gd`, `view/ability_radial.gd`
- Max 4 per squad, roles Bulwark (tank: dmg taken x0.4, threat x2, shiv), Lancer (dps), Medic (support);
  role affinity from skills + traits suggests the role. Commands `form_squad`, `disband_squad`,
  `squad_hold` (formation around an anchor), `squad_focus`, `squad_shakedown` (contraband).
- Abilities (`use_ability`, essence cost 1, contamination puff on the user's cell, noise burst x3 threat):
  **taunt** (Bulwark: threat x4 r 6 for 150 t), **volley** (Lancer: 3 shots x2.5), **stabilise** (Medic r 5).
  Fighting dirty vs clean-and-slow is the prison-planet twist (scout combat_system.md #6-7).
- Telegraphed strikes (`enemies.json telegraph`): brute slam aoe, spitter line, burrower eruption; red
  tile/ring wind-up; dodge by position, not by a roll.
- Injury bands Fit / Wounded / Down + bleed-out timer; rescue job; Medic stabilises in range.
- Militia rally (`rules.json militia_rally`, `sim/squads/militia.gd`): unassigned inmates run to the
  nearest banner on alarm as weak militia.
- QA (25 d x 5 seeds): squads cut total deaths -33 %, per wave faced -53 %, per repelled wave -11 %
  (target 30 % not met). Bot: forms no squads (uses turrets + equip).

## Turrets `[BUILT]` — `data/buildings.json turret`, `sim/combat/supply_turret_job.gd`, `data/ammo.json`
Cost 10 refined essence (D17: defence tied to refining). Buffer of `essence_rounds` (capacity, refill
below, per shot), supply job hauls ammo; `turret_target_mode` rule (nearest / threatening / weakest);
wear per shot, repair; `raid_engineer` rule sends one engineer out to fix turrets during a wave. Heavy
turret / ammo-fed tiers from the E9 contract `[IDEA]` (not built). Fortification: walls (sapper-only
targets), doors.

## Shelter and alarm `[BUILT]`
HQ capsule is the shelter and the loss condition (`hq_destroyed`, D9); `mine_hut` local shelter;
`evacuate_low_hq` rule abandons a shelter below 50 % hp; shelter ration feeds hidden inmates.

## Wave rewards and loot
Creature loot (`enemies.json loot`, rarity x (1 + 3 x pollution_frac), ilvl by day, none before day 6) and a
35 % armour reward on a repelled wave (`gear.json _wave_reward`) — see [06-items-gear/crafting-loot.md](../06-items-gear/crafting-loot.md).

## Not built / ideas
- Creature behaviour tags `provoke_at` (passive species until a contamination threshold) `[IDEA]`.
- Pre-wave scouting report panel beyond `scout_sighting` `[IDEA]`; time slow while a radial is open `[IDEA]`.
- Bait build category with a ghost range ring `[IDEA]` (decoys exist as plain buildings).
