# G1c atmosphere and polish
Done:
- view/atmosphere.gd (Atmosphere): procedural sky, depth fog (FOG_ENABLED switch, FOG_BEGIN<FOG_END), edge-fade apron
  plane (shader: darkens 9 cells inside the map border, solid void colour outside), day/contamination tint via set_tint.
- Blob shadows under all units: one MultiMesh (shadow_blob.png), brutes larger.
- view/selection_marker.gd (SelectionMarker): ring under selected colonist; GameController sets
  world3d.selected_colonist (2 one-line hooks in game.gd, cleared on non-colonist inspect and on bind).
- Standing item piles: pooled billboard Sprite3D (cap MAX_PILES=300), refreshed every 10 frames, size grows with count.
- gen_art.py `# region G1c`: shadow_blob.png, select_ring.png (+ .import).
Tests: tests/test_atmosphere.gd (atmosphere_builds_and_params_sane, selection_marker_follows_and_hides). Full suite green.
Screenshots: scratchpad g1c.png (default zoom), g1c_far.png (zoom 0.35): no hard map edge, soft dark fade.
Known issues:
- Flat item art is still drawn on the ground by WorldView (not my file), so piles appear both flat and upright.
- Selection ring not seen in screenshot (no selection in the screenshot scene); covered by test only.
- Edge apron sits at y=0.04, so unit feet within the 9-cell border band are slightly darkened.
