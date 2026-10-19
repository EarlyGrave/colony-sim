# Y5 report (UI leftovers)
- Belt entry: "Belt" button (96x72) is the first item of the Build popup; tap = same flow as the automation strip (`hud.belt_requested` -> `GameController._on_auto_tool("belt")`), popup closes, strip appears. Reachable from idle.
- HUD game-over box: moved into ModalLayer, `ModalStyle.apply` + title label + filled primary 64 px "New Sentence", `make_scrim()` (0.75, STOP) shown with the box.
- Side-sheet scrim: `SheetScrim` (0.45, STOP) in ModalLayer behind the sheet; sheets are now parented to `modal_root`; tap scrim = `close_side()`. Scrim stops above the bottom bar so the toolbar stays tappable.
- All edits in `# region Y5` (hud.gd, + tagged one-liners in hud.gd/game.gd). No sim changes, goldens untouched.
- Tests: tests/test_y5_ui.gd (3). Full sharded suite: 771 passed, 0 failed (incl. test_world_visible_percent >=55%). web_smoke: PASS.
- Screenshots 844x390: docs/agents/Y5/build.png (Build popup with Belt), docs/agents/Y5/sheet.png (sheet + scrim).
