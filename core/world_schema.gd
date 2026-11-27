extends RefCounted
## Schema v2: independent polity, administrative geography and kinship.
const VERSION = 3
const Economy = preload("res://core/economy.gd")
const Registry = preload("res://core/entity_registry.gd")

static func migrate(raw: Dictionary) -> Dictionary:
	var s := raw.duplicate(true)
	var version = s.get("schema_version", -1)
	if version == VERSION:
		return s
	if version == 2:
		return Economy.migrate(s) if validate_base(s) else {}
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
	s["schema_version"] = 2
	return Economy.migrate(s) if validate_base(s) else {}

static func valid_int(value: Variant) -> bool:
	return (value is int or value is float) and value == int(value)

static func validate_base(s: Dictionary) -> bool:
	if s.get("schema_version") not in [2, 3] or not valid_int(s.get("day")) or s["day"] < 0:
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
		for key in ["branch_id", "settlement_id", "head_id"]:
			if not valid_int(h.get(key)):
				return false
		if registry.find("branches", int(h["branch_id"])).is_empty() or registry.find("settlements", int(h["settlement_id"])).is_empty():
			return false
		if registry.find("characters", int(h["head_id"])).get("household_id") != h["id"]:
			return false
	for c in s["clans"]:
		for key in ["leader_id", "home_settlement_id"]:
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

static func validate(s: Dictionary) -> bool:
	if s.get("schema_version") != VERSION or not validate_base(s):
		return false
	for key in ["accounts", "assets", "enterprises", "ledger", "chronicle"]:
		if not s.get(key) is Array:
			return false
	if not valid_int(s.get("last_economy_day")) or s["last_economy_day"] < 0 or s["last_economy_day"] > s["day"] or int(s["last_economy_day"]) % 30 != 0:
		return false
	var registry = Registry.new()
	registry.rebuild(s)
	var owners: Dictionary = {}
	var account_ids: Dictionary = {}
	for a in s["accounts"]:
		if not a is Dictionary:
			return false
		for key in ["id", "owner_id", "cash", "grain"]:
			if not valid_int(a.get(key)) or a[key] < 0:
				return false
		if a["id"] == 0 or a.get("owner_kind") not in Economy.OWNER_TYPES:
			return false
		var kind := str(a["owner_kind"])
		var id := int(a["owner_id"])
		var owner := Economy.owner_key(kind, id)
		if owners.has(owner) or account_ids.has(int(a["id"])) or registry.find(kind, id).is_empty():
			return false
		owners[owner] = true
		account_ids[int(a["id"])] = true
	for kind in Economy.OWNER_TYPES:
		for entity in s[kind]:
			if not owners.has(Economy.owner_key(kind, int(entity["id"]))):
				return false
			for key in ["cash", "grain", "land"]:
				if entity.has(key):
					return false
	var assets: Dictionary = {}
	for a in s["assets"]:
		if not a is Dictionary:
			return false
		for key in ["id", "owner_id", "settlement_id", "area"]:
			if not valid_int(a.get(key)):
				return false
		if a["id"] <= 0 or a["area"] <= 0 or assets.has(int(a["id"])) or a.get("type") != "farmland" or not a.get("name") is String:
			return false
		if not owners.has(Economy.owner_key(str(a.get("owner_kind")), int(a["owner_id"]))) or registry.find("settlements", int(a["settlement_id"])).is_empty():
			return false
		assets[int(a["id"])] = true
	var operated: Dictionary = {}
	var enterprises: Dictionary = {}
	for e in s["enterprises"]:
		if not e is Dictionary:
			return false
		for key in ["id", "asset_id", "manager_id", "last_harvest"]:
			if not valid_int(e.get(key)):
				return false
		if e["id"] <= 0 or e["last_harvest"] < 0 or enterprises.has(int(e["id"])) or operated.has(int(e["asset_id"])) or not assets.has(int(e["asset_id"])):
			return false
		if e.get("policy") != "self_farm" or not e.get("name") is String:
			return false
		if e["manager_id"] != -1 and not s["characters"].any(func(p): return p["id"] == e["manager_id"]):
			return false
		operated[int(e["asset_id"])] = true
		enterprises[int(e["id"])] = true
	for entry in s["ledger"]:
		if not entry is Dictionary:
			return false
		for key in ["day", "account_id", "delta"]:
			if not valid_int(entry.get(key)):
				return false
		if entry["day"] < 0 or entry["day"] > s["day"] or not account_ids.has(int(entry["account_id"])) or entry.get("resource") not in ["cash", "grain"] or not entry.get("reason") is String:
			return false
	for entry in s["chronicle"]:
		if not entry is Dictionary or not valid_int(entry.get("day")) or not entry.get("text") is String:
			return false
	return true
