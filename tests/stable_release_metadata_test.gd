extends SceneTree
const Policy = preload("res://scripts/update_policy.gd")
const Store = preload("res://scripts/update_store.gd")
const Service = preload("res://scripts/update_service.gd")
var checks := 0
var failures := 0
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)
func _init() -> void:
	check(Store.BUILTIN_VERSION == "1.3.41", "stable installed bootstrap version")
	check(Service.CURRENT_VERSION == "1.3.41", "stable updater version")
	check(ProjectSettings.get_setting("application/config/version") == "1.3.41", "stable project version")
	var stable := {"tag_name":"v1.3.41", "draft":false, "prerelease":false}
	var candidate := {"tag_name":"v1.3.41-test.1", "draft":false, "prerelease":true}
	for channel in ["stable", "testing"]:
		check(Policy.select_release([candidate, stable], "1.3.26", channel) == stable, "old install selects stable: " + channel)
		check(Policy.select_release([candidate, stable], "1.3.41-test.1", channel) == stable, "candidate upgrades to stable: " + channel)
		check(Policy.select_release([candidate, stable], "1.3.41", channel).is_empty(), "stable cannot downgrade/reinstall: " + channel)
	check(Policy.select_release([candidate], "1.3.26", "stable").is_empty(), "stable channel rejects test package")
	var draft := stable.duplicate()
	draft.draft = true
	check(Policy.select_release([draft], "1.3.26", "stable").is_empty(), "draft remains unavailable")
	check(Policy.compare("1.3.42-test.1", "1.3.41") > 0, "next-version update fixture is newer than stable")
	print("Stable release metadata: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
