extends CharacterBody3D
# Petani. Pemain lokal dikendalikan keyboard/mouse; pemain lain (multiplayer)
# hanya mengikuti posisi yang dikirim lewat jaringan.

signal footstep

const SPEED := 6.0
const JUMP := 5.5
const GRAVITY := 14.0
const MODELS = ["character-male-a", "character-female-b", "character-male-c",
	"character-female-c", "character-male-d", "character-female-d"]

var is_local := true
var input_enabled := true
var model_idx := 0
var display_name := ""
var cam_yaw := 0.0
var cam_pitch := -0.35
var pivot: Node3D
var model: Node3D
var start_pos: Vector3
var speed_mult := 1.0
var anim: AnimationPlayer
var action_time := 0.0
var step_timer := 0.0
var send_timer := 0.0
var current_anim := "idle"
var name_label: Label3D
# Data jaringan untuk pemain lain.
var net_pos := Vector3.ZERO
var net_rot := 0.0
var net_anim := "idle"


func _ready() -> void:
	start_pos = position
	net_pos = position
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.8
	cs.shape = cap
	cs.position.y = 0.9
	add_child(cs)

	model = Node3D.new()
	add_child(model)
	set_model(model_idx)

	name_label = Label3D.new()
	name_label.position.y = 2.3
	name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	name_label.font_size = 48
	name_label.outline_size = 12
	name_label.pixel_size = 0.005
	name_label.modulate = Color(1, 0.95, 0.7)
	name_label.text = display_name
	name_label.visible = not is_local
	add_child(name_label)

	if is_local:
		pivot = Node3D.new()
		pivot.position.y = 1.4
		add_child(pivot)
		var spring := SpringArm3D.new()
		spring.spring_length = 6.0
		spring.add_excluded_object(get_rid())
		pivot.add_child(spring)
		var cam := Camera3D.new()
		spring.add_child(cam)
		cam.current = true
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func set_model(idx: int) -> void:
	# Karakter Kenney Mini Characters (CC0); model asli menghadap +Z.
	model_idx = clampi(idx, 0, MODELS.size() - 1)
	for c in model.get_children():
		c.queue_free()
	var ch: Node3D = load("res://assets/chars/%s.glb" % MODELS[model_idx]).instantiate()
	ch.scale = Vector3.ONE * 2.2
	ch.rotation.y = PI
	model.add_child(ch)
	anim = ch.find_child("AnimationPlayer", true, false) as AnimationPlayer


func set_display_name(n: String) -> void:
	display_name = n
	if name_label:
		name_label.text = n


func _unhandled_input(event: InputEvent) -> void:
	if not is_local or not input_enabled:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		cam_yaw -= event.relative.x * 0.005
		cam_pitch = clamp(cam_pitch - event.relative.y * 0.005, -1.2, 0.3)
	elif event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _play(want: String) -> void:
	current_anim = want
	if anim and anim.current_animation != want and anim.has_animation(want):
		anim.play(want, 0.15)


func _physics_process(delta: float) -> void:
	if not is_local:
		global_position = global_position.lerp(net_pos, minf(1.0, delta * 12))
		model.rotation.y = lerp_angle(model.rotation.y, net_rot, minf(1.0, delta * 12))
		_play(net_anim)
		return

	if input_enabled and Input.is_key_pressed(KEY_Q): cam_yaw += 2.0 * delta
	if input_enabled and Input.is_key_pressed(KEY_E): cam_yaw -= 2.0 * delta
	pivot.rotation = Vector3(cam_pitch, cam_yaw, 0)

	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	elif input_enabled and Input.is_key_pressed(KEY_SPACE):
		velocity.y = JUMP

	var input := Vector2.ZERO
	if input_enabled:
		if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): input.y -= 1
		if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): input.y += 1
		if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): input.x -= 1
		if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): input.x += 1
	var dir := Vector3(input.x, 0, input.y).rotated(Vector3.UP, cam_yaw).normalized()

	if dir != Vector3.ZERO:
		velocity.x = dir.x * SPEED * speed_mult
		velocity.z = dir.z * SPEED * speed_mult
		model.rotation.y = lerp_angle(model.rotation.y, atan2(-dir.x, -dir.z), 10 * delta)
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)
	move_and_slide()

	action_time -= delta
	var want := "idle"
	if action_time > 0:
		want = "interact-right"
	elif not is_on_floor():
		want = "jump"
	elif dir != Vector3.ZERO:
		want = "walk" if speed_mult < 1.0 else "sprint"
	_play(want)

	# Suara langkah kaki.
	if is_on_floor() and dir != Vector3.ZERO:
		step_timer -= delta
		if step_timer <= 0:
			step_timer = 0.45 if speed_mult < 1.0 else 0.3
			footstep.emit()

	if global_position.y < -10:
		global_position = start_pos
		velocity = Vector3.ZERO

	# Kirim posisi ke pemain lain (20x per detik).
	send_timer -= delta
	if send_timer <= 0 and multiplayer.multiplayer_peer is ENetMultiplayerPeer \
			and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		send_timer = 0.05
		net_state.rpc(global_position, model.rotation.y, current_anim)


@rpc("any_peer", "unreliable_ordered")
func net_state(p: Vector3, r: float, a: String) -> void:
	if multiplayer.get_remote_sender_id() != name.to_int():
		return
	net_pos = p
	net_rot = r
	net_anim = a


func do_action() -> void:
	action_time = 0.5
