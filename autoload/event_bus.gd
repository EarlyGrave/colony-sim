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
# region Q0
signal quest_started(quest_id: String)
signal quest_beat(quest_id: String, beat_id: String, text: String)
signal quest_choice_posted(uid: int, quest_id: String, options: Array)
signal quest_resolved(quest_id: String, option_id: String)
# endregion
# region L3
signal power_changed(net_id: int)  # a network's brownout factor moved to another 0.05 bucket
signal power_meltdown(building_id: int)
# endregion

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
# region raids
signal raid_started(raid_id: String, points: float, unit_count: int)
signal raid_tremor(cell: Vector2i, ticks_left: int, text: String)
signal raid_burrowed(cell: Vector2i, count: int)
signal raid_retreat(raid_id: String)
# region needs
signal colonist_ate(colonist_id: int, item_id: String)
signal colonist_slept(colonist_id: int, in_bed: bool)
signal colonist_starving(colonist_id: int)
signal plant_sown(cell: Vector2i, plant_id: String)
signal plant_harvested(cell: Vector2i, item_id: String, amount: int)
# endregion
# region doctor
signal colonist_rescued(patient_id: int, carrier_id: int)
signal colonist_tended(patient_id: int, doctor_id: int, injuries: int)
signal patient_fed(patient_id: int, feeder_id: int)
# endregion
# region contracts
# region R2b
signal letter_received(title: String, text: String)
# endregion
signal contract_offered(contract_id: int)
signal contract_fulfilled(contract_id: int)
signal contract_failed(contract_id: int, reason: String)
# region progression
signal xp_awarded(colonist_id: int, skill_id: String, amount: float, reason: String)
signal wave_repelled(wave_index: int)
# region ammo
signal ammo_depleted(kind: String, id: int)  # kind: "turret" | "colonist"
# region debt
signal debt_paid(colonist_id: int)
signal debt_choice_made(colonist_id: int, outcome: String)
signal riot_started(colonist_id: int)
signal colonist_escaped(colonist_id: int)
signal escape_stopped(colonist_id: int)
# endregion
# region perks
signal perk_learned(colonist_id: int, perk_id: String)
signal perk_used(colonist_id: int, perk_id: String)
# region C2
signal ability_used(squad_id: int, ability_id: String, user_id: int)
# endregion
signal perk_point_available(colonist_id: int, skill_id: String, points: int)
# endregion
# region crises
signal crisis_started(crisis_id: String, text: String)
signal crisis_resolved(crisis_id: String, option_id: String, by_timeout: bool)
# region idle-work
signal patrol_spotted(colonist_id: int, cell: Vector2i, enemies: int)
signal waste_scrubbed(colonist_id: int, cell: Vector2i, amount: float)
signal patrol_route_changed(count: int)
# endregion
# region meta
signal run_ended(summary: Dictionary)
# region mutation
signal cell_mutated(cell: Vector2i)
signal cell_purified(cell: Vector2i)
# endregion
# region R2a
signal research_completed(tech_id: String)
# endregion
# region O1
signal tutorial_step_changed(step: int)
signal tutorial_finished()
# endregion
# region R4
signal map_switched(id: int)
signal expedition_sent(id: int)
signal expedition_arrived(id: int)
signal expedition_loss(id: int, debt: int)
signal cargo_arrived(id: int, n: int)
# endregion
# region F2
signal outpost_lost(id: int)
# endregion

# region B5
signal wave_report(report: Dictionary)  # {wave, lost:[{name,by,why}], main_attack, colonist_deaths, kills}
# endregion

# region E1
signal petition_phase_done(phase: int)
signal beacon_launched(alive: int)  # region S2
signal ending_won(id: String)  # region EN1
# endregion

# region I1
signal block_standing_changed(block: String, standing: float)
# endregion

# region S1
signal shuttle_phase(phase: String)
signal shuttle_won
# endregion

# region RO
signal raid_objective_met(raid_id: String, kind: String)
# endregion
