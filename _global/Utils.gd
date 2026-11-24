extends Node

## --- Keybind

func get_clean_action_text(action_name: StringName) -> String:
	var events := InputMap.action_get_events(action_name)
	for event in events:
		if event is InputEventKey:
			# Handles both physical and standard keycodes
			var keycode = event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode
			return OS.get_keycode_string(keycode)
			
		elif event is InputEventMouseButton:
			match event.button_index:
				MOUSE_BUTTON_LEFT: return "LMB"
				MOUSE_BUTTON_RIGHT: return "RMB"
				MOUSE_BUTTON_MIDDLE: return "MMB"
				MOUSE_BUTTON_XBUTTON1: return "MB4"
				MOUSE_BUTTON_XBUTTON2: return "MB5"
				MOUSE_BUTTON_WHEEL_UP: return "MW Up"
				MOUSE_BUTTON_WHEEL_DOWN: return "MW Dn"
				_: return "Mouse %d" % event.button_index
				
	return ""

func format_action_text(text: String) -> String:
	var regex := RegEx.new()
	regex.compile('"(\\w+)"')
	
	var result := text
	for match in regex.search_all(text):
		var action_name := match.get_string(1)
		var key_string := get_clean_action_text(action_name)
		result = result.replace(match.get_string(0), key_string)
	
	return result

### --- Formats

func format_number_clean(v : float) -> String:
	if is_equal_approx(v, round(v)):
		return str(int(round(v)))
	return str(v)

func format_time(seconds: float, show_hours := false) -> String:
	var s := int(seconds) % 60
	var m := int(seconds / 60) % 60
	if show_hours:
		var h := int(seconds / 3600)
		return "%02d:%02d:%02d" % [h, m, s]
	return "%02d:%02d" % [m, s]

### --- Data Types

func roll_chance(probability: float) -> bool:
	return randf() < probability

## Rolls true/false for one weighted option's share of a pool, using the same
## roll_success mechanism as a flat-probability roll.
## E.g. roll_weight(25, [70, 25, 5]) → true ~25% of the time (25 out of a 100 total).
## Use this when you only care about one specific outcome ("did the rare drop trigger?")
## rather than picking an item from the whole table — for that, use array_weighted_random
## or dict_weighted_random instead.
func roll_weight(weight: float, all_weights: Array) -> bool:
	var total := 0.0
	for w in all_weights:
		total += w
	if total <= 0.0:
		return false
	return roll_chance(weight / total)


## --- Array

func array_get_random(arr: Array) -> Variant:
	return arr[randi() % arr.size()]

func array_remove_duplicates(arr: Array) -> Array:
	var seen: Dictionary = {}
	var result: Array = []
	for item in arr:
		if item not in seen:
			seen[item] = true
			result.append(item)
	return result

## Returns a new shuffled copy of `arr` without mutating the original.
func array_shuffle(arr: Array) -> Array:
	var result := arr.duplicate()
	result.shuffle()
	return result


## --- Dictionary

## Merges two dictionaries, with `override` values winning on key conflicts.
func dict_merge(base: Dictionary, override: Dictionary) -> Dictionary:
	var result := base.duplicate()
	for key in override:
		result[key] = override[key]
	return result

## Returns a value for `key`, or `default` if the key doesn't exist.
## (Godot has dict.get(key, default) already — but worth a wrapper if you want null-safety on nested dicts)
func dict_get_nested(dict: Dictionary, keys: Array, default = null):
	var current = dict
	for key in keys:
		if current is Dictionary and current.has(key):
			current = current[key]
		else:
			return default
	return current

## --- String

func get_hotkey_text(action: StringName) -> String:
	var events := InputMap.action_get_events(action)
	if events.is_empty():
		return "(unbound)"
	return events[0].as_text()

## --- Vector2
func is_within_distance(pos1 : Vector2, pos2 : Vector2, distance : float):
	return pos1.distance_to(pos2) <= distance

# Finds a random position within the center's radiius.
func random_position_in_radius(center: Vector2, radius: float) -> Vector2:
	randomize()
	var angle = randf_range(0, TAU)
	var distance = radius * sqrt(randf())
	return center + Vector2(cos(angle), sin(angle)) * distance

# Returns a random normalized 2D direction vector. More readable than the raw formula.
func random_direction_2d() -> Vector2:
	return Vector2.from_angle(randf_range(0.0, TAU))

