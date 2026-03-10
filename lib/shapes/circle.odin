package shapes


import rl "vendor:raylib"


Circle :: struct {
	using shape: BasicShape,
	r:           f32,
}


new_basic_circle :: proc(r: f32, color := rl.RED, fill_color := rl.RED) -> Circle {
	circle := Circle{}
	circle.r = r
	circle.color = color
	circle.fill_color = fill_color

	circle.segments = make([]Segment, 4)

	// As defined by https://spencermortensen.com/articles/bezier-circle/
	// Define 4 quater circles and piece them together

	// NOTE: muliply with r, to go from unit circle to circle with radius r
	a := 1.00005507808 * r
	b := 0.55342925736 * r
	c := 0.99873327689 * r

	rotate := proc(v: Vector2) -> Vector2 {
		return {v.y, -v.x}
	}

	// Segment top left
	circle.segments[3].points = make([]Vector2, 4)
	circle.segments[3].points[3] = Vector2{0, a}
	circle.segments[3].points[2] = Vector2{b, c}
	circle.segments[3].points[1] = Vector2{c, b}
	circle.segments[3].points[0] = Vector2{a, 0}
	circle.segments[3].thickness = 1.0

	// Segment bottom left
	circle.segments[2].points = make([]Vector2, 4)
	circle.segments[2].points[3] = Vector2{a, -0}
	circle.segments[2].points[2] = Vector2{c, -b}
	circle.segments[2].points[1] = Vector2{b, -c}
	circle.segments[2].points[0] = Vector2{0, -a}
	circle.segments[2].thickness = 1.0

	// Segment bottom right
	circle.segments[1].points = make([]Vector2, 4)
	circle.segments[1].points[3] = Vector2{0, -a}
	circle.segments[1].points[2] = Vector2{-b, -c}
	circle.segments[1].points[1] = Vector2{-c, -b}
	circle.segments[1].points[0] = Vector2{-a, 0}
	circle.segments[1].thickness = 1.0

	// Segment top right
	circle.segments[0].points = make([]Vector2, 4)
	circle.segments[0].points[3] = Vector2{-a, 0}
	circle.segments[0].points[2] = Vector2{-c, b}
	circle.segments[0].points[1] = Vector2{-b, c}
	circle.segments[0].points[0] = Vector2{0, a}
	circle.segments[0].thickness = 1.0

	return circle
}
