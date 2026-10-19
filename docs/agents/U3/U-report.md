# U3 modal polish report
- New `view/modal_style.gd` (`ModalStyle`): `apply(panel)` (opaque 0.97 panel, 12px rounded border, 18px body), `style_label`, `style_button(primary)`, `make_scrim()` (0.75, mouse STOP), `contrast()`.
- Converted: Sentence Ended (win; own scrim + card, 2-col stats, filled "New Run" / outlined "Continue", 64px, fits 844x390), plus Reviews, Petition, Dispatch, Shuttle panels via a `# region U3` hook in `PanelRegistry.make_panel` (ids in `ModalStyle.MODAL_IDS`).
- NOT converted: HUD game-over box (`hud.gd` `_game_over`, U1 owns hud.gd). Reconcile: in hud.gd build, call `ModalStyle.apply(_game_over)`, style its label/button (`style_button(b, true)`), and add `ModalStyle.make_scrim()` behind it in U1's ModalLayer (also usable as scrim for the 4 side sheets when opened: add make_scrim() to ModalLayer, then the panel).
- Test: `tests/test_u3_modal.gd` (contrast title >=7, body >=4.5, accent button text >=4.5, alpha >=0.95, scrim >=0.75, button min h >=64, scrim input STOP, 4 panels styled).
- Screenshots: docs/agents/U3/before.png, after.png (844x390).
- Sharded suite 758 passed, 0 failed; web_smoke PASS; goldens untouched; no sim changes.
