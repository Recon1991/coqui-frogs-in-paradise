# /scripts/services/I18n.gd
extends Node
# (No class_name when used as Autoload "I18n")

## CONFIG
const CSV_PATH := "res://i18n/coqui_key_translations.csv"
const DEV_SHOW_MISSING_KEYS := true  # show ❓prefix for missing keys in dev

var current_locale: String = "en"
var _warned: Dictionary = {}  # String -> bool

func _ready() -> void:
	_load_csv_translations(CSV_PATH)
	set_locale("en")  # default English (source + fallback)

## PUBLIC API ----------------------------------------------------------

func set_locale(locale_code: String) -> void:
	current_locale = locale_code
	TranslationServer.set_locale(locale_code)

func t(key: String, args: Dictionary = {}) -> String:
	var s: String = TranslationServer.translate(key)
	var missing: bool = (s == key)
	if missing and DEV_SHOW_MISSING_KEYS:
		s = "❓" + key
		_warn_once(key)
	for k in args.keys():
		s = s.replace("{" + str(k) + "}", str(args[k]))
	return s

func tp(one_key: String, other_key: String, n: int) -> String:
	var key: String = one_key if n == 1 else other_key
	return t(key, {"n": n})

func a11y(key: String, args: Dictionary = {}) -> String:
	return t(key, args)

func reload_csv() -> void:
	_clear_translations()
	_load_csv_translations(CSV_PATH)
	set_locale(current_locale)

## INTERNALS ----------------------------------------------------------

func _warn_once(key: String) -> void:
	if not _warned.has(key):
		_warned[key] = true
		push_warning("[i18n] Missing translation: " + key)

func _clear_translations() -> void:
	# Newly loaded translations will override previous messages.
	pass

func _load_csv_translations(path: String) -> void:
	if not FileAccess.file_exists(path):
		push_warning("[i18n] Missing CSV: " + path)
		return

	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	var header: PackedStringArray = PackedStringArray()
	var locales: PackedStringArray = PackedStringArray()         # e.g., ["en","es","ja"]
	var locale_to_tr: Dictionary = {}                            # String -> Translation

	var line_idx: int = 0
	while not file.eof_reached():
		var raw: String = file.get_line()

		if raw.strip_edges() == "":
			line_idx += 1
			continue

		var cols: PackedStringArray = _split_csv_line(raw)
		if cols.is_empty():
			line_idx += 1
			continue

		if line_idx == 0:
			header = cols
			if header.size() < 2 or String(header[0]).strip_edges() != "key":
				push_error("[i18n] CSV header must start with 'key'. Got: " + str(header))
				return
			# from column 1 to the end
			locales = header.slice(1)  # still a PackedStringArray
			for loc_str in locales:
				var tr_res: Translation = Translation.new()
				tr_res.locale = String(loc_str).strip_edges()
				locale_to_tr[tr_res.locale] = tr_res
		else:
			var key: String = String(cols[0]).strip_edges()
			if key == "" or key.begins_with("#"):
				line_idx += 1
				continue

			var limit: int = min(cols.size(), header.size())
			for i: int in range(1, limit):
				var loc: String = String(header[i]).strip_edges()
				if loc == "" or not locale_to_tr.has(loc):
					continue
				var text: String = String(cols[i])
				if text != "":
					var tr_res: Translation = locale_to_tr[loc] as Translation
					tr_res.add_message(key, text)

		line_idx += 1

	# Register all locales
	for loc_str in locales:
		var loc: String = String(loc_str)
		if locale_to_tr.has(loc):
			TranslationServer.add_translation(locale_to_tr[loc] as Translation)

func _split_csv_line(s: String) -> PackedStringArray:
	# Minimal CSV parser handling quotes, commas, and escaped quotes ("")
	var result: PackedStringArray = PackedStringArray()
	var cur: String = ""
	var in_quotes: bool = false
	var i: int = 0
	while i < s.length():
		var ch: String = s[i]
		if ch == '"':
			if in_quotes and i + 1 < s.length() and s[i + 1] == '"':
				cur += '"'
				i += 1
			else:
				in_quotes = not in_quotes
		elif ch == ',' and not in_quotes:
			result.append(cur)
			cur = ""
		else:
			cur += ch
		i += 1
	result.append(cur)
	return result
