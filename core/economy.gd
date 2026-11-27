extends RefCounted
## Integer grain (shi), cash (guan), land (mu). No implicit market creation of cash.
const OWNER_TYPES = ["clans", "branches", "households", "characters", "polities"]

static func owner_key(kind: String, id: int) -> String:
	return "%s:%d" % [kind, id]

static func account(s: Dictionary, kind: String, id: int) -> Dictionary:
	for a in s["accounts"]:
		if a["owner_kind"] == kind and int(a["owner_id"]) == id:
			return a
	return {}

static func migrate(s: Dictionary) -> Dictionary:
	s["accounts"] = []
	s["assets"] = []
	s["enterprises"] = []
	s["ledger"] = []
	s["chronicle"] = []
	s["last_economy_day"] = int(s["day"]) - int(s["day"]) % 30
	for kind in OWNER_TYPES:
		for owner in s[kind]:
			var id := int(owner["id"])
			var a := {"id": s["accounts"].size() + 1, "owner_kind": kind, "owner_id": id, "cash": int(owner.get("cash", 0)), "grain": int(owner.get("grain", 0))}
			s["accounts"].append(a)
			var land := int(owner.get("land", 0))
			if land > 0:
				var asset_id: int = s["assets"].size() + 1
				var location := int(owner.get("home_settlement_id", owner.get("settlement_id", -1)))
				var manager := int(owner.get("leader_id", owner.get("head_id", -1)))
				s["assets"].append({"id": asset_id, "name": str(owner["name"]) + "田地", "type": "farmland", "owner_kind": kind, "owner_id": id, "settlement_id": location, "area": land})
				s["enterprises"].append({"id": asset_id, "name": str(owner["name"]) + "田庄", "asset_id": asset_id, "manager_id": manager, "policy": "self_farm", "last_harvest": 0})
			owner.erase("cash")
			owner.erase("grain")
			owner.erase("land")
	s["schema_version"] = 3
	return s

static func summary(s: Dictionary, kind: String, id: int) -> Dictionary:
	var a := account(s, kind, id)
	var land := 0
	for asset in s["assets"]:
		if asset["owner_kind"] == kind and int(asset["owner_id"]) == id:
			land += int(asset["area"])
	return {"cash": int(a.get("cash", 0)), "grain": int(a.get("grain", 0)), "land": land}

static func record(s: Dictionary, a: Dictionary, resource: String, delta: int, reason: String, day: int) -> void:
	if delta == 0:
		return
	a[resource] = int(a[resource]) + delta
	s["ledger"].append({"day": day, "account_id": a["id"], "resource": resource, "delta": delta, "reason": reason})

static func settle_month(s: Dictionary, day: int) -> void:
	if day % 30 != 0 or day <= int(s["last_economy_day"]):
		return
	s["last_economy_day"] = day
	# Harvest at the end of month 9. Simplified one crop per year.
	if day % 360 == 270:
		for e in s["enterprises"]:
			var asset: Dictionary = {}
			for candidate in s["assets"]:
				if candidate["id"] == e["asset_id"]:
					asset = candidate
					break
			if asset.is_empty():
				continue
			var a := account(s, asset["owner_kind"], int(asset["owner_id"]))
			if a.is_empty():
				continue
			var skill := 50
			for p in s["characters"]:
				if p["id"] == e["manager_id"]:
					skill = int(p["skills"][2])
					break
			var output := floori(int(asset["area"]) * (1.0 + skill / 100.0))
			e["last_harvest"] = output
			record(s, a, "grain", output, "秋收", day)
			s["chronicle"].append({"day": day, "text": "%s秋收%d石" % [e["name"], output]})
	# Each registered household member consumes one shi per month.
	for h in s["households"]:
		var demand := 0
		for p in s["characters"]:
			if p["household_id"] == h["id"]:
				demand += 1
		var a := account(s, "households", int(h["id"]))
		var supplied := mini(demand, int(a["grain"]))
		record(s, a, "grain", -supplied, "家庭口粮", day)
		if supplied < demand:
			s["chronicle"].append({"day": day, "text": "%s缺粮%d石" % [h["name"], demand - supplied]})

static func transfer(s: Dictionary, source: Dictionary, target: Dictionary, resource: String, amount: int, reason: String) -> bool:
	if source.is_empty() or target.is_empty() or source["id"] == target["id"] or resource not in ["cash", "grain"] or amount <= 0 or int(source[resource]) < amount:
		return false
	var day := int(s["day"])
	record(s, source, resource, -amount, reason, day)
	record(s, target, resource, amount, reason, day)
	return true
