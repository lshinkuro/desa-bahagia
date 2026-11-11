extends Node3D
# Game Pedesaan: rawat sapi & ayam ala Tamagotchi dan selesaikan misi.
# Aset 3D: Kenney (CC0) — lihat assets/LICENSE-*.txt

const MISSIONS = [
	{"key": "apple", "goal": 2, "text": "Makan apel untuk menambah energi"},
	{"key": "hay", "goal": 2, "text": "Ambil jerami di padang rumput sapi"},
	{"key": "feed_cow", "goal": 2, "text": "Beri jerami ke sapi yang lapar"},
	{"key": "pet_cow", "goal": 3, "text": "Elus sapi supaya senang"},
	{"key": "harvest", "goal": 4, "text": "Panen sayur di kebun"},
	{"key": "feed_chicken", "goal": 1, "text": "Beri sayur ke ayam di kandang"},
	{"key": "egg", "goal": 2, "text": "Ambil telur di kandang ayam"},
	{"key": "milk", "goal": 2, "text": "Perah susu sapi (sapi harus kenyang & senang)"},
	{"key": "sleep", "goal": 1, "text": "Tidur di rumahmu saat malam"},
	{"key": "wood", "goal": 5, "text": "Tebang pohon untuk mengumpulkan kayu"},
	{"key": "build_plot", "goal": 1, "text": "Bangun petak kebun sendiri (tekan B)"},
	{"key": "build_house", "goal": 1, "text": "Bangun rumah kayu (tekan B, butuh 15 kayu + 30 koin)"},
]
const HOME_DOOR = Vector3(-3.6, 0, 11.25)
const HAY_SPOT = Vector3(-31.7, 0, -15.5)
const COOP_SPOT = Vector3(-18, 0, -14)
const STALL_SPOT = Vector3(5.5, 0, -2.4)
const POND = Vector3(-26, 0, 15)
const HOUSE_Z = [-24, -10, 10, 24]
const S_HOUSE := 2.5

var mission_index := 0
var mission_count := 0
var energy := 100.0
var chicken_hunger := 20.0
var egg_timer := 10.0
var inv := {"Bibit": 3, "Kayu": 0, "Jerami": 0, "Sayur": 0, "Telur": 0, "Susu": 0}
var crops: Array = []
var egg_meshes: Array = []
var eggs := 0
var coop_label: Label3D
var game_speed := 1.0

const APPLE_POSITIONS = [
	Vector3(0, 0.7, -15), Vector3(-3, 0.7, 28), Vector3(-15, 0.7, -5),
	Vector3(15, 0.7, 20), Vector3(-30, 0.7, -22), Vector3(27, 0.7, 13),
	Vector3(38, 0.7, -7), Vector3(-20, 0.7, 32), Vector3(35, 0.7, -30),
	Vector3(-40, 0.7, 2),
]
var apples: Array = []
var chickens: Array = []
var clouds: Array = []
var player: CharacterBody3D
var rng := RandomNumberGenerator.new()
var time := 0.0
var cows: Array = []
const PASTURE_MIN = Vector2(-47, -19)
const PASTURE_MAX = Vector2(-27, -3)
# Siang-malam: satu hari penuh = DAY_LENGTH detik.
const DAY_LENGTH := 180.0
var day_time := 0.12  # 0..1, 0 = jam 06:00
var sun: DirectionalLight3D
var moon: DirectionalLight3D
var env: Environment
var sky_mat: ProceduralSkyMaterial
var lamps: Array = []
var model_cache := {}


func _ready() -> void:
	rng.seed = 7
	_setup_environment()
	_make_ground()
	_make_roads()
	_make_houses()
	_make_field()
	_make_pond()
	_make_coop()
	_make_pasture()
	_make_lamps()
	_make_trees()
	_make_decor()
	_make_scenery()
	_spawn_apples()
	_setup_audio_hud()


# ---------- helper ----------
func mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.9
	return m


func noise_mat(c1: Color, c2: Color, uv_scale: float, freq := 0.03) -> StandardMaterial3D:
	# Tekstur bergaya lukisan: noise lembut dua warna.
	var noise := FastNoiseLite.new()
	noise.frequency = freq
	noise.fractal_octaves = 4
	var grad := Gradient.new()
	grad.set_color(0, c1)
	grad.set_color(1, c2)
	var tex := NoiseTexture2D.new()
	tex.width = 512
	tex.height = 512
	tex.seamless = true
	tex.noise = noise
	tex.color_ramp = grad
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.uv1_scale = Vector3(uv_scale, uv_scale, 1)
	m.roughness = 1.0
	return m


func add_mesh(parent: Node, mesh: Mesh, pos: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = mat(color)
	parent.add_child(mi)
	return mi


func box(pos: Vector3, size: Vector3, color: Color, collide := true, parent: Node = self) -> Node3D:
	var bm := BoxMesh.new()
	bm.size = size
	if not collide:
		return add_mesh(parent, bm, pos, color)
	var body := StaticBody3D.new()
	body.position = pos
	parent.add_child(body)
	add_mesh(body, bm, Vector3.ZERO, color)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	body.add_child(cs)
	return body


func model(path: String, pos: Vector3, s := 1.0, rot := 0.0, parent: Node = self) -> Node3D:
	if not model_cache.has(path):
		model_cache[path] = load("res://assets/%s.glb" % path)
	var n: Node3D = model_cache[path].instantiate()
	n.position = pos
	n.scale = Vector3.ONE * s
	n.rotation.y = rot
	if path.begins_with("nature/"):
		for mi in n.find_children("*", "MeshInstance3D", true, false):
			for i in mi.mesh.get_surface_count():
				mi.set_surface_override_material(i, _fix_mat(mi.mesh.surface_get_material(i)))
	parent.add_child(n)
	return n


var _mat_cache := {}
func _fix_mat(m: Material) -> Material:
	# Palet Nature Kit hijau-kebiruan & unlit: geser ke hijau hangat dan aktifkan cahaya.
	if not (m is BaseMaterial3D):
		return m
	if _mat_cache.has(m):
		return _mat_cache[m]
	var out: BaseMaterial3D = m.duplicate()
	out.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	out.roughness = 0.9
	var c: Color = out.albedo_color
	var nm := m.resource_name.to_lower()
	if nm.contains("wood") or nm.contains("bark") or nm.contains("trunk"):
		out.albedo_color = Color(0.5, 0.33, 0.2)
	elif nm.contains("dirt"):
		out.albedo_color = Color(0.45, 0.32, 0.2)
	elif c.h > 0.36 and c.h < 0.62 and c.s > 0.15:
		var t := (c.h - 0.36) / 0.26
		out.albedo_color = Color.from_hsv(lerpf(0.2, 0.3, t), clampf(c.s * 1.25, 0, 1), c.v * 0.72)
	_mat_cache[m] = out
	return out


func collider(pos: Vector3, size: Vector3, parent: Node = self, rot := 0.0) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	body.rotation.y = rot
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	body.add_child(cs)
	parent.add_child(body)


func cyl_collider(pos: Vector3, radius: float, height: float) -> void:
	var body := StaticBody3D.new()
	body.position = pos + Vector3(0, height / 2, 0)
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	cs.shape = shape
	body.add_child(cs)
	add_child(body)


func find_anim(n: Node) -> AnimationPlayer:
	return n.find_child("AnimationPlayer", true, false) as AnimationPlayer


func mesh_of(path: String) -> Mesh:
	var n: Node = load("res://assets/%s.glb" % path).instantiate()
	var mi := n.find_children("*", "MeshInstance3D", true, false)
	var mesh: Mesh = (mi[0] as MeshInstance3D).mesh.duplicate() if mi.size() > 0 else null
	n.free()
	if mesh and path.begins_with("nature/"):
		for i in mesh.get_surface_count():
			mesh.surface_set_material(i, _fix_mat(mesh.surface_get_material(i)))
	return mesh


func _is_open(p: Vector3, margin := 0.0) -> bool:
	# true jika titik tidak berada di jalan, rumah, kebun, kolam, atau kandang.
	if absf(p.x) < 2.6 + margin and absf(p.z) < 41: return false
	if absf(p.z) < 2.2 + margin and p.x > -29 and p.x < 21: return false
	if absf(p.x) > 4.2 - margin and absf(p.x) < 13 + margin:
		for z in HOUSE_Z:
			if absf(p.z - z) < 3.2 + margin: return false
	if p.x > 18 - margin and p.x < 36 + margin and absf(p.z) < 11 + margin: return false
	if p.distance_to(POND) < 6.8 + margin: return false
	if p.distance_to(Vector3(-18, 0, -16)) < 2.6 + margin: return false
	return true


func scatter(paths: Array, count: int, smin: float, smax: float, area: float, margin := 0.0, shadows := false) -> void:
	# Menyebar banyak objek kecil (rumput, bunga) secara efisien dengan MultiMesh.
	for path in paths:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh_of(path)
		var xfs: Array[Transform3D] = []
		var tries := 0
		while xfs.size() < count and tries < count * 10:
			tries += 1
			var p := Vector3(rng.randf_range(-area, area), 0, rng.randf_range(-area, area))
			if not _is_open(p, margin): continue
			var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(smin, smax))
			xfs.append(Transform3D(b, p))
		mm.instance_count = xfs.size()
		for i in xfs.size():
			mm.set_instance_transform(i, xfs[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		if not shadows:
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)


# ---------- world ----------
func _setup_environment() -> void:
	sky_mat = ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.3, 0.55, 0.95)
	sky_mat.sky_horizon_color = Color(0.85, 0.9, 0.95)
	sky_mat.ground_horizon_color = Color(0.85, 0.9, 0.95)
	sky_mat.sun_angle_max = 20
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	env.ssao_enabled = true
	env.ssao_radius = 1.5
	env.ssao_intensity = 1.5
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 0.9
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.08
	env.adjustment_contrast = 1.05
	env.fog_enabled = true
	env.fog_light_color = Color(0.8, 0.88, 0.95)
	env.fog_density = 0.004
	env.fog_sun_scatter = 0.25
	env.fog_aerial_perspective = 0.4
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	sun.shadow_blur = 1.5
	sun.directional_shadow_max_distance = 90
	add_child(sun)

	moon = DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-60, 140, 0)
	moon.light_color = Color(0.6, 0.7, 1.0)
	moon.light_energy = 0.0
	add_child(moon)


