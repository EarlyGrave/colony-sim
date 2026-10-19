# YX report: reconcile (targets NOT reached; honest state)
Result: real factory_bot still gets 0/5 audit2, 0 P1-P4, 0 parts, 0 launch in 60 d. Suite 777 passed x2, web_smoke PASS, goldens regenerated once.
Why Y3 looked good then bad: (a) ore 12-14k = belt-fed essence miners (60-120 ore/day each, buffer 20) running unblocked once the colony lives; consumption stays ~1000-1500, so ore is NOT the limit when lines work. (b) seeds 2/3 "died regardless of HQ hp" because HP is not the killer: colonists ESCAPE (debt despair, died=0, alive=0 -> "colonists_dead") or the planet dies (pollution 100%).
Bottlenecks found (bot + sim), all fixed unless noted:
1. Smelter wedge (sim): station recipe choice took refine_essence first; when capped, a smelter holding iron+essence never switched to smelting. Now picks the first recipe that can run AND may_operate.
2. Cap (sim): `refine_cap` stopped EVERY machine incl. workbench hand_plate/assembler -> no plates -> no repairs -> deadlock. Now only waste-making recipes are gated (tests/test_yx_cap.gd).
3. Map (sim): seeds 2,3,5 had NO copper (parts impossible); Y1 nitrogen also ate the last iron blob (seed 1). guaranteed_nodes now copper 1, iron 1, nitrogen 2; the last blob of a resource and the last 2 essence blobs are never converted.
4. Bot: froze forever if the refinery was destroyed (rebuild added); repair/operating work priority defaulted to 3 and starved behind hauling/building (now 1); the 45-plate hammer bill starts only after the generator exists (early ore goes to miners/smelters).
5. Data (smallest set; Y3 values halved or dropped): refined/batch 3->6 (waste stays 4); smelt 4 ore -> 2 ingots + 1 waste (was 2 -> 1 + 1); early costs miner 25->15, smelter 30->20, refinery 20->15, workbench 15->10, assembler 30->20, storage_in 10->5; wear miner 6->2, smelter/refinery 12->6; turret 10->7 refined; threat first_wave_delay 2.8->3.5, base_strength 1.5->1.2, per_wave 0.9->0.7; debt despair_per_day 16->10. Dropped: HQ x5 hp, colonist hp, mining x2, refine work_ticks, per_wealth. apply_y3, the `y3` block and test_y3_economy are removed; tools take `--ov=` / `--ovf=` JSON overrides (tools only).
Rejected: miner output_capacity 60 (broke the test_automation_flow ratio, no bot gain); taint-exempt smelting (waste items bleed 0.02 pollution/unit/day, planet_dead at d32).
## Bot table, 60 d, standard, seeds 1-5 (end / alive / ore produced / refined produced / plates made)
before (Y3 report, merged HEAD): survived/8/1540/255/16 ; colonists_dead/0/969/153/8 ; hq_destroyed/6/1558/186/4 ; colonists_dead/0/1180/153/9 ; hq_destroyed/0/721/96/7
after (this branch): colonists_dead/0/1395/420/37 ; planet_dead/6/1360/402/54 ; colonists_dead/0/1533/420/65 ; colonists_dead/0/1468/378/89 ; hq_destroyed/6/804/334/9
audit2 / P1-P4 / parts / launch: none on any seed, before or after (parts 0/24; blocker "parts -10, plate -40").
Per change (alive at d60, 5 seeds): refined 6 alone 2,4,2,1,0 (refined 160-420, was 96-255); + early costs/wear/threat soften + plate bill after generator: 3-5 of 5 alive; + copper/iron guarantee and refinery rebuild: seed 5 unfreezes; + cap fix: plates made 37-89 (was 8-17) but pollution then kills one seed (planet_dead).
## Pillar table (kx, d21, standard_term, 5 seeds)
baseline 7.0 waves, throttle 4.2, mining 4.0, deaths 0 -> gap 2.8 (>= 2 holds). Note: merged HEAD measured 5.8 / 4.4 (gap 1.4) with this tool; the earlier 6.4 / 4.2 does not reproduce.
## Next bottleneck, precisely
- Parts never appear: plates (50-89 made) are eaten by repairs/fuel cells and the assembler/smelters sit broken until a plate is free; the bot reaches its assembler only at d29-45. Needs a plate reserve for repairs and an assembler chain by ~d25.
- Waste: unburned waste items bleed 0.02 pollution per unit per day; ~270 waste from 400 refined kills the planet or forces the 50% cap. The bot must burn waste (ash beacon) or refine less. Debt (30-90 refined x 8 colonists, due in 12 d) cannot be paid from <= 420 refined, so escapes end runs (colonists_dead with died=0).
- Run-to-run chaos from raids is high: use more than 5 seeds before further tuning.
Files: data/{recipes,buildings,balance,biomes,debt}.json, sim/buildings/building_system.gd, sim/core/defs.gd, tools/{factory_bot,factory_bot_report,kx_pillar_table,yx_dump,yx_nodes}.gd, tests/{test_y1_nitrogen,test_yx_cap,test_machines,test_chips,...}.gd.
