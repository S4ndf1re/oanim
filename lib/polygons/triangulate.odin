package polygons

import "base:runtime"
import "core:container/avl"
import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:slice"
import "core:testing"

TriangulationFailureReason :: union {
	enum {
		LessThanThreeVertices,
		HalfEdgeInitializationFailed,
		NoStartOrEnd,
	},
}

@(private)
TreeKey :: struct {
	edge:      ^HeEdge,
	current_y: ^f32,
}

@(private)
tree_cmp_fn :: proc(a, b: TreeKey) -> avl.Ordering {
	a_x := edge_get_x_for_y(a.edge, a.current_y^)
	b_x := edge_get_x_for_y(b.edge, b.current_y^)

	if a_x < b_x {
		return .Less
	}
	if a_x > b_x {
		return .Greater
	}
	return .Equal
}

@(private)
edge_get_x_for_y :: proc(edge: ^HeEdge, y: f32) -> f32 {
	// e.y := a.y * (1-t) + b.y * t
	// e.y := t * -a.y + a.y + b.y * t
	// e.y := a.y + t * (b.y - a.y)
	// e.y - a.y = t * (b.y - a.y)
	// (e.y - a.y) / (b.y - a.y) = t
	a := edge.origin.position
	b := edge.next.origin.position

	t := (y - a.y) / (b.y - a.y)

	return a.x * (1.0 - t) + b.x * t
}


@(private)
MonotoneType :: enum {
	Start,
	End,
	Regular,
	Split,
	Merge,
}

Triangle :: [3]int

ClassifiedNode :: struct {
	type: MonotoneType,
	node: ^HeNode,
}


@(private)
less_than :: proc(u, v: Vector2) -> bool {
	return u.y < v.y || (u.y == v.y && u.x > v.x)
}

// Check, if the inner side of the polygon is on the right side or left side of v
@(private)
is_inner_right :: proc(prev, node: ^HeNode) -> bool {
	return !less_than(prev.position, node.position)
}

@(private)
inner_angle_between :: proc(u, v, w: Vector2) -> f32 {
	angle := angle_between(u, v, w)

	if is_right_turn(u, v, w) {
		angle = 2.0 * math.PI - angle
	}

	return angle
}

// Find the edge left of target. Left means, n.x < target.x
@(private)
find_left_of :: proc(
	tree: ^avl.Tree(TreeKey),
	target: ^HeNode,
	current_y: f32,
) -> (
	^HeEdge,
	bool,
) {
	iter := avl.iterator(tree, .Forward)
	last_edge: ^HeEdge = nil
	for {
		val, ok := avl.iterator_next(&iter)
		if !ok {
			break
		}
		if val.value.edge.origin == target && last_edge != nil {
			return last_edge, true
		}
		last_edge = val.value.edge
	}

	if last_edge != nil {
		x := edge_get_x_for_y(last_edge, current_y)
		if x < target.position.x {
			return last_edge, true
		}
	}

	return nil, false
}

// Test if the polygon is in CW or CCW order
is_clockwise :: proc(poly: Polygon) -> bool {
	sum: f32 = 0.0

	poly_len := len(poly)
	for i in 0 ..< poly_len {
		v1 := poly[i]
		v2 := poly[(i + 1) % poly_len]

		sum += (v2.x - v1.x) * (v2.y + v1.y)
	}

	return sum >= 0
}

// Make sure, that the order of the polygon is in ccw
ensure_cw :: proc(poly: Polygon) {
	if is_clockwise(poly) {
		return
	}

	slice.reverse(poly)
}

// Comporess the polygon by removing `straight lines` (defined by the dist_from_line threshold)
// and `point to point` distance (dist_to_point threshold)
compress_polygon :: proc(
	polygon: Polygon,
	dist_from_line: f32 = 0.001,
	dist_to_point: f32 = 0.001,
) -> Polygon {
	if len(polygon) < 3 {
		return slice.clone(polygon)
	}

	new_poly := make([dynamic]Vector2, context.temp_allocator)
	defer delete(new_poly)
	append(&new_poly, polygon[0])
	append(&new_poly, polygon[1])

	for i in 2 ..< len(polygon) {
		current := polygon[i]
		for len(new_poly) >= 2 {
			if linalg.length(new_poly[len(new_poly) - 1] - current) < dist_to_point {
				pop(&new_poly)
			} else if distance_from_line(
				   new_poly[len(new_poly) - 2],
				   new_poly[len(new_poly) - 1],
				   current,
			   ) <
			   dist_from_line {
				pop(&new_poly)
			} else {
				break
			}
		}
		append(&new_poly, current)
	}

	return slice.clone(new_poly[:])
}

