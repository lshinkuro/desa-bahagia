extends CanvasLayer
# Tampilan (HUD) dan menu utama bergaya kayu & perkamen (Kenney UI Pack Adventure, CC0).

signal play_single(player_name: String, model_idx: int)
signal play_host(player_name: String, model_idx: int)
signal play_join(player_name: String, model_idx: int, ip: String)
signal volume_changed(bus: String, value: float)
signal shop_buy(item_id: String)
signal shop_sell
signal shop_closed
signal chat_send(text: String)
signal reset_save

const INK := Color(0.33, 0.2, 0.1)
const CHARACTERS = ["Petani Budi", "Petani Sari", "Petani Joko", "Petani Rina", "Petani Dodi", "Petani Ayu"]
const ITEM_ICONS = {"Bibit": "seed", "Kayu": "wood", "Jerami": "hay", "Sayur": "carrot", "Telur": "egg", "Susu": "carton"}

var audio: Node
var root: Control
var hud: Control
var menu: Control
var day_label: Label
var time_label: Label
var coin_label: Label
var story_label: Label
var story_bar: ProgressBar
var daily_box: VBoxContainer
var bars := {}
var slots := {}
var prompt_panel: PanelContainer
var prompt_label: Label
var toast_panel: PanelContainer
var toast_label: Label
var toast_time := 0.0
var big_panel: PanelContainer
var big_label: Label
var players_panel: PanelContainer
var players_label: Label
var help_panel: PanelContainer
var build_panel: PanelContainer
var build_label: Label
var menu_status: Label
var name_edit: LineEdit
var ip_edit: LineEdit
var char_pick: OptionButton
var font: Font
var minimap: Control
var shop_panel: PanelContainer
var shop_coin_label: Label
var shop_sell_btn: Button
var chat_box: VBoxContainer
var chat_input: LineEdit
var chat_lines: Array = []
var version_text := ""


# ---------- tema ----------
func _tex_box(file: String, margin: int, content: int) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = load("res://assets/ui/" + file)
	sb.texture_margin_left = margin
	sb.texture_margin_right = margin
	sb.texture_margin_top = margin
	sb.texture_margin_bottom = margin
	sb.content_margin_left = content
	sb.content_margin_right = content
	sb.content_margin_top = content - 4
	sb.content_margin_bottom = content - 4
	return sb


