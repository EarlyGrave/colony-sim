extends Node
## Global event bus. Systems talk to each other through these signals.
##
## The game uses the autoload instance. Tests create their own instance with
## `preload("res://autoload/event_bus.gd").new()` so simulations stay isolated.
## The simulation never reaches for the autoload by name: it receives a bus
## in its constructor.

# --- Time ---
signal tick_advanced(tick: int)
signal day_started(day: int)

# --- Map / designations ---
signal tile_changed(cell: Vector2i)
signal designation_changed(cell: Vector2i)
signal zone_changed(cell: Vector2i)

# --- Items ---
signal item_mined(cell: Vector2i, item_id: String, amount: int)

# --- Buildings / production ---
signal building_placed(building_id: int)
signal building_destroyed(building_id: int)
signal building_broken(building_id: int)
signal building_repaired(building_id: int)
signal batch_refined(building_id: int, recipe_id: String)
signal first_refine_done()

# --- Contamination ---
signal contamination_changed(level: float)
signal forecast_revealed()

# --- Threats ---
signal threat_awakened()
signal wave_started(wave_index: int, strength: float)
signal wave_ended(wave_index: int)
signal wave_incoming(origin: Vector2i, ticks_left: int)
signal enemy_killed(enemy_id: int)
signal colonist_died(colonist_id: int)
signal alarm_changed(active: bool)
signal rule_changed(rule_id: String, on: bool)

# region health
signal colonist_downed(colonist_id: int)
signal injury_added(colonist_id: int, part: String, kind: String, severity: float)
# endregion

# region mood
signal mood_break_started(colonist_id: int, kind: String)
signal thought_added(colonist_id: int, thought_id: String)
# region crafting
signal bills_changed(building_id: int)
signal zone_settings_changed(cell: Vector2i)
# region combat
signal colonist_drafted(colonist_id: int, on: bool)
# endregion

# --- Game flow ---
signal game_over(reason: String)
signal story_event(event_id: String, text: String)

# region jobs-core
signal skill_leveled(colonist_id: int, skill_id: String, level: int)
signal work_priority_changed(colonist_id: int, work_type: String, priority: int)
# endregion

# region construction
signal blueprint_placed(blueprint_id: int)
signal blueprint_progress(blueprint_id: int)
signal blueprint_cancelled(blueprint_id: int)
signal blueprint_completed(blueprint_id: int, building_id: int)
# region arrivals
signal event_choice_posted(uid: int, text: String)
signal event_choice_resolved(uid: int, accepted: bool)
signal colonist_joined(colonist_id: int)
# endregion