func _make_ground() -> void:
	var pm := PlaneMesh.new()
	pm.size = Vector2(240, 240)
	var mi := MeshInstance3D.new()
	mi.mesh = pm
	mi.material_override = noise_mat(Color(0.28, 0.48, 0.14), Color(0.46, 0.62, 0.22), 30)
	add_child(mi)
	collider(Vector3(0, -0.5, 0), Vector3(240, 1, 240))


func _road(pos: Vector3, size: Vector2) -> void:
	var pm := PlaneMesh.new()
	pm.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = pm
	mi.position = pos + Vector3(0, 0.02, 0)
	var m := noise_mat(Color(0.55, 0.4, 0.25), Color(0.75, 0.6, 0.4), 1, 0.08)
	m.uv1_scale = Vector3(size.x / 8, size.y / 8, 1)
	mi.material_override = m
	add_child(mi)


func _make_roads() -> void:
	_road(Vector3(0, 0, 0), Vector2(4.5, 82))
	_road(Vector3(10, 0, 0), Vector2(20, 3.6))
	_road(Vector3(-14, 0, 0), Vector2(28, 3))
	# Batu pijakan di tepi jalan.
	for z in range(-40, 41, 5):
		for side in [-1, 1]:
			if absf(z) < 3: continue
			model("nature/rock_smallB", Vector3(side * 2.7, 0, z + rng.randf_range(-0.6, 0.6)), 1.6, rng.randf() * TAU)


func _make_houses() -> void:
	var i := 0
	for side in [-1, 1]:
		for z in HOUSE_Z:
			_house(Vector3(side * 8.5, 0, z), -side * PI / 2, i % 2 == 0)
			i += 1
	var home := _status_label(self, HOME_DOOR + Vector3(-1.2, 6.8, 0))
	home.text = "Rumahmu"
	home.modulate = Color(1, 0.9, 0.5)


func _house(pos: Vector3, rot: float, wood: bool, s := S_HOUSE, w := 2, d := 3) -> Node3D:
	# Rumah modular dari Kenney Fantasy Town Kit; pintu di sisi +Z lokal.
	var h := Node3D.new()
	h.position = pos
	h.rotation.y = rot
	add_child(h)
	var wall := "town/wall-wood" if wood else "town/wall"
	var window := "town/wall-wood-window-shutters" if wood else "town/wall-window-shutters"
	for i in w:
		for j in d:
			var c := Vector3(i - (w - 1) / 2.0, 0, j - (d - 1) / 2.0) * s
			if i == w - 1: model(window if j == 1 else wall, c, s, 0, h)
			if i == 0: model(window if j == 1 else wall, c, s, PI, h)
			if j == d - 1: model("town/wall-wood-door" if i == 0 else window, c, s, -PI / 2, h)
			if j == 0: model(wall, c, s, PI / 2, h)
			model("town/roof-high", c + Vector3(0, s, 0), s, 0.0 if i == 0 else PI, h)
	var gable := Color(0.62, 0.36, 0.25) if wood else Color(0.92, 0.86, 0.76)
	for z in [-d / 2.0, d / 2.0]:
		var pm := PrismMesh.new()
		pm.size = Vector3(w * s, s, 0.12)
		add_mesh(h, pm, Vector3(0, s * 1.5, z * s), gable)
	model("town/chimney", Vector3(0.45 * s, s * 1.1, -0.6 * s), s * 0.8, 0, h)
	collider(Vector3(0, s / 2, 0), Vector3(w * s, s, d * s), h)
	# Hiasan halaman.
	if s == S_HOUSE:
		model("survival/barrel", Vector3(w * s / 2 + 0.6, 0, d * s / 2 + 0.6), 3.0, rng.randf() * TAU, h)
		for k in 4:
			model("nature/flower_" + ["redA", "yellowA", "purpleA", "redB"][k],
				Vector3(-w * s / 2 + 0.6 + k * 0.6, 0, d * s / 2 + 0.5), 2.5, rng.randf() * TAU, h)
		model("nature/plant_bushDetailed", Vector3(-w * s / 2 - 0.6, 0, d * s / 2 - 0.5), 3.0, 0, h)
	return h


func _make_field() -> void:
	# Kebun sayur: barisan tanah + tanaman yang bisa dipanen.
	var soil := PlaneMesh.new()
	soil.size = Vector2(16, 18)
	var sm := MeshInstance3D.new()
	sm.mesh = soil
	sm.position = Vector3(27, 0.03, 0)
	sm.material_override = noise_mat(Color(0.35, 0.22, 0.12), Color(0.5, 0.33, 0.18), 2, 0.1)
	add_child(sm)
	var kinds := ["nature/crop_carrot", "nature/crop_pumpkin", "nature/crop_turnip", "nature/crops_leafsStageB", "nature/crop_melon"]
	for z in range(-8, 9, 2):
		var kind: String = kinds[int((z + 8) * 0.5) % kinds.size()]
		for x in range(20, 35, 2):
			model("nature/crops_dirtRow", Vector3(x, 0.05, z), 2.0)
			var cm := model(kind, Vector3(x, 0.05, z), 2.4, rng.randf() * TAU)
			crops.append({"node": cm, "ready": true, "timer": 0.0, "plot": false, "planted": true, "full": cm.scale.x})
	_fence_line(Vector3(19, 0, -10), Vector3(35, 0, -10))
	_fence_line(Vector3(19, 0, 10), Vector3(35, 0, 10))
	_fence_line(Vector3(35, 0, -10), Vector3(35, 0, 10))
	_fence_line(Vector3(19, 0, -10), Vector3(19, 0, -2))
	_fence_line(Vector3(19, 0, 2), Vector3(19, 0, 10))
	model("town/cart", Vector3(17, 0, 5), 2.5, 0.3)
	collider(Vector3(17, 0.7, 5), Vector3(2.2, 1.4, 3.3), self, 0.3)
	model("survival/signpost", Vector3(17.5, 0, -3), 3.0, PI / 2)


func _fence_line(a: Vector3, b: Vector3) -> void:
	var length := a.distance_to(b)
	var dirv := (b - a) / length
	var theta := atan2(-dirv.z, dirv.x)
	var n := maxi(1, int(ceil(length / 2.0)))
	var seg := length / n
	var s := 2.2
	for k in n:
		var center := a.lerp(b, (k + 0.5) / n)
		var f := model("nature/fence_simple", center + Vector3(sin(theta), 0, cos(theta)) * 0.5 * s, s, theta)
		f.scale.x = seg
	var horizontal_x: bool = absf(b.x - a.x) > absf(b.z - a.z)
	var size := Vector3(length, 1.2, 0.2) if horizontal_x else Vector3(0.2, 1.2, length)
	collider((a + b) / 2 + Vector3(0, 0.6, 0), size)


func _make_pond() -> void:
	var water := CylinderMesh.new()
	water.top_radius = 6
	water.bottom_radius = 6
	water.height = 0.05
	water.radial_segments = 48
	var wm := StandardMaterial3D.new()
	wm.albedo_color = Color(0.2, 0.55, 0.75, 0.85)
	wm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wm.metallic = 0.4
	wm.roughness = 0.05
	var mi := MeshInstance3D.new()
	mi.mesh = water
	mi.position = POND + Vector3(0, 0.04, 0)
	mi.material_override = wm
	add_child(mi)
	for k in 18:
		var a := k * TAU / 18 + rng.randf_range(-0.1, 0.1)
		var rock: String = ["nature/rock_smallA", "nature/rock_smallC", "nature/rock_smallE", "nature/rock_largeA"][k % 4]
		model(rock, POND + Vector3(cos(a), 0, sin(a)) * 6.3, rng.randf_range(2.0, 3.0), rng.randf() * TAU)
	for k in 6:
		var a := rng.randf() * TAU
		model("nature/lily_large" if k % 2 == 0 else "nature/lily_small",
			POND + Vector3(cos(a), 0.05, sin(a)) * rng.randf_range(1.5, 4.5), 2.5, rng.randf() * TAU)
	for k in 8:
		var a := rng.randf() * TAU
		model("nature/plant_flatTall", POND + Vector3(cos(a), 0, sin(a)) * 6.9, 3.0, rng.randf() * TAU)
	model("nature/log_large", POND + Vector3(7.5, 0, 2), 2.5, 0.6)
	model("nature/bridge_wood", POND + Vector3(0, 0, -6), 2.2, 0)


