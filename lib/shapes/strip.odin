package shapes

import "core:mem"
import "core:slice"
import rl "vendor:raylib"


Strip :: struct {
	using shape: BasicShape,
}

// Create a new line strip where two neighboring points are combined into a segment. This can be drawn using the normal basic shape drawing techniques
new_strip_shape :: proc(
	points: []Vector2,
	color := rl.RED,
	thickness: f32,
	allocator := context.allocator,
	temp_allocator := context.temp_allocator,
) -> Strip {
	strip := Strip{}
	strip.color = color
	strip.fill_color = rl.BLACK
	// Make transparent, as a strip cannot be filled
	strip.fill_color.w = 0

	segments := make([dynamic]Segment, 0, len(points) * 2, temp_allocator)
	defer delete(segments)

	for i in 0 ..< len(points)-1 {
		pts := slice.clone(points[i:i + 2], allocator)
		append(&segments, Segment{thickness = thickness, points = pts})
	}

	strip.segments = slice.clone(segments[:], allocator)
	return strip
}
