# E4 report (petition/dispatch/review UI)
Done: view/panels/petition_panel.gd, dispatch_panel.gd (new), reviews_panel.gd (region E4 lines), panel_registry (2 lines, region E4),
hud.gd region E4 (`_e4_update`: Petition/Dispatch buttons hidden unless state exists; petition button text = chip "Petition P2/4"), tests/test_e4_ui.gd (3 tests).
Panels use `api` (test seam) else `sim`; all sim calls guarded by has_method. Deliver/Ship/pick buttons are 64 px high, progress bars per item.
Assumed sim API names (adjust on merge if E1/E2/E3 differ):
- sim.petition_state() -> {enabled, phase:int (current, 0-based), phases:[{title, done, reward, items:[{item, have, need}]}]}
- sim.deliver_petition(phase:int)
- sim.dispatch_state() -> {enabled, tiers:[{title, done, picked, items:[{item,have,need}], choices:[{id,label}]}]}
- sim.deliver_dispatch(tier:int), sim.pick_dispatch_modifier(tier:int, id:String)
- sim.milestones.rank_title() -> String, sim.milestones.range_score() -> number (Reviews panel lines). Reviews 4-5 progress itself comes from existing current_review()/review_progress().
Results: full sharded suite 721 passed, 0 failed; tools/web_smoke.py WEB SMOKE PASS (844x390). With APIs absent the buttons stay hidden, so phone layout is unchanged.
Not done: per-panel screenshots (no sim data to show until E1/E2 merge; panels verified by stub test only).
