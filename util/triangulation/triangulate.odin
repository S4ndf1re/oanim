package triangulation

import "base:runtime"
import "core:container/avl"
import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:mem"
import "core:slice"
import "core:testing"

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

cosine :: proc(a, b: Vector2) -> f32 {
	return linalg.dot(a, b) / (linalg.length(a) * linalg.length(b))
}

normal :: proc(v: Vector2) -> Vector2 {
	result := v.yx
	result.x *= -1
	return result
}

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

point_on_line_t :: proc(line_start, line_end, point: Vector2) -> f32 {
	r := line_end - line_start
	s1 := point.x
	s2 := point.y

	r1 := r.x
	r2 := r.y

	x1_1 := line_start.x
	x1_2 := line_start.y

	t := (1.0 - r1 * s1 + r1 * x1_1 - r2 * s2 + r2 * x1_2) / (-r1 * r1 - r2 * r2)
	return t
}

@(private)
angle_between :: proc(u, v, w: Vector2) -> f32 {
	diff1 := u - v
	diff2 := w - v

	cos := cosine(diff1, diff2)

	return math.acos(cos)
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

triangulate :: proc(
	poly: Polygon,
	allocator: runtime.Allocator = context.allocator,
	temp_allocator: runtime.Allocator = context.temp_allocator,
) -> (
	[]Triangle,
	bool,
) {
	he := he_new_empty(allocator)
	// everything is cw until here
	if !he_init_from_polygon(&he, poly, cw = false, temp_allocator = temp_allocator) {
		return nil, false
	}
	defer he_destroy(&he)

	nodes := he_get_nodes(&he, allocator)
	defer delete(nodes, allocator)
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
	for node in nodes {
		u := node.edge.prev.origin.position
		v := node.position
		w := node.edge.next.origin.position
		i := node.original_idx
		angle := inner_angle_between(u, v, w)
		if less_than(u, v) && less_than(w, v) && angle < math.PI {
			classes[i] = .Start
		} else if less_than(u, v) && less_than(w, v) && angle > math.PI {
			classes[i] = .Split
		} else if less_than(v, u) && less_than(v, w) && angle < math.PI {
			classes[i] = .End
		} else if less_than(v, u) && less_than(v, w) && angle > math.PI {
			classes[i] = .Merge
		} else {
			classes[i] = .Regular
		}
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
			h := helper[e.prev]
			if classes[h.original_idx] == .Merge {
				he_split_face_by_nodes(&he, vi, h)
			}

			avl.remove(&tree, TreeKey{edge = e.prev, current_y = &current_y})
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
			h := helper[e.prev]
			if classes[h.original_idx] == .Merge {
				he_split_face_by_nodes(&he, vi, h)
			}

			avl.remove(&tree, TreeKey{edge = e, current_y = &current_y})

			ej, ok := find_left_of(&tree, vi, current_y)

			if ok {
				h := helper[ej]
				if classes[h.original_idx] == .Merge {
					he_split_face_by_nodes(&he, vi, h)
				}
				helper[ej] = vi
			}
		} else if classes[i] == .Regular {
			if is_inner_right(e.prev.origin, vi) {
				h := helper[e.prev]
				if classes[h.original_idx] == .Merge {
					he_split_face_by_nodes(&he, vi, h)
				}
				avl.remove(&tree, TreeKey{edge = e.prev, current_y = &current_y})

				helper[e.prev] = vi
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
			fmt.printfln("")
			fmt.printfln("")
		}
	}

	// Clone here, so that later changes will not affect anything
	{
		faces := he_get_faces(&he)
		defer delete(faces)
		for face in faces {
			triangulate_y_monotone(&he, face)
		}
	}


	// Collect triangles
	triangles := make([dynamic]Triangle)
	defer delete(triangles)

	fmt.printf("\nPrinting out triangesl\n")
	faces := he_get_faces(&he)
	defer delete(faces)
	for face in faces {
		he_print_face(face)
		fmt.println()
		edges := he_collect_edges_for_face(face)
		assert(len(edges) == 3)
		root := edges[0]
		append(
			&triangles,
			// Make CW triangle
			Triangle {
				root.next.next.origin.original_idx,
				root.next.origin.original_idx,
				root.origin.original_idx,
			},
		)
		delete(edges)
	}

	return slice.clone(triangles[:]), true
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

	stack := make([dynamic]^HeNode, context.temp_allocator)
	defer delete(stack)

	append(&stack, nodes[0])
	append(&stack, nodes[1])

	for i in 2 ..< len(nodes) - 1 {
		top_s := stack[len(stack) - 1]
		n := nodes[i]
		if !(old_next[top_s.original_idx].origin == n) &&
		   !(old_prev[top_s.original_idx].origin == n) {
			// are on different sides of monoton

			last_popped: ^HeNode = nil
			for len(stack) > 1 {
				last_popped = pop(&stack)
				he_split_face_by_nodes(he, n, last_popped)
			}
			append(&stack, last_popped)
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
	triangles, ok := triangulate(triangle[:])
	defer delete(triangles)

	testing.expect(t, ok)
	testing.expect(t, len(triangles) == 1)
}

@(test)
simple_triangulation_quad_test :: proc(t: ^testing.T) {
	triangle := [?]Vector2{{0.0, 0.0}, {1.0, 0}, {0.0, -1.0}, {-1.0, 0.0}}
	triangles, ok := triangulate(triangle[:])
	defer delete(triangles)

	testing.expect(t, ok)
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
	triangles, ok := triangulate(triangle[:])
	defer delete(triangles)

	testing.expect(t, ok)
	testing.expect(t, len(triangles) == 5)
}
