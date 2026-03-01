package lib

import "core:mem"
import "core:slice"
import "polygons"

import "shapes"


// implement simple graham scan algorithm
// Returns the CW winded convex hull for points
convex_hull :: proc(
	points: []shapes.Vector2,
	allocator: mem.Allocator = context.allocator,
	temp_allocator: mem.Allocator = context.temp_allocator,
) -> []shapes.Vector2 {
	if len(points) <= 2 {
		return slice.clone(points)
	}

	ps := make([]shapes.Vector2, len(points), temp_allocator)
	defer delete(ps, temp_allocator)
	copy(ps, points)

	slice.sort_by(
		ps,
		proc(a, b: shapes.Vector2) -> bool {if a.x != b.x {return a.x < b.x}
			else {return a.y < b.y}},
	)

	upper_hull := make([dynamic]shapes.Vector2, temp_allocator)
	lower_hull := make([dynamic]shapes.Vector2, temp_allocator)

	defer delete(upper_hull)
	defer delete(lower_hull)

	append(&upper_hull, ps[0])
	append(&upper_hull, ps[1])

	append(&lower_hull, ps[len(ps) - 1])
	append(&lower_hull, ps[len(ps) - 2])

	for i := 2; i < len(ps); i += 1 {
		vert := ps[i]
		for len(upper_hull) >= 2 &&
		    !polygons.is_right_turn(
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
		    !polygons.is_right_turn(
				    lower_hull[len(lower_hull) - 2],
				    lower_hull[len(lower_hull) - 1],
				    vert,
			    ) {
			pop(&lower_hull)
		}

		append(&lower_hull, vert)
	}

	result := make([]shapes.Vector2, len(upper_hull) + len(lower_hull) - 2)
	copy(result[:len(upper_hull)], upper_hull[:])
	copy(result[len(upper_hull):], lower_hull[1:len(lower_hull) - 1])

	return result
}

// Assume, this is a convex hull, otherwise this will likeley result in unwanted behaviour
// Assume CW winding order
to_triangle_fan_indices :: proc(
	points: []shapes.Vector2,
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