# Finds the nearest point on a line segment to a given point. Essential for rope/line snapping.
# Basically, closest POINT on a line, from a point.
func closest_point_on_segment(point: Vector2, a: Vector2, b: Vector2) -> Vector2:
	var ab := b - a
	var t := clampf((point - a).dot(ab) / ab.dot(ab), 0.0, 1.0)
	return a + t * ab




### --- Nodes & Scenes

## Walks the tree under `parent`, calling `on_match(node)` for every node that
## satisfies `predicate`. If `on_match` returns true, traversal stops early.
## "predicate" must return a boolean value.
func traverse_tree(parent: Node, predicate: Callable, on_match: Callable) -> bool:
	for child in parent.get_children():
		if predicate.call(child):
			if on_match.call(child):
				return true
		if traverse_tree(child, predicate, on_match):
			return true
	return false


func find_first_child_where(parent: Node, predicate: Callable) -> Node:
	var found := [null]
	traverse_tree(parent, predicate, func(n):
		found[0] = n
		return true  # stop at first match
	)
	return found[0]

func find_all_children_where(parent: Node, predicate: Callable) -> Array:
	var result: Array = []
	traverse_tree(parent, predicate, func(n):
		result.append(n)
		return false  # keep going, collect everything
	)
	return result


func get_all_child_of_type(parent : Node, type : Variant) -> Array[Node]:
	return find_all_children_where(parent, func(n): return is_instance_of(n, type))

func get_first_child_of_type(parent: Node, type: Variant) -> Node:
	return find_first_child_where(parent, func(n): return is_instance_of(n, type))

func get_first_child_of_group(parent: Node, group: String) -> Node:
	return find_first_child_where(parent, func(n): return n.is_in_group(group))

func remove_all_children(parent: Node) -> void:
	for child in parent.get_children():
		child.queue_free()

func convert_to_node(variant: Variant) -> Node:
	if variant is PackedScene:
		return variant.instantiate()
	elif variant is String:
		if variant.begins_with("uid://"):
			# It's a UID, resolve it to a path first
			var path := ResourceUID.get_id_path(ResourceUID.text_to_id(variant))
			return load(path).instantiate()
		else:
			# Normal res:// or relative path
			return load(variant).instantiate()
	elif variant is Node:
		return variant
	else:
		assert(false, "Variant cannot be converted to node. Invalid variant type.")
		return null


# Collision Layers

func is_body_in_layers(body: Node2D, target_layers) -> bool:
	if not (body is CollisionObject2D):
		return false
	return (body.collision_layer & target_layers) != 0

### --- Signals & Events

func connect_once(sig: Signal, callable: Callable) -> void:
	safe_disconnect(sig, callable)
	sig.connect(callable, CONNECT_ONE_SHOT)

func safe_connect(sig: Signal, callable: Callable) -> void:
	safe_disconnect(sig, callable)
	sig.connect(callable)

func safe_disconnect(sig: Signal, callable: Callable) -> void:
	if sig.is_connected(callable): sig.disconnect(callable)


## Disconnects every callable currently connected to `sig`.
func disconnect_all(sig: Signal) -> void:
	for connection in sig.get_connections():
		sig.disconnect(connection["callable"])

### --- Time & Tweens

func wait_seconds(seconds: float, process_always: bool = false) -> void:
	await get_tree().create_timer(seconds, process_always).timeout

func wait_frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame

## Sets a bool property on `target` to true, then automatically back to false after `duration`.
## Reuses `timer` across calls (stops/restarts it), so calling this repeatedly resets the duration
## instead of stacking timers or duplicate signal connections.
func set_temporary_flag(target: Object, property: String, timer: Timer, duration: float) -> void:
	target.set(property, true)
	timer.stop()
	
	# Remove every signal in the timer
	for c in timer.timeout.get_connections():
		timer.timeout.disconnect(c["callable"])
	
	timer.start(duration)
	
	# Connects one shot
	timer.timeout.connect(func(): target.set(property, false), CONNECT_ONE_SHOT)


## This is a one shot timer! Remember!
## Mostly used for Resources since they don't have any node in a scene tree. But up to you.
func create_oneshot_timer(timer_name : String, duration : float, parent_node : Node, connect_timeout_to_function : Callable) -> Timer:
	var existing = parent_node.get_node_or_null(timer_name)
	
	if existing:
		parent_node.remove_child(existing)
		existing.queue_free()

	var timer := Timer.new()
	timer.name = timer_name
	timer.one_shot = true
	parent_node.add_child(timer)
	
	timer.timeout.connect(connect_timeout_to_function, CONNECT_ONE_SHOT)
	timer.timeout.connect(timer.queue_free)
	
	timer.start(duration)
	
	return timer