func _make_coop() -> void:
	# Kandang ayam kecil dari potongan rumah + ayam beranimasi.
	_house(Vector3(-18, 0, -16.5), 0, true, 1.5, 2, 1)
	box(Vector3(-18, 0.1, -14.3), Vector3(2.6, 0.2, 0.9), Color(0.85, 0.72, 0.4), false)
	for k in range(6):
		var em := model("food/egg", Vector3(-19 + k * 0.4, 0.2, -14.3), 2.5, rng.randf() * TAU)
		em.visible = false
		egg_meshes.append(em)
	coop_label = _status_label(self, Vector3(-18, 3.6, -16))
	for k in range(6):
		_add_chicken(Vector3(-18 + rng.randf_range(-5, 5), 0, -12 + rng.randf_range(-3, 3)))


func _add_chicken(pos: Vector3) -> void:
	var c := Node3D.new()
	c.position = pos
	add_child(c)
	var m := model("pets/animal-chick", Vector3.ZERO, 0.3, PI, c)
	var ap := find_anim(m)
	if ap:
		ap.play("walk")
		ap.speed_scale = rng.randf_range(0.9, 1.2)
	chickens.append({"node": c, "dir": rng.randf() * TAU, "timer": 0.0})


func _make_pasture() -> void:
	# Padang rumput berpagar dengan sapi; celah pintu di sisi timur.
	var a := PASTURE_MIN
	var b := PASTURE_MAX
	_fence_line(Vector3(a.x, 0, a.y), Vector3(b.x, 0, a.y))
	_fence_line(Vector3(a.x, 0, b.y), Vector3(b.x, 0, b.y))
	_fence_line(Vector3(a.x, 0, a.y), Vector3(a.x, 0, b.y))
	_fence_line(Vector3(b.x, 0, a.y), Vector3(b.x, 0, -13))
	_fence_line(Vector3(b.x, 0, -9), Vector3(b.x, 0, b.y))
	# Palung minum, ember, dan tumpukan jerami.
	box(Vector3(-44, 0.3, -11), Vector3(1.2, 0.6, 3), Color(0.45, 0.3, 0.18))
	box(Vector3(-44, 0.55, -11), Vector3(1.0, 0.05, 2.8), Color(0.3, 0.6, 0.85), false)
	model("survival/bucket", Vector3(-43, 0, -13), 3.0)
	model("survival/barrel", Vector3(-44, 0, -14), 3.5)
	var hay_mat := noise_mat(Color(0.85, 0.7, 0.3), Color(0.98, 0.88, 0.5), 2, 0.2)
	for hp in [Vector3(-31, 0.6, -17), Vector3(-32.4, 0.6, -17), Vector3(-31.7, 1.6, -17)]:
		var hay := CylinderMesh.new()
		hay.top_radius = 0.65
		hay.bottom_radius = 0.65
		hay.height = 1.3
		var hm := MeshInstance3D.new()
		hm.mesh = hay
		hm.material_override = hay_mat
		hm.position = hp
		hm.rotation.x = PI / 2
		add_child(hm)
	for k in range(5):
		_add_cow(Vector3(rng.randf_range(a.x + 3, b.x - 3), 0, rng.randf_range(a.y + 3, b.y - 3)))
	var sign := _status_label(self, HAY_SPOT + Vector3(0, 2.8, -1.5))
	sign.text = "Jerami"
	sign.modulate = Color(1, 0.9, 0.5)


func _status_label(parent: Node, pos: Vector3) -> Label3D:
	var l := Label3D.new()
	l.position = pos
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.font_size = 56
	l.outline_size = 14
	l.pixel_size = 0.006
	parent.add_child(l)
	return l


func _add_cow(pos: Vector3) -> void:
	var c := _cow()
	c.position = pos
	cows.append({"node": c, "dir": rng.randf() * TAU, "timer": rng.randf_range(0, 3), "walk": false,
		"hunger": rng.randf_range(20, 55), "happy": rng.randf_range(25, 55), "milk_cd": 0.0,
		"heart": 0.0, "label": _status_label(c, Vector3(0, 2.6, 0)), "anim": find_anim(c)})


func _cow() -> Node3D:
	# Sapi Kenney Cube Pets; node induk menghadap -Z (model asli menghadap +Z).
	var c := Node3D.new()
	add_child(c)
	model("pets/animal-cow", Vector3.ZERO, 1.2, PI, c)
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(1.7, 1.8, 1.8)
	col.shape = sh
	col.position = Vector3(0, 0.9, 0)
	body.add_child(col)
	c.add_child(body)
	return c


func _make_lamps() -> void:
	# Lentera jalan yang menyala saat malam.
	for z in [-31, -17, -3, 3, 17, 31]:
		var x := 3.2 if z % 2 == 0 else -3.2
		model("town/lantern", Vector3(x, 0, z), 2.0)
		cyl_collider(Vector3(x, 0, z), 0.2, 3)
		var bulb := SphereMesh.new()
		bulb.radius = 0.12
		bulb.height = 0.24
		var bm := add_mesh(self, bulb, Vector3(x, 2.75, z), Color(1, 0.9, 0.6))
		var m := bm.material_override as StandardMaterial3D
		m.emission_enabled = true
		m.emission = Color(1, 0.75, 0.4)
		var light := OmniLight3D.new()
		light.position = Vector3(x, 2.8, z)
		light.light_color = Color(1, 0.75, 0.45)
		light.omni_range = 10
		light.light_energy = 0
		light.shadow_enabled = false
		add_child(light)
		lamps.append({"light": light, "mat": m})


func _tree_ok(p: Vector3) -> bool:
	if absf(p.x) < 14 and absf(p.z) < 34: return false
	if p.x > 16 and p.x < 38 and absf(p.z) < 13: return false
	if p.distance_to(POND) < 9: return false
	if p.distance_to(Vector3(-18, 0, -14)) < 8: return false
	if p.x > PASTURE_MIN.x - 2 and p.x < PASTURE_MAX.x + 2 and p.z > PASTURE_MIN.y - 2 and p.z < PASTURE_MAX.y + 2: return false
	for ap in APPLE_POSITIONS:
		if Vector2(p.x, p.z).distance_to(Vector2(ap.x, ap.z)) < 3: return false
	return true


func _make_trees() -> void:
	var leafy := ["tree_oak", "tree_default", "tree_detailed", "tree_fat", "tree_tall", "tree_simple", "tree_detailed", "tree_oak"]
	var pines := ["tree_pineRoundA", "tree_pineRoundC", "tree_pineTallA_detailed", "tree_pineDefaultA", "tree_pineRoundE"]
	var placed := 0
	var tries := 0
	while placed < 140 and tries < 4000:
		tries += 1
		var p := Vector3(rng.randf_range(-75, 75), 0, rng.randf_range(-75, 75))
		if not _tree_ok(p): continue
		var far := maxf(absf(p.x), absf(p.z)) > 50
		var kind: String = pines[rng.randi() % pines.size()] if far and rng.randf() < 0.7 else leafy[rng.randi() % leafy.size()]
		var tn := model("nature/" + kind, p, rng.randf_range(4.0, 5.5), rng.randf() * TAU)
		trees.append({"pos": p, "node": tn})
		cyl_collider(p, 0.5, 3)
		placed += 1


func _make_decor() -> void:
	# Semak, batu, jamur, tunggul, kayu — ditempatkan acak di area terbuka.
	var items := ["plant_bush", "plant_bushDetailed", "plant_bushLarge", "rock_smallB", "rock_smallD",
		"mushroom_redGroup", "mushroom_tanGroup", "stump_roundDetailed", "log", "rock_largeB"]
	for k in 90:
		var p := Vector3(rng.randf_range(-60, 60), 0, rng.randf_range(-60, 60))
		if not _is_open(p, 1.0) or not _tree_ok(p): continue
		var it: String = items[k % items.size()]
		model("nature/" + it, p, rng.randf_range(2.5, 3.5), rng.randf() * TAU)
	# Rumput dan bunga (MultiMesh).
	scatter(["nature/grass_large", "nature/grass", "nature/grass_leafs"], 700, 1.6, 2.4, 70, 0.3)
	scatter(["nature/flower_redA", "nature/flower_yellowB", "nature/flower_purpleA", "nature/flower_yellowA", "nature/flower_redC"], 120, 2.0, 2.8, 60, 0.5)
	# Pasar kecil & sumur di persimpangan.
	model("town/stall-red", Vector3(5.5, 0, -4.5), 2.5, 0)
	var ks := _status_label(self, Vector3(5.5, 3.8, -4.5))
	ks.text = "Kios"
	ks.modulate = Color(1, 0.9, 0.5)
	collider(Vector3(5.5, 1.2, -4.5), Vector3(2.4, 2.4, 2.4))
	model("town/fountain-round", Vector3(-6, 0, -4.6), 1.6)
	collider(Vector3(-6, 0.25, -4.6), Vector3(3.0, 0.5, 3.0))


