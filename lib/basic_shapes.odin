package lib

import "core:slice"
import rl "vendor:raylib"

// A basic shape is a list of segments.
// it can be thought of as a connected curve.
// Each segment is mapped to a part of the input parameter t for the basic shape.
// For example: if the basic shape has 4 segments, each segment is mapped to 1/4 of the total parameter space (normally 0->1)
BasicShape :: struct {
	segments:   []Segment,
	color:      rl.Color,
	fill_color: rl.Color,
}

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

	rect.segments[0] = make([]Vector2, 2)
	rect.segments[0][0] = top_left
	rect.segments[0][1] = top_right

	rect.segments[1] = make([]Vector2, 2)
	rect.segments[1][0] = top_right
	rect.segments[1][1] = bottom_right

	rect.segments[2] = make([]Vector2, 2)
	rect.segments[2][0] = bottom_right
	rect.segments[2][1] = bottom_left

	rect.segments[3] = make([]Vector2, 2)
	rect.segments[3][0] = bottom_left
	rect.segments[3][1] = top_left

	return rect
}

// Delete a basic shape
destroy_basic_shape :: proc(shape: ^BasicShape) {
	for seg in shape.segments {
		// Delete a basic shape
		delete(seg)
	}

	delete(shape.segments)
}


// Split the parameter `t` to the segments into `ts`.
// Each segment timestamp `ts` is a mapping from 1/n to 0->1
@(private)
split_t_into_ts :: proc(shape: ^BasicShape, t: f32, ts: []f32) -> bool {
	if len(shape.segments) != len(ts) {
		return false
	}


	denominator := (1.0 / (f32)(len(ts)))

	complete_segments := (int)(t / denominator)
	leftover := t - (f32)(complete_segments) * denominator

	for i in 0 ..< complete_segments {
		ts[i] = 1.0
	}

	if complete_segments < len(ts) {
		ts[complete_segments] = leftover / denominator
	}

	complete_segments += 1
	for complete_segments < len(ts) {
		ts[complete_segments] = -1.0
		complete_segments += 1.0
	}

	return true
}

// Draw a shape using the draw curve by identifying the current parameterspace `ts`
draw_shape_until :: proc(
	shape: ^BasicShape,
	t: f32,
	translation: Vector2 = {0.0, 0.0},
	rotationAngle: f32 = 0.0,
) {
	ts := make([]f32, len(shape.segments))
	split_t_into_ts(shape, t, ts)

	zipped := soa_zip(t = ts, shape = shape.segments)

	for z in zipped {
		draw_curve(
			z.shape,
			z.t,
			0.001,
			color = shape.color,
			translation = translation,
			rotationAngle = rotationAngle,
		)
	}
}

// Draw a complete shape
draw_shape_all :: proc(shape: ^BasicShape) {
	for s in shape.segments {
		draw_curve(s, 1.0, 0.001, color = shape.color)
	}
}

draw_shape :: proc {
	draw_shape_all,
	draw_shape_until,
}

// Fill a shape. Identify the same paramters as draw_shape_until
fill_shape_until :: proc(
	shape: ^BasicShape,
	t: f32,
	translation: Vector2 = {0.0, 0.0},
	rotationAngle: f32 = 0.0,
) {
	ts := make([]f32, len(shape.segments))
	split_t_into_ts(shape, t, ts)

	fill_curves(
		shape.segments,
		ts,
		0.01,
		color = shape.color,
		fill_color = shape.fill_color,
		translation = translation,
		rotationAngle = rotationAngle,
	)
}

// Fill the whole shape
fill_shape_all :: proc(
	shape: ^BasicShape,
	translation: Vector2 = {0.0, 0.0},
	rotationAngle: f32 = 0.0,
) {
	ts := make([]f32, len(shape.segments))
	slice.fill(ts, 1.0)

	fill_curves(
		shape.segments,
		ts,
		0.001,
		color = shape.color,
		fill_color = shape.fill_color,
		translation = translation,
		rotationAngle = rotationAngle,
	)
}

fill_shape :: proc {
	fill_shape_all,
	fill_shape_until,
}
