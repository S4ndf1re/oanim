package simple_draw

import "core:fmt"
import rl "vendor:raylib"

import util "../../lib"
import "../../lib"
import "../../lib/shapes"
import "../../lib/tasks"

SVG_PATH :: "nano.svg"

State :: struct {
	task:           tasks.TaskSystem,
	control_points: shapes.Segment,
	rect:           shapes.Rectangle,
	circle:         shapes.Circle,
	t:              f32,
	grid:           util.Grid,
}

state: ^State

create_task :: proc(task: ^tasks.TaskSystem) {
	tasks.destroy_system(task)

	fmt.println("Initilizing system")
	tasks.init_system(task)
	task.trigger_callback_after_done = true
	state.task.loop = true

	frames := lib.Keyframes{}
	lib.init(&frames, false)
	lib.push_keyframe(
		&frames,
		lib.Keyframe{start = 0.0, end = 1.0, duration = 2.0, ease_fn = lib.sinus_ease},
	)
	lib.push_keyframe(
		&frames,
		lib.Keyframe{start = 1.0, end = 0.0, duration = 1.0, ease_fn = lib.sinus_ease},
	)
	lib.push_keyframe(
		&frames,
		lib.Keyframe{start = 0.0, end = 0.5, duration = 1.0, ease_fn = lib.sinus_ease},
	)
	tasks.add_task(task, tasks.new_keyframe_task(frames, state, proc(ptr: rawptr, t: f32) {
			state := cast(^State)ptr
			fill_color := rl.RED
			fill_color.w = 50
			lib.fill_curve(
				state.control_points,
				t,
				0.01,
				color = rl.BLUE,
				fill_color = fill_color,
				translation = shapes.Vector2{100.0, 0.0},
			)
		}))
	tasks.add_task(task, tasks.new_wait_task(1.0))


	frames = lib.Keyframes{}
	lib.init(&frames, false)
	lib.push_keyframe(
		&frames,
		lib.Keyframe{start = 0.0, end = 1.0, duration = 2.0, ease_fn = lib.sinus_ease},
	)
	lib.push_keyframe(
		&frames,
		lib.Keyframe{start = 1.0, end = 0.0, duration = 1.0, ease_fn = lib.sinus_ease},
	)
	tasks.add_task(task, tasks.new_keyframe_task(frames, state, proc(ptr: rawptr, t: f32) {
			state := cast(^State)ptr
			window_w := rl.GetScreenWidth()
			window_h := rl.GetScreenHeight()
			lib.fill_shape(
				&state.rect,
				t,
				translation = shapes.Vector2{(f32)(window_w) * t, (f32)(window_h) / 2.0},
				rotationAngle = 90.0 * t,
			)
		}))
	tasks.add_task(task, tasks.new_wait_task(1.0))
}


set_current_t_callback: tasks.KeyframeTaskCallback : proc(ptr: rawptr, value: f32) {
	state := (^State)(ptr)

	state.t = value
}

create_segment :: proc(kfs: ^shapes.Segment) {
	shapes.destroy_segment(kfs)

	points := make([]shapes.Vector2, 3)
	points[0] = {100.0, 100.0}
	points[1] = {200.0, 300.0}
	points[2] = {500.0, 100.0}

	shapes.segment_from_points(kfs, points, 1.0)
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
}

@(export)
plugin_update :: proc(dt: f32) {
}

@(export)
plugin_render :: proc() {
	util.render_grid(&state.grid)

	tasks.update_system(&state.task)
}

@(export)
plugin_shutdown :: proc() {
	tasks.destroy_system(&state.task)

	shapes.destroy_segment(&state.control_points)

	shapes.destroy_basic_shape(&state.rect)
	shapes.destroy_basic_shape(&state.circle)

	free(state)
}

@(export)
plugin_memory :: proc() -> rawptr {
	return state
}

@(export)
plugin_hot_reload :: proc(memory: rawptr) {
	state = cast(^State)memory

	create_task(&state.task)
	create_segment(&state.control_points)
	create_basic_shapes(&state.rect, &state.circle)

	state.grid.color = rl.WHITE
	state.grid.count = {100, 100, 100}
	state.grid.spacing = {10, 10, 10}
	state.grid.length = {1000, 1000, 1000}
}
