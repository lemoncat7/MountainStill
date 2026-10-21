#!/usr/bin/env python3
"""Bake legacy cutouts onto the canonical attachment canvases, never at runtime.

Pillow is the only dependency. Originals are immutable input. --check rebuilds in
memory, checks the entire output pixel payload and metadata, and runs seam tests.
"""
from __future__ import annotations

import argparse
import hashlib
import io
import json
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / "assets/cultivation/sidewalk"
OUT = ART / "normalized"
ARM_SIZE = (219, 396)
LEG_SIZE = (210, 501)
CHEST_SIZE = (288, 448)
HEAD_SIZE = (578, 650)
ARM_ORIGIN = (86.0, 38.0)
LEG_ORIGIN = (102.0, 20.0)
ARM_SCALE = 0.245
LEG_SCALE = 0.225
ANKLE_X = 102 - 5 / LEG_SCALE
KNEE_Y = 20 + 53 / LEG_SCALE
ANKLE_Y = 20 + 96 / LEG_SCALE
NAMES = ("head", "torso", "arm", "leg", "head_pin", "head_crown",
         "chest_blue", "chest_jade", "sleeve_blue", "sleeve_jade",
         "legs_blue", "legs_jade", "feet_cloth", "feet_boots")


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def image_bytes(image: Image.Image) -> bytes:
    stream = io.BytesIO()
    image.save(stream, format="PNG", compress_level=9)
    return stream.getvalue()


def json_bytes(data: dict) -> bytes:
    return (json.dumps(data, indent=2, ensure_ascii=False) + "\n").encode()


def clean(image: Image.Image, rectangles: list[tuple[int, ...]]) -> Image.Image:
    """Erase only measured, disconnected neighboring atlas fragments."""
    image = image.copy()
    for x0, y0, x1, y1 in rectangles:
        image.paste((0, 0, 0, 0), (x0, y0, x1, y1))
    return image


def placed(image: Image.Image, size: tuple[int, int], offset: tuple[int, int]) -> Image.Image:
    result = Image.new("RGBA", size)
    # Integer translation is lossless, including anti-aliased edge pixels.
    result.paste(image, offset)
    return result


def affine_canvas(image: Image.Image, size: tuple[int, int], rect: tuple[float, ...]) -> Image.Image:
    """Rect is exact floating output coordinates, not rounded sprite bounds."""
    x, y, width, height = rect
    return image.transform(size, Image.Transform.AFFINE,
                           (image.width / width, 0, -x * image.width / width,
                            0, image.height / height, -y * image.height / height),
                           Image.Resampling.BICUBIC)


def trousers(image: Image.Image, cuff_center_x: float) -> Image.Image:
    """Keep waist/knee; fit shin/cuff once to the shared ankle overlap band.

    Both axes are continuous at the knee and cuff. All horizontal garment
    sections preserve their authored width; only the lower-leg axis changes.
    """
    knots = [(0.0, 0.0, 0.0), (KNEE_Y, KNEE_Y, 0.0),
             (338.0, 426.0, ANKLE_X - cuff_center_x),
             (355.0, 445.0, ANKLE_X - cuff_center_x),
             (501.0, 591.0, ANKLE_X - cuff_center_x)]
    result = Image.new("RGBA", LEG_SIZE)
    for y in range(result.height):
        target_y = y + 0.5
        if target_y < KNEE_Y:
            result.paste(image.crop((0, y, image.width, y + 1)), (0, y))
            continue
        for first, last in zip(knots, knots[1:]):
            sy0, ty0, dx0 = first
            sy1, ty1, dx1 = last
            if ty0 <= target_y < ty1:
                slope = (sy1 - sy0) / (ty1 - ty0)
                sy = sy0 + (target_y - ty0) * slope
                shift = dx0 + (dx1 - dx0) * (sy - sy0) / (sy1 - sy0)
                # Pillow samples output pixel centres; undo the row's +0.5.
                row = image.transform((result.width, 1), Image.Transform.AFFINE,
                    (1, 0, -shift, 0, slope, sy - slope * 0.5),
                    Image.Resampling.BICUBIC)
                result.paste(row, (0, y))
                break
    return result


def family_for(name: str) -> str:
    if name == "arm" or name.startswith("sleeve_"):
        return "arm"
    if name == "leg" or name.startswith(("legs_", "feet_")):
        return "leg"
    if name == "head" or name.startswith("head_"):
        return "head"
    if name.startswith("chest_"):
        return "chest"
    return "torso"


