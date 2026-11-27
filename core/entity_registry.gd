extends RefCounted
## IDs are unique within each entity type; ancestors share character IDs.
var tables: Dictionary = {}

func rebuild(state: Dictionary) -> bool:
	var candidate: Dictionary = {}
	for kind in ["polities", "regions", "settlements", "clans", "branches", "households", "characters"]:
		var records: Array = state[kind].duplicate()
		if kind == "characters":
			records.append_array(state["ancestors"])
		var index: Dictionary = {}
		for record in records:
			if not record is Dictionary:
				return false
			var raw = record.get("id", -1)
			if not (raw is int or raw is float) or raw != int(raw):
				return false
			var id := int(raw)
			if id <= 0 or index.has(id):
				return false
			index[id] = record
		candidate[kind] = index
	tables = candidate
	return true

func find(kind: String, id: int) -> Dictionary:
	return tables.get(kind, {}).get(id, {})

func next_id(kind: String) -> int:
	var largest := 0
	for id in tables.get(kind, {}):
		largest = maxi(largest, int(id))
	return largest + 1