func _make_scenery() -> void:
	# Bukit-bukit di kejauhan + awan yang bergerak.
	for k in 22:
		var a := k * TAU / 22 + rng.randf_range(-0.1, 0.1)
		var r := rng.randf_range(100, 115)
		var hill := SphereMesh.new()
		hill.radial_segments = 14
		hill.rings = 7
		var hm := add_mesh(self, hill, Vector3(cos(a) * r, -4, sin(a) * r),
			Color(0.25, 0.48, 0.2).lerp(Color(0.45, 0.62, 0.3), rng.randf()))
		hm.scale = Vector3(rng.randf_range(25, 40), rng.randf_range(12, 26), rng.randf_range(25, 40))
		hm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var cloud_mat := StandardMaterial3D.new()
	cloud_mat.albedo_color = Color(1, 1, 1, 0.92)
	cloud_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cloud_mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	cloud_mat.emission_enabled = true
	cloud_mat.emission = Color(0.35, 0.35, 0.4)
	for k in 14:
		var c := Node3D.new()
		c.position = Vector3(rng.randf_range(-120, 120), rng.randf_range(40, 55), rng.randf_range(-120, 120))
		add_child(c)
		for p in 5:
			var s := SphereMesh.new()
			s.radial_segments = 10
			s.rings = 5
			var mi := MeshInstance3D.new()
			mi.mesh = s
			mi.material_override = cloud_mat
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.position = Vector3(p * 3.5 - 7, rng.randf_range(-0.5, 1.5), rng.randf_range(-2, 2))
			mi.scale = Vector3.ONE * rng.randf_range(4, 7) * Vector3(1.4, 0.7, 1)
			c.add_child(mi)
		clouds.append(c)


# ---------- apel ----------
func _spawn_apples() -> void:
	for pos in APPLE_POSITIONS:
		var area := Area3D.new()
		area.position = pos
		add_child(area)
		model("food/apple", Vector3(0, -0.3, 0), 3.2, 0, area)
		var glow := OmniLight3D.new()
		glow.light_color = Color(1, 0.5, 0.4)
		glow.light_energy = 0.6
		glow.omni_range = 2
		area.add_child(glow)
		var cs := CollisionShape3D.new()
		var sh := SphereShape3D.new()
		sh.radius = 0.9
		cs.shape = sh
		area.add_child(cs)
		area.body_entered.connect(_on_apple_touched.bind(area))
		apples.append(area)


func _on_apple_touched(body: Node, area: Area3D) -> void:
	# Hanya host yang memproses apel (pemain mana pun yang menyentuhnya).
	if not _host() or body.get_parent() != players_root or not area.visible:
		return
	_server_act("apple", apples.find(area), 0, body.name.to_int())


# ---------- pemain, audio, HUD, jaringan ----------
const PORT := 7777
const DAILY_POOL = [
	{"key": "milk", "goal": 3, "text": "Perah %d susu", "reward": 40},
	{"key": "egg", "goal": 4, "text": "Kumpulkan %d telur", "reward": 30},
	{"key": "pet_cow", "goal": 6, "text": "Elus sapi %d kali", "reward": 20},
	{"key": "harvest", "goal": 8, "text": "Panen %d sayur", "reward": 30},
	{"key": "apple", "goal": 3, "text": "Makan %d apel", "reward": 15},
	{"key": "feed_cow", "goal": 4, "text": "Beri makan sapi %d kali", "reward": 25},
	{"key": "feed_chicken", "goal": 2, "text": "Beri makan ayam %d kali", "reward": 20},
	{"key": "sell", "goal": 5, "text": "Jual %d barang di kios", "reward": 35},
	{"key": "wood", "goal": 6, "text": "Kumpulkan %d kayu", "reward": 20},
	{"key": "build", "goal": 1, "text": "Bangun %d bangunan", "reward": 30},
]
const BUILD_COST = {"plot": {"Kayu": 2, "coins": 0}, "house": {"Kayu": 15, "coins": 30}}
const PRICES = {"Telur": 5, "Susu": 10, "Sayur": 3}

var audio: Node
var hud: CanvasLayer
var menu_cam: Camera3D
var players_root: Node3D
var started := false
var online := false
var my_name := "Petani"
var my_model := 0
var coins := 0
var day_index := 1
var daily: Array = []
var daily_day := -1
var net_timer := 0.0
var moo_timer := 8.0
var trees: Array = []
var wood_cd := {}
var builds: Array = []
var sleep_spots: Array = [HOME_DOOR]
var build_mode := ""
var ghost: MeshInstance3D
var ghost_ok := false


static var menu_note := ""   # pesan untuk menu setelah adegan dimuat ulang


func _open_pause() -> void:
	var info := "Main sendiri - Hari %d" % day_index
	if online:
		info = ("Kamu host: keluar akan menutup server untuk semua pemain." if multiplayer.is_server()
			else "Terhubung ke server sebagai %s." % my_name)
	hud.show_pause(true, info)
	audio.sfx("open")


func _setup_audio_hud() -> void:
	audio = preload("res://audio.gd").new()
	add_child(audio)
	hud = preload("res://hud.gd").new()
	add_child(hud)
	hud.setup(audio)
	hud.play_single.connect(_on_single)
	hud.play_host.connect(_on_host)
	hud.play_join.connect(_on_join)
	hud.volume_changed.connect(audio.set_volume)
	hud.shop_buy.connect(_shop_buy)
	hud.shop_sell.connect(func(): _on_action("sell", 0); _open_shop(true))
	hud.shop_closed.connect(func(): _open_shop(false))
	hud.chat_send.connect(_send_chat)
	hud.reset_save.connect(_reset_save)
	hud.save_now.connect(func():
		_save_game()
		audio.sfx("coins")
		hud.show_pause(true, "Permainan tersimpan (Hari %d)." % day_index))
	hud.logout.connect(_logout)
	hud.quit_game.connect(func():
		_save_game()
		get_tree().quit())
	players_root = Node3D.new()
	players_root.name = "Players"
	add_child(players_root)
	menu_cam = Camera3D.new()
	add_child(menu_cam)
	menu_cam.current = true
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_conn_failed)
	multiplayer.server_disconnected.connect(_on_server_lost)
	hud.show_menu()
	_show_save_info()
	if menu_note != "":
		hud.set_menu_status(menu_note)
		menu_note = ""
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _host() -> bool:
	return not online or multiplayer.is_server()


func _local_ip() -> String:
	for a in IP.get_local_addresses():
		if a.begins_with("192.168.") or a.begins_with("10.") or a.begins_with("172."):
			return a
	return "127.0.0.1"


func _on_single(n: String, m: int) -> void:
	my_name = n
	my_model = m
	online = false
	_start_game()


func _on_host(n: String, m: int) -> void:
	var peer := ENetMultiplayerPeer.new()
	if peer.create_server(PORT, 8) != OK:
		hud.set_menu_status("Gagal membuat server (port %d sedang dipakai?)" % PORT)
		audio.sfx("error")
		return
	multiplayer.multiplayer_peer = peer
	online = true
	my_name = n
	my_model = m
	_start_game()
	hud.big_message("Server aktif!\nTeman bisa gabung ke IP: %s" % _local_ip(), 6)


func _on_join(n: String, m: int, ip: String) -> void:
	var peer := ENetMultiplayerPeer.new()
	if ip == "" or peer.create_client(ip, PORT) != OK:
		hud.set_menu_status("Alamat IP tidak valid")
		audio.sfx("error")
		return
	multiplayer.multiplayer_peer = peer
	my_name = n
	my_model = m
	hud.set_menu_status("Menghubungkan ke %s ..." % ip)


func _on_connected() -> void:
	online = true
	_start_game()


func _on_conn_failed() -> void:
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	hud.set_menu_status("Gagal terhubung. Pastikan IP benar dan host sudah membuat server.")
	audio.sfx("error")


func _on_server_lost() -> void:
	_save_game()
	menu_note = "Host menutup server. Kamu kembali ke menu utama."
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	get_tree().reload_current_scene()


func _logout() -> void:
	# Simpan, putuskan koneksi, lalu muat ulang adegan -> kembali ke menu utama.
	_save_game()
	menu_note = "Kamu sudah keluar. Progres tersimpan."
	if online and multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	get_tree().reload_current_scene()


func _start_game() -> void:
	started = true
	if _host():
		_load_world()
	_load_player()
	player = _spawn_player_node(multiplayer.get_unique_id(), true, my_name, my_model)
	player.footstep.connect(audio.footstep)
	menu_cam.current = false
	hud.minimap.main = self
	hud.show_game()
	_refresh_daily()
	_update_ui()
	if online:
		player_info.rpc(my_name, my_model)
		_update_players()
	audio.sfx("open")
	toast("Selamat datang, %s!" % my_name)


