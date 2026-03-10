package lib

import "shapes"

// compute decasteljau bezier point using control `points` and a parameter `t`
decas :: proc(segment: shapes.Segment, t: f32) -> shapes.Vector2 {
	assert(len(segment.points) >= 1)
	n := len(segment.points)

	working_points := make([]shapes.Vector2, n, allocator = context.temp_allocator)
	defer delete(working_points, allocator = context.temp_allocator)
	copy(working_points[:], segment.points[:])

	for i := n; i > 1; i -= 1 {
		for j := 0; j < i - 1; j += 1 {
			working_points[j] = working_points[j] * (1.0 - t) + working_points[j + 1] * t
		}
	}

	return working_points[0]
}
