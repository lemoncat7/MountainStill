#!/usr/bin/env python3
"""Fail-closed offline verifier for one exact v1.3.43 job output; no network."""
import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import re
import stat
import zipfile

TAG = "v1.3.43"
SOURCE = "9175b882fe7ab0c2b9fff045d31a616e6edd377b"
PREFIX = f"MountainStill-{TAG}"
WIN, MAC, SRC = (f"{PREFIX}-{label}.zip" for label in ("Windows-x86_64", "macOS-Universal", "Public-Source"))
PCK = {p: f"MountainStill-{p}.pck" for p in ("windows", "macos")}
MANIFEST, SUMS = "MountainStill-update.json", "SHA256SUMS.txt"
ASSETS = (WIN, MAC, SRC, *PCK.values(), SUMS, MANIFEST)
MAX_SIZE = 700 * 1024**2
HASH = r"[a-f0-9]{64}"

def require(value, message):
    if not value:
        raise ValueError(message)

def unique_object(items):
    out = {}
    for key, value in items:
        require(key not in out, "Duplicate JSON key: " + key)
        out[key] = value
    return out

def parse_json(path):
    return json.loads(path.read_text(encoding="utf-8"), object_pairs_hook=unique_object)

def fingerprint(path):
    require(path.is_file() and not path.is_symlink(), f"Not a regular file: {path.name}")
    size = path.stat().st_size
    require(0 < size <= MAX_SIZE, f"Invalid file size: {path.name}")
    with path.open("rb") as f:
        sha = hashlib.file_digest(f, "sha256").hexdigest()
    return dict(size=size, sha256=sha)

def validate_zip(path):
    with zipfile.ZipFile(path) as z:
        names = set()
        count = 0
        for i in z.infolist():
            name = i.filename
            parts = name.rstrip("/").split("/")
            require(name == i.orig_filename and parts and all(parts) and all(p not in (".", "..") for p in parts)
                    and ":" not in name and "\\" not in name and not stat.S_ISLNK(i.external_attr >> 16)
                    and name not in names and name == str(PurePosixPath(name)) + ("/" if i.is_dir() else ""),
                    f"Unsafe ZIP entry in {path.name}: {name!r}")
            count += i.file_size
            require(count <= MAX_SIZE, f"ZIP expansion over ceiling: {path.name}")
            names.add(name)
        require(z.testzip() is None, f"ZIP CRC error: {path.name}")
    if path.name == WIN:
        require("MountainStill/MountainStill.exe" in names, "Windows ZIP missing executable")
    if path.name == MAC:
        p = "山隐 · Mountain Still.app/Contents/"
        require({p+"Info.plist", p+"MacOS/山隐 · Mountain Still", p+"Resources/山隐 · Mountain Still.pck"} <= names,
                "macOS ZIP missing application files")
    if path.name == SRC:
        require({"MountainStill/project.godot", "MountainStill/main.tscn"} <= names,
                "Source archive missing project files")

def verify(root, report):
    actual = {name: fingerprint(root / name) for name in ASSETS}
    require(sum(x["size"] for x in actual.values()) <= MAX_SIZE, "Asset total exceeds ceiling")
    require(fingerprint(report)["size"] <= 65536, "Build report too large")
    record = parse_json(report)
    require(record.get("source_sha") == SOURCE and record.get("tracked_source_unchanged") is True
            and record.get("godot_version") == "4.6.3.stable.official.7d41c59c4"
            and record.get("godot_archive_sha256") == "d0bc2113065e481c9c2c2b2c37daa4e8be3fe9e27f0ab9ab0b6096e9a37907f3"
            and record.get("templates_archive_sha256") == "3fbe2c0e2dec9d537ab9ec97bcf8da91dcf23357fc51f67092dd068d839290a8"
            and record.get("status") == "REBUILT_CANDIDATE_NOT_RELEASED",
            "Incorrect build provenance")
    seen = {}
    for row in record["files"]:
        name = row["name"]
        require(name in actual and name not in seen, f"Unsafe, duplicate or unexpected report asset: {name!r}")
        seen[name] = {k: row[k] for k in ("size", "sha256")}
    require(seen == actual, "Local bytes do not match all seven build fingerprints")

    require(actual[SUMS]["size"] <= 4096, "Checksum list too large")
    checks = {}
    for line in (root / SUMS).read_text(encoding="ascii").splitlines():
        m = re.fullmatch(f"({HASH})  ([A-Za-z0-9_.-]+)", line)
        require(m, "Malformed checksum line")
        sha, name = m.groups()
        require(name != SUMS and name in actual and name not in checks, "Unexpected/duplicate checksum")
        checks[name] = sha
    require(checks == {k: v["sha256"] for k, v in actual.items() if k != SUMS}, "Checksum coverage or integrity mismatch")

    require(actual[MANIFEST]["size"] <= 4096, "Update manifest too large")
    manifest = parse_json(root / MANIFEST)
    constants = dict(schema=1, version="1.3.43", engine="4.6.3", bootstrap=1, save_schema=4)
    require(set(manifest) == (set(constants) | {"packages"})
            and all(type(manifest[k]) is type(v) and manifest[k] == v for k,v in constants.items())
            and set(manifest["packages"]) == set(PCK), "Manifest schema, version, or platform mismatch")
    for platform, name in PCK.items():
        spec = manifest["packages"][platform]
        correct = dict(kind="pck", asset=name, **actual[name], restart_required=True)
        require(set(spec) == set(correct) and all(type(spec[k]) is type(v) and spec[k] == v for k,v in correct.items()),
                f"Updater {platform} does not bind exact package bytes")
        with (root / name).open("rb") as f:
            require(f.read(4) == b"GDPC", f"Invalid PCK magic: {name}")

    for name in (WIN,MAC,SRC):
        validate_zip(root / name)
    return actual

if __name__ == "__main__":
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("directory", type=Path)
    ap.add_argument("build_report", type=Path)
    a = ap.parse_args()
    print(json.dumps(verify(a.directory, a.build_report), indent=2, sort_keys=True))