func _spawn_player_node(id: int, local: bool, n: String, m: int) -> CharacterBody3D:
	var p: CharacterBody3D = preload("res://player.gd").new()
	p.name = str(id)
	p.is_local = local
	p.model_idx = m
	p.display_name = n
	p.position = Vector3(randf_range(-1.5, 1.5), 1, randf_range(3, 6))
	players_root.add_child(p)
	return p


@rpc("any_peer", "reliable")
func player_info(n: String, m: int) -> void:
	var id := multiplayer.get_remote_sender_id()
	var p = players_root.get_node_or_null(str(id))
	if p == null:
		_spawn_player_node(id, false, n, m)
		toast("%s bergabung!" % n)
		audio.sfx("open")
	else:
		p.set_display_name(n)
		p.set_model(m)
	_update_players()


func _on_peer_connected(id: int) -> void:
	if started:
		player_info.rpc_id(id, my_name, my_model)
	if multiplayer.is_server() and builds.size() > 0:
		sync_builds.rpc_id(id, builds)


func _on_peer_disconnected(id: int) -> void:
	var p = players_root.get_node_or_null(str(id))
	if p:
		toast("%s keluar" % p.display_name)
		p.queue_free()
	_update_players.call_deferred()


func _update_players() -> void:
	if not online:
		return
	var names := []
	for p in players_root.get_children():
		if not p.is_queued_for_deletion():
			names.append(p.display_name + (" (kamu)" if p == player else ""))
	hud.set_players(names)


# --- sinkronisasi dunia: host -> semua pemain ---
func _send_world() -> void:
	var cow_data := []
	for c in cows:
		cow_data.append([c.node.position, c.node.rotation.y, c.hunger, c.happy, c.milk_cd, c.heart, c.walk])
	var crop_bits := PackedByteArray()
	for cr in crops:
		crop_bits.append(1 if cr.ready else (2 if cr.planted else 0))
	var apple_bits := PackedByteArray()
	for a in apples:
		apple_bits.append(1 if a.visible else 0)
	world_state.rpc([day_time, day_index, game_speed, chicken_hunger, eggs, cow_data, crop_bits, apple_bits])


@rpc("authority", "unreliable_ordered")
func world_state(d: Array) -> void:
	day_time = d[0]
	if d[1] != day_index:
		day_index = d[1]
		_new_day()
	game_speed = d[2]
	chicken_hunger = d[3]
	eggs = d[4]
	for i in egg_meshes.size():
		egg_meshes[i].visible = i < eggs
	for i in mini(cows.size(), d[5].size()):
		var c: Dictionary = cows[i]
		var cd: Array = d[5][i]
		c.tpos = cd[0]
		c.trot = cd[1]
		c.hunger = cd[2]
		c.happy = cd[3]
		c.milk_cd = cd[4]
		c.heart = cd[5]
		c.walk = cd[6]
	for i in mini(crops.size(), d[6].size()):
		crops[i].ready = d[6][i] == 1
		crops[i].planted = d[6][i] != 0
		_crop_visual(crops[i])
	for i in mini(apples.size(), d[7].size()):
		apples[i].visible = d[7][i] == 1


# --- misi ---
func _refresh_daily() -> void:
	# Misi harian sama untuk semua pemain (diacak dengan seed nomor hari).
	if daily_day == day_index:
		return
	daily_day = day_index
	var r := RandomNumberGenerator.new()
	r.seed = day_index * 7919 + 13
	var pool := DAILY_POOL.duplicate()
	daily = []
	for i in 3:
		var k := r.randi() % pool.size()
		var d: Dictionary = pool[k].duplicate()
		pool.remove_at(k)
		d.count = 0
		d.done = false
		daily.append(d)
	if hud:
		hud.set_daily(daily)


func _new_day() -> void:
	_refresh_daily()
	if started:
		toast("Hari %d dimulai! Misi harian baru" % day_index)
		audio.sfx("daily")


func _update_ui() -> void:
	if not hud:
		return
	if mission_index < MISSIONS.size():
		var m: Dictionary = MISSIONS[mission_index]
		hud.set_story("%d/%d  %s" % [mission_index + 1, MISSIONS.size(), m.text], mission_count, m.goal)
	else:
		hud.set_story("Semua misi utama selesai! Kerjakan misi harian & jaga hewanmu.", 0, 0)
	hud.set_inventory(inv)


func toast(msg: String) -> void:
	if hud:
		hud.toast(msg)


func progress(key: String, amount := 1) -> void:
	for d in daily:
		if not d.done and d.key == key:
			d.count += amount
			if d.count >= d.goal:
				d.done = true
				coins += d.reward
				toast("Misi harian selesai! +%d koin" % d.reward)
				audio.sfx("coins")
			hud.set_daily(daily)
	if mission_index < MISSIONS.size() and MISSIONS[mission_index].key == key:
		mission_count += amount
		if mission_count >= MISSIONS[mission_index].goal:
			mission_index += 1
			mission_count = 0
			coins += 20
			if mission_index >= MISSIONS.size():
				hud.big_message("Selamat, %s!\nKamu petani hebat!\nSemua misi utama selesai" % my_name)
				audio.sfx("win")
			else:
				toast("Misi selesai! +20 koin")
				audio.sfx("mission")
	_update_ui()


func _unhandled_input(event: InputEvent) -> void:
	if not started:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT and build_mode != "":
		_set_build_mode("")
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if hud.shop_panel.visible:
		if event.keycode in [KEY_F, KEY_ESCAPE]:
			_open_shop(false)
		return
	if hud.pause_panel.visible:
		if event.keycode == KEY_ESCAPE:
			hud.show_pause(false)
		return
	if hud.chat_input.visible:
		return
	if event.keycode == KEY_ESCAPE:
		if build_mode != "":
			_set_build_mode("")
		else:
			_open_pause()
		return
	if event.keycode in [KEY_ENTER, KEY_KP_ENTER]:
		hud.open_chat()
		get_viewport().set_input_as_handled()
		return
	if event.keycode == KEY_B:
		_set_build_mode("" if build_mode != "" else "menu")
		audio.sfx("open")
		return
	if build_mode == "menu" and event.keycode in [KEY_1, KEY_2]:
		var kind := "plot" if event.keycode == KEY_1 else "house"
		var cost: Dictionary = BUILD_COST[kind]
		if inv["Kayu"] < cost.Kayu or coins < cost.coins:
			toast("Bahan kurang: butuh %d kayu%s" % [cost.Kayu, " + %d koin" % cost.coins if cost.coins > 0 else ""])
			audio.sfx("error")
			return
		_set_build_mode(kind)
		return
	if build_mode in ["plot", "house"] and event.keycode == KEY_F:
		_place_build()
		return
	if event.keycode == KEY_F and build_mode == "":
		var a := _find_action()
		if a[1] != "":
			_on_action(a[1], a[2])
			player.do_action()


# ---------- aksi pemain ----------
func _hour() -> float:
	return fmod(day_time * 24.0 + 6.0, 24.0)


func _can_milk(c: Dictionary) -> bool:
	return c.hunger >= 50 and c.happy >= 70 and c.milk_cd <= 0


func _sell_value() -> Array:
	var value := 0
	var n := 0
	for k in PRICES:
		value += inv[k] * PRICES[k]
		n += inv[k]
	return [value, n]


func _find_action() -> Array:
	# Mengembalikan [teks petunjuk, jenis aksi, indeks] untuk benda terdekat.
	if player == null:
		return ["", "", 0]
	var p := player.global_position
	p.y = 0
	if p.distance_to(STALL_SPOT) < 2.8:
		return ["[F] Buka kios (jual & beli)", "shop", 0]
	for sp in sleep_spots:
		if p.distance_to(sp) < 2.5:
			return ["[F] Tidur", "sleep", 0]
	if p.distance_to(HAY_SPOT) < 2.8:
		return ["[F] Ambil jerami", "hay", 0]
	if p.distance_to(COOP_SPOT) < 2.8:
		if eggs > 0:
			return ["[F] Ambil telur (%d)" % eggs, "egg", 0]
		if inv["Sayur"] > 0:
			return ["[F] Beri sayur ke ayam", "feed_chicken", 0]
		return ["Ayam butuh sayur dari kebun", "", 0]
	var best := -1
	var best_d := 3.0
	for i in cows.size():
		var d: float = p.distance_to(cows[i].node.position)
		if d < best_d:
			best_d = d
			best = i
	if best >= 0:
		var c: Dictionary = cows[best]
		if inv["Jerami"] > 0 and c.hunger < 90:
			return ["[F] Beri jerami ke sapi", "feed_cow", best]
		var on_pet_mission: bool = mission_index < MISSIONS.size() and MISSIONS[mission_index].key == "pet_cow"
		if not on_pet_mission and _can_milk(c):
			return ["[F] Perah susu", "milk_cow", best]
		var hint := ""
		if c.hunger < 50:
			hint = "  (sapi lapar, bawa jerami)"
		elif c.milk_cd > 0:
			hint = "  (susu belum siap)"
		return ["[F] Elus sapi" + hint, "pet_cow", best]
	for i in crops.size():
		var cr: Dictionary = crops[i]
		var dist := p.distance_to(cr.node.position * Vector3(1, 0, 1))
		if cr.ready and dist < 1.4:
			return ["[F] Panen sayur", "harvest", i]
		if cr.plot and not cr.planted and dist < 1.8:
			if inv["Bibit"] > 0:
				return ["[F] Tanam bibit (sisa %d)" % inv["Bibit"], "plant", i]
			return ["Petak kosong - beli bibit di kios", "", 0]
	for i in trees.size():
		if p.distance_to(trees[i].pos) < 2.3:
			if wood_cd.get(i, 0.0) > time:
				return ["Pohon ini baru ditebang, coba pohon lain", "", 0]
			return ["[F] Tebang kayu", "wood", i]
	return ["", "", 0]


