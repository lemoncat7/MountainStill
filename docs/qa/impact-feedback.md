# Material contact feedback

Godot 4.6.3. Tested 20 October 2026.

## Result

`scripts/combat_impact.gd` provides event-driven, contact-local feedback for both
combatants. Weapon and target material are independent layers. Light hits, heavy
hits, blocks and guard breaks have different hold, recoil, debris and sound.
All sounds are original deterministic synthesis with no downloaded samples.

The painter draws small pigment fragments, directional contact edges, feather
barbs or a short guard arc. It does not draw a full-screen flash, apply camera
shake, alter the global engine clock, move the background, or move the UI.

## Integration contract

- `describe(event)` returns the presentation profile without mutating the event.
- `stream(profile)` returns cached mono 32 kHz, 16-bit `AudioStreamWAV`.
- `draw(canvas, {profile, age, position, scale})` is called inside `_draw()`.
- `reaction(profile, age)` optionally returns a decaying amount, offset and
  compression, without altering damage, pressure or action ordering.
- `footstep_profile(material, serial)` supplies a quiet sole/ground texture.

Final contact events should already contain final `poise_broken`, and should
provide `enemy_visual_type` and `hero_style`. The new monster `move_family`,
`impact_weight`, `impact_direction` and `contact_role` metadata take precedence.
Legacy charge/sweep/burst IDs still map to the proper families.

The host should use `active`, `hitstop`, `reaction_duration`,
`reaction_magnitude`, `knockback`, `direction`, `duration` and `gain_db`.
The hitstop recommendation applies only to the local duel and its contact
effects. A small voice pool prevents rapid pecks and multi-hit skills from
cutting off the preceding sound.

## Authored distinctions

| Contact | Local hold | Settle | Character |
| --- | ---: | ---: | --- |
| Light | 18–31 ms | 202–242 ms | Brief contact edge, 3 small marks |
| Heavy | 55–72 ms | About 335–356 ms | Lower body thud, 5 material fragments |
| Block | 28–38 ms | 194–238 ms | Reduced displacement, short material ring |
| Guard break | 88–97 ms | 400 ms | Three crack transients, broken guard strokes |
| Slam aftershock | About 13 ms | About 214 ms | Reduced displacement and level |

Moss pounce is a compact earthy tap; rush uses a firmer 111 Hz body; slam a
lower 78 Hz body with slower damping. Crane peck uses a short 187 Hz body with
beak clack; sweep uses an airy feather layer; dive combines a firmer body and
beak contact. Metallic sword contact, wooden fan contact, flesh, stone, frost,
ember and thunder retain their separate layers.

Four deterministic noise/pitch variations avoid exact sample repetition.
Footsteps peak at substantially lower output level than contacts and have no
hitstop, recoil or impact drawing.

## Validation

Command:

    godot --headless --path . --script tests/test_combat_impact.gd -- --output=/tmp/mountain-impact-proof

Result: **225 checks, 0 failures**, Godot 4.6.3.

Checks cover profile fields, unchanged input events, distinct tactile classes,
strength/settle ordering, finite numeric fallbacks, material selection, explicit
monster families, zero global shake/time manipulation, fully absorbed shields,
no fabricated contact for dodge/whiff/heal/support, bounded progression scaling,
restrained aftershocks, cached deterministic audio, PCM format, headroom, DC
offset, zero endpoints, unique samples and WAV export.

`tests/show_combat_impact.gd` passed Godot's `--check-only` parser. It is a
native-renderer contact sheet using the live painter. This helper-only pass did
not render or inspect that image; native visual review is separate from these
unit checks.

## Audio evidence

- `impact-audio-combined.wav`: 21-example reel at the actual recommended host
  gains, with 240 ms between examples; total duration **8.178 seconds**
- `impact-audio-manifest.json`: clip order, offsets, duration, gain, peak, RMS
  and DC measurements
- `impact-audio-analysis.json`: same measurements plus FFT spectral centroid
- Individual raw clips can be regenerated with the command above

| Class | Sample peak | Output peak after host gain |
| --- | ---: | ---: |
| Light | 0.480 | 0.110 |
| Heavy | 0.540 | 0.156 |
| Block | 0.480 | 0.119 |
| Guard break | 0.580 | 0.163 |
| Footstep | 0.290 | 0.033–0.037 |

Durations are 96–236 ms. No sample clips. Absolute DC offset is below 0.0013
and both endpoints are zero in all examples. The guard examples have distinct
spectral centroids: wood 419 Hz, shield 588 Hz, air 757 Hz, metal 830 Hz.
These are signal measurements, not a substitute for listening.

**Listening status: not listened to in this helper QA pass.** The reel is
available for headphone/speaker review and comparison against the music and
live combat mix. Unit checks do not establish native host playback, visual
quality, subjective impact quality, or the final game's loudness balance.
