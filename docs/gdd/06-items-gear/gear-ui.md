# Gear UI (phone)

Status: `[BUILT]` (E4 read-only panel, E5 equip/unequip/socket, F8 gear screen) — `view/panels/gear_panel.gd`,
`view/panels/gear_screen.gd`, `view/panels/item_card.gd`, `view/gear_icons.gd`, `data/stat_names.json`,
icons from `tools/gen_art.py` (16x16 gear icons + rarity frames).

- **Gear panel** on the inmate card: 6 slot rows (names from `equipment.json`), >= 64 px rows, no drag.
- **Gear screen** (More menu, "Open gear" on the inspector): paper doll with 6 slots, grid inventory of
  stored gear (4 columns at phone width), tap-select -> equip, inmate switcher, wide sheet; equip/unequip/
  socket go through recorded commands.
- **Item card**: base stats vs affix lines, sockets, durability, fighter profile; human stat names and %
  formatting from `stat_names.json`.
- Phone fit: 844x390 overlap scan, flexible card (FX6); `web_smoke.py` taps the toolbar.
- "Equip best" for the player `[PARTIAL]`: the bot has it; the player button is a question (README Q8).

Owner request behind F8: "grid inventory + icons". Not built: drag between slots (by design, touch),
comparison tooltips (no hover), repair button (no repair job).
