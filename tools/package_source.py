#!/usr/bin/env python3
"""Build a current-project-only source archive; never include caches or prior prototypes."""
from pathlib import Path
import argparse
import hashlib
import zipfile
from release_file_policy import exclusion_reason

ROOT = Path(__file__).resolve().parents[1]
BASE = [".gitignore", "BUILD_VERIFICATION.md", "FIRST_TEST_README.md", "PUBLICATION_NOTES.md", "bootstrap.tscn", "project.godot", "main.tscn", "default_bus_layout.tres", "icon.svg", "export_presets.cfg", "README.md"]
SCRIPTS = [f"scripts/{name}" for name in ("cultivation.gd", "cultivation_state.gd", "equipment_ledger.gd", "desktop_mode.gd", "quiet_button.gd", "ink_hotspot.gd", "ink_paper.gd", "ink_pages.gd", "adventure_pages.gd", "journal_pages.gd", "cultivation_content.gd", "character_walk.gd", "character_meditation.gd", "character_preview.gd", "export_all.sh")]
TESTS = [f"tests/{name}" for name in ("test_cultivation.gd", "test_cultivation_ui.gd", "test_equipment.gd", "test_desktop_mode.gd", "test_campaign.gd", "test_campaign_journey.gd", "test_equipment_upgrade.gd", "test_campaign_ui.gd", "test_preview_layout.gd", "test_character_walk.gd", "show_character_walk.gd", "test_character_meditation.gd", "test_motion_transitions.gd", "show_character_meditation.gd", "show_meditation_scene.gd", "show_motion_interactions.gd", "show_book_transition.gd", "test_scene_framing.gd", "test_adventure_state.gd", "test_adventure_ui.gd", "test_combat_pose.gd", "show_adventure_loop.gd")]
TOOLS = [f"tools/{name}" for name in ("crop_props_assets.py", "crop_equipment_assets.py", "crop_encounter_assets.py", "generate_audio.py", "package_builds.py", "package_source.py", "verify_builds.py", "audit_export_payload.gd", "prepare_stone_recovery.py")]
ASSETS = ["assets/cultivation/sanctuary-warm.png", "assets/cultivation/sanctuary-diorama.png"]
ASSETS += ["assets/cultivation/sources/sanctuary-diorama-source.png", "assets/cultivation/sources/sanctuary-diorama-prompt.txt", "assets/cultivation/sources/sanctuary-diorama-canopy-prompt.txt", "assets/cultivation/sources/sanctuary-diorama-provenance.json", "assets/cultivation/sources/sanctuary-diorama-alpha-stats.json"]
ASSETS += ["assets/ui/ink/rice-paper.png", "assets/ui/ink/soot-brush.png", "assets/ui/ink/README.md"]
ASSETS += [f"assets/cultivation/avatars/{name}.png" for name in ("sword", "fan", "mist_slash", "petal")]
ASSETS += ["assets/cultivation/avatars/props-anchors.json", "assets/cultivation/avatars/sources/props-sheet.png"]
ASSETS += [f"assets/cultivation/equipment/{name}.png" for name in ("base", "head_pin", "head_crown", "chest_blue", "chest_jade", "legs_blue", "legs_jade", "feet_cloth", "feet_boots")]
ASSETS += ["assets/cultivation/equipment/equipment-anchors.json", "assets/cultivation/equipment/ART-NOTES.txt", "assets/cultivation/equipment/sources/base-source.png", "assets/cultivation/equipment/sources/equipment-atlas.png"]
for name in ("fox_idle", "fox_attack", "boar_idle", "boar_attack", "chest_closed", "chest_open"):
    ASSETS += [f"assets/cultivation/encounters/{name}.png", f"assets/cultivation/encounters/sources/{name}_source.png"]
ASSETS += ["assets/cultivation/encounters/metadata.json", "assets/cultivation/encounters/sources/prompts.json"]
ASSETS += ["assets/cultivation/sanctuary-warm-layout.json", "assets/cultivation/sources/sanctuary-warm-layout-source.png", "assets/cultivation/sources/sanctuary-warm-layout-prompt.txt"]
ASSETS += [f"assets/fonts/{name}" for name in ("NotoSansCJK-Regular.ttc", "NotoSerifCJK-Regular.ttc", "DejaVuSans.ttf", "MaShanZheng-Regular.ttf")]
ASSETS += [f"assets/audio/{name}.wav" for name in ("music", "equip", "level", "loot")]
ASSETS += ["assets/audio/SOURCE_LICENSE.txt", "assets/fonts/MaShanZheng-OFL.txt"]

