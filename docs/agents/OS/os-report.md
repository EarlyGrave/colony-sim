# OS report: ore supply / no-iron maps / seed 9 wipe (acceptance NOT met; one generator fix kept)
Kept: sim/map/map_generator.gd (region OS) - if a guaranteed resource (iron/nitrogen/copper) is absent from the whole map, coal blobs
(never the last one) become donors of last resort. Seed 8 had no iron AND no nitrogen (coal 19 cells ate the far blobs); now iron 7, nitrogen 3.
Maps changed only for seeds 7-10 (node_res only, tiles identical); seeds 1-6 results identical. 10 seeds/60 d: alive>=8 9/10, audit 6,
P1 4, P3 4, plates>=60 on s1/4/5 (3/10), launch 0 (s1,s5,s7 reach "shuttle building", parts 0/24).
Tools: tools/os_diag.gd (per-colonist health/alarm timeline), tools/os_diag2.gd (miner/smelter/power/buffer state); bot knob pg_bot.extra_iron (default 0).

Findings
- Ore wall is HAULING, not mining: at d40 (s3) all essence miners sit at output_capacity 20 (0.1 ore/tick fills it in 1/3 day, carry cap 10).
  The iron miner was broken and unrepaired, far from the hub (iron_ore 40-97 / 60 d, ingots 18-42).
- s9 "sickness" is not disease: raids (alarm d30.5, d34.5) keep all 8 hidden in the shelter; needs._decide blocks eating when hidden/alarm, food hits 0,
  starvation injuries (3 dmg / 50 ticks) stack; a spitter (burn) hit then downs everyone, downed colonists cannot eat, nobody is left to feed them.
  Food stock was 335-408 the whole time. Real sim gap: no food access during long alarms / all-downed colony.

Experiments (10 seeds, 60 d, jobs=3; alive>=8 / P1 / P3 / plates>=60)
- gen fix only (kept): 9/10, 4, 4, 3
- + extra_miners 5 (ov): 7/10, 4, 3 (chaotic)
- + extra_iron 1 (iron line at plan step 6): 8/10, 6, 1 (s2 colonists_dead)
- + starvation clock paused while hidden in alarm (needs_system): 8/10, 4, 3 (s8 hq_destroyed, s9 dead; timelines shift) - reverted
- + miner output_capacity 20->60 (data): 8/10, 6, 2 (s2 dead, s8 hq_destroyed) - reverted; data unchanged so no kx_pillar_table run
Next: (a) feed hidden/downed colonists (shelter ration, or FeedPatient without an able helper); (b) haul priority for miner buffers
(bigger buffers help P1 but hurt survival via raid timing); (c) bot: repair/rebuild the remote iron miner.
