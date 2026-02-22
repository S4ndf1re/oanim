package util

import "core:math"
import "core:math/linalg"
import "core:mem"
import "core:slice"

point_on_line_t :: proc(line_start, line_end, point: Vector2) -> f32 {
	r := line_end - line_start
	s1 := point.x
	s2 := point.y

	r1 := r.x
	r2 := r.y

	x1_1 := line_start.x
	x1_2 := line_start.y

	t := (1.0 - r1 * s1 + r1 * x1_1 - r2 * s2 + r2 * x1_2) / (-r1 * r1 - r2 * r2)
	return t
}

cosine :: proc(a, b: Vector2) -> f32 {
	return linalg.dot(a, b) / (linalg.length(a) * linalg.length(b))
}

normal :: proc(v: Vector2) -> Vector2 {
	result := v.yx
	result.x *= -1
	return result
}

is_right_turn :: proc(p, test, q: Vector2) -> bool {
	direction_line := q - p
	line_normal := normal(direction_line)

	t_min_dist := math.clamp(point_on_line_t(p, q, test), 0.0, 1.0)
	p_min_dist := p * (1.0 - t_min_dist) + q * t_min_dist

	directional_test := test - p_min_dist
	dist := linalg.length(directional_test)
	cos := cosine(line_normal, directional_test)

	return cos >= 0.0 || dist < 0.000001
}

// implement simple graham scan algorithm
// Returns the CW winded convex hull for points
convex_hull :: proc(
	points: []Vector2,
	allocator: mem.Allocator = context.allocator,
	temp_allocator: mem.Allocator = context.temp_allocator,
) -> []Vector2 {
	if len(points) <= 2 {
		return slice.clone(points)
	}

	ps := make([]Vector2, len(points), temp_allocator)
	defer delete(ps, temp_allocator)
	copy(ps, points)

	slice.sort_by(
		ps,
		proc(a, b: Vector2) -> bool {if a.x != b.x {return a.x < b.x} else {return a.y < b.y}},
	)

	upper_hull := make([dynamic]Vector2, temp_allocator)
	lower_hull := make([dynamic]Vector2, temp_allocator)

	defer delete(upper_hull)
	defer delete(lower_hull)

	append(&upper_hull, ps[0])
	append(&upper_hull, ps[1])

	append(&lower_hull, ps[len(ps) - 1])
	append(&lower_hull, ps[len(ps) - 2])

	for i := 2; i < len(ps); i += 1 {
		vert := ps[i]
		for len(upper_hull) >= 2 &&
		    !is_right_turn(
				    upper_hull[len(upper_hull) - 2],
				    upper_hull[len(upper_hull) - 1],
				    vert,
			    ) {
			pop(&upper_hull)
		}

		append(&upper_hull, vert)
	}

	for i := len(ps) - 3; i >= 0; i -= 1 {
		vert := ps[i]
		for len(lower_hull) >= 2 &&
		    !is_right_turn(
				    lower_hull[len(lower_hull) - 2],
				    lower_hull[len(lower_hull) - 1],
				    vert,
			    ) {
			pop(&lower_hull)
		}

		append(&lower_hull, vert)
	}

	result := make([]Vector2, len(upper_hull) + len(lower_hull) - 2)
	copy(result[:len(upper_hull)], upper_hull[:])
	copy(result[len(upper_hull):], lower_hull[1:len(lower_hull) - 1])

	return result
}

// Assume, this is a convex hull, otherwise this will likeley result in unwanted behaviour
// Assume CW winding order
to_triangle_fan_indices :: proc(
	points: []Vector2,
	allocator: mem.Allocator = context.allocator,
	temp_allocator: mem.Allocator = context.temp_allocator,
) -> (
	[][3]int,
	bool,
) {
	if len(points) < 3 {
		return nil, false
	}

	triangles := make([dynamic][3]int, temp_allocator)
	defer delete(triangles)

	for i := 1; i < len(points) - 1; i += 1 {
		indizes: [3]int = {0, i, i + 1}
		append(&triangles, indizes)
	}

	result := slice.clone(triangles[:])
	return result, true
}
