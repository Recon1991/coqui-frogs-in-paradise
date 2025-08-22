# res://scripts/services/Unlocks.gd
extends Node

func is_unlocked(id: String, frogs: Dictionary, habitats: Dictionary, diversity: int, lifetime: float) -> bool:
	if id == "backyard_coqui": return true
	var rules: Dictionary = Config.unlocks.get(id, {}) as Dictionary
	if rules.is_empty(): return true

	# habitats gate
	if rules.has("habitats"):
		var need: Dictionary = rules["habitats"] as Dictionary
		for lane in need.keys():
			if habitats.get(String(lane), 0) < int(need[lane]): return false
	# diversity gate
	if rules.has("diversity") and diversity < int(rules["diversity"]): return false
	# lifetime croaks gate
	if rules.has("lifetime") and lifetime < float(rules["lifetime"]): return false
	# frog counts gate
	if rules.has("frogs"):
		var fneed: Dictionary = rules["frogs"] as Dictionary
		for sid in fneed.keys():
			if frogs.get(String(sid), 0) < int(fneed[sid]): return false
	return true

func hint(id: String) -> String:
	if id == "backyard_coqui": return ""
	var rules: Dictionary = Config.unlocks.get(id, {}) as Dictionary
	if rules.is_empty(): return ""
	var parts: Array[String] = []
	if rules.has("habitats"):
		var lane_txt: Array[String] = []
		for lane in (rules["habitats"] as Dictionary).keys():
			lane_txt.append("%s %s" % [String(lane).capitalize(), _roman(int((rules["habitats"] as Dictionary)[lane]))])
		parts.append("Reach " + ", ".join(lane_txt))
	if rules.has("diversity"): parts.append("Diversity %d" % int(rules["diversity"]))
	if rules.has("lifetime"):  parts.append("Lifetime %.0f croaks" % float(rules["lifetime"]))
	if rules.has("frogs"):
		for sid in (rules["frogs"] as Dictionary).keys():
			parts.append("%s x%d" % [String(sid).capitalize().replace("_"," "), int((rules["frogs"] as Dictionary)[sid])])
	return "Locked — " + "; ".join(parts)

func _roman(n: int) -> String:
	var map := {1000:"M",900:"CM",500:"D",400:"CD",100:"C",90:"XC",50:"L",40:"XL",10:"X",9:"IX",5:"V",4:"IV",1:"I"}
	var s := ""; var x := n
	for k in map.keys():
		var v: int = int(k)
		while x >= v: s += map[k]; x -= v
	return s
