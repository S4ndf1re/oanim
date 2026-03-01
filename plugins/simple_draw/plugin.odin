package simple_draw

import rl "vendor:raylib"

import util "../../lib"
import "../../lib/basic_shapes"
import "../../lib/basic_shapes/shapes"

State :: struct {
	frames:         util.Keyframes,
	control_points: shapes.Segment,
	rect:           shapes.Rectangle,
	circle:         shapes.Circle,
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

create_segment :: proc(kfs: ^shapes.Segment) {
	delete(kfs^)

	kfs^ = make(shapes.Segment, 3)
	kfs^[0] = {100.0, 100.0}
	kfs^[1] = {200.0, 300.0}
	kfs^[2] = {500.0, 100.0}
}

create_basic_shapes :: proc(rect: ^shapes.Rectangle, circle: ^shapes.Circle) {
	shapes.destroy_basic_shape(rect)
	shapes.destroy_basic_shape(circle)

	fill_color := rl.BLUE
	fill_color.w = 50
	rect^ = shapes.new_basic_rect(100.0, 100.0, rl.RED, fill_color)

	fill_color = rl.BLUE
	fill_color.w = 50
	circle^ = shapes.new_basic_circle(100.0, rl.RED, fill_color)
}

@(export)
plugin_init :: proc() {
	state = new(State)
	state.frames = util.init(true)
	state.control_points = make(shapes.Segment, 3)
	state.rect = shapes.new_basic_rect(100.0, 100.0)
	state.circle = shapes.new_basic_circle(100.0)


	create_keyframes(&state.frames)
	create_segment(&state.control_points)
	create_basic_shapes(&state.rect, &state.circle)
}

@(export)
plugin_update :: proc(dt: f32) {
	util.advance(dt, &state.frames)
}

@(export)
plugin_render :: proc() {
	window_h := rl.GetScreenHeight()
	window_w := rl.GetScreenWidth()
	w, h: i32 = 50, 50

	t := util.get_value(&state.frames)
	fill_color := rl.RED
	fill_color.w = 50
	// basic_shapes.fill_curve(
	// 	state.control_points,
	// 	t,
	// 	0.01,
	// 	color = rl.RED,
	// 	fill_color = fill_color,
	// 	translation = shapes.Vector2{100.0, 0.0},
	// )
	// x_pos := util.lerp(0.0, (f32)(window_w), t)
	// y_pos := util.lerp(0.0, (f32)(window_h), t)
	// rl.DrawRectangle((i32)(x_pos - (f32)(w / 2)), (i32)(y_pos - (f32)(h / 2)), w, h, rl.BLUE)

	// basic_shapes.fill_shape(
	// 	&state.rect,
	// 	t,
	// 	translation = shapes.Vector2{(f32)(window_w) * t, (f32)(window_h) / 2.0},
	// 	rotationAngle = 90.0 * t,
	// )

	basic_shapes.fill_shape(
		&state.circle,
		t,
		translation = shapes.Vector2{(f32)(window_w) * (1.0 - t), (f32)(window_h) / 2.0},
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
	create_basic_shapes(&state.rect, &state.circle)
}
