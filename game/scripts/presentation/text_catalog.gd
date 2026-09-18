extends RefCounted
## S00 text entry point; the full content validator belongs to S13.

const DATA = preload("res://content/text/zh_CN.json")

static func format(key: String, params: Dictionary = {}) -> String:
	var strings: Dictionary = DATA.data["strings"]
	if not strings.has(key):
		push_error("Missing text key: " + key)
		return "[missing:%s]" % key
	return str(strings[key]).format(params)
