package simple_draw

import rl "vendor:raylib"

import util "../../lib"

State :: struct {
	frames:         util.Keyframes,
	control_points: util.Segment,
	shape:          util.Rectangle,
}

state: ^State

create_keyframes :: proc(kfs: ^util.Keyframes) {
	util.clear(kfs)

	util.push(
		kfs,
		util.Keyframe{start = 0.0, end = 1.0, duration = 3.0, ease_fn = util.sinus_ease},
	)
	util.push(
		kfs,
		util.Keyframe{start = 1.0, end = 0.0, duration = 3.0, ease_fn = util.sinus_ease},
	)
}

create_segment :: proc(kfs: ^util.Segment) {
	delete(kfs^)

	kfs^ = make(util.Segment, 3)
	kfs^[0] = {100.0, 100.0}
	kfs^[1] = {200.0, 300.0}
	kfs^[2] = {500.0, 100.0}
}

create_basic_shape :: proc(shape: ^util.Rectangle) {
	util.destroy_basic_shape(shape)

	fill_color := rl.BLUE
	fill_color.w = 50
	shape^ = util.new_basic_rect(100.0, 100.0, rl.RED, fill_color)
}

@(export)
plugin_init :: proc() {
	state = new(State)
	state.frames = util.init(true)
	state.control_points = make(util.Segment, 3)
	state.shape = util.new_basic_rect(100.0, 100.0)


	create_keyframes(&state.frames)
	create_segment(&state.control_points)
	create_basic_shape(&state.shape)
}

@(export)
plugin_update :: proc(dt: f32) {
	util.advance(&state.frames, dt)
}

@(export)
plugin_render :: proc() {
	window_h := rl.GetScreenHeight()
	window_w := rl.GetScreenWidth()
	w, h: i32 = 50, 50

	t := util.get_value(&state.frames)
	fill_color := rl.RED
	fill_color.w = 50
	util.fill_curve(
		state.control_points,
		t,
		0.01,
		color = rl.RED,
		fill_color = fill_color,
		translation = util.Vector2{100.0, 0.0},
	)
	// x_pos := util.lerp(0.0, (f32)(window_w), t)
	// y_pos := util.lerp(0.0, (f32)(window_h), t)
	// rl.DrawRectangle((i32)(x_pos - (f32)(w / 2)), (i32)(y_pos - (f32)(h / 2)), w, h, rl.BLUE)

	util.fill_shape(
		&state.shape,
		t,
		translation = util.Vector2{(f32)(window_w) * t, (f32)(window_h) / 2.0},
		rotationAngle = 90.0 * t,
	)
}

@(export)
plugin_shutdown :: proc() {
	util.destroy(&state.frames)
	free(state)
}

@(export)
plugin_memory :: proc() -> rawptr {
	return state
}

@(export)
plugin_hot_reload :: proc(memory: rawptr) {
	state = cast(^State)memory
	create_keyframes(&state.frames)
	create_segment(&state.control_points)
	create_basic_shape(&state.shape)
}
