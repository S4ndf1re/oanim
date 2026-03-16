package lib

import rl "vendor:raylib"

Grid :: struct {
	spacing: [3]f32,
	count:   [3]int,
	length:  [3]f32,
	color:   rl.Color,
}


// Use raylib to render the grid
render_grid :: proc(grid: ^Grid) {
	for x in 0 ..< grid.count.x {
		start := [3]f32{cast(f32)x * grid.spacing.x, -grid.length.y / 2.0, 0.0}
		end := [3]f32{cast(f32)x * grid.spacing.x, grid.length.y / 2.0, 0.0}

		rl.DrawLine3D(start, end, grid.color)
	}

	for y in 0 ..< grid.count.y {
		start := [3]f32{-grid.length.x / 2.0, cast(f32)y * grid.spacing.y, 0.0}
		end := [3]f32{grid.length.x / 2.0, cast(f32)y * grid.spacing.y, 0.0}

		rl.DrawLine3D(start, end, grid.color)
	}

	// XZ Grid
	for x in 0 ..< grid.count.x {
		start := [3]f32{cast(f32)x * grid.spacing.x, 0.0, -grid.length.z / 2.0}
		end := [3]f32{cast(f32)x * grid.spacing.x, 0.0, grid.length.z / 2.0}

		rl.DrawLine3D(start, end, grid.color)
	}

	for z in 0 ..< grid.count.z {
		start := [3]f32{-grid.length.x / 2.0, 0.0, cast(f32)z * grid.spacing.z}
		end := [3]f32{grid.length.x / 2.0, 0.0, cast(f32)z * grid.spacing.z}

		rl.DrawLine3D(start, end, grid.color)
	}

	// XZ Grid
	for y in 0 ..< grid.count.y {
		start := [3]f32{0.0, cast(f32)y * grid.spacing.y, -grid.length.z / 2.0}
		end := [3]f32{0.0, cast(f32)y * grid.spacing.y, grid.length.z / 2.0}

		rl.DrawLine3D(start, end, grid.color)
	}

	for z in 0 ..< grid.count.z {
		start := [3]f32{0.0, -grid.length.y / 2.0, cast(f32)z * grid.spacing.z}
		end := [3]f32{0.0, grid.length.y / 2.0, cast(f32)z * grid.spacing.z}

		rl.DrawLine3D(start, end, grid.color)
	}
}
