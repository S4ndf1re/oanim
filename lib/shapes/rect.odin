package shapes


import rl "vendor:raylib"

// A simple rectangle as a basic shape
Rectangle :: struct {
	using shape: BasicShape,
	w, h:        f32,
}

// Create a new rectangle centered aroudn the origin with width `w` and height `h`
new_basic_rect :: proc(
	w, h: f32,
	color: rl.Color = rl.RED,
	fill_color: rl.Color = rl.RED,
) -> Rectangle {
	half_width := w / 2.0
	half_height := h / 2.0

	top_left: Vector2 = {-half_width, -half_height}
	top_right: Vector2 = {half_width, -half_height}
	bottom_left: Vector2 = {-half_width, half_height}
	bottom_right: Vector2 = {half_width, half_height}

	rect := Rectangle{}
	rect.w = w
	rect.h = h
	rect.color = color
	rect.fill_color = fill_color
	rect.segments = make([]Segment, 4)

	rect.segments[0].points = make([]Vector2, 2)
	rect.segments[0].points[0] = top_left
	rect.segments[0].points[1] = top_right
	rect.segments[0].thickness = 1.0

	rect.segments[1].points = make([]Vector2, 2)
	rect.segments[1].points[0] = top_right
	rect.segments[1].points[1] = bottom_right
	rect.segments[1].thickness = 1.0

	rect.segments[2].points = make([]Vector2, 2)
	rect.segments[2].points[0] = bottom_right
	rect.segments[2].points[1] = bottom_left
	rect.segments[2].thickness = 1.0

	rect.segments[3].points = make([]Vector2, 2)
	rect.segments[3].points[0] = bottom_left
	rect.segments[3].points[1] = top_left
	rect.segments[3].thickness = 1.0

	return rect
}
