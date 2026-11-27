extends SceneTree
const Schema = preload("res://core/world_schema.gd")
const Store = preload("res://core/world_store.gd")
const Clock = preload("res://core/simulation_clock.gd")
const Registry = preload("res://core/entity_registry.gd")
var failures := 0
var months := 0
var years := 0

func check(condition: bool, description: String) -> void:
	if not condition:
		failures += 1
		push_error(description)

func _initialize() -> void:
	var s := Store.read(Store.SCENARIO)
	check(not s.is_empty(), "scenario validation")
	if s.is_empty():
		quit(1)
		return
	var registry = Registry.new()
	check(registry.rebuild(s), "registry build")
	check(registry.find("characters", 1001).get("name") == "沈氏先祖", "ancestor lookup")
	check(registry.next_id("characters") == 1002, "unique character ID")
	var clock = Clock.new()
	clock.month_started.connect(func(_day): months += 1)
	clock.year_started.connect(func(_day): years += 1)
	clock.advance(s, 360)
	check(months == 12 and years == 1 and s["day"] == 360, "calendar boundaries")
	var bad := s.duplicate(true)
	bad["characters"].append(bad["characters"][0].duplicate(true))
	check(not Schema.validate(bad), "duplicate ID rejection")
	bad = s.duplicate(true)
	bad["regions"][0]["parent_id"] = 4
	check(not Schema.validate(bad), "region cycle rejection")
	var legacy := s.duplicate(true)
	legacy["schema_version"] = 1
	legacy["clan"] = legacy["clans"][0]
	for key in ["clans", "polities", "regions", "settlements", "player_clan_id"]:
		legacy.erase(key)
	check(Schema.validate(Schema.migrate(legacy)), "legacy migration")
	var path := "user://foundation_test.json"
	check(Store.write(s, path) == OK, "save test")
	check(Store.write(s, path) == OK, "overwrite test")
	check(Store.read(path) == s, "save round trip")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("Foundation test failures: ", failures)
	quit(0 if failures == 0 else 1)
