class_name VfxFrames
extends RefCounted
## Dựng SpriteFrames từ một THƯ MỤC chứa các ảnh PNG rời (0001.png, 0003.png, ...), sắp xếp theo tên.
## Kết quả được lưu đệm (cache) để bắn nhiều lần không phải nạp lại ảnh.
## Trả về null nếu thư mục trống/không tồn tại; khi đó nơi gọi dùng hình vẽ thay thế bằng code.

static var _cache: Dictionary = {}


## Gói hiệu ứng pixel-art 32x32 cần lọc NEAREST khi phóng to để không bị nhòe (các gói HD cũ vẫn dùng lọc mặc định).
static func is_pixel_folder(folder: String) -> bool:
	return folder.contains("Effect Bullet Impact Explosion")


## Thư mục asset từng được đặt tên Assets/Projectiles, Assets/Spells, Assets/Spell: nếu đường dẫn không tồn tại thì thử các tên còn lại.
static func resolve_folder(folder: String) -> String:
	if folder.is_empty() or DirAccess.dir_exists_absolute(folder):
		return folder
	var roots: Array[String] = ["/Assets/Spell/", "/Assets/Spells/", "/Assets/Projectiles/"]
	for root in roots:
		if folder.contains(root):
			for other in roots:
				if other != root:
					var alt: String = folder.replace(root, other)
					if DirAccess.dir_exists_absolute(alt):
						return alt
	return folder


## Ảnh đại diện của spell cho ô kỹ năng / viên spell: icon -> khung icon_frame của icon_folder -> khung giữa của vfx_folder.
static func icon_for(spell: SpellData) -> Texture2D:
	if spell == null:
		return null
	if spell.icon != null:
		return spell.icon
	if not spell.icon_folder.is_empty():
		var picked := load_folder(spell.icon_folder, 12.0, true)
		if picked != null:
			return picked.get_frame_texture("default", clampi(spell.icon_frame, 0, picked.get_frame_count("default") - 1))
	var frames := load_folder(spell.vfx_folder, spell.vfx_fps, true)
	if frames != null:
		@warning_ignore("integer_division")
		return frames.get_frame_texture("default", frames.get_frame_count("default") / 2)
	return null


## true nếu ảnh đại diện của spell là pixel-art (cần lọc NEAREST khi vẽ).
static func icon_is_pixel(spell: SpellData) -> bool:
	if spell == null:
		return false
	var folder := spell.icon_folder if not spell.icon_folder.is_empty() else spell.vfx_folder
	return is_pixel_folder(folder)


static func load_folder(folder: String, fps: float = 24.0, loop: bool = true) -> SpriteFrames:
	if folder.is_empty():
		return null
	folder = resolve_folder(folder)
	var key := "%s|%s|%s" % [folder, fps, loop]
	if _cache.has(key):
		return _cache[key] as SpriteFrames
	var names: Array[String] = []
	var seen := {}
	for file_name in DirAccess.get_files_at(folder):
		# Khi chạy từ bản xuất (export), tên file có đuôi .import hoặc .remap -> bỏ đuôi để dùng load() bình thường.
		var clean := file_name.trim_suffix(".import").trim_suffix(".remap")
		if clean.get_extension().to_lower() != "png" or seen.has(clean):
			continue
		seen[clean] = true
		names.append(clean)
	if names.is_empty():
		push_warning("VfxFrames: không tìm thấy ảnh PNG trong '%s'." % folder)
		_cache[key] = null
		return null
	names.sort()
	var frames := SpriteFrames.new()
	frames.set_animation_speed("default", fps)
	frames.set_animation_loop("default", loop)
	for n in names:
		var tex := load(folder.path_join(n)) as Texture2D
		if tex != null:
			frames.add_frame("default", tex)
	if frames.get_frame_count("default") == 0:
		_cache[key] = null
		return null
	_cache[key] = frames
	return frames
