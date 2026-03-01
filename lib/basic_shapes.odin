package lib

import "core:slice"
import "shapes"
import rl "vendor:raylib"


// Split the parameter `t` to the segments into `ts`.
// Each segment timestamp `ts` is a mapping from 1/n to 0->1
@(private)
split_t_into_ts :: proc(shape: ^shapes.BasicShape, t: f32, ts: []f32) -> bool {
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
	shape: ^shapes.BasicShape,
	t: f32,
	translation: shapes.Vector2 = {0.0, 0.0},
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
draw_shape_all :: proc(shape: ^shapes.BasicShape) {
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
	shape: ^shapes.BasicShape,
	t: f32,
	translation: shapes.Vector2 = {0.0, 0.0},
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
	shape: ^shapes.BasicShape,
	translation: shapes.Vector2 = {0.0, 0.0},
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