# Adventure source keeps original generated inputs and reproducible provenance,
# while runtime export manifests deliberately exclude proof sheets and sources.
SCRIPTS += ["scripts/character_sidewalk.gd", "scripts/duel_timeline.gd", "scripts/character_projection.gd", "scripts/portal_dissolve.gdshader"]
# Runtime helpers (motion, per-pose body registration, etc.) are first-class source.
SCRIPTS += [str(path.relative_to(ROOT)) for path in sorted((ROOT / "scripts").rglob("*")) if path.suffix in (".gd", ".gdshader")]
TESTS += [str(path.relative_to(ROOT)) for path in sorted((ROOT / "tests").rglob("*.gd"))]
# Reproducible continuous-capture helpers are source, never captured media or saves.
TESTS += [str(path.relative_to(ROOT)) for path in sorted((ROOT / "tests/capture_tools").rglob("*")) if path.is_file() and path.suffix in (".py", ".sh", ".md")]
TOOLS += [str(path.relative_to(ROOT)) for path in sorted((ROOT / "tools").glob("*")) if path.suffix in (".py", ".gd") and path.name.startswith(("route_", "prepare_sidewalk", "prepare_campaign", "update_adventure", "package_adventure", "qa_", "normalize_equipment_"))]
for folder in ("sidewalk", "routes", "beasts"):
    for path in (ROOT / "assets/cultivation" / folder).rglob("*"):
        if path.is_file() and path.suffix in (".png", ".json", ".txt", ".md", ".svg", ".gd") and "preview" not in path.name:
            ASSETS.append(str(path.relative_to(ROOT)))

TOOLS += ["tools/release_file_policy.py", "tools/verify_export_dependencies.py", "tools/package_updater_delivery.py", "tools/build_update_pack.gd", "tools/build_updater_release.sh", "tools/write_update_manifest.py", "tools/verify_updater_artifacts.py"]
TESTS += [str(path.relative_to(ROOT)) for path in sorted((ROOT / "tests").glob("*")) if path.suffix == ".py" and path.name.startswith(("update_", "bootstrap_"))]

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--dry-run", action="store_true", help="validate and print the allowlist without making an archive")
args = parser.parse_args()
files = [ROOT / name for name in BASE + SCRIPTS + TESTS + TOOLS + ASSETS]
missing = [str(path.relative_to(ROOT)) for path in files if not path.is_file()]
if missing:
    raise SystemExit("Source packaging blocked; required files missing: " + ", ".join(missing))
for path in list(files):
    for suffix in (".import", ".uid"):
        sidecar = Path(str(path) + suffix)
        if sidecar.is_file():
            files.append(sidecar)
files += [path for path in (ROOT / "docs").rglob("*") if path.is_file()]
# Only current runtime assets, their original inputs, provenance and tools are retained.
# Historical full-body outfit presets, old environments and review previews are excluded.
files = sorted(path for path in set(files) if exclusion_reason(path.relative_to(ROOT)) is None)
for path in files:
    print(path.relative_to(ROOT))
if args.dry_run:
    print(f"Validated {len(files)} source files; archive not created.")
    raise SystemExit(0)
out = ROOT / "builds/MountainStill-Source.zip"
out.parent.mkdir(parents=True, exist_ok=True)
with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
    for path in files:
        archive.write(path, "MountainStill/" + str(path.relative_to(ROOT)))
with zipfile.ZipFile(out) as archive:
    assert archive.testzip() is None, "Source ZIP CRC check failed"
    for name in archive.namelist():
        assert exclusion_reason(name.removeprefix("MountainStill/")) is None, name
digest = hashlib.sha256(out.read_bytes()).hexdigest()
(out.parent / "MountainStill-Source.sha256").write_text(digest + "  " + out.name + "\n")
manifest = out.parent / "SHA256SUMS.txt"
if manifest.is_file():
    lines = [line for line in manifest.read_text().splitlines() if not line.endswith("  " + out.name)]
    manifest.write_text("\n".join(lines + [digest + "  " + out.name]) + "\n")
print(f"Verified {out.name}: {out.stat().st_size:,} bytes; SHA-256 {digest}")
