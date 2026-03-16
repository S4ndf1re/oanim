package lib

import "core:fmt"
import "core:math/linalg"
import "polygons"
import "shapes"
import rl "vendor:raylib"
import "vendor:raylib/rlgl"


// this is a near one to one copy from raylib. I wanted to make sure that this function can be called from within an rlgl.Begin() -> rlgl.End() Block.
// The Raylib implementation start a new block
@(private)
draw_line_in_gl_context :: proc(start, end: shapes.Vector2, thickness: f64, depth: f64 = 0.0) {
	diff := end - start
	length := linalg.length(diff)

	if (length > 0 && thickness > 0) {
		factor := thickness / (2.0 * length)
		norm := polygons.normal(diff) * factor

		rlgl.Vertex3f(cast(f32)(start.x - norm.x), cast(f32)(start.y - norm.y), cast(f32)depth)
		rlgl.Vertex3f(cast(f32)(start.x + norm.x), cast(f32)(start.y + norm.y), cast(f32)depth)
		rlgl.Vertex3f(cast(f32)(end.x + norm.x), cast(f32)(end.y + norm.y), cast(f32)depth)

		rlgl.Vertex3f(cast(f32)(end.x + norm.x), cast(f32)(end.y + norm.y), cast(f32)depth)
		rlgl.Vertex3f(cast(f32)(end.x - norm.x), cast(f32)(end.y - norm.y), cast(f32)depth)
		rlgl.Vertex3f(cast(f32)(start.x - norm.x), cast(f32)(start.y - norm.y), cast(f32)depth)
	}
}


// Draw a line strip defined by a list of points
draw_line_strip :: proc(
	strip: []shapes.Vector2,
	color := rl.RED,
	thickness: f32 = 1.0,
	translation: shapes.Vector2 = {0.0, 0.0},
	rotationAngle: f32 = 0.0,
	scale: f32 = 1.0,
) {

	rlgl.PushMatrix()
	rlgl.Translatef(cast(f32)(translation.x), cast(f32)(translation.y), 0.0)
	rlgl.Rotatef(rotationAngle, 0.0, 0.0, 1.0)
	rlgl.Scalef(scale, scale, scale)

	rlgl.Begin(rlgl.TRIANGLES)
	{
		rlgl.Color4ub(color.x, color.y, color.z, color.w)

		for i in 0 ..< len(strip) - 1 {
			draw_line_in_gl_context(strip[i], strip[i + 1], cast(f64)thickness)
		}
	}
	rlgl.End()
	rlgl.PopMatrix()

}

// Draw a simple curve with thickness, transformed by translation and rotationAngle (around z axis).
// The curve is assumed to be a beziér curve and is drawn until `t_until`
draw_curve :: proc(
	curve: shapes.Segment,
	t_until: f64,
	step_size: f64,
	color: rl.Color = rl.RED,
	translation: shapes.Vector2 = {0.0, 0.0},
	rotationAngle: f32 = 0.0,
	scale: f32 = 1.0,
) {
	t: f64 = 0.0

	rlgl.PushMatrix()
	rlgl.Translatef(cast(f32)translation.x, cast(f32)translation.y, 0.0)
	rlgl.Rotatef(rotationAngle, 0.0, 0.0, 1.0)
	rlgl.Scalef(scale, scale, scale)

	rlgl.Begin(rlgl.TRIANGLES)
	{
		rlgl.Color4ub(color.x, color.y, color.z, color.w)

		if t_until >= 0 {
			old_pos := decas(curve, t)
			t += step_size

			for t < t_until {
				pos := decas(curve, t)
				draw_line_in_gl_context(old_pos, pos, cast(f64)curve.thickness)

				old_pos = pos
				t += step_size
			}

			// draw final segment, since, t < t_until
			pos := decas(curve, t_until)
			draw_line_in_gl_context(old_pos, pos, cast(f64)curve.thickness)
		}
	}
	rlgl.End()
	rlgl.PopMatrix()
}

// Same as draw_curve, but fill its interior using tesselation
fill_curve :: proc(
	curve: shapes.Segment,
	t_until: f64,
	step_size: f64,
	color: rl.Color = rl.RED,
	fill_color: rl.Color = rl.RED,
	translation: shapes.Vector2 = {0.0, 0.0},
	rotationAngle: f32 = 0.0,
	scale: f32 = 1.0,
) {
	curves := [?]shapes.Segment{curve}
	t_untils := [?]f64{t_until}
	fill_curves(
		curves[:],
		t_untils[:],
		step_size,
		color,
		fill_color,
		translation,
		rotationAngle,
		scale,
	)
}

// Fill multiple curves using tesselation
fill_curves :: proc(
	curves: []shapes.Segment,
	t_until: []f64,
	step_size: f64,
	color: rl.Color = rl.RED,
	fill_color: rl.Color = rl.RED,
	translation: shapes.Vector2 = {0.0, 0.0},
	rotationAngle: f32 = 0.0,
	scale: f32 = 1.0,
) {
	points := make([dynamic]shapes.Vector2)
	defer delete(points)

	rlgl.PushMatrix()
	rlgl.Translatef(cast(f32)translation.x, cast(f32)translation.y, 0.0)
	rlgl.Rotatef(rotationAngle, 0.0, 0.0, 1.0)
	rlgl.Scalef(scale, scale, scale)

	rlgl.Begin(rlgl.TRIANGLES)
	{
		rlgl.Color4ub(color.x, color.y, color.z, color.w)

		curves_ts := soa_zip(curve = curves, t_until = t_until)
		for curve in curves_ts {
			if curve.t_until >= 0 {
				t: f64 = 0.0
				old_pos := decas(curve.curve, t)
				_ = append(&points, old_pos)

				t += step_size

				for t < curve.t_until {
					pos := decas(curve.curve, t)
					_ = append(&points, pos)
					t += step_size

					draw_line_in_gl_context(old_pos, pos, cast(f64)curve.curve.thickness, -1.0)

					old_pos = pos
				}

				// draw final segment, since, t < t_until
				pos := decas(curve.curve, curve.t_until)
				_ = append(&points, pos)
				draw_line_in_gl_context(old_pos, pos, cast(f64)curve.curve.thickness, -1.0)
			}
		}

		// hull := convex_hull(points[:])
		// defer delete(hull)

		compressed := polygons.compress_polygon(points[:])
		defer delete(compressed)

		triangles, err := polygons.triangulate(compressed)
		if err == nil {
			defer delete(triangles)

			rlgl.Color4ub(fill_color.x, fill_color.y, fill_color.z, fill_color.w)
			for triangle in triangles {
				v1 := compressed[triangle[0]]
				v2 := compressed[triangle[1]]
				v3 := compressed[triangle[2]]
				rlgl.Vertex3f(cast(f32)v1.x, cast(f32)v1.y, 0.0)
				rlgl.Vertex3f(cast(f32)v2.x, cast(f32)v2.y, 0.0)
				rlgl.Vertex3f(cast(f32)v3.x, cast(f32)v3.y, 0.0)
			}
		}
	}
	rlgl.End()
	rlgl.PopMatrix()
}
