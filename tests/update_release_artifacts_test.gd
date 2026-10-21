extends SceneTree
const Policy = preload("res://scripts/update_policy.gd")
const Guard = preload("res://scripts/update_pack_guard.gd")
func _init() -> void:
	var folder = OS.get_cmdline_user_args()[0]
	var manifest = JSON.parse_string(FileAccess.get_file_as_string(folder.path_join("MountainStill-update.json")))
	var release = {"tag_name":"v" + manifest.version,"draft":false,"prerelease":true,"assets":[]}
	for platform in ["windows", "macos"]:
		var p = manifest.packages[platform]
		release.assets.append({"name":p.asset,"state":"uploaded","size":p.size,"digest":"sha256:" + p.sha256,"browser_download_url":Policy.REPO + "/releases/download/" + release.tag_name + "/" + p.asset})
	for platform in ["windows", "macos"]:
		var validated = Policy.validate_manifest(manifest, release, platform)
		assert(not validated.is_empty(), "production manifest policy")
		var path = folder.path_join(validated.asset)
		assert(FileAccess.get_sha256(path) == validated.sha256, "published SHA matches actual PCK")
		assert(FileAccess.open(path, FileAccess.READ).get_length() == int(validated.size), "published size matches actual PCK")
		assert(Guard.validate(path), "runtime namespace/layout guard accepts final PCK")
		print("ARTIFACT_POLICY_GUARD: ", platform, " ", validated.version, " PASS")
	quit()
