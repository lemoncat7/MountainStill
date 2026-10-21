# Equipment attachment template, version 1

All right-facing route/combat clothes use fixed attachment slots. Different
silhouettes, embroidery, sleeve widths, trousers and shoe heights are welcome;
**the joints and attachment canvas do not move between equipment items**.

## Authoring files

- `assets/cultivation/sidewalk/template.json`: complete machine-readable contract.
- `assets/cultivation/sidewalk/template.gd`: generated runtime constants.
- `template-{arm,leg,chest,head}-blank.png`: transparent, correctly sized canvases.
- `template-{arm,leg,chest,head}-overlay.svg`: transparent guides to place over art
  at 100% size. Crosshairs are attachment centres; gold bands are seam overlap.
- `normalized/manifest.json`: source hashes, generated pixel hashes, and the
  one-time legacy migration history. It is an audit record, not runtime offsets.

Never trim transparent padding, auto-centre the painted bounds, or change the
canvas to fit a garment. Export RGBA PNG at the template size. Do not paint the
guide itself into the export. Keep detached objects out of the canvas.

## Coordinates and bind pose

PNG coordinates are pixel-edge coordinates: x goes right, y goes down. Fractions
are intentional. Bind coordinates are right-facing actor-local units before
actor scale and facing. The sole baseline is y=0. The actor uses the same
132/488 scale as before. Source coordinates are not screen pixels.

| Family | Canvas | Fixed anchors / placement |
|---|---:|---|
| Arm, sleeve | 219 × 396 | shoulder (86,38); elbow (102.326531,209.428571); anatomical wrist (143.142857,356.367347) |
| Leg, trousers, footwear | 210 × 501 | hip (102,20); knee (102,255.555556); ankle (79.777778,446.666667) |
| Chest | 288 × 448 | rect (-34,-204,72,112) before torso-width shaping; armhole pixel (62.153846,176); waist (136,380); neck (136,8) |
| Head and ornaments | 578 × 650 | same rect (-150,-489,267,300); neck pixel (324.719101,621.833333) |
| Bare torso | 234 × 386 | unchanged original rect (-28,-204,55,96) |

The arm source mapping is `(pixel-(86,38))*.245`. The leg source mapping is
`(pixel-(102,20))*.225`. These mappings belong to the **family**, not a garment.
The arm elbow source is the skinning reference for its blend, not a separate
bone-length override. The skeleton's upper arm is 42 units; its forearm vector
is (10,36). Leg bones remain 53 and 43 units.

The common visible near armhole is body-local (-24,-160); the far socket is
(-30,-160). These values are after TORSO_WIDTH=1.30, while CHEST_RECT is before
that shaping. The common hip/waist is (0,-109), and neck is (0,-202). The existing
shoulder surface deformation moves the chest patch to the fitted sleeve root.
Do not translate the whole chest or scale bones to hide a broken seam.

The **anatomical wrist** is the fixed hand/forearm attachment and the original
painted fist's weapon joint. `ARM_WRIST` names this source landmark;
`ARM_WRIST_GRIP` remains a compatibility alias for the same point.

`res://scripts/character_sidewalk.gd` owns the live fixed grip. Its
`_grip_offset(arm, side, style, roll)` returns exactly `(0,0)` for both sword and
fan. Weapon-local `(0,0)` stays at this fist joint after actor facing/scale.
`arm.hand_angle` continues to animate the original painted fist continuously;
the blade/fan retains its independently authored angle. The procedural holding
hand is retained only as historical comparison material and has no live
preload, socket or draw path.

The visible hand is the unchanged `normalized/arm.png` at the existing natural
scale. Draw order splits the original 32-row arm mesh at row 24 (source y=297):
rows 0..23 remain in the avatar pass, and rows 24..31 draw exactly once after the
weapon. Both parts use the same full-canvas UVs, `_skin_arm` mapping, actor
transform and tint. This is an occlusion split, not a resized hand crop or a new
hand shape. Clothing import never changes the hand, hit timing or
contact-authority geometry; the zero visual socket adds no contact displacement.

## Seam and overlap rules

- Shoulder: paint an opaque sleeve cap around (86,38). Maintain overlap above
  and below it (roughly -7 to +6 local y). The chest armhole and sleeve cap follow
  the same shoulder. Sleeve volume can extend left or right inside the padding.
- Elbow: use the same source reference and shared y=34..49 local blend for every
  sleeve. A short sleeve may end above it; a long sleeve must continue across
  that blend, with no independently positioned forearm cutout.
- Wrist: y=66..78 local is the shared wrist blend. Keep the anatomical hand
  origin at its fixed wrist reference. Open-palm casts retain their existing
  replacement cut at source y=331.877551. A held sword or fan keeps the original
  fist pixels and merely moves source rows 24..31 to the front occlusion pass.
  Neither mode moves the sleeve or wrist, and no clothing-specific socket exists.
