package lib

import "core:math"

// Map any t in range [0.0, 1.0] to range [0.0, 1.0] in an eased fashion (for example sinus)
EaseFunction :: #type proc(_: f32) -> f32

// Map t between 0 and pi/2 and output the sinus value
sinus_ease :: proc(t: f32) -> f32 {
	t_clamped := math.clamp(t, 0.0, 1.0)
	t_mapped := math.PI * t_clamped - math.PI / 2.0
	return (math.sin(t_mapped) + 1.0) / 2.0
}
