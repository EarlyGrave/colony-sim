# G1d report (camera, effects, depth)
Done
- CameraController: fling inertia (step_inertia), pan clamped to map + 2-cell margin (PAN_MARGIN), zoom clamp 0.35..3.0 verified over 200+ wheel steps.
- New view/effects_3d.gd (Effects3D): turret tracer + hit spark (polls sim.threats.shots), mining dust (item_mined), death puff (enemy_killed). Cap 120, lifetimes via tick(delta), all freed; local fixed-seed RNG; sim untouched.
- world_3d.gd region G1d: spawn node + bind; one-line hooks in bind/unbind.
Not done
- Enemy spit projectiles: no bus signal or sim record for spitter attacks (needs sim change); skipped.
- Depth sorting: no change made (ground is one plane at y=0); not verified in a crowded scene.
Tests: test_camera_3d (round_trip, zoom_clamps, pan_clamp_and_inertia), test_effects_3d (dust, kill_puff_and_tracer, effect_cap). Full suite 312 passed, 0 failed.
Screenshot: /tmp/claude-0/-home-user-colony-sim/2c9ef3d5-c73d-4d98-a862-7d15a0bb0a1a/scratchpad/g1d.png (renders OK; static frame shows no effects).
Known issues: effect visuals not eyeballed in motion; tracers not tied to barrel height (G1b).
Files: view/camera_controller.gd, view/effects_3d.gd, view/world_3d.gd, tests/test_camera_3d.gd, tests/test_effects_3d.gd