// Triangulate the polygon by first creating a half edge datastructure.
// Then, Split the Polygon (one Face) into multiple y monotone faces.
// Each Face is further split down to CW Trianges using a simple y monotone tesselation
// The resulting trianges are returned. Each Triangle consists of the indices into the original polygon
// ## NOTE
// It is advised to compress the polygon first, because straight lines WILL cause problems, and because the function
// will return indizes into the original polygon, this function WILL NOT compress the polygon itself
//
// ## Example
// ```odin
// poly := [?]Vector2{{0.0, 0.0}, {0.5, 1.0}, {1.0, 0.0}}
// compressed := compress(poly[:])
// defer delete(compressed)
//
// trianges, err := triangulate(compresses)
// if err != nil {
//   fmt.println(err)
// } else {
// 	 fmt.println(trianges)
// }
// ```
triangulate :: proc(
	poly: Polygon,
	allocator: runtime.Allocator = context.allocator,
	temp_allocator: runtime.Allocator = context.temp_allocator,
) -> (
	[]Triangle,
	TriangulationFailureReason,
) {
	if len(poly) < 3 {
		return nil, .LessThanThreeVertices
	}
	he := HeContainer{}
	he_init_empty(&he, allocator)
	// everything is cw until here
	if !he_init_from_polygon(
		&he,
		poly,
		cw = !is_clockwise(poly), // Invert, because we want to flip the winding order so that is always ccw
		temp_allocator = temp_allocator,
	) {
		return nil, .HalfEdgeInitializationFailed
	}
	defer he_destroy(&he)

	nodes := he_get_nodes(&he)
	defer delete(nodes)
	slice.sort_by(
		nodes,
		proc(a, b: ^HeNode) -> bool {
			// Sort inverse order, starting at the top
			return !less_than(a.position, b.position)
		},
	)

	classes := make([]MonotoneType, len(nodes), temp_allocator)
	slice.fill(classes, MonotoneType.Regular)
	defer delete(classes, temp_allocator)

	helper := make(map[^HeEdge]^HeNode, len(nodes), temp_allocator)
	defer delete(helper)

	// First, classify all nodes
	has_start := false
	has_end := false
	for node in nodes {
		u := node.edge.prev.origin.position
		v := node.position
		w := node.edge.next.origin.position
		i := node.original_idx
		angle := inner_angle_between(u, v, w)
		if less_than(u, v) && less_than(w, v) && angle < math.PI {
			classes[i] = .Start
			has_start = true
		} else if less_than(u, v) && less_than(w, v) && angle > math.PI {
			classes[i] = .Split
		} else if less_than(v, u) && less_than(v, w) && angle < math.PI {
			classes[i] = .End
			has_end = true
		} else if less_than(v, u) && less_than(v, w) && angle > math.PI {
			classes[i] = .Merge
		} else {
			classes[i] = .Regular
		}
	}

	if !has_end || !has_start {
		// Likely is a line
		return nil, .NoStartOrEnd
	}

	edges := make([]^HeEdge, len(nodes))
	defer delete(edges)
	for n, i in nodes {
		edges[i] = n.edge
	}

	tree := avl.Tree(TreeKey){}
	avl.init(&tree, tree_cmp_fn)
	defer avl.destroy(&tree)
	current_y: f32 = 0.0

	for e in edges {
		vi := e.origin
		i := vi.original_idx
		current_y = vi.position.y

		if classes[i] == .Start {
			helper[e] = vi
			avl.find_or_insert(&tree, TreeKey{edge = e, current_y = &current_y})
		} else if classes[i] == .End {
			h := helper[e.original_prev]
			if classes[h.original_idx] == .Merge {
				he_split_face_by_nodes(&he, vi, h)
			}

			avl.remove(&tree, TreeKey{edge = e.original_prev, current_y = &current_y})
		} else if classes[i] == .Split {
			ej, ok := find_left_of(&tree, vi, current_y)

			if ok {
				h := helper[ej]
				he_split_face_by_nodes(&he, vi, h)
				helper[ej] = vi
			}

			avl.find_or_insert(&tree, TreeKey{edge = e, current_y = &current_y})
			helper[e] = vi
		} else if classes[i] == .Merge {
			h := helper[e.original_prev]
			if classes[h.original_idx] == .Merge {
				he_split_face_by_nodes(&he, vi, h)
			}

			avl.remove(&tree, TreeKey{edge = e.original_prev, current_y = &current_y})

			ej, ok := find_left_of(&tree, vi, current_y)

			if ok {
				h := helper[ej]
				if classes[h.original_idx] == .Merge {
					he_split_face_by_nodes(&he, vi, h)
				}
				helper[ej] = vi
			}
		} else if classes[i] == .Regular {
			if is_inner_right(e.original_prev.origin, vi) {
				h := helper[e.original_prev]
				if classes[h.original_idx] == .Merge {
					he_split_face_by_nodes(&he, vi, h)
				}
				avl.remove(&tree, TreeKey{edge = e.original_prev, current_y = &current_y})

				helper[e] = vi
				avl.find_or_insert(&tree, TreeKey{edge = e, current_y = &current_y})
			} else {
				ej, ok := find_left_of(&tree, vi, current_y)

				if ok {
					h := helper[ej]
					if classes[h.original_idx] == .Merge {
						he_split_face_by_nodes(&he, vi, h)
					}
					helper[ej] = vi
				}
			}
		}
	}

	// Clone here, so that later changes will not affect anything
	{
		faces := he_get_faces(&he)
		defer delete(faces)
		for face, i in faces {
			triangulate_y_monotone(&he, face)
		}
	}

	// Collect triangles
	triangles := make([dynamic]Triangle)
	defer delete(triangles)

	faces := he_get_faces(&he)
	defer delete(faces)
	for face in faces {
		edges := he_collect_edges_for_face(face)
		defer delete(edges)
		assert(len(edges) == 3)
		root := edges[0]

		triangle := Triangle {
			root.prev.origin.original_idx,
			root.next.origin.original_idx,
			root.origin.original_idx,
		}

		append(
			&triangles,
			// Make CW triangle
			triangle,
		)
	}

	return slice.clone(triangles[:]), nil
}

