extends Control
# Peta kecil (minimap) bergaya kertas: denah desa, hewan, bangunan, dan pemain.
# Utara (-Z) selalu di atas. Peta kecil mengikuti pemain; tombol M menampilkan
# peta besar seluruh desa.

var main: Node
var big := false
var cv: Control          # kanvas isi peta (dipotong berbentuk lingkaran)
var center_w := Vector3.ZERO
var range_w := 32.0
const SMALL := 190.0
const BIG := 400.0

const C_BORDER := Color(0.42, 0.26, 0.12)
const C_GRASS := Color(0.62, 0.78, 0.45)
const C_ROAD := Color(0.86, 0.74, 0.52)
const C_SOIL := Color(0.55, 0.38, 0.22)
const C_PASTURE := Color(0.72, 0.86, 0.5)
const C_FENCE := Color(0.45, 0.3, 0.15)
const C_WATER := Color(0.35, 0.62, 0.88)
const C_ROOF := Color(0.82, 0.32, 0.3)
const C_TREE := Color(0.25, 0.48, 0.2)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	cv = Control.new()
	cv.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cv.draw.connect(_draw_content)
	add_child(cv)
	var ring := Control.new()
	ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.draw.connect(func():
		var c := ring.size / 2
		ring.draw_arc(c, c.x - 3.5, 0, TAU, 64, C_BORDER, 7, true)
		ring.draw_arc(c, c.x - 8, 0, TAU, 64, Color(1, 0.95, 0.82, 0.9), 2, true)
		_text(ring, Vector2(c.x, 14), "U", 13, Color(0.6, 0.15, 0.1)))
	add_child(ring)
	_apply_size()


func toggle() -> void:
	big = not big
	_apply_size()


func _apply_size() -> void:
	var s := BIG if big else SMALL
	custom_minimum_size = Vector2(s, s)
	anchor_left = 1.0
	anchor_right = 1.0
	anchor_top = 0.0
	anchor_bottom = 0.0
	offset_left = -s - 16
	offset_right = -16
	offset_top = 206
	offset_bottom = 206 + s


func _process(_d: float) -> void:
	if is_visible_in_tree():
		queue_redraw()
		cv.queue_redraw()


func _draw() -> void:
	# Bentuk lingkaran ini sekaligus menjadi "topeng" untuk isi peta.
	draw_circle(size / 2, size.x / 2 - 1, C_GRASS)


func w2m(p: Vector3) -> Vector2:
	return size / 2 + Vector2(p.x - center_w.x, p.z - center_w.z) * _scale()


func _scale() -> float:
	return (size.x / 2 - 8) / range_w


func _rect(center: Vector3, wsize: Vector2, col: Color, outline := Color.TRANSPARENT) -> void:
	var sz := wsize * _scale()
	var r := Rect2(w2m(center) - sz / 2, sz)
	cv.draw_rect(r, col)
	if outline.a > 0:
		cv.draw_rect(r, outline, false, 1.5)


