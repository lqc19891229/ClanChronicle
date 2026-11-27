extends RefCounted
const Schema = preload("res://core/world_schema.gd")
const SCENARIO = "res://data/scenario.json"
const SAVE_PATH = "user://clan_save.json"

static func read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_warning("World file not found: " + path)
		return {}
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK:
		push_warning("%s:%d: %s" % [path, parser.get_error_line(), parser.get_error_message()])
		return {}
	var raw = parser.data
	if not raw is Dictionary:
		push_warning("World file root must be a dictionary: " + path)
		return {}
	var migrated := Schema.migrate(raw)
	if migrated.is_empty():
		push_warning("World migration failed: " + path)
		return {}
	if not Schema.validate(migrated):
		push_warning("World schema validation failed: " + path)
		return {}
	return migrated

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
