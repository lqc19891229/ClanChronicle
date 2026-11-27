extends Node
## Compatibility facade for the UI. Canonical data lives in world_state.
signal changed
signal day_ended(day: int)
signal month_started(day: int)
signal year_started(day: int)

const Clock = preload("res://core/simulation_clock.gd")
const Registry = preload("res://core/entity_registry.gd")
const Store = preload("res://core/world_store.gd")
var world_state: Dictionary = {}
var registry = Registry.new()
var clock = Clock.new()
var advancing := false
# Legacy UI projection; references the canonical entity dictionaries.
var state: Dictionary:
	get:
		if world_state.is_empty():
			return {}
		var clan := entity("clans", int(world_state["player_clan_id"]))
		var id := int(clan["id"])
		return {"day": world_state["day"], "clan": clan,
			"branches": world_state["branches"].filter(func(b): return int(b["clan_id"]) == id),
			"households": world_state["households"].filter(func(h): return int(entity("branches", int(h["branch_id"])).get("clan_id", -1)) == id),
			"characters": world_state["characters"].filter(func(p): return int(p["clan_id"]) == id),
			"ancestors": world_state["ancestors"]}

func _ready() -> void:
	clock.day_ended.connect(func(day): day_ended.emit(day))
	clock.month_started.connect(func(day): month_started.emit(day))
	clock.year_started.connect(func(day): year_started.emit(day))
	new_game()

func replace_world(candidate: Dictionary) -> bool:
	if advancing or candidate.is_empty():
		return false
	var next_registry = Registry.new()
	if not next_registry.rebuild(candidate):
		return false
	world_state = candidate
	registry = next_registry
	changed.emit()
	return true

func new_game() -> void:
	if not replace_world(Store.read(Store.SCENARIO)):
		push_error("Initial scenario is invalid")

func advance_days(days: int) -> void:
	if advancing or days <= 0 or world_state.is_empty():
		return
	advancing = true
	clock.advance(world_state, days)
	advancing = false
	changed.emit()

func date_text() -> String:
	return Clock.date_text(int(world_state.get("day", 0)))

func age_of(person: Dictionary) -> int:
	return Clock.age(int(world_state.get("day", 0)), int(person.get("birth_day", 0)))

func entity(kind: String, id: int) -> Dictionary:
	return registry.find(kind, id)

func person_by_id(id: int) -> Dictionary:
	return entity("characters", id)

func person_name(id: int) -> String:
	return str(person_by_id(id).get("name", "未记录"))

func branch_name(id: int) -> String:
	return str(entity("branches", id).get("name", "未归属"))

func save_game() -> Error:
	if advancing:
		return ERR_BUSY
	return Store.write(world_state)

func load_game() -> Error:
	if advancing:
		return ERR_BUSY
	if not FileAccess.file_exists(Store.SAVE_PATH):
		return ERR_FILE_NOT_FOUND
	return OK if replace_world(Store.read(Store.SAVE_PATH)) else ERR_FILE_CORRUPT