## This is a looping timer! 
## Useful for Damage-Over-Time ticks or regenerating resources every X seconds.
func create_looping_timer(timer_name: String, interval: float, parent_node: Node, callable: Callable) -> Timer:
	var existing = parent_node.get_node_or_null(timer_name)
	if existing:
		return existing # Already ticking, don't interrupt the cycle rhythm
		
	var timer := Timer.new()
	timer.name = timer_name
	timer.one_shot = false
	timer.autostart = true
	timer.wait_time = interval
	parent_node.add_child(timer)
	
	timer.timeout.connect(callable)
	return timer


### --- Area / Physics


## Checks if a given body (Node2D/PhysicsBody2D) is currently overlapping the given Area2D.
func is_body_in_area(area: Area2D, body : Node2D) -> bool:
	return body in area.get_overlapping_bodies()

## Returns the first overlapping body in the given Area2D that matches the given class/type, or null.
func get_first_class_node_in_area(area: Area2D, type: Variant) -> Node:
	for body in area.get_overlapping_bodies():
		if is_instance_of(body, type):
			return body
	return null

## Returns the first overlapping body in the given Area2D that belongs to the given group, or null.
func get_first_group_node_in_area(area: Area2D, group: String) -> Node:
	for body in area.get_overlapping_bodies():
		if body.is_in_group(group):
			return body
	return null


### --- UI / Screen / Camera

## Find the screen position from world position.
func world_to_screen(world_pos: Vector2, cam: Camera2D) -> Vector2:
	return cam.get_viewport().get_final_transform() * \
		   cam.get_canvas_transform() * world_pos

## Check if VARIANT is on screen.
func is_on_screen(world_pos: Vector2, cam: Camera2D, margin: float = 0.0) -> bool:
	if not cam:
		return false
	var screen_size := cam.get_viewport().get_visible_rect().size
	var zoom := cam.zoom if cam.zoom != Vector2.ZERO else Vector2.ONE
	var visible_world_size := screen_size / zoom
	var cam_rect := Rect2(cam.get_screen_center_position() - visible_world_size / 2.0, visible_world_size)
	return cam_rect.grow(margin).has_point(world_pos)

## Clamps a direction ray starting from the screen center to the screen edge, inset by `padding`.
func clamp_to_screen_edge(screen_size: Vector2, dir: Vector2, padding: float = 20.0) -> Vector2:
	var half: Vector2 = screen_size * 0.5
	var t_x: float = INF
	var t_y: float = INF

	if absf(dir.x) > 0.0001:
		var tx: float = ((half.x - padding) if dir.x > 0 else -(half.x - padding)) / dir.x
		t_x = absf(tx)

	if absf(dir.y) > 0.0001:
		var ty: float = ((half.y - padding) if dir.y > 0 else -(half.y - padding)) / dir.y
		t_y = absf(ty)

	return half + dir * minf(t_x, t_y)

## Positions a Control node (like a tooltip) near an `anchor_pos` (like the mouse).
## If place_above is true, it defaults to appearing above anchor_pos.
## Automatically flips and clamps so the tooltip is always 100% within screen bounds.
func place_tooltip_on_screen(control: Control, anchor_pos: Vector2, offset: Vector2 = Vector2(2, 2), place_above: bool = false) -> void:
	if not is_instance_valid(control):
		return
	control.reset_size()
	var screen_size: Vector2 = control.get_viewport().get_visible_rect().size
	var margin: float = 4.0
	
	var pos_x: float = anchor_pos.x + offset.x
	if pos_x + control.size.x > screen_size.x - margin:
		pos_x = anchor_pos.x - control.size.x - offset.x
	pos_x = clampf(pos_x, margin, maxf(margin, screen_size.x - control.size.x - margin))
	
	var pos_y: float
	if place_above:
		pos_y = anchor_pos.y - control.size.y - offset.y
		if pos_y < margin:
			pos_y = anchor_pos.y + offset.y
	else:
		pos_y = anchor_pos.y + offset.y
		if pos_y + control.size.y > screen_size.y - margin:
			pos_y = anchor_pos.y - control.size.y - offset.y
			
	pos_y = clampf(pos_y, margin, maxf(margin, screen_size.y - control.size.y - margin))
	control.global_position = Vector2(pos_x, pos_y)

