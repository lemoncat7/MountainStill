extends SceneTree
const Policy = preload("res://scripts/update_policy.gd")
const Service = preload("res://scripts/update_service.gd")
var checks = 0
var failures = 0
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		push_error(label)
		failures += 1
func _initialize() -> void:
	for invalid in ["", "banana", "1.2", "01.2.3", "1.2.3-test.01", "1.2.3/evil", "1.2.3\n"]:
		check(Policy.version(invalid).is_empty(), "reject " + invalid)
	var ordered = ["1.2.3-alpha", "1.2.3-alpha.1", "1.2.3-alpha.beta", "1.2.3-beta", "1.2.3-beta.2", "1.2.3-beta.11", "1.2.3-rc.1", "1.2.3", "1.2.4", "1.10.0", "2.0.0"]
	for i in range(ordered.size() - 1):
		check(Policy.compare(ordered[i], ordered[i+1]) < 0, "semver ascending")
		check(Policy.compare(ordered[i+1], ordered[i]) > 0, "semver descending")
	check(Policy.compare("v1.2.3+meta", "1.2.3+other") == 0, "build ignored")
	var release = {"tag_name":"v1.3.9-test.2", "draft":false, "prerelease":true, "assets":[]}
	var stable = {"tag_name":"v1.3.9", "draft":false, "prerelease":false}
	check(Policy.select_release([release], "1.3.9-test.1", "stable").is_empty(), "stable excludes prerelease")
	check(Policy.select_release([release], "1.3.9-test.1", "testing") == release, "testing includes prerelease")
	check(Policy.select_release([release,stable], "1.3.9-test.1", "testing") == stable, "stable beats prerelease")
	check(Policy.select_release([release], "1.3.9", "testing").is_empty(), "no downgrade")
	var asset = {"name":"MountainStill-windows.pck", "state":"uploaded", "size":1234, "browser_download_url":Policy.REPO + "/releases/download/v1.3.9-test.2/MountainStill-windows.pck"}
	release.assets.append(asset)
	var manifest = {"schema":1,"save_schema":4,"bootstrap":1,"engine":"4.6.3","version":"1.3.9-test.2","packages":{"windows":{"kind":"pck","asset":asset.name,"size":1234,"sha256":"a".repeat(64),"restart_required":true}}}
	check(not Policy.validate_manifest(manifest, release, "windows").is_empty(), "valid manifest")
	check(Policy.validate_manifest(manifest, release, "macos").is_empty(), "wrong OS")
	for field in ["schema", "save_schema", "bootstrap", "engine", "version"]:
		var bad = manifest.duplicate(true)
		bad[field] = "invalid"
		check(Policy.validate_manifest(bad,release,"windows").is_empty(), "reject " + field)
	for pair in [["size",-1],["size",1234.1],["size",Policy.MAX_PACK+1],["asset","../evil.pck"],["asset","evil.exe"],["sha256","g".repeat(64)],["kind","zip"],["restart_required",false]]:
		var bad = manifest.duplicate(true)
		bad.packages.windows[pair[0]] = pair[1]
		check(Policy.validate_manifest(bad,release,"windows").is_empty(), "reject pack " + pair[0])
	for url in ["https://evil.example/pck", "http://github.com/lemoncat7/MountainStill/releases/download/v1.3.9-test.2/MountainStill-windows.pck", "https://github.com/lemoncat7/MountainStill.evil/releases/download/v1.3.9-test.2/MountainStill-windows.pck"]:
		var bad = release.duplicate(true)
		bad.assets[0].browser_download_url = url
		check(Policy.validate_manifest(manifest,bad,"windows").is_empty(), "reject foreign URL")
	check(not Policy.allowed_redirect("https://release-assets.githubusercontent.com.evil/x"), "redirect host exact")
	check(not Policy.allowed_redirect("http://release-assets.githubusercontent.com/x"), "redirect TLS")
	check(Policy.allowed_redirect("https://release-assets.githubusercontent.com/x?sig=y"), "CDN permitted")
	for value in [null, false, true, 0, 2, 1.5, [], {}, "bad"]:
		for field in ["schema", "save_schema", "bootstrap", "engine", "version", "packages"]:
			var bad = manifest.duplicate(true)
			bad[field] = value
			check(Policy.validate_manifest(bad,release,"windows").is_empty(), "malformed top-level types")
		for field in ["kind", "asset", "size", "sha256", "restart_required"]:
			var bad = manifest.duplicate(true)
			bad.packages.windows[field] = value
			if field == "restart_required" and value is bool and value: continue
			check(Policy.validate_manifest(bad,release,"windows").is_empty(), "malformed pack types")
	check(Policy.compare("1.0.0--1", "1.0.0-2") > 0, "hyphen identifier is not numeric")
	check(Policy.validate_content({"schema":1,"accent":"#aB1234","message":"青山依旧"}), "valid hot content")
	for data in [{}, {"schema":1,"accent":"#abcd","message":"ok"}, {"schema":1,"accent":"#123456","message":""}, {"schema":1,"accent":"#123456","message":"line\nbreak"}, {"schema":1,"accent":"#123456","message":"x".repeat(121)}, {"schema":1,"accent":"#123456","message":"ok","script":"evil.gd"}, {"schema":1,"accent":3,"message":"ok"}]:
		check(not Policy.validate_content(data), "reject unsafe content")
	print("update_policy: %d checks passed" % checks)
	quit(1 if failures else 0)