func _flat(col: Color, radius := 8, border := Color.TRANSPARENT, bw := 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(radius)
	if bw > 0:
		sb.border_color = border
		sb.set_border_width_all(bw)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	return sb


func _make_theme() -> Theme:
	# Fredoka (Google Fonts, SIL OFL) — tebal & bulat, mudah dibaca.
	var base: FontFile = load("res://assets/ui/fredoka.ttf")
	var fv := FontVariation.new()
	fv.base_font = base
	fv.variation_opentype = {"wght": 600}
	font = fv
	var t := Theme.new()
	t.default_font = font
	t.default_font_size = 17
	t.set_stylebox("panel", "PanelContainer", _tex_box("panel_brown.png", 20, 20))
	t.set_color("font_color", "Label", INK)
	var b := _tex_box("button_brown.png", 12, 16)
	var bh := b.duplicate()
	bh.modulate_color = Color(1.15, 1.1, 1.0)
	var bp := b.duplicate()
	bp.modulate_color = Color(0.8, 0.75, 0.7)
	t.set_stylebox("normal", "Button", b)
	t.set_stylebox("hover", "Button", bh)
	t.set_stylebox("pressed", "Button", bp)
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", INK)
	t.set_color("font_hover_color", "Button", Color(0.6, 0.3, 0.05))
	t.set_color("font_pressed_color", "Button", INK)
	t.set_font_size("font_size", "Button", 19)
	var le := _flat(Color(1, 0.97, 0.9), 6, Color(0.55, 0.35, 0.18), 2)
	t.set_stylebox("normal", "LineEdit", le)
	t.set_stylebox("focus", "LineEdit", _flat(Color(1, 1, 0.95), 6, Color(0.85, 0.55, 0.2), 2))
	t.set_color("font_color", "LineEdit", INK)
	t.set_stylebox("normal", "OptionButton", b)
	t.set_stylebox("hover", "OptionButton", bh)
	t.set_stylebox("pressed", "OptionButton", bp)
	t.set_stylebox("focus", "OptionButton", StyleBoxEmpty.new())
	t.set_color("font_color", "OptionButton", INK)
	t.set_color("font_hover_color", "OptionButton", Color(0.6, 0.3, 0.05))
	t.set_stylebox("background", "ProgressBar", _flat(Color(0.3, 0.18, 0.1, 0.9), 6))
	t.set_stylebox("slider", "HSlider", _flat(Color(0.55, 0.35, 0.18), 4))
	t.set_stylebox("grabber_area", "HSlider", _flat(Color(0.9, 0.6, 0.2), 4))
	t.set_stylebox("grabber_area_highlight", "HSlider", _flat(Color(1, 0.7, 0.3), 4))
	return t


func _label(text: String, size := 17, col := INK, outline := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	if outline:
		l.add_theme_color_override("font_outline_color", Color(0.15, 0.08, 0.03))
		l.add_theme_constant_override("outline_size", maxi(4, int(size * 0.3)))
	return l


func _icon(name: String, size := 28) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = load("res://assets/icons/%s.png" % name)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.custom_minimum_size = Vector2(size, size)
	return tr


func _bar(col: Color, height := 14) -> ProgressBar:
	var pb := ProgressBar.new()
	pb.show_percentage = false
	pb.custom_minimum_size = Vector2(0, height)
	pb.add_theme_stylebox_override("fill", _flat(col, 6))
	return pb


func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 46)
	b.pressed.connect(func():
		if audio: audio.sfx("click")
		cb.call())
	b.mouse_entered.connect(func(): if audio: audio.sfx("hover"))
	return b


# ---------- susun tampilan ----------
func setup(audio_node: Node) -> void:
	audio = audio_node
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = _make_theme()
	add_child(root)
	_build_hud()
	_build_build_panel()
	_build_shop()
	_build_chat()
	_build_menu()


func _build_hud() -> void:
	hud = Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.visible = false
	root.add_child(hud)

	# Kiri atas: hari, jam, koin.
	var clock := PanelContainer.new()
	clock.position = Vector2(16, 14)
	clock.custom_minimum_size = Vector2(250, 0)
	hud.add_child(clock)
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 0)
	clock.add_child(cv)
	day_label = _label("Hari 1", 16, Color(0.6, 0.3, 0.12))
	cv.add_child(day_label)
	time_label = _label("06:00", 34)
	cv.add_child(time_label)
	var coin_row := HBoxContainer.new()
	coin_row.add_child(_icon("coin", 26))
	coin_label = _label("0", 22, Color(0.75, 0.5, 0.05))
	coin_row.add_child(coin_label)
	cv.add_child(coin_row)

	# Kiri: misi utama & harian.
	var mp := PanelContainer.new()
	mp.position = Vector2(16, 150)
	mp.custom_minimum_size = Vector2(340, 0)
	hud.add_child(mp)
	var mv := VBoxContainer.new()
	mv.add_theme_constant_override("separation", 4)
	mp.add_child(mv)
	mv.add_child(_label("MISI UTAMA", 15, Color(0.7, 0.25, 0.15)))
	story_label = _label("", 17)
	story_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	story_label.custom_minimum_size = Vector2(300, 0)
	mv.add_child(story_label)
	story_bar = _bar(Color(0.95, 0.65, 0.2), 10)
	mv.add_child(story_bar)
	var sep := HSeparator.new()
	sep.add_theme_stylebox_override("separator", _flat(Color(0.6, 0.4, 0.2, 0.5), 1))
	mv.add_child(sep)
	mv.add_child(_label("MISI HARIAN", 15, Color(0.2, 0.45, 0.2)))
	daily_box = VBoxContainer.new()
	mv.add_child(daily_box)

	# Kanan: peta kecil di bawah panel status.
	minimap = preload("res://minimap.gd").new()
	hud.add_child(minimap)

	# Kanan atas: status hewan & petani.
	var sp := PanelContainer.new()
	sp.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	sp.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	sp.offset_left = -290
	sp.offset_right = -16
	sp.offset_top = 14
	hud.add_child(sp)
	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 3)
	sp.add_child(sv)
	for item in [["energy", "Energi Petani", Color(1, 0.75, 0.15)],
			["cow_food", "Sapi Kenyang", Color(0.45, 0.8, 0.3)],
			["cow_happy", "Sapi Senang", Color(1, 0.5, 0.65)],
			["chicken", "Ayam Kenyang", Color(1, 0.6, 0.25)]]:
		var row := HBoxContainer.new()
		var l := _label(item[1], 15)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		var pct := _label("0%", 14, Color(0.5, 0.35, 0.2))
		row.add_child(pct)
		sv.add_child(row)
		var pb := _bar(item[2])
		sv.add_child(pb)
		bars[item[0]] = [pb, pct]

	# Bawah tengah: tas (hotbar).
	var hb := HBoxContainer.new()
	hb.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	hb.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hb.grow_vertical = Control.GROW_DIRECTION_BEGIN
	hb.offset_bottom = -14
	hb.add_theme_constant_override("separation", 8)
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hud.add_child(hb)
	for item in ITEM_ICONS:
		var slot := PanelContainer.new()
		slot.add_theme_stylebox_override("panel", _tex_box("panel_brown.png", 18, 12))
		slot.custom_minimum_size = Vector2(76, 76)
		hb.add_child(slot)
		var ov := Control.new()
		slot.add_child(ov)
		var ic := _icon(ITEM_ICONS[item], 44)
		ic.position = Vector2(4, 0)
		ov.add_child(ic)
		var cnt := _label("0", 18, Color.WHITE, true)
		cnt.position = Vector2(30, 26)
		cnt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		cnt.custom_minimum_size = Vector2(22, 0)
		ov.add_child(cnt)
		slot.tooltip_text = item
		slots[item] = cnt

	# Petunjuk aksi di atas tas.
	prompt_panel = PanelContainer.new()
	prompt_panel.add_theme_stylebox_override("panel", _flat(Color(0.12, 0.07, 0.03, 0.75), 18))
	prompt_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	prompt_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	prompt_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	prompt_panel.offset_bottom = -104
	hud.add_child(prompt_panel)
	var ph := HBoxContainer.new()
	ph.add_theme_constant_override("separation", 10)
	prompt_panel.add_child(ph)
	var key := _label("F", 18, INK)
	key.add_theme_stylebox_override("normal", _flat(Color(1, 0.95, 0.8), 6, Color(0.6, 0.4, 0.2), 2))
	key.name = "Key"
	ph.add_child(key)
	prompt_label = _label("", 19, Color(1, 0.96, 0.85))
	ph.add_child(prompt_label)
	prompt_panel.visible = false

	# Notifikasi (spanduk merah).
	toast_panel = PanelContainer.new()
	toast_panel.add_theme_stylebox_override("panel", _tex_box("banner_hanging.png", 40, 40))
	toast_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	toast_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	toast_panel.offset_top = 16
	toast_panel.custom_minimum_size = Vector2(380, 70)
	hud.add_child(toast_panel)
	toast_label = _label("", 20, Color(1, 0.97, 0.88), true)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_panel.add_child(toast_label)
	toast_panel.modulate.a = 0

	# Pesan besar di tengah.
	big_panel = PanelContainer.new()
	big_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	big_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	big_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	big_panel.custom_minimum_size = Vector2(520, 0)
	hud.add_child(big_panel)
	big_label = _label("", 30, Color(0.65, 0.3, 0.1))
	big_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	big_panel.add_child(big_label)
	big_panel.visible = false

	# Daftar pemain online (kanan bawah).
	players_panel = PanelContainer.new()
	players_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	players_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	players_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	players_panel.offset_right = -16
	players_panel.offset_bottom = -14
	hud.add_child(players_panel)
	players_label = _label("", 15)
	players_panel.add_child(players_label)
	players_panel.visible = false

	# Bantuan kontrol (tombol H).
	help_panel = PanelContainer.new()
	help_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	help_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	help_panel.offset_left = 16
	help_panel.offset_bottom = -14
	hud.add_child(help_panel)
	help_panel.add_child(_label("WASD  jalan\nSpasi  lompat\nF  aksi / tebang pohon\nB  menu bangun\nM  peta besar/kecil\nEnter  chat\nMouse / Q E  kamera\nT (tahan)  percepat waktu*\nH  sembunyikan bantuan\nEsc  lepas mouse\n* hanya host", 14))


