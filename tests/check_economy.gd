extends SceneTree
const Store = preload("res://core/world_store.gd")
const Economy = preload("res://core/economy.gd")
const Schema = preload("res://core/world_schema.gd")
const Clock = preload("res://core/simulation_clock.gd")
var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	var s := Store.read(Store.SCENARIO)
	if s.is_empty():
		quit(1)
		return
	check(s["schema_version"] == 3, "migration")
	check(s["assets"].size() == 7, "seven farmland assets")
	var public_account := Economy.account(s, "clans", 1)
	var family := Economy.account(s, "households", 1)
	check(public_account["cash"] == 200 and public_account["grain"] == 100, "initial public account")
	check(Economy.transfer(s, public_account, family, "grain", 10, "test"), "relief")
	check(public_account["grain"] == 90 and family["grain"] == 25, "conserved transfer")
	check(not Economy.transfer(s, public_account, family, "grain", 999, "test"), "insufficient stock")
	var clock = Clock.new()
	clock.month_started.connect(func(day): Economy.settle_month(s, day))
	clock.advance(s, 30)
	check(family["grain"] == 21, "monthly consumption")
	Economy.settle_month(s, 30)
	check(family["grain"] == 21, "no double settlement")
	clock.advance(s, 240)
	check(public_account["grain"] == 215, "public harvest")
	check(s["enterprises"][0]["last_harvest"] == 125, "manager harvest")
	check(Schema.validate(s), "post settlement validation")
	var path := "user://economy_test.json"
	check(Store.write(s, path) == OK, "save")
	check(Store.read(path) == s, "round trip")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("Economy failures: ", failures)
	quit(0 if failures == 0 else 1)