@(private)
is_reflex_vertex :: proc(prev, node, next: ^HeNode, is_left: bool = false) -> bool {
	angle := inner_angle_between(prev.position, node.position, next.position)
	return is_left && angle > math.PI || angle < math.PI
}

@(private)
triangulate_y_monotone :: proc(he: ^HeContainer, face: ^HeFace) {
	edges := he_collect_edges_for_face(face)
	defer delete(edges)

	nodes := make([]^HeNode, len(edges))
	old_prev := make(map[int]^HeEdge)
	old_edge := make(map[int]^HeEdge)
	old_next := make(map[int]^HeEdge)
	defer {
		delete(old_prev)
		delete(old_next)
		delete(old_edge)
		delete(nodes)
	}
	for edge, i in edges {
		idx := edge.origin.original_idx
		nodes[i] = edge.origin
		old_prev[idx] = edge.prev
		old_next[idx] = edge.next
		old_edge[idx] = edge
	}

	slice.sort_by(nodes, proc(a, b: ^HeNode) -> bool {
		return !less_than(a.position, b.position)
	})

	stack := make([dynamic]^HeNode, 0, len(nodes), context.temp_allocator)
	defer delete(stack)

	append(&stack, nodes[0])
	append(&stack, nodes[1])

	for i in 2 ..< len(nodes) - 1 {
		top_s := stack[len(stack) - 1]
		n := nodes[i]
		if !(old_next[top_s.original_idx].origin == n) &&
		   !(old_prev[top_s.original_idx].origin == n) {
			// are on different sides of monoton

			// Empty stack
			for len(stack) > 0 {
				popped := pop(&stack)
				// connect all except the last one
				if len(stack) > 0 {
					he_split_face_by_nodes(he, n, popped)
				}
			}

			append(&stack, top_s)
			append(&stack, n)
		} else {
			last_popped := pop(&stack)
			for len(stack) > 0 {
				is_left := old_next[top_s.original_idx].origin == n
				if !is_reflex_vertex(stack[len(stack) - 1], last_popped, n, is_left) {
					he_split_face_by_nodes(he, n, stack[len(stack) - 1])
					last_popped = pop(&stack)
				} else {
					break
				}
			}

			append(&stack, last_popped)
			append(&stack, n)
		}
	}

	// connect all to last
	for i := len(stack) - 2; i >= 1; i -= 1 {
		he_split_face_by_nodes(he, nodes[len(nodes) - 1], stack[i])
	}
}


@(test)
simple_triangulation_test :: proc(t: ^testing.T) {
	triangle := [?]Vector2{{0.0, 0.0}, {0.5, -1.0}, {1.0, 0.0}}
	triangles, err := triangulate(triangle[:])
	defer delete(triangles)

	testing.expect(t, err == nil)
	testing.expect(t, len(triangles) == 1)
}

@(test)
simple_triangulation_empty_test :: proc(t: ^testing.T) {
	triangle := [?]Vector2{}
	triangles, err := triangulate(triangle[:])
	defer delete(triangles)

	testing.expect(t, err != nil)
	testing.expect(t, triangles == nil)
}

@(test)
simple_triangulation_on_line_test :: proc(t: ^testing.T) {
	triangle := [?]Vector2{{0.0, 0.0}, {1.0, 0.0}, {2.0, 0.0}, {3.0, 0.0}}
	compressed := compress_polygon(triangle[:])
	defer delete(compressed)

	triangles, err := triangulate(compressed)
	defer delete(triangles)

	testing.expect(t, err != nil)
}

