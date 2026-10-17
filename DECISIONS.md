# DECISIONS.md — significant decisions

Format: what was chosen · why · alternatives.

## D1. Godot 4.7.2 + GDScript instead of the TypeScript engine from the design doc
The design doc mentions a custom TypeScript engine + Tauri/Electron. The
kick-off prompt (newer, more specific) demands Godot + GDScript with a web
build. Followed the prompt. Web export still gives an itch.io / iPad-webview
path. Alternatives: custom TS engine (more work, no editor), C# (no web export).

## D2. Own minimal test runner instead of GUT
`tests/test_runner.gd` (≈60 lines) + `TestCase` base. No addon download,
no version drift with Godot 4.7, trivially headless, exit code for CI.
Alternative: GUT — richer but heavier and pinned to Godot versions.

## D3. Event bus: autoload script, injected instance
The prompt asks for an autoload with signals. Sim code receives the bus as a
constructor argument instead of referencing the `EventBus` singleton, so
tests can create isolated bus instances (`EventBusScript.new()`) and run
several simulations without cross-talk. The game passes the real autoload.

## D4. CI deploys only from `main`
Tests + web export run on every push to any branch; Pages deploy only from
`main` (as the prompt specifies). Work branches therefore don't change the
public build until merged.
