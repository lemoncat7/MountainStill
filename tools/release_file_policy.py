"""Shared release filter: inspect every path, including binary QA artifacts."""
from pathlib import PurePosixPath

DENIED_PARTS = frozenset({".git", ".godot", ".aws", ".codex", ".ssh", ".cache", ".config", ".local", "__pycache__", "builds", "cache", "caches", "fontconfig", "isolated", "userdata", "user_data", "user-data", "app_userdata", "logs"})
DENIED_SUFFIXES = frozenset({".log", ".pyc", ".bak", ".tmp", ".mp4", ".avi", ".sqlite", ".sqlite3", ".db", ".pem", ".key", ".p12", ".pfx", ".keystore"})
QA_SUFFIXES = frozenset({".md", ".txt", ".json", ".py", ".gd", ".sh", ".sha256", ".exit"})
QA_BINARY_FIXTURES = frozenset({"docs/qa/side-proportion-revision/baseline-pose-samples.bin"})

def exclusion_reason(relative_path):
    path = PurePosixPath(str(relative_path).replace("\\", "/"))
    parts = tuple(part.lower() for part in path.parts)
    if path.is_absolute() or ".." in parts:
        return "unsafe path"
    if any(part in DENIED_PARTS or part.startswith(("isolated-", "isolated_", "xdg-")) or part.endswith(("-userdata", "-user-data", "-isolated", "_isolated")) for part in parts):
        return "generated cache, isolated user data, or private directory"
    name = path.name.lower()
    if path.suffix.lower() in DENIED_SUFFIXES or ".cache-" in name or name in {"cachedir.tag", ".ds_store"}:
        return "log, cache, temporary, or database file"
    if name.startswith(("cultivation_save", ".env")) or name in {"credentials", "credentials.json", "cookies.json", "cookies.txt", "save.json", "settings.json"}:
        return "local user data or credential file"
    if parts[:2] == ("docs", "qa"):
        if any(part in {"home", "tmp", "temp", "config", "data"} for part in parts[2:-1]):
            return "isolated QA environment data"
        if str(path) not in QA_BINARY_FIXTURES and name != ".gdignore" and path.suffix.lower() not in QA_SUFFIXES:
            return "unapproved QA file type"
    return None

if __name__ == "__main__":
    for bad in ["docs/qa/x/cache/fontconfig/a.cache-9", "docs/qa/x/isolated/y/proof.json", "docs/qa/x/logs/a.txt", "docs/qa/x/userdata/file.json", "docs/qa/x/xdg-data/file.json", "docs/qa/x/secret.bin", "docs/qa/x/run.log", "cultivation_save.json", "../outside"]:
        assert exclusion_reason(bad), bad
    for good in ["assets/cultivation/beasts/sources/windup-isolated.png", "assets/cultivation/beasts/sources/windup-isolated.png.import", "docs/qa/results.json", "docs/qa/side-proportion-revision/baseline-pose-samples.bin", "tests/test_save_compatibility.gd"]:
        assert exclusion_reason(good) is None, good
    print("RELEASE FILE POLICY regression: PASS")
