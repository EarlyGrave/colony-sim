# F1 report (fix 6 failing tests after infinite nodes)
Branch worker-F1 (base 975020c). Full suite: 371 pass, 0 fail.
1. test_mined_ore_reaches_stockpile: nearest nodes are mixed copper/iron/essence and mining clears the designation after each cycle, so the
   old "designate 4 once" helper mined ~4 cycles, mostly non-essence. Test now designates essence nodes and re-designates (helper _mine_for).
2. test_resources_are_conserved (now test_nodes_never_deplete_and_ore_is_conserved): asserted finite deposit_amount accounting. Now asserts
   world==ledger balance, node count unchanged, deposit_lost == 0, total_deposit_amount == 0, ore mined > 0 on seeds 11-13.
3. Cave-in: collapse_deposit would destroy an invulnerable node. Retargeted to temporary rubble: MapGrid.node_rubble_until + bury_node/node_rubbled
   (in checksum), MineGiver skips buried nodes, MineJob aborts if buried, Storyteller._cave_in_cell (event + complication), data rubble_ticks=1200
   in events.json / event_chains.json, Ledger.record_event("cave_in:rubble_cells"). Legacy finite deposits still collapse. Test renamed;
   checks >=1 node buried, ledger count == buried, nodes intact, deposit_lost 0, rubble clears after rubble_ticks.
4. test_learn_through_ui: not a sim bug. The new RNG stream gave the seed-5 colonist a high mining join level, so level 4 earned 0 perk points
   (state "locked", no_points). Test now clears skills.join_levels (same convention as tests/test_perks.gd).
5,6. test_waves x2: scenario.designate_nearest_deposits mined any resource and only one cycle per designation, so refining income was tiny and
   waves weak (0-turret colony lived to wave 4-6). Scenario now designates the purest nearby ESSENCE nodes and re-designates after each cycle
   (item_mined) until ESSENCE_BUDGET=380 ore (old 10 finite deposits held ~450; unbounded mining kills the planet by contamination at wave 4-5
   and masks defence). Test thresholds and intent unchanged.
Extra: test_waves_conserve_items stale-reservation check compared reservation keys to colonist count; a job legitimately holds several keys
   (machine ports), so it now checks every reservation holder is a living colonist.
Open for A1e: designation clearing after each cycle is poor UX for infinite nodes; unbounded hand-mining needs a contamination/balance pass.
