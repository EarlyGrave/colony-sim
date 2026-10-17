# Batch 3 "Prison-planet identity" — plan (from prompter)
Wave 1 (parallel): A1 quality, A2 progression (perk points fix + XP from events), A3 idle→work
(cleanup, patrol, training dummy), A4 contamination crises (50/75/90%), A5 warden contracts,
A6 prisoner debt + riot/escape breaks, A7 ammo.
Wave 2: A8 mutation of contaminated cells (+ crops worse on contaminated soil), A9 meta-progression
between runs, A10 HUD forecast/crisis banner/freedom counter, A11 storyteller event chains,
A12 prison events (debts, transports, wardens).
Wave 3: A13 balance (20 days × 5 seeds), A14 phone UI polish, A15 QA regression. Then game-designer check.
Rules: start with `git reset --hard claude/colony-sim-godot-4jftsm`; new data in data/<feature>.json;
every Simulation command calls `_record(...)` first; shared files only inside `# region <agent>` blocks;
tests/test_<feature>.gd; never push.
