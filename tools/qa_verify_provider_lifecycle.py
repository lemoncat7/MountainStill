#!/usr/bin/env python3
"""Strict source or actual-PCK lifecycle regression gate; Godot exit0 is not enough."""
import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import sys

EXPECTED_CASES = [
    "actual_freed_object", "builtin_fan", "builtin_sword", "builtin_unarmed",
    "null_pose_provider", "scalar_pose_provider", "live_unknown_pose_provider",
    "null_strike_provider", "scalar_strike_provider", "live_unknown_strike_provider",
    "dead_pose", "dead_strike", "dead_both", "nested_dead_hero", "nested_dead_enemy",
    "nested_dead_definition", "live_custom",
]
RESULT_PREFIX = "PROVIDER_LIFECYCLE_RESULT "
CASE_PREFIX = "PROVIDER_LIFECYCLE_CASE "


def pack_project_error(project, output):
    project, output = project.resolve(), output.resolve()
    if not project.is_dir() or any(project.iterdir()):
        return "actual-pack execution requires an existing completely empty project directory"
    if output == project or project in output.parents:
        return "actual-pack evidence/output must stay outside the empty project directory"
    return None


def validate(returncode, stdout, stderr):
    errors = []
    if returncode != 0:
        errors.append(f"process exit {returncode}")
    if re.search(r"SCRIPT ERROR|Parse Error|(?:^|\n)ERROR:", stdout + "\n" + stderr):
        errors.append("Godot error output (exit0 alone is not success)")
    case_lines = [line[len(CASE_PREFIX):] for line in stdout.splitlines() if line.startswith(CASE_PREFIX)]
    if case_lines != EXPECTED_CASES:
        errors.append("missing, duplicated, reordered, or unexpected case markers")
    summaries = [line[len(RESULT_PREFIX):] for line in stdout.splitlines() if line.startswith(RESULT_PREFIX)]
    result = None
    if len(summaries) != 1:
        errors.append("expected exactly one completion summary")
    else:
        try:
            result = json.loads(summaries[0])
            if not isinstance(result, dict) or result.get("schema") != 1:
                errors.append("invalid summary schema")
            elif (result.get("checks") != 62 or result.get("failures") != 0
                  or result.get("cases") != EXPECTED_CASES
                  or not str(result.get("engine", "")).startswith("4.6.3")):
                errors.append("incomplete or failed Godot 4.6.3 regression summary")
        except (json.JSONDecodeError, TypeError):
            errors.append("invalid completion JSON")
    return {"passed": not errors, "errors": errors, "result": result}


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--godot", default="godot")
    p.add_argument("--project", required=True, type=Path)
    p.add_argument("--script", type=Path, default=Path(__file__).resolve().parents[1] / "tests/test_provider_lifecycle_guard.gd")
    p.add_argument("--main-pack", type=Path, help="Actual exported PCK or embedded Windows EXE; use an empty project directory")
    p.add_argument("--output", required=True, type=Path)
    a = p.parse_args()
    if a.main_pack:
        error = pack_project_error(a.project, a.output)
        if error:
            p.error(error)
        if not a.main_pack.is_file():
            p.error("actual pack does not exist")
    a.output.mkdir(parents=True, exist_ok=True)
    env = os.environ.copy()
    for name, child in [("HOME", "home"), ("XDG_DATA_HOME", "data"), ("XDG_CONFIG_HOME", "config"), ("XDG_CACHE_HOME", "cache")]:
        folder = a.output.resolve() / "isolated" / child
        folder.mkdir(parents=True, exist_ok=True)
        env[name] = str(folder)
    command = [a.godot, "--headless", "--path", str(a.project.resolve())]
    if a.main_pack:
        command.extend(["--main-pack", str(a.main_pack.resolve())])
    command.extend(["--script", str(a.script.resolve())])
    try:
        process = subprocess.run(command, env=env, capture_output=True, text=True, timeout=180)
        code, stdout, stderr = process.returncode, process.stdout, process.stderr
    except subprocess.TimeoutExpired as exc:
        code = 124
        stdout = exc.stdout or b""
        stderr = exc.stderr or b""
        if isinstance(stdout, bytes): stdout = stdout.decode(errors="replace")
        if isinstance(stderr, bytes): stderr = stderr.decode(errors="replace")
        stderr += "\nTIMEOUT after 180 seconds\n"
    (a.output / "stdout.txt").write_text(stdout)
    (a.output / "stderr.txt").write_text(stderr)
    result = validate(code, stdout, stderr)
    result.update({"returncode": code, "command": command, "actual_pack": str(a.main_pack.resolve()) if a.main_pack else None})
    (a.output / "result.json").write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps(result, indent=2))
    return 0 if result["passed"] else 1


if __name__ == "__main__":
    sys.exit(main())
