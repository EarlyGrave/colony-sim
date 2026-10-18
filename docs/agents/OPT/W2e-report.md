# OPT-W2e: memory (#14), wasm pass (#15), web smoke tool

Memory (tools/mem_probe.gd, headless; VRAM = analytic RGBA8; 250 map, view of 70x40 cells):
| | before | after |
|---|---|---|
| static MB (250) | 185 | 69 |
| static MB (64) | 63 | 59 |
| chunk SubViewport VRAM (250) | 61 MB (all 64 allocated) | 6 MB (active only) |
| ground ImageTexture VRAM (250) | 61 MB | 6 MB |

Changes: `ChunkLayer` (region W2e) shrinks inactive chunk viewports to 1x1 (render target freed) and restores size on activation.
`WorldView` (region W2e, additive guards in 3 places) gets `lazy_chunks` (set in game.gd): ground Image+texture exist only
for chunks the 3D view activates (budget 2 chunk paints/call, released after 8 s unwanted); world_3d passes the active list.
Default `lazy_chunks=false`, so tests/tools behave as before. 64-map screenshot visually identical (pixel diff is only the
wall-clock time-of-day tint). Risk: a chunk re-activated by a fast pan may show blank for ~1 frame (8-cell margin).

Wasm pass (#15): sim/ is already free of hot-loop String formatting after wave 1; remaining "rep:%d"/"ammo:%d" reservation keys
live in jobs/combat files owned by other workers (not touched). No untyped hot loops found in my files. Export: 41.1 MB total
(wasm 39.5 MB, pck 1.2 MB) uncompressed, release template, unchanged.

Web smoke: `PLAYWRIGHT_BROWSERS_PATH=/opt/pw-browsers python3 tools/web_smoke.py [--no-export]` (needs `pip install playwright==1.56.0`
to match chromium-1194). PASS: boot ok (tutorial game 6 s, ?size=250 8 s), no console errors, 7 toolbar taps, FPS >= 0.5 at DPR 3
(software GL lower bound), JS heap 97 / 116 MB. Screenshots: scratchpad/w2e_{tutorial_main,tutorial_toolbar,tutorial_end,size250_main,size250_end}.png.
Tests: 599 passed, 0 failed twice (sharded); tests/golden unchanged. CLAUDE.md Commands updated (web_smoke, mem_probe).
