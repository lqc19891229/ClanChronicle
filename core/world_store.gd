extends RefCounted
const Schema = preload("res://core/world_schema.gd")
const SCENARIO = "res://data/scenario.json"
const SAVE_PATH = "user://clan_save.json"

static func read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var raw = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not raw is Dictionary:
		return {}
	var migrated := Schema.migrate(raw)
	return migrated if Schema.validate(migrated) else {}

static func write(state: Dictionary, path: String = SAVE_PATH) -> Error:
	if not Schema.validate(state):
		return ERR_INVALID_DATA
	var temporary := path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(state, "\t"))
	file.flush()
	var result := file.get_error()
	file.close()
	if result != OK:
		return result
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(path))