## Positions a tooltip Control node relative to a target Control, Rect2, Node2D, or Vector2.
## Calculates the exact visual center and bounding size of the target (handling rotation and scaling).
## Anchors the bottom of the tooltip to the top of the target, growing dynamically upwards.
## Automatically flips to the bottom side if the target is near the top of the screen.
func place_tooltip_for_rect(control: Control, target: Variant, offset: Vector2 = Vector2(0, 6)) -> void:
	if not is_instance_valid(control) or target == null:
		return
	control.reset_size()
	var screen_size: Vector2 = control.get_viewport().get_visible_rect().size
	var margin: float = 4.0
	
	# Clear anchors so global_position coordinates are applied directly without layout interference
	control.anchor_left = 0.0
	control.anchor_top = 0.0
	control.anchor_right = 0.0
	control.anchor_bottom = 0.0
	
	var scale: Vector2 = control.scale if control.scale != Vector2.ZERO else Vector2.ONE
	var raw_width: float = maxf(control.size.x, control.custom_minimum_size.x)
	var raw_height: float = maxf(control.size.y, control.custom_minimum_size.y)
	var visual_width: float = raw_width * scale.x
	var visual_height: float = raw_height * scale.y
	var pivot_shift: Vector2 = control.pivot_offset * (Vector2.ONE - scale)
	
	var target_center: Vector2 = Vector2.ZERO
	var target_top: float = 0.0
	var target_bottom: float = 0.0
	
	if target is Control:
		if not is_instance_valid(target):
			return
		var gt: Transform2D = target.get_global_transform_with_canvas()
		var s: Vector2 = target.size
		var corners: Array[Vector2] = [
			gt * Vector2.ZERO,
			gt * Vector2(s.x, 0),
			gt * Vector2(0, s.y),
			gt * Vector2(s.x, s.y)
		]
		var min_pos: Vector2 = corners[0]
		var max_pos: Vector2 = corners[0]
		for p in corners:
			min_pos.x = minf(min_pos.x, p.x)
			min_pos.y = minf(min_pos.y, p.y)
			max_pos.x = maxf(max_pos.x, p.x)
			max_pos.y = maxf(max_pos.y, p.y)
		
		target_center = gt * (s * 0.5)
		target_top = min_pos.y
		target_bottom = max_pos.y
	elif target is Rect2:
		target_center = target.get_center()
		target_top = target.position.y
		target_bottom = target.position.y + target.size.y
	elif target is Node2D:
		if not is_instance_valid(target):
			return
		target_center = target.get_global_transform_with_canvas().origin
		target_top = target_center.y
		target_bottom = target_center.y
	elif target is Vector2:
		target_center = target
		target_top = target.y
		target_bottom = target.y
	else:
		return
	
	# Horizontally centered over target node/rect
	var visual_pos_x: float = target_center.x - (visual_width * 0.5) + offset.x
	visual_pos_x = clampf(visual_pos_x, margin, maxf(margin, screen_size.x - visual_width - margin))
	var pos_x: float = visual_pos_x - pivot_shift.x
	
	# Vertical: Anchor bottom of tooltip to top of target node
	var bottom_anchor_y: float = target_top - offset.y
	var visual_top_y: float = bottom_anchor_y - visual_height
	
	if visual_top_y < margin:
		# Flip to bottom side of target node (grows downwards)
		var visual_bottom_anchor_y: float = target_bottom + offset.y
		visual_bottom_anchor_y = clampf(visual_bottom_anchor_y, margin, maxf(margin, screen_size.y - visual_height - margin))
		control.global_position = Vector2(pos_x, visual_bottom_anchor_y - pivot_shift.y)
	else:
		# Anchor bottom to top of target node (grows upwards dynamically)
		control.global_position = Vector2(pos_x, visual_top_y - pivot_shift.y)

## Prevents a Control node (like a draggable window) from leaving the screen bounds.
## It acts like a solid wall and does NOT flip.
func clamp_control_to_screen(control: Control) -> void:
	var screen_size = control.get_viewport().get_visible_rect().size
	
	control.position.x = clampf(control.position.x, 0, screen_size.x - control.size.x)
	control.position.y = clampf(control.position.y, 0, screen_size.y - control.size.y)
