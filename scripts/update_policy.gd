extends RefCounted
## Pure validation; network data is untrusted. Never accept paths from manifests.
const REPO = "https://github.com/lemoncat7/MountainStill"
const API = "https://api.github.com/repos/lemoncat7/MountainStill/releases"
const ENGINE = "4.6.3"
const MAX_PACK = 512 * 1024 * 1024
const MANIFEST = "MountainStill-update.json"

static func version(value: Variant) -> Array:
	if not value is String or value.length() > 128: return []
	var re = RegEx.new()
	re.compile("^v?(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)(?:-([0-9A-Za-z-]+(?:\\.[0-9A-Za-z-]+)*))?(?:\\+([0-9A-Za-z-]+(?:\\.[0-9A-Za-z-]+)*))?$")
	var m = re.search(value)
	if m == null or m.get_string() != value: return []
	var result = [m.get_string(1), m.get_string(2), m.get_string(3), m.get_string(4)]
	for identifier in result[3].split("."):
		if numeric_identifier(identifier) and identifier.length() > 1 and identifier.begins_with("0"): return []
	return result

static func numeric_compare(a: String, b: String) -> int:
	if a.length() != b.length(): return 1 if a.length() > b.length() else -1
	return 0 if a == b else (1 if a > b else -1)

static func compare(a: String, b: String) -> int:
	var av = version(a)
	var bv = version(b)
	if av.is_empty() or bv.is_empty(): return 0
	for i in range(3):
		var c = numeric_compare(av[i], bv[i])
		if c != 0: return c
	if av[3] == bv[3]: return 0
	if av[3] == "": return 1
	if bv[3] == "": return -1
	var ap = av[3].split(".")
	var bp = bv[3].split(".")
	for i in range(mini(ap.size(), bp.size())):
		if ap[i] == bp[i]: continue
		var an = numeric_identifier(ap[i])
		var bn = numeric_identifier(bp[i])
		if an and bn: return numeric_compare(ap[i], bp[i])
		if an != bn: return -1 if an else 1
		return 1 if ap[i] > bp[i] else -1
	return 1 if ap.size() > bp.size() else -1

static func select_release(releases: Array, current: String, channel: String) -> Dictionary:
	var best: Dictionary = {}
	for item in releases:
		if not item is Dictionary or not (item.get("draft") is bool) or item.get("draft"): continue
		var tag = item.get("tag_name", "")
		var parsed = version(tag)
		if parsed.is_empty(): continue
		if channel == "stable" and (not (item.get("prerelease") is bool) or item.get("prerelease") or parsed[3] != ""): continue
		if compare(tag, current) <= 0: continue
		if best.is_empty() or compare(tag, best.tag_name) > 0: best = item
	return best

static func asset(release: Dictionary, name: String) -> Dictionary:
	var assets = release.get("assets", [])
	if not assets is Array: return {}
	var matches: Array = []
	for entry in assets:
		if entry is Dictionary and entry.get("name") is String and entry.get("name") == name: matches.append(entry)
	if matches.size() != 1: return {}
	var found: Dictionary = matches[0]
	var tag = release.get("tag_name", "")
	if version(tag).is_empty(): return {}
	if not found.get("state") is String or found.get("state") != "uploaded": return {}
	if not found.get("browser_download_url") is String or found.get("browser_download_url") != REPO + "/releases/download/" + tag.uri_encode() + "/" + name.uri_encode(): return {}
	return found

static func validate_manifest(data: Variant, release: Dictionary, platform: String) -> Dictionary:
	if not data is Dictionary: return {}
	if not exact_number(data.get("schema"), 1) or data.get("engine") is not String or data.get("engine") != ENGINE or not exact_number(data.get("save_schema"), 4) or not exact_number(data.get("bootstrap"), 1): return {}
	var ver = data.get("version", "")
	if version(ver).is_empty() or ver != str(release.get("tag_name", "")).trim_prefix("v"): return {}
	var packages = data.get("packages", {})
	if not packages is Dictionary or not packages.get(platform) is Dictionary: return {}
	var pack: Dictionary = packages[platform]
	if not pack.get("kind") is String or pack.get("kind") not in ["pck", "content_json"] or not pack.get("restart_required") is bool: return {}
	var hot = pack.kind == "content_json"
	if pack.restart_required == hot: return {}
	var name = pack.get("asset", "")
	if not name is String or name.contains("/") or name.contains("\\") or name.contains(".."): return {}
	if hot and name != "MountainStill-content.json": return {}
	if not hot and not name.ends_with(".pck"): return {}
	var hash_value = pack.get("sha256", "")
	if not hash_value is String or hash_value.length() != 64 or not hash_value.is_valid_hex_number(): return {}
	if hash_value != hash_value.to_lower(): return {}
	var size_value = pack.get("size", 0)
	if not (size_value is int or size_value is float) or size_value != int(size_value) or size_value < 4 or size_value > (16384 if hot else MAX_PACK): return {}
	var published = asset(release, name)
	if published.is_empty() or not exact_number(published.get("size"), int(size_value)): return {}
	var digest = published.get("digest")
	if digest != null and (not digest is String or digest != "sha256:" + hash_value): return {}
	return {"schema": 1, "save_schema": 4, "bootstrap": 1, "version": ver, "engine": ENGINE, "platform": platform, "kind": pack.kind, "asset": name, "size": int(size_value), "sha256": hash_value, "restart_required": not hot, "url": published.browser_download_url, "release_tag": release.tag_name}

static func allowed_redirect(url: String) -> bool:
	# Redirects are followed manually; never allow downgrade, credentials or arbitrary hosts.
	return url.begins_with("https://release-assets.githubusercontent.com/") or url.begins_with("https://objects.githubusercontent.com/github-production-release-asset-")

static func exact_number(value: Variant, expected: int) -> bool:
	return (value is int or value is float) and value == expected

static func numeric_identifier(value: String) -> bool:
	if value.is_empty(): return false
	for c in value.to_ascii_buffer():
		if c < 48 or c > 57: return false
	return true

static func validate_content(data: Variant) -> bool:
	if not data is Dictionary or data.size() != 3: return false
	if not exact_number(data.get("schema"), 1): return false
	if not data.get("accent") is String or not data.get("message") is String: return false
	var color = RegEx.new()
	color.compile("^#[0-9A-Fa-f]{6}$")
	var match_color = color.search(data.accent)
	if match_color == null or match_color.get_string() != data.accent: return false
	if data.message.strip_edges().is_empty() or data.message.length() > 120: return false
	# Reject control characters rather than injecting multiline/UI markup.
	for i in range(data.message.length()):
		if data.message.unicode_at(i) < 32 or data.message.unicode_at(i) == 127: return false
	return true