def transform(name: str, original: Image.Image) -> tuple[Image.Image, dict]:
    # Only these known legacy IDs need registration. Future conforming items
    # use identity import, never an accidental default to the jade fitting.
    spec = {"family": family_for(name), "operation": "identity"}
    if name == "arm":
        return placed(original, ARM_SIZE, (32, 0)), {"family": "arm", "operation": "integer_translation", "translation": [32, 0]}
    if name in ("sleeve_blue", "sleeve_jade"):
        removed = [(140, 0, 155, 15)] if name == "sleeve_blue" else []
        dx = 5 if name == "sleeve_blue" else 12
        result = placed(clean(original, removed), ARM_SIZE, (dx, 0))
        return result, {"family": "arm", "operation": "integer_translation", "translation": [dx, 0], "removed_atlas_fragments": removed}
    if name in ("chest_blue", "chest_jade"):
        removed = [(201, 0, 273, 23), (48, 343, 166, 370)] if name == "chest_blue" else [(188, 0, 230, 11)]
        height = 448 if name == "chest_blue" else 396
        normalized = affine_canvas(clean(original, removed), CHEST_SIZE, (0, 0, 288, height))
        waist_registration = None
        if name == "chest_jade":
            # Fix the measured four-unit waist gap without moving its armhole.
            lower = normalized.transform((288, 180), Image.Transform.AFFINE,
                (1, 0, 0, 0, 156 / 180, 240), Image.Resampling.BICUBIC)
            normalized.paste((0, 0, 0, 0), (0, 240, 288, 448))
            normalized.paste(lower, (0, 240))
            waist_registration = {"fixed_through_y": 240, "source_end_y": 396, "target_end_y": 420}
        return normalized, {
            "family": "chest", "operation": "resample_to_fixed_canvas",
            "output_content_rect": [0, 0, 288, height], "removed_atlas_fragments": removed,
            "waist_registration": waist_registration}
    if name in ("legs_blue", "legs_jade"):
        cx = 100.0 if name == "legs_blue" else 84.0
        return trousers(original, cx), {"family": "leg", "operation": "piecewise_shin_registration",
            "fixed_waist": list(LEG_ORIGIN), "fixed_knee_y": KNEE_Y,
            "legacy_cuff": [cx, 338], "canonical_cuff": [ANKLE_X, 426], "canonical_hem_y": 445}
    if name in ("feet_cloth", "feet_boots"):
        return original.copy(), {"family": "leg", "operation": "identity", "ankle": [ANKLE_X, ANKLE_Y]}
    if name in ("head_pin", "head_crown"):
        rect = (-72, -429, 78, 37) if name == "head_pin" else (-40, -445, 43, 47)
        x, y, w, h = rect
        target = ((x + 150) * 578 / 267, (y + 489) * 650 / 300, w * 578 / 267, h * 650 / 300)
        return affine_canvas(original, HEAD_SIZE, target), {"family": "head", "operation": "resample_to_fixed_canvas", "output_content_rect": list(target)}
    return original.copy(), spec


