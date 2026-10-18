# R1a report
- Added docs/sim_contract.md (160 lines): tick order (research slot marked), RNG rules + call order + separate streams, determinism/number rules, 32-command table (args, validation), bus, 37 data-file schemas, save format v2, state_hash definition (GD var_to_str vs portable canonical JSON, known gaps), architecture constraints.
- Research (pending R2a) section + research.json/milestones.json note left as placeholders; R2a must add its _record commands as table rows (test fails otherwise).
- Added tests/test_contract_doc.gd: every _record command in simulation.gd is a table row, every data/*.json is a table row, no stale commands, doc <= 250 lines.
- Full suite run headless; all tests green.
