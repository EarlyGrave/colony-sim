# N3 report
Branch worktree-agent-a810033f04bba00cd.
- blocks.json: leaning/leaning_delta, M1-M3 numbers+texts.
- block_system.gd (region N3): apply_path, M1 debt of the dead (+1% of members debt, fight waives), M2 succession (once, flag informant_succeeded), M3 walkout (<=15 for 3d -> ultimatum, 2d deadline; met +20 and block_proud, unmet 2 highest-despair members escape; fight: demands refinery stop).
- quest_log.gd: verb path, cond clues_held. debt_system.gd: path_fight skips missed-installment Standing loss.
- tests/test_society_moments.gd 6 pass; quick suite 14 pass (goldens unchanged).
- block_report extended (Standing spread, ultimatums); full 10-seed output not captured (tail clipped) - rerun.
- Deviation: M1 hooked in BlockSystem death listener (no _remove hook for deaths).
