# Research tree and its costs

## Tree `[BUILT]` — `sim/research/research_system.gd`, `tech.gd`, `data/research.json`, `view/panels/research_panel.gd`
23 techs in 4 tiers (0-3). Tier 0/1 free at start (`research.free_tiers` 1) except `conveyance` (the one
paid start tech, B1). Tier 2 needs Audit Delivery tier 2; tier 3 needs petition P3.
| tier | techs |
|---|---|
| 0 | hand_tools, crude_refining, fortification, turret_defense |
| 1 | drilling, conveyance (paid), smelting, storage_ports |
| 2 | assembly, advanced_recipes, filters, decoys_1, expeditions, splitting, smart_logic, electrification |
| 3 | high_throughput, bulk_refining (unlocks dirty fuel), mass_assembly, ai_chips, decoys_2, clean_power, nuclear |
Each tech has `cost` (refined essence, spent when the tech reaches the queue front, exact refund if no
progress) and `waste_mult` (tech raises/lowers refining waste). Commands `set_research`, `queue_research`.

## Three cost kinds (owner answer 2026-10-18) `[BUILT]`
1. Essence for big steps (tech `cost`).
2. Part sets as tier unlocks (Audit Deliveries, Satisfactory-style milestones).
3. Always bench time: `research_bench` operator job, skill 0.5x..1.5x, AI chip may operate it (0.8 speed).
Research is starved in practice by debt-first payments and ~8100 bench ticks for the chain (PL pass).

## Milestones / commendations `[BUILT]` — `data/milestones.json commendations`, meta
participation_ribbon, clean_hands, mass_disappointment, debt_enthusiast, toast_master: dry toasts saved in meta.

## Not built / ideas
- "Tainted insight" (waste above a threshold grants research toward filters/scrubbers) `[IDEA]`
  (`docs/scout/research_expeditions_ecology.md` #3).
- Research-by-expedition (element-locked techs) `[IDEA]`.