func _build_build_panel() -> void:
	build_panel = PanelContainer.new()
	build_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	build_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	build_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	build_panel.offset_right = -16
	build_panel.offset_bottom = -100
	hud.add_child(build_panel)
	var v := VBoxContainer.new()
	build_panel.add_child(v)
	v.add_child(_label("MENU BANGUN", 16, Color(0.6, 0.3, 0.12)))
	build_label = _label("", 16)
	v.add_child(build_label)
	build_panel.visible = false


func show_build(mode: String, wood: int, coins: int, ok := true) -> void:
	# mode: "" = tutup, "menu" = pilih, "plot"/"house" = sedang menempatkan.
	build_panel.visible = mode != ""
	if mode == "menu":
		build_label.text = "[1] Petak Kebun\n     2 Kayu\n[2] Rumah Kayu\n     15 Kayu + 30 Koin\n\nKayu: %d   Koin: %d\n[B] Tutup" % [wood, coins]
	elif mode != "":
		var nm := "Petak Kebun" if mode == "plot" else "Rumah Kayu"
		build_label.text = "%s\n\n%s\n[F] Bangun\n[B] Batal\nPutar badan untuk\nmengubah arah" % [nm,
			"Tempat cocok" if ok else "Tidak bisa di sini!"]


func _build_menu() -> void:
	menu = Control.new()
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(menu)
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.03, 0.02, 0.35)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu.add_child(center)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", -8)
	center.add_child(col)

	var banner := PanelContainer.new()
	banner.add_theme_stylebox_override("panel", _tex_box("banner_classic_curtain.png", 46, 46))
	banner.custom_minimum_size = Vector2(520, 100)
	banner.z_index = 1
	col.add_child(banner)
	var title := _label("DESA BAHAGIA", 42, Color(1, 0.95, 0.8), true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.add_child(title)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(460, 0)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	var sub := _label("Rawat hewan, panen sayur, dan selesaikan misi bersama teman!", 15, Color(0.5, 0.32, 0.15))
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	v.add_child(grid)
	grid.add_child(_label("Nama", 17))
	name_edit = LineEdit.new()
	name_edit.text = "Petani%d" % (randi() % 100)
	name_edit.max_length = 14
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(name_edit)
	grid.add_child(_label("Karakter", 17))
	char_pick = OptionButton.new()
	for c in CHARACTERS:
		char_pick.add_item(c)
	char_pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(char_pick)

	v.add_child(_button("Main Sendiri", func(): play_single.emit(_name(), char_pick.selected)))
	v.add_child(_button("Buat Server (Host)", func(): play_host.emit(_name(), char_pick.selected)))
	var jr := HBoxContainer.new()
	ip_edit = LineEdit.new()
	ip_edit.text = "127.0.0.1"
	ip_edit.placeholder_text = "Alamat IP host"
	ip_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	jr.add_child(ip_edit)
	var jb := _button("Gabung", func(): play_join.emit(_name(), char_pick.selected, ip_edit.text.strip_edges()))
	jb.custom_minimum_size = Vector2(130, 46)
	jr.add_child(jb)
	v.add_child(jr)

	menu_status = _label("", 14, Color(0.55, 0.25, 0.1))
	menu_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	menu_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(menu_status)

	for bus in [["Music", "Musik", 0.6], ["SFX", "Efek suara", 0.8]]:
		var row := HBoxContainer.new()
		var l := _label(bus[1], 15)
		l.custom_minimum_size = Vector2(110, 0)
		row.add_child(l)
		var s := HSlider.new()
		s.min_value = 0
		s.max_value = 1
		s.step = 0.05
		s.value = bus[2]
		s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var bus_name: String = bus[0]
		s.value_changed.connect(func(val): volume_changed.emit(bus_name, val))
		row.add_child(s)
		v.add_child(row)

	var rb := Button.new()
	rb.text = "Hapus data simpanan"
	rb.flat = true
	rb.add_theme_font_size_override("font_size", 13)
	rb.add_theme_color_override("font_color", Color(0.65, 0.3, 0.15))
	rb.pressed.connect(func():
		if audio: audio.sfx("click")
		reset_save.emit())
	v.add_child(rb)
	var credit := _label("v%s  -  Aset: Kenney.nl & OpenGameArt (CC0)" % ProjectSettings.get_setting("application/config/version", "1.0"), 12, Color(0.55, 0.4, 0.25))
	credit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(credit)


func _name() -> String:
	var n := name_edit.text.strip_edges()
	return n if n != "" else "Petani"


# ---------- API untuk main.gd ----------
func show_game() -> void:
	menu.visible = false
	hud.visible = true


func show_menu(status := "") -> void:
	menu.visible = true
	hud.visible = false
	menu_status.text = status


func set_menu_status(text: String) -> void:
	menu_status.text = text


func set_clock(day: int, hours: float, is_day: bool, coins: int) -> void:
	day_label.text = "HARI %d  -  %s" % [day, "SIANG" if is_day else "MALAM"]
	time_label.text = "%02d:%02d" % [int(hours), int(fmod(hours, 1.0) * 60)]
	time_label.add_theme_color_override("font_color", INK if is_day else Color(0.25, 0.3, 0.55))
	coin_label.text = str(coins)


func set_bar(key: String, value: float) -> void:
	bars[key][0].value = value
	bars[key][1].text = "%d%%" % int(value)


func set_inventory(inv: Dictionary) -> void:
	for k in slots:
		slots[k].text = str(inv.get(k, 0))


func set_story(text: String, count: int, goal: int) -> void:
	story_label.text = text
	story_bar.max_value = maxi(goal, 1)
	story_bar.value = count
	story_bar.visible = goal > 0


func set_daily(list: Array) -> void:
	for c in daily_box.get_children():
		c.queue_free()
	for d in list:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var box := Label.new()
		box.text = "v" if d.done else ""
		box.custom_minimum_size = Vector2(22, 22)
		box.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		box.add_theme_color_override("font_color", Color(0.2, 0.55, 0.2))
		box.add_theme_stylebox_override("normal", _flat(Color(1, 0.97, 0.88), 4, Color(0.55, 0.35, 0.18), 2))
		row.add_child(box)
		var t := _label("%s  (%d/%d)" % [d.text % d.goal, mini(d.count, d.goal), d.goal], 15,
			Color(0.45, 0.6, 0.4) if d.done else INK)
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(t)
		row.add_child(_icon("coin", 18))
		row.add_child(_label(str(d.reward), 15, Color(0.75, 0.5, 0.05)))
		daily_box.add_child(row)


func prompt(text: String) -> void:
	prompt_panel.visible = text != ""
	var has_key := text.begins_with("[F] ")
	prompt_panel.get_child(0).get_node("Key").visible = has_key
	prompt_label.text = text.substr(4) if has_key else text


func toast(text: String) -> void:
	toast_label.text = text
	toast_time = 2.8


func big_message(text: String, seconds := 5.0) -> void:
	big_label.text = text
	big_panel.visible = true
	get_tree().create_timer(seconds).timeout.connect(func(): big_panel.visible = false)


func set_players(names: Array) -> void:
	players_panel.visible = names.size() > 0
	players_label.text = "ONLINE (%d)\n%s" % [names.size(), "\n".join(PackedStringArray(names))]


func _unhandled_input(event: InputEvent) -> void:
	if hud.visible and not is_busy() and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_H:
			help_panel.visible = not help_panel.visible
		elif event.keycode == KEY_M:
			minimap.toggle()
			if audio: audio.sfx("open")


func _process(delta: float) -> void:
	for cl in chat_lines:
		cl[1] -= delta
		cl[0].modulate.a = 1.0 if chat_input.visible else clampf(cl[1], 0, 1)
	if toast_time > 0:
		toast_time -= delta
		toast_panel.modulate.a = clampf(toast_time * 2.0, 0, 1)


# ---------- toko ----------
func _build_shop() -> void:
	shop_panel = PanelContainer.new()
	shop_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	shop_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	shop_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	shop_panel.custom_minimum_size = Vector2(470, 0)
	hud.add_child(shop_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	shop_panel.add_child(v)
	var top := HBoxContainer.new()
	var t := _label("KIOS DESA", 24, Color(0.65, 0.28, 0.1))
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(t)
	top.add_child(_icon("coin", 24))
	shop_coin_label = _label("0", 22, Color(0.75, 0.5, 0.05))
	top.add_child(shop_coin_label)
	v.add_child(top)
	shop_sell_btn = _button("Jual semua hasil panen", func(): shop_sell.emit())
	v.add_child(shop_sell_btn)
	v.add_child(_label("BELI", 15, Color(0.2, 0.45, 0.2)))
	for item in [["seed", "seed", "Bibit Sayur", "Tanam di petak kebunmu", 5],
			["bread", "bread", "Roti Hangat", "Langsung dimakan: energi +40", 10],
			["chicken", "egg", "Ayam Baru", "Lebih banyak ayam = lebih cepat bertelur", 40],
			["cow", "carton", "Sapi Baru", "Tambah sapi di padang rumput", 120]]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row.add_child(_icon(item[1], 40))
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_constant_override("separation", -2)
		info.add_child(_label(item[2], 18))
		info.add_child(_label(item[3], 13, Color(0.5, 0.35, 0.2)))
		row.add_child(info)
		var price := HBoxContainer.new()
		price.add_child(_icon("coin", 18))
		price.add_child(_label(str(item[4]), 17, Color(0.75, 0.5, 0.05)))
		row.add_child(price)
		var id: String = item[0]
		var b := _button("Beli", func(): shop_buy.emit(id))
		b.custom_minimum_size = Vector2(80, 40)
		row.add_child(b)
		v.add_child(row)
	v.add_child(_button("Tutup", func(): shop_closed.emit()))
	shop_panel.visible = false


func show_shop(open: bool, coins := 0, sell_value := 0, sell_count := 0) -> void:
	shop_panel.visible = open
	shop_coin_label.text = str(coins)
	shop_sell_btn.text = "Jual %d barang  (+%d koin)" % [sell_count, sell_value] if sell_count > 0 else "Belum ada hasil untuk dijual"
	shop_sell_btn.disabled = sell_count == 0
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if open else Input.MOUSE_MODE_CAPTURED


func is_busy() -> bool:
	return shop_panel.visible or chat_input.visible


# ---------- chat ----------
func _build_chat() -> void:
	var holder := VBoxContainer.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	holder.grow_vertical = Control.GROW_DIRECTION_BEGIN
	holder.offset_left = 290
	holder.offset_bottom = -110
	holder.custom_minimum_size = Vector2(420, 0)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(holder)
	chat_box = VBoxContainer.new()
	chat_box.add_theme_constant_override("separation", 2)
	chat_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(chat_box)
	chat_input = LineEdit.new()
	chat_input.placeholder_text = "Ketik pesan lalu Enter (Esc batal)"
	chat_input.max_length = 120
	chat_input.visible = false
	chat_input.text_submitted.connect(func(txt: String):
		var msg := txt.strip_edges()
		chat_input.text = ""
		chat_input.visible = false
		chat_input.release_focus()
		if msg != "":
			chat_send.emit(msg))
	chat_input.gui_input.connect(func(e):
		if e is InputEventKey and e.pressed and e.keycode == KEY_ESCAPE:
			chat_input.text = ""
			chat_input.visible = false
			chat_input.release_focus()
			get_viewport().set_input_as_handled())
	holder.add_child(chat_input)


func open_chat() -> void:
	chat_input.visible = true
	chat_input.grab_focus.call_deferred()


func add_chat(who: String, text: String, system := false) -> void:
	var l := _label("%s: %s" % [who, text] if not system else text, 16,
		Color(1, 0.95, 0.75) if not system else Color(0.75, 1, 0.75), true)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(420, 0)
	chat_box.add_child(l)
	chat_lines.append([l, 14.0])
	while chat_lines.size() > 7:
		chat_lines.pop_front()[0].queue_free()
