# R4-W2 report (sim hooks)
- Branch `r4w2`. Files: sim/core/simulation.gd (region R4b), sim/meta/start_opts.gd (R4b note), docs/sim_contract.md (2 rows), tests/test_sim_hooks.gd.
- opts `crew` (snapshots {name, engineer, skills{}, passions{}}) replaces the random colony via `_place_crew_colony`
  (one `colonists.spawn` per member = fixed rng draws, then fields overwritten); `supplies` replace start_items; `biome` is only passed through (W1 reads it).
- `no_refining`: `can_place_building` returns "No refining here" for `is_refining_building(def)` (data-driven: a recipe producing waste runs there: refinery, smelter).
- `dispatch_party(ids, supplies) -> {ok, crew[], supplies{}}`: atomic, rejects dead/unknown/duplicate ids and unowned supplies (no change);
  removes colonists from `colonists.list`, consumes supplies (ledger sink `expedition`).
- `receive_cargo(items, radius) -> lost`: crate cell via sim.rng near HQ, ledger source `cargo`, uses `drop()` (lost recorded in ledger).
- Both commands log their args as JSON TEXT (save log/replay only handles scalars; Dictionary args would be mis-decoded as Vector2i). Methods accept Array/Dictionary or String.
- Hook for W3/W4: crew snapshot dict above; pass as `opts.crew`. Opts crew floats after JSON are int()-cast on read.
- Tests: test_sim_hooks (6) + test_contract_doc green; default start path untouched.