- Waist: keep the chest and trouser root overlapping around body-local (0,-109).
  For these templates the chest waist is source (136,380), and the trouser root
  is (102,20). Cloth below this point may hang freely, but the waist cannot drift.
- Knee: preserve the y=255.555556 source reference. Shared knee blend is local
  y=46..60. Garment volume can differ without moving the knee seam.
- Ankle: trousers have a cuff reference (79.777778,426) and hem y=445. A useful
  opaque overlap is source y=418..437. Footwear may have a higher shaft, but both
  cloth shoes and boots must cover this overlap. Actual tested shared coverage
  is at least 24 opaque source pixels per sampled row in the central band.
- Foot: keep ankle (79.777778,446.666667), foot direction and sole within the
  common leg canvas. Do not use shoe height to move the planted foot.
- Clothing order remains far arm, far leg, near leg, bare torso, chest, near
  arm, head, ornament. A held sword's rear hilt/pommel is drawn **before the
  holding forearm**; its front blade/crossguard is drawn **after that forearm**.
  The original painted fist draws once after both weapon portions, using its
  unchanged mesh coordinates. The old back-hand hook draws nothing. Use the
  existing shared draw helpers; do not add per-garment weapon layering.

## One-time migration of current art

Original PNGs and original atlases are immutable. The importer writes only
`normalized/` and generated `template*` authoring files.

- Base arm: lossless integer copy at x=32 on the padded canvas.
- Blue sleeve: lossless integer copy at x=5. Jade sleeve: copy at x=12. With the
  common x-origin 86 these exactly bake the former -27/-20 registrations.
  No sleeve pixels are clipped by the shift. A tiny unrelated blue top-right
  atlas fragment is removed before copying.
- Chests: both use 288×448 and one draw rectangle. Blue's content uses full
  height; jade's prior 99-unit content becomes 396 pixels inside that same
  canvas. Jade's lower rows 240..396 are then mapped to 240..420 to close the
  measured waist gap, leaving its armhole and collar fixed. Isolated adjacent
  top-right fragments and the unrelated blue bottom fragment are removed once.
- Trousers: original waist and knee pixels through source row 254 are identical.
  The short legacy shins are extended continuously to the same cuff and hem.
  Cross-section widths are retained. Legacy cuff x=100 (blue) / 84 (jade) is
  registered offline to x=79.777778; no names reach runtime skinning.
- Shoes, bare leg, bare torso and base head: pixel-identical copies.
- Hair pin and crown: their prior authored placement is resampled into the same
  full head canvas. Both now use HEAD_RECT, without per-ornament rectangles.

Integer sleeve migration is pixel-exact. Chest/head scaling and lower-trouser
fitting necessarily resample pixels with deterministic bicubic filtering; no new
costume artwork is synthesized. All normalized textures retain mipmaps. Their
source/pixel hashes make accidental regeneration or modification detectable.

## Rebuild and validate

Run from the project directory (Python 3 and Pillow):

```sh
python tools/normalize_equipment_template.py
python tools/normalize_equipment_template.py --check
godot --headless --path . --editor --import
godot --headless --path . --script tests/test_equipment_template.gd
```

`--check` is read-only and verifies every generated payload, all 14 asset sizes,
source hashes, lossless migration cases, shoulder coverage, waist coverage,
and all four mixed trouser/shoe seam combinations. Regeneration does not read
its own outputs as input, so repeated runs cannot accumulate shifts.

The Godot regression also verifies the actual renderer consumes normalized
assets, rejects legacy runtime registration branches, and exercises 16 mixed
outfits × 3 weapon styles × 2 facings × 5 phases × 3 phase samples. Body armhole,
sleeve root, anatomical wrist and waist must all follow the shared live rig.
The painted-fist regression pins the normalized PNG to its v8 SHA-256, verifies
the original source/UV/scale partition and zero socket, and compares joint paths
against the v8 fixture while independently checking bounded, moving and
continuous `hand_angle`. Existing mesh-orientation,
contact-line, defense and motion gates remain independent and unchanged.

These numeric tests complement native visual inspection at actor size and
close-up. Inspect idle, walking, guard, extension and recovery in both facings;
check silhouette, joint folds and volume as well as numerical socket equality.

## Adding equipment

1. Copy the relevant blank template and load its overlay at native size.
2. Paint volume around the fixed crosshairs and overlap bands. Keep transparent
   canvas margins. Use the existing base art underneath as an anatomy reference.
3. Export the exact RGBA canvas size. A new chest and sleeve form a matching pair;
   trousers, shoes and head ornament remain independently mixable.
4. Treat conforming new art as an identity import. If legacy art needs fitting,
   add that one-time transformation to the importer and record it in its audit
   manifest. Never add an equipment-name conditional to rendering.
5. Extend the asset list/fixture, verify all seam combinations, and perform native
   visual review. Changing this contract itself requires a versioned migration
   of every affected asset, rather than leaving old offsets alongside new ones.
