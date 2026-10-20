# Colonists, needs, jobs, health

## Colonist model `[BUILT]` — `sim/colonists/colonist.gd`, `colonist_system.gd`, `generator.gd`, `colonist_record.gd`
Start 4 inmates (1 engineer with a rifle), cap 8 (`data/arrivals.json`); arrivals by storyteller events
(wanderer, transport drop, pod crash, new_prisoners) with a pick-1-of-N choice dialog. Generated: name,
nickname, backstory, rap sheet (`data/names.json`), block (society), skills L1-4 with passions, up to 2
traits (25 % none), start gear (shiv; engineers rifle). Records: kills/ore/repairs/downs -> earned
nicknames and commendations (flavor pass). Death is permanent (D22).

## Needs `[BUILT]` — `sim/needs/`, `data/needs.json`, `data/time.json`
Food and rest 0..1 with thresholds; eat (`raw_food`/`meal`, stove cooks), sleep (bed > floor), day/night
clock (600 ticks/day, night 20-5 h, night daylight 0.35). **Shelter ration** (SR): hidden/alarmed/downed/
sick colonists eat from stock so static colonies no longer starve under alarm. Starvation damages.
Farming: growing zone + `tuber` plant (sow/harvest jobs, mutation field lowers growth/yield).

## Jobs `[BUILT]` — `sim/jobs/job_system.gd` + `*_job.gd`, `givers/`, `data/jobs.json`, `data/work.json`
Work-giver model (D6): an idle colonist asks givers in priority order, nearest candidate wins, string-key
reservations. 13 work types with per-colonist priorities 0-4 (`set_work_priority`, Work panel):
researching, doctoring, repair, operating, hauling, cooking, growing, construction, mining, crafting,
cleanup, patrol, training. Flee overrides everything on alarm / in a lockdown radius. Special jobs:
deliver (blueprints), calibrate (chips), detail (petition waiver), debt (pay at terminal), rescue/tend/
feed_patient (doctor), draft/fight/retreat (combat), supply_turret (ammo), scrub (cleanup).
Idle work (`data/idle_work.json`): cleanup r 6 (contamination per scrub, illness chance), patrol (auto
route, detects creatures early, XP), training at the `training_dummy` (daily XP cap).
Known: idle ~30 % in peaceful games; haul priorities are sensitive (HM pass reverted).

## Construction `[BUILT]` — `sim/buildings/blueprint.gd`, `build_job.gd`, `deliver_job.gd`
Blueprint -> deliver materials -> build work; several blueprints at once; may use loose ore; `deconstruct`
refunds 50 %. Walls/doors; buildings walkable except walls (D8).

## Health `[BUILT]` — `sim/health/`, `data/health.json`
Four parts (head/torso/arms/legs), injury kinds (cut, bruise, bite, bullet, burn, illness, starvation),
bleeding, pain -> consciousness/moving; player-facing bands **Fit / Wounded / Down** with a bleed-out timer
(combat batch C). Doctor: rescue to bed, tend (quality by medicine skill), feed patients; infection roll;
illnesses fever/infection/toxic_fallout. Downed and rescued -> trait Hardened may be acquired.
Design rule (scout): no limb loss, prosthetics or per-part infection chains.

## Expeditions crews
Colonists can leave on an expedition party (`dispatch_party`/`receive_party`) carrying debt collateral;
see [09-world/expeditions-ecology.md](../09-world/expeditions-ecology.md).

## Not built
- Carry capacity by weight (`balance.colonist.carry_capacity` exists; trait `carry` read) — fine.
- Perishable food, hospital rooms, room bonuses `[IDEA]` (scout inmates.md ONI note: one bonus per room type).
