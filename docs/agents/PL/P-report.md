# PL report: plates/parts/audit (audit tier 2 target MET; P1/P3/launch NOT)
Eval (factory_eval 10 seeds/60 d, standard): before 0/10 audit, 6/10 alive; after 7/10 audit (d44-55), 10/10 alive. Noisy: equivalent builds gave 5-7/10. P1 0/10, P3 0/10, launch 0/10.
## Root causes (per-day trace: tools/pl_trace.gd --seed=N --cap=35)
1. EVERY recipe batch polluted (+0.7): make_parts/make_plate/hand_plate drove pollution to 70-100% (planet_dead, smelters capped). Fix: only recipes with a contaminating output pollute (contamination_system.gd).
2. Smelting (waste-making) was blocked forever by the taint cap -> 0 ingots. Recipe fields cap_margin 30 and contam_mult 0.4 on smelt_iron/copper.
3. Tutorial stockpile is 2x2 = 4 stacks: ore, ingots, plates, coal filled it, miners/smelters stalled, haulers idled. Bot grows it to 6x4.
4. Debt payments drained refined to ~3, so filters/assembly essence was never affordable (assembly d27 -> d16). Bot reserves research essence.
5. Bot built one blueprint at a time (8-10 d/step), a duplicate refinery, burned node reservations on failed lines, hung on unplaceable steps, construction priority below mining. Fixed in tools/factory_bot.gd (max_pending 3, skip after 60 fails).
6. make_parts ran unbounded (59-81 parts, 10 needed) and ate all plates: recipe field stock_cap {parts: 25}; assembler input_capacity 20 -> 8 (plates were hoarded in its input, repairs found none).
7. Smelter stands beside its miner (long belts kept failing; colonists haul ingots); 4 compactors right after the refinery; bot taint cap 35 (50 gave 3/10).
## Rejected
PLAN reorder (terminal/lines/power earlier): 3-5/10, more deaths. Cap 20: worse survival. Cap 50: 3/10.
## Suite
782 passed 0 failed x2 (no golden regen needed), kx pillar d21: baseline 7.2 / throttle 4.2 / mining 4.0 (gap 3.0 holds), web_smoke PASS.
## Next bottlenecks
- Audit lands d44-55; P1 needs 60 plates + 20 parts more (one iron line ~1 plate/day): need 2+ iron and 2 copper lines and power (unpowered machines run at 50%) by ~d25; seeds 4/9 get no copper line, seed 6 no iron.
- Miners sit at condition 0 for many days: repair needs 1 plate and plates are scarce -> consider plate-free miner repair.
- Use >=10 seeds; +-2 seeds chaos between builds.
Files: sim/buildings/building_system.gd, sim/contamination/contamination_system.gd, data/{recipes,buildings}.json, tools/{factory_bot,pl_trace}.gd.
