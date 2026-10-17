# Colony Sim (working title)

Colony sim on a prison planet: "RimWorld meets Factorio". Prisoners mine
essence ore (safe) and refine it (dangerous: waste contaminates the planet and
draws creature waves). Godot 4.7 / GDScript, web build on GitHub Pages.

## Play
Latest build of `main`: `https://<owner>.github.io/colony-sim/` (GitHub Pages,
updated automatically by CI on every push to `main`).

## Local setup
```bash
V=4.7.2-stable
B=https://github.com/godotengine/godot-builds/releases/download/$V
curl -sSLO $B/Godot_v${V}_linux.x86_64.zip && unzip Godot_v${V}_linux.x86_64.zip
# web templates (only needed for export)
curl -sSLO $B/Godot_v${V}_export_templates.tpz
T=~/.local/share/godot/export_templates/4.7.2.stable && mkdir -p $T
unzip -j Godot_v${V}_export_templates.tpz 'templates/web_*' 'templates/version.txt' -d $T
```

## Run
```bash
godot --headless --path . --import                     # once
godot --headless --path . res://tests/run_tests.tscn   # tests
godot --path .                                         # play (needs a display)
godot --headless --path . --export-release "Web" build/web/index.html
```

## Layout
```
autoload/   EventBus (signals between systems)
data/       JSON definitions: items, buildings, recipes, zones, enemies, balance
sim/        pure simulation, no rendering (one dir per system)
view/       scenes, rendering, camera, HUD — reads sim state only
tests/      headless tests (own tiny runner)
```
See `CLAUDE.md` for architecture rules, `PROGRESS.md` for status,
`DECISIONS.md` for design decisions.
