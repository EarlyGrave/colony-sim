# R4-W5 report (view + UI for expeditions)
Branch r4w5 (base 0cbc1b6). Not pushed.
- `view/campaign_view.gd` (new): guarded read adapter over Campaign API (maps/active/in_flight/map_info, data/expedition.json). Works with no Campaign.
- `view/panels/map_switcher.gd`: chips (>=64 px) per map, badges `[n]` in-flight crates and `!` alarm, plus Expedition / Cargo buttons.
- `view/panels/expedition_panel.gd`: expedition flow biome -> crew (never everyone) -> supplies steppers -> confirm (travel time, collateral) ->
  one `send_expedition`; cargo dialog (target map, items capped by sling capacity) -> one `sling_send`. Locked with reason if rule `expeditions` not researched.
- `view/game.gd` region R4e: `campaign` var, `sim = campaign.active_sim()`, `switch_map(id)`, `attach_campaign(c)`, rebinding WorldView/WorldView3D/camera/HUD,
  `_r4e_step()` -> `campaign.step()`, bus factory (home = EventBus, others isolated), letters on expedition_arrived/loss/cargo_arrived,
  guarded save v3 hooks `SaveGame.campaign_to_dict/campaign_from_dict(d, bus_factory)` (assumed names, returns {ok,campaign}; W4 may need to match).
  Without sim/campaign/campaign.gd the game runs exactly as before (single Simulation).
- `view/hud.gd` region R4e: `bind_campaign`, `open_expedition(mode)`; `autoload/event_bus.gd` region R4: 5 signals.
- `tests/test_expedition_ui.gd` (stub Campaign): 5 tests green (buttons >= 64, flow calls send once, switch swaps sim and map size 250 -> 96).
- `tools/screenshot.gd`: `--panel=exp_map|exp_crew|exp_cargo` demo. Screenshots in scratchpad r4w5_map.png, r4w5_crew.png.
- Integration note: when the real Campaign lands, check ctor arg order `(seed, bus_factory, defs, opts)` and that bus_factory is called home-first.
