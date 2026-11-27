extends Node
## Compatibility facade for the UI. Canonical data lives in world_state.
signal changed
signal day_ended(day: int)
signal month_started(day: int)
signal year_started(day: int)

const Economy = preload("res://core/economy.gd")
const Clock = preload("res://core/simulation_clock.gd")
const Registry = preload("res://core/entity_registry.gd")
const Store = preload("res://core/world_store.gd")
const Schema = preload("res://core/world_schema.gd")
var world_state: Dictionary = {}
var registry = Registry.new()
var clock = Clock.new()
var advancing := false
# Legacy UI projection; property fields are derived from canonical accounts.
var state: Dictionary:
	get:
		if world_state.is_empty():
			return {}
		var clan := with_property(entity("clans", int(world_state["player_clan_id"])), "clans")
		var id := int(clan["id"])
		return {"day": world_state["day"], "clan": clan,
			"branches": world_state["branches"].filter(func(b): return int(b["clan_id"]) == id),
			"households": world_state["households"].filter(func(h): return int(entity("branches", int(h["branch_id"])).get("clan_id", -1)) == id).map(func(h): return with_property(h, "households")),
			"characters": world_state["characters"].filter(func(p): return int(p["clan_id"]) == id),
			"ancestors": world_state["ancestors"]}

func with_property(property_owner: Dictionary, kind: String) -> Dictionary:
	var view := property_owner.duplicate()
	view.merge(Economy.summary(world_state, kind, int(property_owner["id"])), true)
	return view

func grant_grain(household_id: int, amount: int) -> bool:
	if advancing or world_state.is_empty():
		return false
	var h := entity("households", household_id)
	var clan_id := int(world_state["player_clan_id"])
	if h.is_empty() or int(entity("branches", int(h["branch_id"])).get("clan_id", -1)) != clan_id:
		return false
	var success := Economy.transfer(world_state, Economy.account(world_state, "clans", clan_id), Economy.account(world_state, "households", household_id), "grain", amount, "宗族救济")
	if success:
		world_state["chronicle"].append({"day": world_state["day"], "text": "%s获得宗族救济%d石" % [h["name"], amount]})
		changed.emit()
	return success

func _ready() -> void:
	clock.day_ended.connect(func(day): day_ended.emit(day))
	clock.month_started.connect(func(day):
		Economy.settle_month(world_state, day)
		month_started.emit(day)
	)
	clock.year_started.connect(func(day): year_started.emit(day))
	new_game()

func replace_world(candidate: Dictionary) -> bool:
	if advancing or candidate.is_empty() or not Schema.validate(candidate):
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