func _on_action(kind: String, idx: int) -> void:
	match kind:
		"hay":
			if inv["Jerami"] >= 3:
				toast("Tasmu penuh jerami (maks 3)")
				audio.sfx("error")
				return
			inv["Jerami"] += 1
			toast("Jerami +1")
			audio.sfx("pickup")
			progress("hay")
		"wood":
			inv["Kayu"] += 1
			wood_cd[idx] = time + 20.0
			energy = maxf(0, energy - 2)
			var tn: Node3D = trees[idx].node
			var tw := create_tween()
			tw.tween_property(tn, "rotation:z", 0.08, 0.08)
			tw.tween_property(tn, "rotation:z", -0.06, 0.1)
			tw.tween_property(tn, "rotation:z", 0.0, 0.1)
			toast("Kayu +1")
			audio.sfx("eat")
			progress("wood")
		"shop":
			_open_shop(true)
		"sell":
			var sv := _sell_value()
			coins += sv[0]
			for k in PRICES:
				inv[k] = 0
			toast("Terjual! +%d koin" % sv[0])
			audio.sfx("coins")
			progress("sell", sv[1])
		_:
			var extra := 1 if energy <= 25 else 0
			if _host():
				_server_act(kind, idx, extra, multiplayer.get_unique_id())
			else:
				req_act.rpc_id(1, kind, idx, extra)


@rpc("any_peer", "reliable")
func req_act(kind: String, idx: int, extra: int) -> void:
	if multiplayer.is_server():
		_server_act(kind, idx, extra, multiplayer.get_remote_sender_id())


func _server_act(kind: String, idx: int, extra: int, peer: int) -> void:
	# Host memvalidasi & menerapkan perubahan dunia, lalu memberi tahu pemain.
	var amount := 1
	match kind:
		"feed_cow":
			var c: Dictionary = cows[idx]
			if c.hunger >= 95:
				amount = -1
			else:
				c.hunger = minf(100, c.hunger + 50)
				c.heart = 2.0
		"pet_cow":
			var c: Dictionary = cows[idx]
			c.happy = minf(100, c.happy + 20)
			c.heart = 1.5
		"milk_cow":
			var c: Dictionary = cows[idx]
			if _can_milk(c):
				c.milk_cd = 90.0
				c.happy = maxf(0, c.happy - 10)
			else:
				amount = -1
		"harvest":
			var cr: Dictionary = crops[idx]
			if cr.ready:
				cr.ready = false
				cr.timer = 60.0
				if cr.plot:
					cr.planted = false
				_crop_visual(cr)
			else:
				amount = -1
		"plant":
			var cr: Dictionary = crops[idx]
			if cr.plot and not cr.planted and not cr.ready:
				cr.planted = true
				cr.timer = 40.0
				_crop_visual(cr)
			else:
				amount = -1
		"feed_chicken":
			chicken_hunger = minf(100, chicken_hunger + 40)
			egg_timer = minf(egg_timer, 4.0)
		"egg":
			amount = eggs if eggs > 0 else -1
			eggs = 0
			for em in egg_meshes:
				em.visible = false
		"sleep":
			var h := _hour()
			if h >= 18 or h < 5:
				day_time = 0.0
				day_index += 1
				_new_day()
				for c in cows:
					c.hunger = maxf(0, c.hunger - 15)
					c.happy = maxf(0, c.happy - 10)
				chicken_hunger = maxf(0, chicken_hunger - 15)
				amount = 2
			elif extra == 0:
				amount = -1
		"apple":
			var a: Area3D = apples[idx]
			if not a.visible:
				amount = -1
			else:
				a.visible = false
				a.set_meta("respawn", 60.0)
	if peer == multiplayer.get_unique_id():
		_act_done(kind, idx, amount)
	else:
		act_done.rpc_id(peer, kind, idx, amount)


@rpc("authority", "reliable")
func act_done(kind: String, idx: int, amount: int) -> void:
	_act_done(kind, idx, amount)


func _act_done(kind: String, idx: int, amount: int) -> void:
	if amount < 0:
		var msg := {"sleep": "Belum malam. Tidur setelah jam 18:00", "harvest": "Sudah dipanen pemain lain",
			"egg": "Telur sudah diambil", "milk_cow": "Susu belum siap", "feed_cow": "Sapi ini sudah kenyang"}
		if msg.has(kind):
			toast(msg[kind])
			audio.sfx("error")
		return
	match kind:
		"feed_cow":
			inv["Jerami"] = maxi(0, inv["Jerami"] - 1)
			toast("Sapi makan dengan lahap. Mooo!")
			audio.moo(cows[idx].node.position)
			progress("feed_cow")
		"pet_cow":
			energy = maxf(0, energy - 1)
			audio.sfx("cloth")
			if randf() < 0.3:
				audio.moo(cows[idx].node.position)
			progress("pet_cow")
		"milk_cow":
			inv["Susu"] += 1
			energy = maxf(0, energy - 4)
			toast("Susu +1")
			audio.sfx("milk")
			progress("milk")
		"plant":
			inv["Bibit"] = maxi(0, inv["Bibit"] - 1)
			toast("Bibit ditanam! Tunggu sebentar...")
			audio.sfx("pluck")
			progress("plant")
		"harvest":
			inv["Sayur"] += 1
			energy = maxf(0, energy - 2)
			toast("Sayur +1")
			audio.sfx("pluck")
			progress("harvest")
		"feed_chicken":
			inv["Sayur"] = maxi(0, inv["Sayur"] - 1)
			toast("Ayam senang! Petok petok!")
			audio.sfx("pickup")
			progress("feed_chicken")
		"egg":
			inv["Telur"] += amount
			toast("Telur +%d" % amount)
			audio.sfx("pickup")
			progress("egg", amount)
		"sleep":
			energy = 100
			audio.sfx("door")
			if amount == 2:
				toast("Selamat pagi! Energi penuh lagi (tersimpan)")
				progress("sleep")
				_save_game.call_deferred()
			else:
				toast("Kamu istirahat sebentar. Energi pulih")
		"apple":
			energy = minf(100, energy + 20)
			toast("Nyam! Energi +20")
			audio.sfx("pluck")
			progress("apple")
	_update_ui()


# ---------- membangun ----------
func _set_build_mode(mode: String) -> void:
	build_mode = mode
	ghost_ok = true
	if ghost:
		ghost.queue_free()
		ghost = null
	if mode in ["plot", "house"]:
		var bm := BoxMesh.new()
		bm.size = Vector3(2.2, 0.3, 2.2) if mode == "plot" else Vector3(2 * S_HOUSE, 5, 3 * S_HOUSE)
		ghost = MeshInstance3D.new()
		ghost.mesh = bm
		var m := StandardMaterial3D.new()
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		ghost.material_override = m
		ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(ghost)
	hud.show_build(mode, inv["Kayu"], coins)


func _build_spot() -> Array:
	var r: float = player.model.rotation.y
	var fwd := Vector3(-sin(r), 0, -cos(r))
	var dist := 3.0 if build_mode == "plot" else 7.0
	var pos := (player.global_position + fwd * dist).round()
	pos.y = 0
	var rot := roundf(r / (PI / 2)) * (PI / 2)
	return [pos, rot]


func _can_build(kind: String, pos: Vector3) -> bool:
	var rad := 1.6 if kind == "plot" else 5.0
	if absf(pos.x) > 62 or absf(pos.z) > 62: return false
	if not _is_open(pos, rad - 0.5): return false
	if pos.x > PASTURE_MIN.x - rad and pos.x < PASTURE_MAX.x + rad and pos.z > PASTURE_MIN.y - rad and pos.z < PASTURE_MAX.y + rad: return false
	for spot in [Vector3(-6, 0, -4.6), STALL_SPOT, COOP_SPOT, HAY_SPOT]:
		if pos.distance_to(spot) < rad + 2.5: return false
	for t in trees:
		if pos.distance_to(t.pos) < rad + 0.6: return false
	for b in builds_local:
		var other := 1.6 if b[0] == "plot" else 5.0
		if pos.distance_to(b[1]) < rad + other - 0.4: return false
	return true


