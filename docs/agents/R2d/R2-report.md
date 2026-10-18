# R2d research UI report
- New `view/panels/research_panel.gd` (ResearchPanel + nested ResearchAdapter), registered in `panel_registry.gd` slot 5 (region R2d). The HUD panel-bar button (64 px) comes from the registry, so `hud.gd`/`game.gd` are untouched.
- Layout: horizontal scroll, one column per tier T0..T3, audit strip (part counts + Deliver >= 64 px), cards 160x96 with name, cost (days/hours + essence), "adds N% waste", state (locked reason / available / queued / active with progress strip / done).
- Tap = `queue_research(id, on)`; Deliver = `deliver_audit(tier)`. No `sim/` changes, no hover (Buttons only, so emulated mouse duplicates are not an issue).
- `tools/screenshot.gd`: new `--panel=<id>` arg. Screenshots: scratchpad r2d_phone.png (1080x2160, --scale=2.5) and r2d_desktop.png (1600x900).
- Tests: `tests/test_research_panel.gd` (4: 14 nodes rendered, all buttons >= 64 px, tap queue/unqueue, locked tap no-op) pass.

## Assumptions for reconciliation with R2a/R2b
- `sim.research` exposes properties `techs` (id->def), `done`, `queue` (queue[0] = active), `progress` (id->bench ticks), `delivered` (tier->{item:n}), optional `tier_unlocked(t)`; sim has `queue_research(id,on)` and `deliver_audit(tier)`; `sim.ticks_per_day` exists.
- Tech def: `{name, tier, prereqs[], cost{bench_ticks, essence}, waste_mult}`; milestones: `tier -> {parts{item:n}}` (string keys, optional wrapper key).
- Without sim.research or data files the adapter uses a built-in 14-tech sample (remove SAMPLE_* once R2a lands), a local fake queue, and shows T0/T1 as done.
- The tap-queue test returns early when no tech is "available" (true with the sample); with real data it exercises the sim.
- Known gap: in the phone shot only T0/T1 are visible (T2/T3 are scrolled off to the right; the side panel is narrow).
