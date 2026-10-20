# 08 — UI / UX (phone-first)

| file | content |
|---|---|
| [touch-rules.md](touch-rules.md) | hard touch rules, UI scale, input model, pseudo-3D view and camera, ship checks for UI |
| [hud-panels.md](hud-panels.md) | HUD layout at 844x390, the panel registry (every panel with status), notifications, tutorial, new-game dialog |

Sources: scout [onboarding_phone_ux.md](../../scout/onboarding_phone_ux.md), contract [docs/contracts/ui-touch.md](../../contracts/ui-touch.md),
GDD §12. Code: `view/game.gd` (GameController), `view/hud.gd`, `view/panels/*`, `view/world_view.gd`, `view/world_3d.gd`,
`view/camera_controller.gd`. Tests: `tests/test_phone_layout.gd`, `tools/web_smoke.py`, `tools/screenshot.tscn`.