@(test)
simple_triangulation_quad_test :: proc(t: ^testing.T) {
	triangle := [?]Vector2{{0.0, 0.0}, {1.0, 0}, {0.0, -1.0}, {-1.0, 0.0}}
	triangles, err := triangulate(triangle[:])
	defer delete(triangles)

	testing.expect(t, err == nil)
	testing.expect(t, len(triangles) == 2)
}

@(test)
simple_triangulation_complex_test :: proc(t: ^testing.T) {
	triangle := [?]Vector2 {
		{0.0, 0.0},
		{0.5, -1.0},
		{1.0, 0.0},
		{1.5, -1.5},
		{1.0, -3.0},
		{0.5, -2.0},
		{0.0, -3.0},
	}
	triangles, err := triangulate(triangle[:])
	defer delete(triangles)

	testing.expect(t, err == nil)
	testing.expect(t, len(triangles) == 5)
}

@(test)
simple_triangulation_extracted_test :: proc(t: ^testing.T) {
	triangle := [?]Vector2 {
		{100.0, 100.0},
		{102.019997, 103.960007},
		{104.08, 107.839996},
		{105.973778, 111.273544},
	}
	triangles, err := triangulate(triangle[:])
	defer delete(triangles)

	testing.expect(t, err == nil)
	fmt.println(triangles)
}


@(test)
simple_triangulation_extracted_long_line_test :: proc(t: ^testing.T) {
	triangle := [?]Vector2 {
		{-50.0, -50.0},
		{-49.0, -50.0},
		{-48.0, -50.0},
		{-47.0, -50.0},
		{-46.0, -50.0},
		{-45.0, -50.0},
		{-44.0, -50.0},
		{-43.0, -50.0},
		{-42.0, -50.0},
		{-41.0, -50.0},
		{-40.0, -50.0},
		{-39.0, -50.0},
		{-38.0, -50.0},
		{-37.0, -50.0},
		{-36.0, -50.0},
		{-35.0, -50.0},
		{-34.0, -50.0},
		{-33.0, -50.0},
		{-32.0, -50.0},
		{-31.0, -50.0},
		{-29.999996, -49.999996},
		{-29.118324, -50},
	}
	compressed := compress_polygon(triangle[:])
	defer delete(compressed)

	triangles, err := triangulate(compressed)
	defer delete(triangles)

	testing.expect(t, err != nil)
}

@(test)
simple_triangulation_extracted_long2_test :: proc(t: ^testing.T) {
	triangle := [?]Vector2 {
		{100, 100},
		{102.019997, 103.960007},
		{104.08, 107.839996},
		{106.18, 111.639999},
		{108.31999, 115.36},
		{110.5, 119},
		{112.72, 122.559998},
		{114.98, 126.04},
		{117.279999, 129.44},
		{119.619995, 132.76001},
		{122, 136},
		{124.419998, 139.16},
		{126.87999, 142.23999},
		{129.37999, 145.23999},
		{131.919998, 148.16},
		{134.5, 151},
		{137.12, 153.76001},
		{139.779999, 156.44},
		{142.48001, 159.03999},
		{145.22, 161.56},
		{148, 164},
		{150.82, 166.36},
		{153.680008, 168.639999},
		{156.58002, 170.84001},
		{159.52002, 172.96002},
		{162.50002, 175},
		{165.52, 176.96},
		{168.58, 178.84001},
		{171.67999, 180.64001},
		{174.82, 182.36002},
		{178, 184},
		{181.22, 185.56},
		{184.48, 187.040009},
		{187.779999, 188.440018},
		{191.12, 189.76001},
		{194.5, 191},
		{197.91998, 192.16},
		{201.37997, 193.24},
		{204.87997, 194.23999},
		{208.41998, 195.16},
		{211.999969, 196},
		{215.61996, 196.75999},
		{219.279968, 197.44},
		{222.97995, 198.03999},
		{226.71996, 198.56},
		{230.499969, 199},
		{234.31995, 199.36002},
		{238.17993, 199.64001},
		{242.07993, 199.84001},
		{246.019928, 199.96},
		{249.99992, 200.00003},
		{252.13481, 199.988678},
	}
	compressed := compress_polygon(triangle[:])
	defer delete(compressed)

	triangles, err := triangulate(compressed)
	defer delete(triangles)

	testing.expect(t, err == nil)
}

@(test)
simple_triangulation_cube_test :: proc(t: ^testing.T) {
	triangle := [?]Vector2 {
		{-50.0, -50.0},
		{50.0, -50.0},
		{50.0, 50.0},
		{-50.0, 50.0},
		{-50.0, -3.366661},
	}
	compressed := compress_polygon(triangle[:])
	defer delete(compressed)

	triangles, err := triangulate(compressed)
	defer delete(triangles)

	testing.expect(t, err == nil)
}
