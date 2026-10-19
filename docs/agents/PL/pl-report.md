# PL report: why plates stay ~0 (acceptance NOT met; one sim bug fixed)
Branch: worktree of claude/colony-sim-godot-4jftsm. Quick tests 14/14. Goldens untouched. Data unchanged (no pillar-table run needed).

Fix (sim): haul_giver picked ONE consumer per ore stack (nearest). If that was the refinery and ore_reserve gave it 0, the stack went back to
storage and the workbench behind it was never tried. Now the next consumer is tried when it is a workbench (job_system._building_needing skip_id).
Result 10 seeds/60 d: alive>=8 9/10, audit 8/10, P1 4/10, P3 4/10, P4 on s1+s5 (before: 8/10, 7, 5, 3, none). Plates still 3-9 on s3/8/10.

Findings (tools/pl_diag.gd: workbench state, job mix, ledger per seed):
- s9: pure disease (colonists sick, all idle, 8 -> 3 alive d36-39); workbench has ore + may_operate but nobody works. Not a plate-logic bug.
- s8/s9: no iron ore at all (iron_ore 0/0): plates only from hand_plate (3 ore each); s8 built wb #2 at d45 (sp_ore>=80 gate).
- s10/s3/s8: stored ore ~0 all game, workbench input 1 of 10, ~25% of colonist samples idle; plate output 160-280 / 60 d, 110+ eaten by
  repairs (1 plate per repair) and parts (1 plate each); stock never reaches 60. Ore supply (~1400 / 60 d) is the wall, not the reserve rule.
- hand_plate chain: 3 ore -> 1 plate, refinery shares the same ore; ore_reserve (amt 40..120, low 70/high 130) changed nothing (rf_reserve is on by default).

Experiments (10 seeds, 60 d, jobs=3; alive>=8 / audit / P1 / P3 / launch):
- baseline (CS): 8/10, 7, 5, 3, 0
- haul fix: 9/10, 8, 4, 4, 0   <- kept
- haul fix + reserve 120/70/130: 9/10, 7, 4, 2, 0
- haul fix + sp_ore 0 (early wb2): 8/10, 6, 3, 2, 0 (hq_destroyed s3, dead s9)
- haul fix + hand_plate 2 ore (data): 6/10, 6, 6, 3, 0 (P4 on s1; +50% plates but survival worse; runs are chaotic). Reverted.
Next: raise ore supply (more/earlier miners on essence nodes) or a medic/disease fix for s9; hand_plate 3->2 needs a survival check
(tools/kx_pillar_table.gd) before it can ship. tools/pl_diag.gd is the probe (--seed --days).
