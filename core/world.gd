extends Node
## World state, simplified 360-day calendar, persistence.
signal changed
const SCENARIO = "res://data/scenario.json"
const SAVE_PATH = "user://clan_save.json"
const VERSION = 1
var state: Dictionary = {}

func _ready() -> void:
    new_game()

func new_game() -> void:
    var parsed = JSON.parse_string(FileAccess.get_file_as_string(SCENARIO))
    if parsed is Dictionary:
        state = parsed
        changed.emit()
    else:
        push_error("Initial scenario is invalid")

func advance_days(days: int) -> void:
    if days <= 0 or state.is_empty():
        return
    state["day"] = int(state["day"]) + days
    changed.emit()

func date_text() -> String:
    var day: int = int(state.get("day", 0))
    return "承平 %d 年 %02d 月 %02d 日" % [floori(day / 360.0) + 1, floori((day % 360) / 30.0) + 1, day % 30 + 1]

func age_of(person: Dictionary) -> int:
    return floori((int(state.get("day", 0)) - int(person.get("birth_day", 0))) / 360.0)

func person_by_id(id: int) -> Dictionary:
    for person in state.get("characters", []):
        if int(person["id"]) == id:
            return person
    for person in state.get("ancestors", []):
        if int(person["id"]) == id:
            return person
    return {}

func person_name(id: int) -> String:
    return str(person_by_id(id).get("name", "未记录"))

func branch_name(id: int) -> String:
    for branch in state.get("branches", []):
        if int(branch["id"]) == id:
            return str(branch["name"])
    return "未归属"

func save_game() -> Error:
    var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    if file == null:
        return FileAccess.get_open_error()
    file.store_string(JSON.stringify(state, "\t"))
    file.close()
    return OK

func load_game() -> Error:
    if not FileAccess.file_exists(SAVE_PATH):
        return ERR_FILE_NOT_FOUND
    var parsed = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
    if not parsed is Dictionary:
        return ERR_FILE_CORRUPT
    if int(parsed.get("schema_version", -1)) != VERSION:
        return ERR_INVALID_DATA
    for key in ["day", "clan", "branches", "households", "characters", "ancestors"]:
        if not parsed.has(key):
            return ERR_FILE_CORRUPT
    if not parsed["clan"] is Dictionary or not parsed["characters"] is Array or not parsed["branches"] is Array or not parsed["households"] is Array or not parsed["ancestors"] is Array:
        return ERR_FILE_CORRUPT
    if int(parsed["day"]) < 0:
        return ERR_FILE_CORRUPT
    state = parsed
    changed.emit()
    return OK
