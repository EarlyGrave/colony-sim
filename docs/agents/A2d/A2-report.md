# A2d report: belt touch UI
- New view/panels/automation_panel.gd (AutomationPanel): buttons Belt / Remove / Rotate / Machines / Undo, all >= 64 px high; machines row (miner, smelter, assembler, storage_in, storage_out) uses the existing place_building tap flow (ids added to GameController.BUILD_TOOLS).
- Static helpers extend_path (Manhattan snap, x then y, backtrack pops) and path_last_dir (0=N,1=E,2=S,3=W; last step direction, default keeps previous).
- CameraController (region A2d): capture_drag flag + stroke_began/moved/ended signals. While capture is on, one-finger/left-mouse drag paints instead of panning; a 2nd finger cancels the stroke and pinch/pan/wheel work as before. Mouse events with DEVICE_ID_EMULATION are ignored while capturing (touch events drive strokes).
- GameController (region A2d): stroke_begin/move/end, preview in WorldView (belt_draft/belt_bad; red = can_belt_cell_error), commit via place_belt (one command per drag), remove_belt, set_belt_dir (tap on a belt rotates 90 deg), undo_belt (history of placed paths).
- Selecting any HUD tool leaves belt tools and clears the panel selection; selecting a panel tool resets the HUD radio to inspect.
- Tests: tests/test_belt_input.gd (5, pass). Full suite: 360 pass, 6 fail = same 6 baseline failures (mining x2, storyteller cave-in, ui_perks, waves x2).
- Not verified visually (headless only): panel position (center-right) may overlap other HUD on small phones.
