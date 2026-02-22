package util

import "core:math/linalg"
import rl "vendor:raylib"
import "vendor:raylib/rlgl"


draw_line_in_gl_context :: proc(start, end: Vector2, thickness: f32) {
	diff := end - start
	length := linalg.length(diff)

	if (length > 0 && thickness > 0) {
		factor := thickness / (2.0 * length)
		norm := normal(diff) * factor

		rlgl.Vertex2f(start.x - norm.x, start.y - norm.y)
		rlgl.Vertex2f(start.x + norm.x, start.y + norm.y)
		rlgl.Vertex2f(end.x + norm.x, end.y + norm.y)

		rlgl.Vertex2f(end.x + norm.x, end.y + norm.y)
		rlgl.Vertex2f(end.x - norm.x, end.y - norm.y)
		rlgl.Vertex2f(start.x - norm.x, start.y - norm.y)
	}
}

draw_curve :: proc(
	curve: Segment,
	t_until: f32,
	step_size: f32,
	color: rl.Color = rl.RED,
	translation: Vector2 = {0.0, 0.0},
	rotationAngle: f32 = 0.0,
	thickness: f32 = 1.0,
) {
	t: f32 = 0.0

	rlgl.DrawRenderBatchActive()
	rlgl.PushMatrix()
	defer rlgl.PopMatrix()
	rlgl.MatrixMode(rlgl.MODELVIEW)
	rlgl.Translatef(translation.x, translation.y, 0.0)
	rlgl.Rotatef(rotationAngle, 0.0, 0.0, 1.0)
	defer rlgl.DrawRenderBatchActive()

	rlgl.Begin(rlgl.TRIANGLES)
	{
		rlgl.Color4ub(color.x, color.y, color.z, color.w)

		if t_until >= 0 {
			old_pos := decas(curve, t)
			t += step_size

			for t < t_until {
				pos := decas(curve, t)
				draw_line_in_gl_context(old_pos, pos, thickness)

				old_pos = pos
				t += step_size
			}

			// draw final segment, since, t < t_until
			pos := decas(curve, t_until)
			draw_line_in_gl_context(old_pos, pos, thickness)
		}
	}
	rlgl.End()
}

fill_curve :: proc(
	curve: Segment,
	t_until: f32,
	step_size: f32,
	color: rl.Color = rl.RED,
	fill_color: rl.Color = rl.RED,
	translation: Vector2 = {0.0, 0.0},
	rotationAngle: f32 = 0.0,
	thickness: f32 = 1.0,
) {
	curves := [?]Segment{curve}
	t_untils := [?]f32{t_until}
	fill_curves(
		curves[:],
		t_untils[:],
		step_size,
		color,
		fill_color,
		translation,
		rotationAngle,
		thickness,
	)
}

fill_curves :: proc(
	curves: []Segment,
	t_until: []f32,
	step_size: f32,
	color: rl.Color = rl.RED,
	fill_color: rl.Color = rl.RED,
	translation: Vector2 = {0.0, 0.0},
	rotationAngle: f32 = 0.0,
	thickness: f32 = 1.0,
) {
	points := make([dynamic]Vector2)
	defer delete(points)

	rlgl.DrawRenderBatchActive()
	rlgl.PushMatrix()
	defer rlgl.PopMatrix()
	rlgl.MatrixMode(rlgl.MODELVIEW)
	rlgl.Translatef(translation.x, translation.y, 0.0)
	rlgl.Rotatef(rotationAngle, 0.0, 0.0, 1.0)
	defer rlgl.DrawRenderBatchActive()

	rlgl.Begin(rlgl.TRIANGLES)
	{
		rlgl.Color4ub(color.x, color.y, color.z, color.w)

		curves_ts := soa_zip(curve = curves, t_until = t_until)
		for curve in curves_ts {
			if curve.t_until >= 0 {
				t: f32 = 0.0
				old_pos := decas(curve.curve, t)
				_ = append(&points, old_pos)

				t += step_size

				for t < curve.t_until {
					pos := decas(curve.curve, t)
					_ = append(&points, pos)
					t += step_size

					draw_line_in_gl_context(old_pos, pos, thickness)

					old_pos = pos
				}

				// draw final segment, since, t < t_until
				pos := decas(curve.curve, curve.t_until)
				_ = append(&points, pos)
				draw_line_in_gl_context(old_pos, pos, thickness)
			}
		}

		hull := convex_hull(points[:])
		defer delete(hull)

		triangles, ok := to_triangle_fan_indices(hull)
		if ok {
			defer delete(triangles)

			rlgl.Color4ub(fill_color.x, fill_color.y, fill_color.z, fill_color.w)
			for triangle in triangles {
				v1 := hull[triangle[0]]
				v2 := hull[triangle[1]]
				v3 := hull[triangle[2]]
				rlgl.Vertex2f(v1.x, v1.y)
				rlgl.Vertex2f(v2.x, v2.y)
				rlgl.Vertex2f(v3.x, v3.y)
			}
		}
	}
	rlgl.End()
}