func _place_build() -> void:
	var spot := _build_spot()
	if not _can_build(build_mode, spot[0]):
		toast("Tidak bisa membangun di sini")
		audio.sfx("error")
		return
	var cost: Dictionary = BUILD_COST[build_mode]
	inv["Kayu"] -= cost.Kayu
	coins -= cost.coins
	var kind := build_mode
	if _host():
		_server_build(kind, spot[0], spot[1], my_name)
	else:
		req_build.rpc_id(1, kind, spot[0], spot[1], my_name)
	progress("build")
	progress("build_plot" if kind == "plot" else "build_house")
	toast("Petak kebun dibangun! Sayur akan tumbuh" if kind == "plot" else "Rumah kayu selesai dibangun!")
	audio.sfx("mission" if kind == "house" else "pickup")
	player.do_action()
	_set_build_mode("")


@rpc("any_peer", "reliable")
func req_build(kind: String, pos: Vector3, rot: float, owner: String) -> void:
	if multiplayer.is_server():
		_server_build(kind, pos, rot, owner)


func _server_build(kind: String, pos: Vector3, rot: float, owner: String) -> void:
	builds.append([kind, pos, rot, owner])
	if online:
		spawn_build.rpc(kind, pos, rot, owner)
	else:
		_spawn_build(kind, pos, rot, owner)


@rpc("authority", "call_local", "reliable")
func spawn_build(kind: String, pos: Vector3, rot: float, owner: String) -> void:
	_spawn_build(kind, pos, rot, owner)


@rpc("authority", "reliable")
func sync_builds(list: Array) -> void:
	if builds_local.is_empty():
		for b in list:
			_spawn_build(b[0], b[1], b[2], b[3])


var builds_local: Array = []
func _spawn_build(kind: String, pos: Vector3, rot: float, owner: String) -> void:
	builds_local.append([kind, pos, rot, owner])
	audio.sfx("door", pos)
	if kind == "plot":
		var pm := PlaneMesh.new()
		pm.size = Vector2(2.2, 2.2)
		var sm := MeshInstance3D.new()
		sm.mesh = pm
		sm.position = pos + Vector3(0, 0.04, 0)
		sm.rotation.y = rot
		sm.material_override = noise_mat(Color(0.35, 0.22, 0.12), Color(0.5, 0.33, 0.18), 1, 0.15)
		add_child(sm)
		for k in 4:
			model("nature/rock_smallA", pos + Vector3([-1.1, 1.1][k % 2], 0, [-1.1, 1.1][k / 2]).rotated(Vector3.UP, rot), 1.2)
		var kinds := ["nature/crop_carrot", "nature/crop_pumpkin", "nature/crop_turnip", "nature/crops_leafsStageB", "nature/crop_melon"]
		var kind_i := int(absf(pos.x * 7 + pos.z * 13)) % kinds.size()
		var cm := model(kinds[kind_i], pos + Vector3(0, 0.05, 0), 3.0, rot)
		var cr := {"node": cm, "ready": false, "timer": 40.0, "plot": true, "planted": false, "full": 3.0}
		crops.append(cr)
		_crop_visual(cr)
	elif kind == "cow":
		_add_cow(pos)
	elif kind == "chicken":
		_add_chicken(pos)
	else:
		_house(pos, rot, true)
		var door: Vector3 = pos + Vector3(-0.5 * S_HOUSE, 0, 1.5 * S_HOUSE + 1.0).rotated(Vector3.UP, rot)
		sleep_spots.append(door)
		var l := _status_label(self, pos + Vector3(0, 6.5, 0))
		l.text = "Rumah " + owner
		l.modulate = Color(1, 0.9, 0.5)


func _update_build_ghost() -> void:
	if ghost == null:
		return
	var spot := _build_spot()
	ghost.position = spot[0] + Vector3(0, ghost.mesh.size.y / 2, 0)
	ghost.rotation.y = spot[1]
	var ok := _can_build(build_mode, spot[0])
	(ghost.material_override as StandardMaterial3D).albedo_color = Color(0.3, 1, 0.4, 0.35) if ok else Color(1, 0.3, 0.3, 0.35)
	if ok != ghost_ok:
		ghost_ok = ok
		hud.show_build(build_mode, inv["Kayu"], coins, ok)


func _update_farm(dt: float) -> void:
	# dt = waktu game (ikut dipercepat dengan tombol T).
	if started:
		energy = maxf(0, energy - dt * 0.2)
		player.speed_mult = 0.45 if energy <= 0 else 1.0
	if _host():
		chicken_hunger = maxf(0, chicken_hunger - dt * 0.3)
		if chicken_hunger > 30 and eggs < egg_meshes.size():
			egg_timer -= dt
			if egg_timer <= 0:
				egg_meshes[eggs].visible = true
				eggs += 1
				egg_timer = 25.0 * 6.0 / maxf(chickens.size(), 1)
		for c in cows:
			c.hunger = maxf(0, c.hunger - dt * 0.25)
			c.happy = maxf(0, c.happy - dt * (0.35 if c.hunger < 30 else 0.18))
			c.milk_cd = maxf(0, c.milk_cd - dt)
			c.heart = maxf(0, c.heart - dt / game_speed)
		for cr in crops:
			if not cr.ready and cr.planted:
				cr.timer -= dt
				if cr.timer <= 0:
					cr.ready = true
					_crop_visual(cr)
			elif not cr.ready and not cr.plot:
				cr.timer -= dt
				if cr.timer <= 0:
					cr.ready = true
					cr.planted = true
					_crop_visual(cr)
		for a in apples:
			if not a.visible:
				a.set_meta("respawn", a.get_meta("respawn", 0.0) - dt)
				if a.get_meta("respawn") <= 0:
					a.visible = true

	if chicken_hunger < 30:
		coop_label.text = "Ayam lapar!"
		coop_label.modulate = Color(1, 0.5, 0.2)
	elif eggs > 0:
		coop_label.text = "Telur: %d" % eggs
		coop_label.modulate = Color(1, 1, 0.8)
	else:
		coop_label.text = ""
	var sum_food := 0.0
	var sum_happy := 0.0
	for c in cows:
		sum_food += c.hunger
		sum_happy += c.happy
		var l: Label3D = c.label
		l.position.y = 2.6
		if c.heart > 0:
			l.text = "<3"
			l.modulate = Color(1, 0.4, 0.6)
			l.position.y = 2.6 + (1.5 - c.heart) * 0.3
		elif c.hunger < 30:
			l.text = "Lapar!"
			l.modulate = Color(1, 0.5, 0.2)
		elif c.happy < 30:
			l.text = "Sedih..."
			l.modulate = Color(0.6, 0.7, 1)
		elif _can_milk(c):
			l.text = "Susu siap"
			l.modulate = Color(1, 1, 1)
		else:
			l.text = ""

	if not started:
		return
	hud.set_bar("energy", energy)
	hud.set_bar("cow_food", sum_food / cows.size())
	hud.set_bar("cow_happy", sum_happy / cows.size())
	hud.set_bar("chicken", chicken_hunger)
	_update_build_ghost()
	var act := _find_action()
	var text: String = act[0]
	if build_mode != "":
		text = ""
	if energy <= 0 and text == "":
		text = "Kamu kelelahan! Makan apel atau tidur di rumah"
	hud.prompt(text)


func _update_day_night(delta: float) -> void:
	if _host():
		game_speed = 8.0 if started and not hud.is_busy() and Input.is_key_pressed(KEY_T) else 1.0
	var before := day_time
	day_time = fmod(day_time + delta * game_speed / DAY_LENGTH, 1.0)
	if _host() and day_time < before:
		day_index += 1
		_new_day()
	var angle := day_time * TAU  # 0 = terbit, PI/2 = siang, PI = terbenam
	var height := sin(angle)
	var d := smoothstep(-0.08, 0.25, height)      # 1 = siang, 0 = malam
	var dusk := clampf(1.0 - absf(height) * 4.0, 0.0, 1.0)  # senja/fajar

	sun.rotation = Vector3(-angle, deg_to_rad(-30), 0)
	sun.light_energy = 1.2 * d
	sun.light_color = Color(1, 1, 1).lerp(Color(1, 0.55, 0.3), dusk)
	sun.visible = d > 0.01
	moon.light_energy = 0.25 * (1.0 - d)

	var night_top := Color(0.02, 0.03, 0.1)
	var night_hor := Color(0.06, 0.08, 0.18)
	sky_mat.sky_top_color = night_top.lerp(Color(0.35, 0.6, 0.95), d)
	var hor := night_hor.lerp(Color(0.75, 0.85, 0.95), d).lerp(Color(1.0, 0.55, 0.3), dusk * 0.7)
	sky_mat.sky_horizon_color = hor
	sky_mat.ground_horizon_color = hor
	sky_mat.ground_bottom_color = Color(0.05, 0.05, 0.08).lerp(Color(0.3, 0.35, 0.25), d)
	env.fog_light_color = hor
	env.ambient_light_energy = lerp(0.35, 1.0, d)

	var night := 1.0 - d
	for l in lamps:
		l.light.light_energy = 2.5 * night
		l.mat.emission_energy_multiplier = 3.0 * night
	if started:
		hud.set_clock(day_index, _hour(), d > 0.5, coins)


