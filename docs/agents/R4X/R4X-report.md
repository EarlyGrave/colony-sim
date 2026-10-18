# R4X report (expedition integration)
Branch `r4x-integration` (base a088761). Not pushed. Goldens not touched.
- Campaign: one signature `Campaign.new(seed, bus_factory, defs = null, opts = {})` (+ `start()`); public `bus_factory`; home opts via `opts.home_opts`.
  W3/W4/W5 all agree now (SaveGame builds it without `start()`). `step()` calls `Expedition.tick` + `Sling.tick`; commands `send_expedition/recall/sling_send` delegate to the helpers and log on success.
  Map ids are stable (recall leaves gaps) -> `entry(id)`, no list indices. `Expedition._arrive_party` calls `Campaign.add_outpost(biome, crew, supplies, id)` (one outpost builder, creates the Autopilot ledger).
- `state_hash` canonicalises dict key order (JSON save sorts keys) -> save/load round trip hashes equal.
- W2 hooks used for real: guards removed. `dispatch_party([], items)` now allowed (sling crate removal, was refused). New command `receive_party(crew)` (recall returns the party; documented).
- `sling_send(target, items)`: fires from the ACTIVE outpost to home (panel semantics); cargo dialog lists only Home as target. Sling capacity shown in UI now read from the building def (dropped duplicate `sling` block from expedition.json).
- Data fixes found by integrating: stockpile did not accept cinder_ore/prism_ore/bog_resin (zones.json); upkeep item "food" did not exist -> `raw_food` (start stock has it).
- tests/stub_campaign.gd and the UI stub deleted; test_expedition/test_sling/test_campaign_save/test_expedition_ui run on the real Campaign (the 2 early-return W4 tests execute). New tests/test_expedition_e2e.gd:
  research gate -> send 2 colonists + supplies (ash) -> arrival at travel_ticks -> autopilot cinder_ore -> visit, build sling by command, sling_send -> save mid-flight -> load -> equal hash -> crate lands on exact tick, hashes still equal. Plus game-level campaign/autosave v3 test.
  Note: the tech grant in tests is a direct `research.done.append` (not replayed), repeated on the loaded copy.
- GameController: real game already runs a Campaign (home = map 0, seed unchanged, `home_opts` fixed). Save = v3; load shows "Loading", frees old/new isolated buses correctly; old v2 saves are wrapped as a campaign home (`_r4e_wrap`).
- Debt: `sim/debt` has no add-debt API (per-colonist, drawn on join) -> collateral stays the ledger counter `ledgers["campaign"].collateral_debt`; removed the double charge (Campaign + Expedition).
- Belt strip: AutomationPanel now bottom-left content-width (was full-width band over the side panel) and hides when it would overlap an open side panel (phone width).
- Screenshots (looked at): scratchpad r4x_map.png (Home / Ash 1 switcher, outpost active), r4x_crew.png, r4x_crew_phone.png, r4x_cargo.png. Remaining cosmetic: legend + faint "Continue" ghost sit under the side panel (pre-existing).
- tools/screenshot.gd `--panel=exp_*` now drives the real flow. docs/sim_contract.md: receive_party row, 7c Campaign.
- Open: outposts are 96x96 (home 64x64) per data/expedition.json; no Recall button in UI yet (API `recall` works); research is not driven by commands in the e2e test.
- Full suite: 503 passed, 3 failed (the known test_golden + test_waves x2; zones.json stockpile accepts change may shift goldens, regenerate after R3X merge).
