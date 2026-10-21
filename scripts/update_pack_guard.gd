extends RefCounted
## Format reference: godotengine/godot 4.6 core/io/pck_packer.cpp and file_access_pack.cpp.
## Strict standalone PCK v3 reader for packs emitted by Godot 4.6.3 PCKPacker.
## No mounting, extraction or resource decoding occurs during this validation.
## This protects the bootstrap namespace, not against a compromised trusted publisher.
const MAX_SIZE := 512 * 1024 * 1024
const MAX_FILES := 10000
const MAX_DIRECTORY := 8 * 1024 * 1024

static func allowed_path(path: String) -> bool:
	if path.is_empty() or path.length() > 4096 or path.begins_with("/") or path.ends_with("/") or "\\" in path or ":" in path:
		return false
	for character in path:
		if character.unicode_at(0) < 32 or character.unicode_at(0) == 127:
			return false
	for component in path.split("/"):
		if component in ["", ".", ".."] or component.ends_with(".") or component.ends_with(" "):
			return false
	var lower := path.to_lower()
	if lower.begins_with("scripts/update_"):
		return false
	if path in ["main.tscn", "default_bus_layout.tres", "icon.svg", "icon.svg.import"]:
		return true
	var extension := path.get_extension()
	if path.begins_with(".godot/imported/"):
		return extension in ["ctex", "sample", "fontdata", "oggvorbisstr", "mp3str"]
	if path.begins_with("scripts/"):
		return extension in ["gd", "gdshader"]
	if path.begins_with("assets/"):
		return extension in ["import", "png", "jpg", "jpeg", "webp", "svg", "wav", "ogg", "mp3", "ttf", "otf", "ttc", "json", "gd", "gdshader", "tres"]
	return false

static func validate(file_path: String) -> bool:
	var f := FileAccess.open(file_path, FileAccess.READ)
	if f == null:
		return false
	var length := f.get_length()
	if length < 108 or length > MAX_SIZE:
		return false
	if f.get_32() != 0x43504447 or f.get_32() != 3:
		return false
	if f.get_32() != 4 or f.get_32() != 6 or f.get_32() != 3:
		return false
	# Only relative-file-base flag, no encrypted directory/sparse bundle.
	if f.get_32() != 2:
		return false
	var base := f.get_64()
	var directory := f.get_64()
	if base < 104 or directory < base or directory > length - 4 or length - directory > MAX_DIRECTORY:
		return false
	for i in range(16):
		if f.get_32() != 0:
			return false
	f.seek(directory)
	var count := f.get_32()
	if count < 1 or count > MAX_FILES:
		return false
	var paths := {}
	var ranges: Array = []
	for i in range(count):
		if f.get_position() > length - 4:
			return false
		var path_length := f.get_32()
		if path_length < 1 or path_length > 4096 or path_length % 4 != 0 or path_length > length - f.get_position() - 36:
			return false
		var bytes := f.get_buffer(path_length)
		var real_length := bytes.size()
		while real_length > 0 and bytes[real_length - 1] == 0:
			real_length -= 1
		if real_length == 0 or bytes.size() - real_length > 3:
			return false
		bytes.resize(real_length)
		if bytes.has(0):
			return false
		var path := bytes.get_string_from_utf8()
		if path.to_utf8_buffer() != bytes or not allowed_path(path) or paths.has(path.to_lower()):
			return false
		paths[path.to_lower()] = true
		var offset := f.get_64()
		var size := f.get_64()
		f.get_buffer(16) # Per-file MD5 is not an authenticity check; whole PCK SHA is verified by store.
		if f.get_32() != 0: # Reject encrypted, removal, delta and unknown entry flags.
			return false
		# Signed-negative rejects uint64 overflow before bounded subtraction/addition.
		if offset < 0 or size < 0 or offset > directory - base or size > directory - base - offset:
			return false
		if size > 0:
			ranges.append([base + offset, base + offset + size])
	if f.get_position() != length:
		return false
	ranges.sort_custom(func(a, b): return a[0] < b[0])
	var end := base
	for bounds in ranges:
		if bounds[0] < end:
			return false
		end = bounds[1]
	return true