def contract() -> dict:
    return {
        "version": 1,
        "coordinates": {"source": "PNG pixel edges, x right / y down; floating-point landmarks",
            "bind": "right-facing actor-local units before facing/actor scale; sole baseline y=0",
            "chest": "CHEST_RECT before TORSO_WIDTH=1.30; shoulder landmarks below are after width",
            "runtime": "shared rig deformation only; never inspect garment names for registration"},
        "canvases": {"arm": list(ARM_SIZE), "leg": list(LEG_SIZE), "chest": list(CHEST_SIZE), "head": list(HEAD_SIZE), "torso": [234, 386]},
        "rects": {"chest": [-34, -204, 72, 112], "head": [-150, -489, 267, 300], "bare_torso": [-28, -204, 55, 96]},
        "arm": {"source_origin": list(ARM_ORIGIN), "source_scale": ARM_SCALE,
            "elbow_source": [86 + 4 / ARM_SCALE, 38 + 42 / ARM_SCALE],
            "wrist_source": [86 + 14 / ARM_SCALE, 38 + 78 / ARM_SCALE],
            "upper_length": 42, "forearm_vector": [10, 36],
            "elbow_blend_local_y": [34, 49], "wrist_blend_local_y": [66, 78],
            "replace_hand_cut_source_y": 38 + 72 / ARM_SCALE,
            "shoulder_cap_source": [86, 38], "cap_overlap_local_y": [-7, 6]},
        "leg": {"source_origin": list(LEG_ORIGIN), "source_scale": LEG_SCALE,
            "hip_source": list(LEG_ORIGIN), "knee_source": [102, KNEE_Y],
            "ankle_source": [ANKLE_X, ANKLE_Y], "sole_source_y": 501,
            "upper_length": 53, "lower_length": 43,
            "knee_blend_local_y": [46, 60], "ankle_blend_local_y": [87, 98],
            "trouser_cuff_source": [ANKLE_X, 426], "trouser_hem_source_y": 445,
            "trouser_shoe_overlap_source_y": [418, 437], "waist_overlap_local_y": [-4, 4]},
        "body": {"near_armhole_bind": [-24, -160], "far_armhole_bind": [-30, -160],
            "bare_shoulder_surface_bind": [-18, -177],
            "near_armhole_chest_source": [(-24 / 1.30 + 34) * 4, 176],
            "waist_hip_bind": [0, -109], "waist_chest_source": [136, 380],
            "neck_bind": [0, -202], "neck_chest_source": [136, 8],
            "shoulder_follow": "shared shoulder_surface_point; armhole and sleeve root use the same fitted shoulder"},
        "head": {"neck_source": [150 * 578 / 267, 287 * 650 / 300],
            "ornaments": "same full head canvas and HEAD_RECT; no per-ornament draw rectangles"},
        "weapon": {
            "hand_origin": "fixed original painted fist joint at the anatomical fitted wrist",
            "socket_provider": "res://scripts/character_sidewalk.gd",
            "socket_method": "_grip_offset(arm, side, style, roll)",
            "hand_local_socket": [0, 0],
            "socket_units": "zero native hand-local offset; apply actor facing/scale at the existing wrist",
            "socket_ownership": "Original normalized arm artwork and the live rig own the fixed fist joint; no procedural replacement hand or garment offset table.",
            "visual_handle": "weapon-local (0,0) at the original painted fist joint; hand_angle remains animated and weapon rotation remains independent",
            "collision_authority": "unchanged; zero visual handle offset introduces no contact-authority displacement",
            "weapon_local_grip": [0, 0], "rule": "Clothing import cannot move the anatomical wrist, resize the painted fist, or redefine its fixed socket."},
        "ordering": ["far_arm", "far_leg", "near_leg", "bare_torso", "chest", "near_arm", "head", "head_ornament"],
        "weapon_layer_constraints": {
            "rear_sword_hilt": "before the holding forearm",
            "front_sword_blade_and_crossguard": "after the holding forearm and before the painted fist",
            "hand_passes": ["original arm mesh rows 0..23", "weapon at the fixed original fist joint", "original arm mesh rows 24..31 once, at unchanged source UVs and scale"],
            "painted_fist_source_split": {"first_row": 24, "total_rows": 32, "source_y": 297},
            "ownership": "character_sidewalk.draw_held_weapon and draw_grip_front; draw_grip_back is an empty compatibility hook; no garment-specific layer rules"},
        "assets": {name: family_for(name) for name in NAMES}
    }


def module() -> bytes:
    return b'''extends RefCounted
## Canonical attachment contract. Generated by tools/normalize_equipment_template.py.
## All wearable-specific registration belongs to the offline importer, never here.
const VERSION := 1
const ASSET_ROOT := "res://assets/cultivation/sidewalk/normalized/"
const ARM_CANVAS := Vector2i(219, 396)
const LEG_CANVAS := Vector2i(210, 501)
const CHEST_CANVAS := Vector2i(288, 448)
const HEAD_CANVAS := Vector2i(578, 650)
const ARM_ORIGIN := Vector2(86, 38)
const ARM_SOURCE_SCALE := 0.245
const LEG_ORIGIN := Vector2(102, 20)
const LEG_SOURCE_SCALE := 0.225
const CHEST_RECT := Rect2(-34, -204, 72, 112)
const HEAD_RECT := Rect2(-150, -489, 267, 300)
const BARE_TORSO_RECT := Rect2(-28, -204, 55, 96)
const NEAR_ARMHOLE := Vector2(-24, -160)
const FAR_ARMHOLE := Vector2(-30, -160)
const BARE_SHOULDER_SURFACE := Vector2(-18, -177)
const HIP_BIND := Vector2(0, -109)
const NECK_BIND := Vector2(0, -202)
const ARM_ELBOW := ARM_ORIGIN + Vector2(4, 42) / ARM_SOURCE_SCALE
const ARM_WRIST := ARM_ORIGIN + Vector2(14, 78) / ARM_SOURCE_SCALE
# Compatibility alias: the original painted fist and handle share this joint.
const ARM_WRIST_GRIP := ARM_WRIST
# The live rig retains the original painted fist with a fixed zero socket.
const HAND_SOCKET_PROVIDER := "res://scripts/character_sidewalk.gd"
const ARM_HAND_CUT_Y := 38.0 + 72.0 / ARM_SOURCE_SCALE
const LEG_KNEE := LEG_ORIGIN + Vector2(0, 53) / LEG_SOURCE_SCALE
const LEG_ANKLE := LEG_ORIGIN + Vector2(-5, 96) / LEG_SOURCE_SCALE
const TROUSER_CUFF := Vector2(LEG_ANKLE.x, 426)
const TROUSER_HEM_Y := 445.0
const SHOE_OVERLAP_Y := Vector2(418, 437)
const ASSET_KEYS := @ASSET_KEYS@
'''.replace(b"@ASSET_KEYS@", json.dumps(list(NAMES)).encode())


