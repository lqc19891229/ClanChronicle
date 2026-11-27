extends RefCounted
## Schema v2: independent polity, administrative geography and kinship.
const VERSION = 2
const Registry = preload("res://core/entity_registry.gd")

static func migrate(raw: Dictionary) -> Dictionary:
	var s := raw.duplicate(true)
	var version = s.get("schema_version", -1)
	if version == VERSION:
		return s
	if version != 1 or not s.get("clan") is Dictionary:
		return {}
	for key in ["branches", "households", "characters", "ancestors"]:
		if not s.get(key) is Array:
			return {}
		for record in s[key]:
			if not record is Dictionary:
				return {}
	var clan: Dictionary = s["clan"]
	var clan_id = clan.get("id", -1)
	s["polities"] = [{"id": 1, "name": "大梁", "capital_settlement_id": -1}]
	s["regions"] = []
	var names := ["青州", "清河郡", "清河县", "东乡"]
	var levels := ["zhou", "jun", "xian", "xiang"]
	for i in range(4):
		s["regions"].append({"id": i + 1, "name": names[i], "level": levels[i], "parent_id": -1 if i == 0 else i, "legal_polity_id": 1, "controlling_polity_id": 1})
	s["settlements"] = [{"id": 1, "name": "沈家村", "region_id": 4}]
	clan["home_settlement_id"] = 1
	s["clans"] = [clan]
	s["player_clan_id"] = clan_id
	s.erase("clan")
	for b in s["branches"]:
		b["clan_id"] = clan_id
	for h in s["households"]:
		h["settlement_id"] = 1
	for p in s["characters"]:
		p["clan_id"] = clan_id
		p["settlement_id"] = 1
	s["schema_version"] = VERSION
	return s

static func valid_int(value: Variant) -> bool:
	return (value is int or value is float) and value == int(value)

static func validate(s: Dictionary) -> bool:
	if s.get("schema_version") != VERSION or not valid_int(s.get("day")) or s["day"] < 0:
		return false
	for key in ["polities", "regions", "settlements", "clans", "branches", "households", "characters", "ancestors"]:
		if not s.get(key) is Array:
			return false
	var registry = Registry.new()
	if not registry.rebuild(s):
		return false
	if not valid_int(s.get("player_clan_id")) or registry.find("clans", int(s["player_clan_id"])).is_empty():
		return false
	for r in s["regions"]:
		if not r.get("level") in ["zhou", "jun", "xian", "xiang", "li"]:
			return false
		for key in ["parent_id", "legal_polity_id", "controlling_polity_id"]:
			if not valid_int(r.get(key)):
				return false
		for key in ["legal_polity_id", "controlling_polity_id"]:
			if int(r[key]) != -1 and registry.find("polities", int(r[key])).is_empty():
				return false
		var visited: Dictionary = {}
		var current: Dictionary = r
		while not current.is_empty():
			var id := int(current["id"])
			if visited.has(id) or not valid_int(current.get("parent_id")):
				return false
			visited[id] = true
			var parent := int(current["parent_id"])
			if parent == -1:
				break
			current = registry.find("regions", parent)
			if current.is_empty():
				return false
	for settlement in s["settlements"]:
		if not valid_int(settlement.get("region_id")) or registry.find("regions", int(settlement["region_id"])).is_empty():
			return false
	for b in s["branches"]:
		if not valid_int(b.get("clan_id")) or registry.find("clans", int(b["clan_id"])).is_empty():
			return false
		if not valid_int(b.get("head_id")):
			return false
		var head: Dictionary = registry.find("characters", int(b["head_id"]))
		if head.get("branch_id") != b["id"]:
			return false
	for h in s["households"]:
		for key in ["branch_id", "settlement_id", "head_id", "cash", "grain", "land"]:
			if not valid_int(h.get(key)):
				return false
		if registry.find("branches", int(h["branch_id"])).is_empty() or registry.find("settlements", int(h["settlement_id"])).is_empty():
			return false
		if registry.find("characters", int(h["head_id"])).get("household_id") != h["id"]:
			return false
	for c in s["clans"]:
		for key in ["leader_id", "home_settlement_id", "cash", "grain", "land"]:
			if not valid_int(c.get(key)):
				return false
		if registry.find("characters", int(c["leader_id"])).get("clan_id") != c["id"] or registry.find("settlements", int(c["home_settlement_id"])).is_empty():
			return false
		if not c.get("name") is String or not c.get("location") is String:
			return false
	for p in s["characters"]:
		for key in ["birth_day", "clan_id", "branch_id", "household_id", "settlement_id", "father_id", "mother_id", "spouse_id"]:
			if not valid_int(p.get(key)):
				return false
		if p["birth_day"] > s["day"]:
			return false
		for key in ["name", "sex", "occupation"]:
			if not p.get(key) is String:
				return false
		var b: Dictionary = registry.find("branches", int(p["branch_id"]))
		var h: Dictionary = registry.find("households", int(p["household_id"]))
		if b.get("clan_id") != p["clan_id"] or h.get("branch_id") != p["branch_id"] or registry.find("settlements", int(p["settlement_id"])).is_empty():
			return false
		if not p.get("skills") is Array or p["skills"].size() != 6:
			return false
		for skill in p["skills"]:
			if not valid_int(skill) or skill < 0 or skill > 100:
				return false
		for key in ["father_id", "mother_id", "spouse_id"]:
			var relative := int(p[key])
			if relative == int(p["id"]) or (relative != -1 and registry.find("characters", relative).is_empty()):
				return false
		if int(p["spouse_id"]) != -1 and registry.find("characters", int(p["spouse_id"])).get("spouse_id") != p["id"]:
			return false
	return true