func _text(target: CanvasItem, pos: Vector2, t: String, fs := 11, col := Color(0.3, 0.18, 0.08)) -> void:
	var f := get_theme_default_font()
	var w := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	target.draw_string_outline(f, pos - Vector2(w / 2, -4), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(1, 0.97, 0.88, 0.9))
	target.draw_string(f, pos - Vector2(w / 2, -4), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


func _draw_content() -> void:
	if main == null or main.player == null:
		return
	if big:
		center_w = Vector3.ZERO
		range_w = 66.0
	else:
		center_w = main.player.global_position
		range_w = 32.0
	var s := _scale()

	# Jalan, kebun, padang rumput, kolam.
	_rect(Vector3(0, 0, 0), Vector2(4.5, 82), C_ROAD)
	_rect(Vector3(10, 0, 0), Vector2(20, 3.6), C_ROAD)
	_rect(Vector3(-14, 0, 0), Vector2(28, 3), C_ROAD)
	_rect(Vector3(27, 0, 0), Vector2(16, 20), C_SOIL, C_FENCE)
	var pmin: Vector2 = main.PASTURE_MIN
	var pmax: Vector2 = main.PASTURE_MAX
	_rect(Vector3((pmin.x + pmax.x) / 2, 0, (pmin.y + pmax.y) / 2), pmax - pmin, C_PASTURE, C_FENCE)
	cv.draw_circle(w2m(main.POND), 6 * s, C_WATER)

	# Pohon.
	for t in main.trees:
		cv.draw_circle(w2m(t.pos), maxf(1.6, 1.3 * s), C_TREE)

	# Rumah desa + kandang + kios + air mancur.
	for side in [-1, 1]:
		for z in main.HOUSE_Z:
			_rect(Vector3(side * 8.5, 0, z), Vector2(7.5, 5), C_ROOF, C_BORDER)
	_rect(Vector3(-18, 0, -16.5), Vector2(3, 1.5), Color(0.75, 0.45, 0.25), C_BORDER)
	_rect(Vector3(5.5, 0, -4.5), Vector2(2.5, 2.5), Color(0.95, 0.4, 0.35), C_BORDER)
	cv.draw_circle(w2m(Vector3(-6, 0, -4.6)), 1.6 * s, C_WATER)
	_rect(main.HAY_SPOT + Vector3(0, 0, -1.5), Vector2(2.6, 1.4), Color(0.95, 0.82, 0.4))

	# Bangunan buatan pemain.
	for b in main.builds_local:
		var pos: Vector3 = b[1]
		if b[0] == "plot":
			_rect(pos, Vector2(2.2, 2.2), C_SOIL, C_FENCE)
		elif b[0] == "house":
			var turned := absf(sin(float(b[2]))) > 0.5
			_rect(pos, Vector2(7.5, 5) if turned else Vector2(5, 7.5), Color(0.7, 0.45, 0.25), C_BORDER)

	# Hewan.
	for cw in main.cows:
		var m := w2m(cw.node.position)
		cv.draw_circle(m, maxf(2.4, 0.8 * s), Color.WHITE)
		cv.draw_arc(m, maxf(2.4, 0.8 * s), 0, TAU, 12, Color(0.2, 0.2, 0.2), 1.0)
	for ch in main.chickens:
		cv.draw_circle(w2m(ch.node.position), maxf(1.4, 0.4 * s), Color(1, 0.88, 0.25))

	# Label tempat penting.
	var fs := 13 if big else 11
	_text(cv, w2m(Vector3(27, 0, -12.5)), "Kebun", fs)
	_text(cv, w2m(Vector3(-37, 0, -1)), "Sapi", fs)
	_text(cv, w2m(Vector3(-37, 0, -22)), "Jerami", fs)
	_text(cv, w2m(Vector3(-16, 0, -20.5)), "Ayam", fs)
	_text(cv, w2m(Vector3(5.5, 0, -7.5)), "Kios", fs)
	_text(cv, w2m(main.POND + Vector3(0, 0, 8)), "Kolam", fs)
	_text(cv, w2m(main.HOME_DOOR + Vector3(-4, 0, -4)), "Rumahmu", fs, Color(0.6, 0.2, 0.1))

	# Pemain lain (titik biru).
	if main.players_root:
		for p in main.players_root.get_children():
			if p == main.player:
				continue
			var m := w2m(p.global_position)
			cv.draw_circle(m, 4.5, Color(0.25, 0.5, 0.95))
			cv.draw_arc(m, 4.5, 0, TAU, 12, Color.WHITE, 1.2)
			_text(cv, m + Vector2(0, -11), p.display_name, 11, Color(0.15, 0.3, 0.7))

	# Kamu: panah merah sesuai arah hadap.
	var pm := w2m(main.player.global_position)
	var r: float = main.player.model.rotation.y
	var f := Vector2(-sin(r), -cos(r))
	var side := Vector2(-f.y, f.x)
	var pts := PackedVector2Array([pm + f * 9, pm - f * 5 + side * 6, pm - f * 2, pm - f * 5 - side * 6])
	cv.draw_colored_polygon(pts, Color(0.9, 0.2, 0.15))
	cv.draw_polyline(pts + PackedVector2Array([pts[0]]), Color.WHITE, 1.5)