func _play(ap: AnimationPlayer, anim: String) -> void:
	if ap and ap.current_animation != anim and ap.has_animation(anim):
		ap.play(anim, 0.25)


func _process(delta: float) -> void:
	time += delta
	_update_day_night(delta)
	_update_farm(delta * game_speed)
	if started:
		player.input_enabled = not hud.is_busy()
		save_timer -= delta
		if save_timer <= 0:
			save_timer = 30.0
			_save_game()
	if not started:
		# Kamera menu berputar pelan mengelilingi desa.
		var a := time * 0.05
		menu_cam.look_at_from_position(Vector3(cos(a) * 32, 14, sin(a) * 32), Vector3(0, 2, 0))
	if online and multiplayer.is_server():
		net_timer -= delta
		if net_timer <= 0:
			net_timer = 0.1
			_send_world()
	for cl in clouds:
		cl.position.x += delta * 1.5
		if cl.position.x > 130:
			cl.position.x = -130
	moo_timer -= delta
	if moo_timer <= 0:
		moo_timer = rng.randf_range(12, 25)
		audio.moo(cows[rng.randi() % cows.size()].node.position)
	for c in cows:
		var n: Node3D = c.node
		if _host():
			c.timer -= delta
			if c.timer <= 0:
				c.walk = rng.randf() < 0.45
				c.timer = rng.randf_range(2, 5)
				c.dir = rng.randf() * TAU
			if c.walk:
				var next: Vector3 = n.position + Vector3(-sin(c.dir), 0, -cos(c.dir)) * delta * 0.9
				if next.x < PASTURE_MIN.x + 2 or next.x > PASTURE_MAX.x - 2 or next.z < PASTURE_MIN.y + 2 or next.z > PASTURE_MAX.y - 2:
					c.dir += PI
				else:
					n.position = next
				n.rotation.y = lerp_angle(n.rotation.y, c.dir, delta * 3)
		elif c.has("tpos"):
			n.position = n.position.lerp(c.tpos, minf(1.0, delta * 8))
			n.rotation.y = lerp_angle(n.rotation.y, c.trot, minf(1.0, delta * 8))
		_play(c.anim, "walk" if c.walk else ("eat" if c.hunger < 80 else "idle"))
	for a in apples:
		a.rotation.y += delta * 2
		a.position.y = 0.7 + sin(time * 3 + a.position.x) * 0.15
	for c in chickens:
		c.timer -= delta
		if c.timer <= 0:
			c.timer = rng.randf_range(1, 3)
			c.dir = rng.randf() * TAU
		var n: Node3D = c.node
		var next: Vector3 = n.position + Vector3(sin(c.dir), 0, cos(c.dir)) * delta * 1.2
		if next.distance_to(Vector3(-18, 0, -12)) > 6:
			c.dir += PI
		else:
			n.position = next
			n.rotation.y = lerp_angle(n.rotation.y, c.dir + PI, delta * 6)


func _crop_visual(cr: Dictionary) -> void:
	var n: Node3D = cr.node
	if cr.ready:
		n.visible = true
		n.scale = Vector3.ONE * cr.full
	elif cr.plot and cr.planted:
		n.visible = true
		n.scale = Vector3.ONE * cr.full * 0.35
	else:
		n.visible = false


# ---------- toko ----------
const SHOP_PRICES = {"seed": 5, "bread": 10, "chicken": 40, "cow": 120}
var shop_open := false


func _open_shop(open: bool) -> void:
	shop_open = open
	var sv := _sell_value()
	hud.show_shop(open, coins, sv[0], sv[1])
	if open:
		audio.sfx("open")


func _shop_buy(id: String) -> void:
	var price: int = SHOP_PRICES[id]
	if coins < price:
		toast("Koin tidak cukup (butuh %d)" % price)
		audio.sfx("error")
		return
	match id:
		"seed":
			inv["Bibit"] += 1
			toast("Bibit +1")
		"bread":
			energy = minf(100, energy + 40)
			toast("Nyam! Energi +40")
		"chicken":
			if chickens.size() >= 16:
				toast("Kandang ayam sudah penuh")
				audio.sfx("error")
				return
			var pos := Vector3(-18 + randf_range(-4, 4), 0, -12 + randf_range(-2, 2))
			if _host(): _server_build("chicken", pos, 0, my_name)
			else: req_build.rpc_id(1, "chicken", pos, 0.0, my_name)
			toast("Ayam baru datang ke kandang!")
		"cow":
			if cows.size() >= 12:
				toast("Padang rumput sudah penuh")
				audio.sfx("error")
				return
			var pos := Vector3(randf_range(PASTURE_MIN.x + 3, PASTURE_MAX.x - 3), 0, randf_range(PASTURE_MIN.y + 3, PASTURE_MAX.y - 3))
			if _host(): _server_build("cow", pos, 0, my_name)
			else: req_build.rpc_id(1, "cow", pos, 0.0, my_name)
			toast("Sapi baru datang ke padang rumput!")
	coins -= price
	audio.sfx("coins")
	progress("buy")
	_update_ui()
	_open_shop(true)


# ---------- chat ----------
func _send_chat(text: String) -> void:
	if online:
		chat_msg.rpc(my_name, text)
	else:
		chat_msg(my_name, text)


@rpc("any_peer", "call_local", "reliable")
func chat_msg(who: String, text: String) -> void:
	hud.add_chat(who, text.left(120))
	audio.sfx("hover")


# ---------- simpan / muat ----------
const WORLD_SAVE := "user://world.sav"
var save_timer := 30.0


func _player_save_path() -> String:
	return "user://player_%s.sav" % my_name.to_lower().validate_filename()


func _write(path: String, data: Dictionary) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_var(data)


func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	var d = f.get_var() if f else null
	return d if d is Dictionary else {}


func _save_game() -> void:
	if not started:
		return
	_write(_player_save_path(), {"coins": coins, "inv": inv, "energy": energy,
		"mission_index": mission_index, "mission_count": mission_count,
		"daily_day": daily_day, "daily": daily, "model": my_model})
	if _host():
		var cow_stats := []
		for c in cows:
			cow_stats.append([c.hunger, c.happy, c.milk_cd])
		var crop_states := []
		for cr in crops:
			crop_states.append([cr.ready, cr.planted, cr.timer])
		var apple_states := []
		for a in apples:
			apple_states.append(a.visible)
		_write(WORLD_SAVE, {"day_time": day_time, "day_index": day_index, "chicken_hunger": chicken_hunger,
			"eggs": eggs, "builds": builds, "cows": cow_stats, "crops": crop_states, "apples": apple_states})


func _load_world() -> void:
	var w := _read(WORLD_SAVE)
	if w.is_empty():
		return
	for b in w.get("builds", []):
		builds.append(b)
		_spawn_build(b[0], b[1], b[2], b[3])
	day_time = w.get("day_time", day_time)
	day_index = w.get("day_index", day_index)
	chicken_hunger = w.get("chicken_hunger", chicken_hunger)
	eggs = mini(w.get("eggs", 0), egg_meshes.size())
	for i in egg_meshes.size():
		egg_meshes[i].visible = i < eggs
	var cs: Array = w.get("cows", [])
	for i in mini(cs.size(), cows.size()):
		cows[i].hunger = cs[i][0]
		cows[i].happy = cs[i][1]
		cows[i].milk_cd = cs[i][2]
	var crs: Array = w.get("crops", [])
	for i in mini(crs.size(), crops.size()):
		crops[i].ready = crs[i][0]
		crops[i].planted = crs[i][1]
		crops[i].timer = crs[i][2]
		_crop_visual(crops[i])
	var aps: Array = w.get("apples", [])
	for i in mini(aps.size(), apples.size()):
		apples[i].visible = aps[i]
		if not aps[i]:
			apples[i].set_meta("respawn", 30.0)


func _load_player() -> void:
	var d := _read(_player_save_path())
	if d.is_empty():
		return
	coins = d.get("coins", 0)
	var saved_inv: Dictionary = d.get("inv", {})
	for k in inv:
		inv[k] = saved_inv.get(k, inv[k])
	energy = d.get("energy", 100.0)
	mission_index = mini(d.get("mission_index", 0), MISSIONS.size())
	mission_count = d.get("mission_count", 0)
	if d.get("daily_day", -1) == day_index:
		daily_day = day_index
		daily = d.get("daily", [])
	(func(): toast("Data %s dimuat. Selamat datang kembali!" % my_name)).call_deferred()


func _show_save_info() -> void:
	var w := _read(WORLD_SAVE)
	if not w.is_empty():
		hud.set_menu_status("Simpanan ditemukan: lanjut dari Hari %d" % w.get("day_index", 1))


func _reset_save() -> void:
	var dir := DirAccess.open("user://")
	if dir:
		for f in dir.get_files():
			if f.ends_with(".sav"):
				dir.remove(f)
	hud.set_menu_status("Data simpanan dihapus. Permainan dimulai dari awal.")


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_game()
