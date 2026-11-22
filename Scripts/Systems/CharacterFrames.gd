class_name CharacterFrames
extends RefCounted
## Công cụ dùng chung cho Player và Enemy: cắt spritesheet của "2D HD Character pack" thành animation 8 hướng.
## Mỗi spritesheet có 8 hàng (8 hướng) x N cột (khung hình), mỗi khung frame_size pixel.
## Không cần gắn vào node nào, chỉ cần để file này trong project.


## Dựng SpriteFrames từ thư mục chứa các spritesheet.
## sheets: {"khóa": "TênFile"}, ví dụ {"idle": "Idle", "move": "Walk"} (file là TênFile.png).
## loops:  {"khóa": true/false} animation có lặp không.
## Animation tạo ra có tên "<khóa>_<hàng>", ví dụ "move_3". Trả về null nếu không có sheet nào đọc được.
static func build(folder: String, sheets: Dictionary, loops: Dictionary, frame_size: int, fps: float) -> SpriteFrames:
	if folder.is_empty():
		push_warning("CharacterFrames: chưa chọn Character Folder.")
		return null
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	var found_any := false
	for key in sheets:
		var path := folder.path_join(str(sheets[key]) + ".png")
		if not ResourceLoader.exists(path):
			push_warning("CharacterFrames: không tìm thấy %s" % path)
			continue
		var tex := load(path) as Texture2D
		if tex == null:
			continue
		var cols := floori(float(tex.get_width()) / frame_size)
		var rows := floori(float(tex.get_height()) / frame_size)
		for r in rows:
			var anim_name := "%s_%d" % [key, r]
			frames.add_animation(anim_name)
			frames.set_animation_speed(anim_name, fps)
			frames.set_animation_loop(anim_name, bool(loops.get(key, true)))
			for c in cols:
				var atlas := AtlasTexture.new()
				atlas.atlas = tex
				atlas.region = Rect2(c * frame_size, r * frame_size, frame_size, frame_size)
				frames.add_frame(anim_name, atlas)
		found_any = true
	return frames if found_any else null


## Hàng của hướng nhìn trong spritesheet "2D HD Character pack" (đã đối chiếu bằng mắt với Idle/Walk của 1Knight và 6Mage).
## Thứ tự hàng 0..7 là: SE, S, SW, W, NW, N, NE, E (xoay theo chiều kim đồng hồ, bắt đầu từ Đông-Nam).
## LƯU Ý: thứ tự cũ (W, SW, S, SE, E, NE, N, NW) lấy từ pack "2D HD Character Knight" trong Player.tscn, KHÔNG đúng với pack này.
## Bảng tra theo "bát phân" của góc: chỉ số 0 = Đông, 1 = Đông-Nam, 2 = Nam, 3 = Tây-Nam, 4 = Tây, 5 = Tây-Bắc, 6 = Bắc, 7 = Đông-Bắc
## (trục Y của Godot hướng xuống nên góc dương là hướng xuống). Nếu đổi sang pack có thứ tự hàng khác, chỉ cần sửa bảng này.
const ROW_BY_OCTANT: Array[int] = [7, 0, 1, 2, 3, 4, 5, 6]


static func direction_row(dir: Vector2) -> int:
	var octant := posmod(roundi(dir.angle() / (PI / 4.0)), 8)
	return ROW_BY_OCTANT[octant]
