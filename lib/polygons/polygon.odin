package polygons

import "core:math"
import "core:math/linalg"

Vector2 :: [2]f32

// CW Polygon
Polygon :: []Vector2


// implement the cosine of the dot product for a and b
cosine :: proc(a, b: Vector2) -> f32 {
	return linalg.dot(a, b) / (linalg.length(a) * linalg.length(b))
}

// implement the 2d normal for a vector `v`
normal :: proc(v: Vector2) -> Vector2 {
	result := v.yx
	result.x *= -1
	return result
}

// Compute the distance from the line between p and q to test
distance_from_line :: proc(p, test, q: Vector2) -> f32 {
	t := point_on_line_t(p, q, test)
	t_min_dist := math.clamp(t, 0.0, 1.0)
	p_min_dist := p * (1.0 - t_min_dist) + q * t_min_dist
	directional_test := test - p_min_dist
	dist := linalg.length(directional_test)
	return dist
}

// Check if the segment p -> test -> q is a right turn.
// This is done by checking if the p->test is positined above or below the line p->q
// A threshold is applied to the distance that `test` as to the line to allow for floating point errors
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

// Find the parameter `t` in `f(t) := a * (1.0-t) + b * t`,
// where `a = line_start` and `b = line_end`
// So that f(t) is the closest point on the line line_start->line_end to `point`
point_on_line_t :: proc(line_start, line_end, point: Vector2) -> f32 {
	sp := point - line_start
	se := line_end - line_start

	se_len := linalg.length2(se)

	dot_prod := linalg.dot(sp, se)

	t := dot_prod / se_len

	return t
}

// Compute the angle between `u`, `v` and `w`
angle_between :: proc(u, v, w: Vector2) -> f32 {
	diff1 := u - v
	diff2 := w - v

	cos := cosine(diff1, diff2)

	return math.acos(cos)
}