def overlay(family: str, data: dict) -> bytes:
    width, height = data["canvases"][family]
    points = {
        "arm": [("shoulder", ARM_ORIGIN), ("elbow", data["arm"]["elbow_source"]), ("wrist", data["arm"]["wrist_source"])],
        "leg": [("hip", LEG_ORIGIN), ("knee", [102, KNEE_Y]), ("cuff", [ANKLE_X, 426]), ("ankle", [ANKLE_X, ANKLE_Y])],
        "chest": [("neck", data["body"]["neck_chest_source"]), ("armhole", data["body"]["near_armhole_chest_source"]), ("waist", [136, 380])],
        "head": [("neck", data["head"]["neck_source"])],
    }[family]
    rows = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">',
            '<style>text{font:10px sans-serif;fill:#12a5a0;paint-order:stroke;stroke:white;stroke-width:2px}path,circle,line,rect{vector-effect:non-scaling-stroke}</style>',
            f'<rect x="0.5" y="0.5" width="{width-1}" height="{height-1}" fill="none" stroke="#12a5a0" stroke-dasharray="4 4"/>']
    if family == "leg":
        rows += [f'<rect x="{ANKLE_X-24:.5f}" y="418" width="48" height="19" fill="#f0bc4680"/>']
    if family == "arm":
        rows += ['<rect x="66" y="10" width="40" height="52" fill="#f0bc4640"/>']
    for name, (x, y) in points:
        rows += [f'<path d="M{x-7:.5f} {y:.5f}h14 M{x:.5f} {y-7:.5f}v14" stroke="#12a5a0" fill="none"/>',
                 f'<circle cx="{x:.5f}" cy="{y:.5f}" r="3" fill="none" stroke="#12a5a0"/>',
                 f'<text x="{min(x+10,width-88):.5f}" y="{max(12,y-10):.5f}">{name}</text>']
    rows.append('</svg>\n')
    return "\n".join(rows).encode()


def validate(images: dict[str, Image.Image], metadata: dict, data: dict) -> int:
    checks = 0
    def check(ok: bool, label: str):
        nonlocal checks
        checks += 1
        if not ok:
            raise AssertionError(label)
    for name, image in images.items():
        check(list(image.size) == data["canvases"][data["assets"][name]], name + " canvas")
        check(image.mode == "RGBA", name + " alpha")
        original = Image.open(ART / (name + ".png")).convert("RGBA")
        check(digest((ART / (name + ".png")).read_bytes()) == metadata["assets"][name]["source_sha256"], name + " immutable original")
        if name in ["head", "torso", "leg", "feet_cloth", "feet_boots"]:
            check(image.tobytes() == original.tobytes(), name + " preserved pixels")
    # An explicit pixel-roundtrip catches accidental interpolation or clipping.
    check(images["arm"].crop((32, 0, 187, 396)).tobytes() == Image.open(ART / "arm.png").convert("RGBA").tobytes(), "base arm lossless padding")
    for name, dx in [("sleeve_blue", 5), ("sleeve_jade", 12)]:
        original = Image.open(ART / (name + ".png")).convert("RGBA")
        erased = [(140, 0, 155, 15)] if name == "sleeve_blue" else []
        check(images[name].crop((dx, 0, dx+155, 396)).tobytes() == clean(original, erased).tobytes(), name + " lossless registration")
        for x, y in [(86,38), (80,30), (92,45)]:
            check(images[name].getpixel((x,y))[3] > 192, name + " shoulder cap overlap")
    for pants in ["legs_blue", "legs_jade"]:
        for shoe in ["feet_cloth", "feet_boots"]:
            # All four combinations must have actual opaque overlap across a
            # useful central band, not merely overlapping rectangular canvases.
            for y in [420, 426, 432, 436]:
                overlap = [x for x in range(55,105) if images[pants].getpixel((x,y))[3] > 192 and images[shoe].getpixel((x,y))[3] > 192]
                check(len(overlap) >= 24, pants + "/" + shoe + " seam y=" + str(y))
    for pants in ["legs_blue", "legs_jade"]:
        original = Image.open(ART / (pants + ".png")).convert("RGBA")
        check(images[pants].crop((0,0,210,255)).tobytes() == original.crop((0,0,210,255)).tobytes(), pants + " waist and knee unchanged")
    for chest in ["chest_blue", "chest_jade"]:
        x, y = data["body"]["near_armhole_chest_source"]
        check(images[chest].getpixel((round(x),round(y)))[3] > 192, chest + " painted socket coverage")
        check(images[chest].getpixel((136,380))[3] > 192, chest + " hip overlap")
    return checks


