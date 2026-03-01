package shapes

import rl "vendor:raylib"

Vector2 :: [2]f32
Segment :: []Vector2

// A basic shape is a list of segments.
// it can be thought of as a connected curve.
// Each segment is mapped to a part of the input parameter t for the basic shape.
// For example: if the basic shape has 4 segments, each segment is mapped to 1/4 of the total parameter space (normally 0->1)
BasicShape :: struct {
	segments:   []Segment,
	color:      rl.Color,
	fill_color: rl.Color,
}


// Delete a basic shape
destroy_basic_shape :: proc(shape: ^BasicShape) {
	for seg in shape.segments {
		// Delete a basic shape
		delete(seg)
	}

	delete(shape.segments)
}
