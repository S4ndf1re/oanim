package shapes

import rl "vendor:raylib"

Vector2 :: [2]f32
Segment :: struct {
	thickness: f32,
	points:    []Vector2,
}


segment_from_points :: proc(seg: ^Segment, points: []Vector2, thickness: f32 = 0.0) {
	seg.points = points
	seg.thickness = thickness
}

destroy_segment :: proc(seg: ^Segment) {
	if seg.points != nil {
		delete(seg.points)
	}
}

// A basic shape is a list of segments.
// it can be thought of as a connected curve.
// Each segment is mapped to a part of the input parameter t for the basic shape.
// For example: if the basic shape has 4 segments, each segment is mapped to 1/4 of the total parameter space (normally 0->1)
BasicShape :: struct {
	segments:           []Segment,
	color:              rl.Color,
	fill_color:         rl.Color,
	_self:              rawptr,
	_additional_delete: proc(_: rawptr),
}


// Delete a basic shape
destroy_basic_shape :: proc(shape: ^BasicShape) {
	for i in 0 ..< len(shape.segments) {
		// Delete a basic shape
		destroy_segment(&shape.segments[i])
	}

	if shape.segments != nil {
		delete(shape.segments)
	}

	if shape._additional_delete != nil {
		shape._additional_delete(shape._self)
	}
}
