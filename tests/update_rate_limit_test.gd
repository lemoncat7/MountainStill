extends SceneTree
const Rate = preload("res://scripts/update_rate_limit.gd")
var checks := 0
var failures := 0
const NOW := 1445412480.0 # Wed, 21 Oct 2015 07:28:00 GMT
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)
func result(code: int, headers: Array = [], message: String = "", now: float = NOW) -> Dictionary:
	return Rate.response(code, PackedStringArray(headers), JSON.stringify({"message": message}).to_utf8_buffer(), now)
func delay(code: int, headers: Array = [], message: String = "", now: float = NOW) -> int:
	return result(code, headers, message, now).get("seconds", -1)
func _init() -> void:
	check(result(200).is_empty(), "success is not rate limited")
	check(result(500, ["Retry-After: 20"]).is_empty(), "503/500 retry not conflated")
	check(result(403).is_empty(), "ordinary forbidden is not rate limited")
	check(result(403, [], "Resource not accessible by integration").is_empty(), "permissions remain distinct")
	check(delay(429) == 60, "429 missing headers bounded fallback")
	check(delay(403, ["X-RateLimit-Remaining: 0", "X-RateLimit-Reset: 1445412510"]) == 30, "primary reset")
	check(delay(403, ["x-RaTeLiMiT-ReMaInInG: 0", "x-ratelimit-reset: 1445412510"]) == 30, "case insensitive headers")
	check(result(403, ["X-RateLimit-Remaining: 12"]).is_empty(), "positive remaining does not imply limit")
	check(delay(403, [], "API rate limit exceeded for 192.0.2.1.") == 60, "GitHub primary JSON message")
	check(delay(403, [], "You have exceeded a secondary rate limit.") == 60, "secondary message")
	check(delay(403, [], "You have triggered an abuse detection mechanism.") == 60, "abuse limit")
	check(delay(403, ["Retry-After: 30"]) == 30, "403 retry-after evidence")
	check(delay(429, ["Retry-After: 0"]) == 1, "zero retry avoids immediate loop")
	check(delay(429, ["Retry-After: 999999999999"]) == 3600, "huge valid delay bounded")
	for invalid in ["-3", "+5", "1.5", "nan", "inf", "10000000000000", ""]:
		check(delay(429, ["Retry-After: " + invalid]) == 60, "malformed retry fallback " + invalid)
		check(result(403, ["Retry-After: " + invalid]).is_empty(), "malformed retry not evidence " + invalid)
	check(delay(429, ["Date: Wed, 21 Oct 2015 07:28:00 GMT", "Retry-After: Wed, 21 Oct 2015 07:29:00 GMT"], "", 0.0) == 60, "HTTP date ignores wrong local clock")
	check(delay(403, ["Date: Wed, 21 Oct 2015 07:28:00 GMT", "X-RateLimit-Remaining: 0", "X-RateLimit-Reset: 1445412510"], "", 9999999999.0) == 30, "server date shields future local clock")
	check(delay(403, ["X-RateLimit-Remaining: 0", "X-RateLimit-Reset: 1"]) == 1, "past reset permits next-second retry")
	check(delay(403, ["X-RateLimit-Remaining: 0", "X-RateLimit-Reset: 999999999999"]) == 3600, "future reset bounded")
	check(delay(403, ["X-RateLimit-Remaining: 0", "X-RateLimit-Reset: 1445412510"], "", NAN) == 60, "invalid clock conservative fallback")
	check(delay(403, ["Retry-After: Wed, 21 Oct 2015 07:29:00 GMT"], "", NAN) == 60, "valid date with invalid clock still signals limit")
	check(delay(429, ["Retry-After: Wed, 21 Oct 2015 07:27:00 GMT"]) == 1, "past retry date")
	check(delay(429, ["Retry-After: Tue, 29 Feb 2023 07:28:00 GMT"]) == 60, "invalid nonleap date rejected")
	check(Rate._http_date("Thu, 29 Feb 2024 07:28:00 GMT") > 0, "leap day valid")
	check(Rate._http_date("Wed, 31 Apr 2024 07:28:00 GMT") < 0, "invalid month day rejected")
	check(Rate._http_date("Wed, 21 Oct 2015 24:28:00 GMT") < 0, "invalid hour rejected")
	check(delay(429, ["Retry-After: " + "9".repeat(2000)]) == 60, "oversized header ignored")
	check(Rate.response(403, [], "API rate limit exceeded".to_utf8_buffer(), NOW).is_empty(), "nonJSON not falsely classified")
	check(Rate.response(403, [], JSON.stringify({"message": "API rate limit exceeded" + "a".repeat(8192)}).to_utf8_buffer(), NOW).is_empty(), "oversized message ignored")
	check(delay(429, ["Retry-After: 15", "X-RateLimit-Remaining: 0", "X-RateLimit-Reset: 1445412510"]) == 15, "retry-after takes precedence")
	check(delay(429, ["Retry-After: 15", "Retry-After: 900"]) == 15, "duplicate headers deterministic first value")
	check(result(403, ["X-RateLimit-Remaining: 0"]).reason == "primary", "primary reason")
	check(result(403, [], "You have exceeded a secondary rate limit.").reason == "secondary", "secondary reason")
	check(result(429).reason == "http_429", "generic 429 reason")
	check(result(403, ["Retry-After: 3"]).reason == "retry_after", "retry evidence reason")
	check(delay(429, ["Date: nonsense", "Retry-After: Wed, 21 Oct 2015 07:29:00 GMT"]) == 60, "bad server date uses local time")
	check(delay(403, ["X-RateLimit-Remaining: 0", "X-RateLimit-Reset: nonsense"]) == 60, "malformed reset fallback")
	check(delay(403, ["X-RateLimit-Remaining: 0", "X-RateLimit-Reset: 1445412481"], "", NOW + 0.2) == 1, "fractional delay rounds up")
	check(result(403, ["X-RateLimit-Remaining: -0"]).is_empty(), "signed remaining not trusted")
	check(result(403, [], "This API rate limit is not exceeded").is_empty(), "nonexplicit rate wording not trusted")
	check(Rate._http_date("Sun, 29 Feb 2100 07:28:00 GMT") < 0, "century not leap")
	check(Rate._http_date("Tue, 29 Feb 2000 07:28:00 GMT") > 0, "400-year leap")
	print("UPDATE RATE LIMIT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
