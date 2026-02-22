package util

Vector2 :: [2]f32

Segment :: []Vector2

// compute decasteljau computation
decas :: proc(points: Segment, t: f32) -> Vector2 {
	assert(len(points) >= 1)
	n := len(points)

	working_points := make(Segment, n, allocator = context.temp_allocator)
	defer delete(working_points, allocator = context.temp_allocator)
	copy(working_points[:], points[:])

	for i := n; i > 1; i -= 1 {
		for j := 0; j < i - 1; j += 1 {
			working_points[j] = working_points[j] * (1.0 - t) + working_points[j + 1] * t
		}
	}

	return working_points[0]
}
