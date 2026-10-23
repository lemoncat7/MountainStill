extends RefCounted
## Pure interpretation of public HTTP rate limits. No transport or credentials.
const DEFAULT_SECONDS := 60
const MAX_SECONDS := 3600

static func response(code: int, headers: PackedStringArray, body: PackedByteArray, now: float) -> Dictionary:
	if code not in [403, 429]: return {}
	var fields: Dictionary = {}
	# Bound parsing even if a server returns unexpectedly large headers/body.
	for index in range(mini(headers.size(), 128)):
		var header: String = headers[index]
		if header.length() > 1024: continue
		var colon := header.find(":")
		if colon < 1: continue
		var key := header.substr(0, colon).strip_edges().to_lower()
		if key in ["date", "retry-after", "x-ratelimit-remaining", "x-ratelimit-reset"] and not fields.has(key):
			fields[key] = header.substr(colon + 1).strip_edges()
	var remaining := _unsigned(str(fields.get("x-ratelimit-remaining", "")))
	var server_date := _http_date(str(fields.get("date", "")))
	var reference := server_date if server_date >= 0.0 else now
	if not is_finite(reference) or reference < 0.0: reference = -1.0
	var retry := str(fields.get("retry-after", ""))
	var retry_seconds := _unsigned(retry)
	var valid_retry := retry_seconds >= 0.0
	if retry_seconds < 0.0:
		var retry_date := _http_date(retry)
		valid_retry = retry_date >= 0.0
		if retry_date >= 0.0 and reference >= 0.0: retry_seconds = maxf(0.0, retry_date - reference)
	var message := ""
	if body.size() <= 8192:
		var parser := JSON.new()
		if parser.parse(body.get_string_from_utf8()) == OK and parser.data is Dictionary and parser.data.get("message") is String:
			message = str(parser.data.message).to_lower()
	var secondary := message.contains("secondary rate limit") or message.contains("abuse detection")
	var primary := remaining == 0.0 or message.contains("api rate limit exceeded")
	if code == 403 and not primary and not secondary and not valid_retry: return {}
	var seconds := float(DEFAULT_SECONDS)
	if retry_seconds >= 0.0:
		seconds = retry_seconds
	elif primary:
		var reset := _unsigned(str(fields.get("x-ratelimit-reset", "")))
		if reset >= 0.0 and reference >= 0.0: seconds = reset - reference
	return {
		"seconds": int(clampf(ceil(seconds), 1.0, float(MAX_SECONDS))),
		"reason": "primary" if primary else ("secondary" if secondary else ("retry_after" if valid_retry else "http_429"))
	}

static func _unsigned(value: String) -> float:
	if value.is_empty() or value.length() > 12: return -1.0
	for character in value:
		if character < "0" or character > "9": return -1.0
	return value.to_float()

static func _http_date(value: String) -> float:
	# HTTP's preferred IMF-fixdate, e.g. Wed, 21 Oct 2015 07:28:00 GMT.
	# Reject obsolete/ambiguous formats rather than relying on locale parsing.
	if value.length() != 29 or value.substr(3, 2) != ", " or value.substr(7, 1) != " " or value.substr(11, 1) != " " or value.substr(16, 1) != " " or value.substr(19, 1) != ":" or value.substr(22, 1) != ":" or value.substr(25) != " GMT": return -1.0
	if value.left(3) not in ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]: return -1.0
	var month := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"].find(value.substr(8, 3)) + 1
	var year := int(_unsigned(value.substr(12, 4)))
	var day := int(_unsigned(value.substr(5, 2)))
	var hour := int(_unsigned(value.substr(17, 2)))
	var minute := int(_unsigned(value.substr(20, 2)))
	var second := int(_unsigned(value.substr(23, 2)))
	if month < 1 or year < 1970 or year > 9999 or day < 1 or hour < 0 or hour > 23 or minute < 0 or minute > 59 or second < 0 or second > 59: return -1.0
	var days := [31, 29 if year % 4 == 0 and (year % 100 != 0 or year % 400 == 0) else 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
	if day > days[month - 1]: return -1.0
	return float(Time.get_unix_time_from_datetime_dict({"year": year, "month": month, "day": day, "hour": hour, "minute": minute, "second": second}))
