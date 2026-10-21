#!/usr/bin/env python3
"""Package tested build outputs without modifying or hiding OS security settings."""
from pathlib import Path
import hashlib
import shutil
import tarfile
import zipfile

ROOT = Path(__file__).resolve().parents[1]
BUILDS = ROOT / "builds"
DOCUMENTS = [ROOT / name for name in ("README.md", "FIRST_TEST_README.md", "BUILD_VERIFICATION.md", "PUBLICATION_NOTES.md")] + sorted((ROOT / "docs").rglob("*"))
DOCUMENTS = [path for path in DOCUMENTS if path.is_file()]
for folder in ("windows", "linux"):
    for source in DOCUMENTS:
        destination = BUILDS / folder / source.relative_to(ROOT)
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, destination)
with zipfile.ZipFile(BUILDS / "MountainStill-Windows-x86_64.zip", "w", zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
    for path in sorted((BUILDS / "windows").rglob("*")):
        if path.is_file():
            archive.write(path, "MountainStill/" + str(path.relative_to(BUILDS / "windows")))
with tarfile.open(BUILDS / "MountainStill-Linux-x86_64.tar.gz", "w:gz") as archive:
    archive.add(BUILDS / "linux", arcname="MountainStill")
shutil.copy2(BUILDS / "macos/MountainStill-macOS.zip", BUILDS / "MountainStill-macOS-Universal.zip")
with zipfile.ZipFile(BUILDS / "MountainStill-macOS-Universal.zip", "a", zipfile.ZIP_DEFLATED) as archive:
    for source in DOCUMENTS:
        archive.write(source, str(source.relative_to(ROOT)))
paths = [BUILDS / name for name in ("MountainStill-Windows-x86_64.zip", "MountainStill-macOS-Universal.zip", "MountainStill-Linux-x86_64.tar.gz")]
(BUILDS / "SHA256SUMS.txt").write_text("".join(hashlib.sha256(p.read_bytes()).hexdigest() + "  " + p.name + "\n" for p in paths), encoding="utf-8")
for path in paths:
    print(f"{path.name}: {path.stat().st_size:,} bytes")