def import_file(path: Path) -> bytes:
    resource = "res://" + str(path.relative_to(ROOT))
    cache = "res://.godot/imported/" + path.name + "-" + hashlib.md5(resource.encode()).hexdigest() + ".ctex"
    return f'''[remap]\n\nimporter="texture"\ntype="CompressedTexture2D"\npath="{cache}"\nmetadata={{\n"vram_texture": false\n}}\n\n[deps]\n\nsource_file="{resource}"\ndest_files=["{cache}"]\n\n[params]\n\ncompress/mode=0\nmipmaps/generate=true\nmipmaps/limit=-1\nprocess/fix_alpha_border=true\nprocess/premult_alpha=false\nprocess/size_limit=0\ndetect_3d/compress_to=1\n'''.encode()


def build(check_only: bool) -> None:
    data = contract()
    images, outputs = {}, {}
    metadata = {"version": 1, "template": "../template.json", "tool": "tools/normalize_equipment_template.py",
        "policy": "Legacy registration is baked once. Runtime uses only shared attachment families.", "assets": {}}
    for name in NAMES:
        source_path = ART / (name + ".png")
        image, spec = transform(name, Image.open(source_path).convert("RGBA"))
        images[name] = image
        output = image_bytes(image)
        outputs[OUT / (name + ".png")] = output
        metadata["assets"][name] = {"source": "../"+name+".png", "source_sha256": digest(source_path.read_bytes()),
            "file": name+".png", "rgba_sha256": digest(image.tobytes()), "canvas": list(image.size),
            "alpha_bounds": list(image.getchannel("A").getbbox()), **spec}
    checks = validate(images, metadata, data)
    outputs[OUT / "manifest.json"] = json_bytes(metadata)
    outputs[ART / "template.json"] = json_bytes(data)
    outputs[ART / "template.gd"] = module()
    for family in ["arm", "leg", "chest", "head"]:
        outputs[ART / ("template-" + family + "-overlay.svg")] = overlay(family, data)
        outputs[ART / ("template-" + family + "-blank.png")] = image_bytes(Image.new("RGBA", tuple(data["canvases"][family])))
    failures = []
    for path, payload in outputs.items():
        if check_only:
            if not path.exists() or path.read_bytes() != payload:
                failures.append(str(path.relative_to(ROOT)))
        else:
            path.parent.mkdir(parents=True, exist_ok=True)
            if not path.exists() or path.read_bytes() != payload:
                path.write_bytes(payload)
    for name in NAMES:
        png = OUT / (name + ".png")
        sidecar = png.with_suffix(".png.import")
        if check_only:
            if not sidecar.exists() or "mipmaps/generate=true" not in sidecar.read_text():
                failures.append(str(sidecar.relative_to(ROOT)) + " (mipmaps)")
        elif not sidecar.exists():
            sidecar.write_bytes(import_file(png))
    if failures:
        raise SystemExit("Stale template outputs:\n" + "\n".join(failures))
    print(f"Equipment attachment template: {checks} pixel/seam checks; {len(NAMES)} assets; " + ("all generated outputs current" if check_only else "normalized outputs written"))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="validate without changing any file")
    build(parser.parse_args().check)
