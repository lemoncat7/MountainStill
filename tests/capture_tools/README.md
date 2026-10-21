# Continuous native fresh-player capture

Run `bash tests/capture_tools/capture_fresh_journey.sh /absolute/new-output` from a native desktop terminal with Godot 4.6.3 installed. The directory must contain neither an earned save nor a movie. Set `GODOT_BIN` if needed. The driver assigns only an isolated save path before ordinary scene startup. It uses live control rectangles and automated mouse motion/down/up through Godot's input dispatcher, never signal emission or gameplay-state injection. All waits run ordinary production processing. No RNG seed is supplied.

The source movie uses native MovieMaker OGV at fixed 60 fps. Its game timeline is ordinary 1x speed even when software rendering requires more wall time. The neutral backdrop and small elapsed-time banner are recording-only nodes; production art and transparency settings remain unchanged. Inspect the actual native desktop as well as the movie: a correct viewport capture alone does not prove working native window presentation.

After successful completion, run:

- `python3 tests/capture_tools/audit_causal_evidence.py /absolute/output/complete-player-journey.json`
- `bash tests/capture_tools/encode_journey.sh /absolute/output`

The encoder preserves all elapsed video, converts 60 to 30 fps, and creates consecutive MP4 parts near 150-second keyframe boundaries, with exact measured ranges in the manifest. It verifies each is at most 8 MiB. The manifest includes SHA-256, exact source frame intervals, playback duration, codec, and dimensions. Audio/container padding is separated from video duration.

The continuous movie's middle reload is a normal scene reload of the same earned file, not a new OS process. A separate stronger proof is available after the full run:

`godot --path . --resolution 1200x320 --fixed-fps 60 --write-movie /absolute/restart-output/native.ogv --script tests/show_complete_player_restart.gd -- --earned=/absolute/output/earned-save.json --expected=/absolute/output/complete-player-journey.json --output=/absolute/restart-output`

Create the restart output directory first and redirect the command's output to its `native.log`. This new process loads the exact original earned save. Persistent gear, materials, learned ranks, claims and chapters are compared exactly; ordinary offline qi/merit/lifetime changes remain enabled and are logged. Keep this short proof separate from the uninterrupted fresh-play film.

For fast logic preflight only, use `--headless --disable-render-loop` with the same fresh driver. Such a run is explicitly not native video evidence. The full JSON action/phase ledger records before/after economics, all eighteen searches, source hashes, and reload continuity.
