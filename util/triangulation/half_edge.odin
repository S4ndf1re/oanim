package triangulation

import "base:runtime"
import "core:container/rbtree"
import "core:fmt"
import "core:slice"

HeContainer :: struct {
	edges: [dynamic]HeEdge,
	faces: [dynamic]HeFace,
	nodes: [dynamic]HeNode,
}

HeEdge :: struct {
	origin: ^HeNode,
	face:   ^HeFace,
	next:   ^HeEdge,
	prev:   ^HeEdge,
	twin:   ^HeEdge,
}

HeNode :: struct {
	original_idx: int,
	edge:         ^HeEdge,
	position:     Vector2,
}

HeFace :: struct {
	inner: ^HeEdge,
	outer: ^HeEdge,
}

he_empty_push_node :: proc(he: ^HeContainer) -> (^HeNode, int) {
	idx := len(he.nodes)
	_ = append(&he.nodes, HeNode{})
	node := &he.nodes[idx]
	return node, idx
}

he_empty_push_face :: proc(he: ^HeContainer) -> (^HeFace, int) {
	idx := len(he.faces)
	_ = append(&he.faces, HeFace{})
	face := &he.faces[idx]
	return face, idx
}

he_empty_push_edge :: proc(he: ^HeContainer) -> (^HeEdge, int) {
	idx := len(he.edges)
	_ = append(&he.edges, HeEdge{})
	edge := &he.edges[idx]
	return edge, idx
}

he_new_empty :: proc(allocator: runtime.Allocator = context.allocator) -> HeContainer {
	return HeContainer {
		edges = make([dynamic]HeEdge, allocator),
		faces = make([dynamic]HeFace, allocator),
		nodes = make([dynamic]HeNode, allocator),
	}
}

he_init_from_cw_ring :: proc(
	he: ^HeContainer,
	outline: Polygon,
	temp_alloc: runtime.Allocator = context.temp_allocator,
) -> bool {
	// in order to create a face, you need at least 3 verticies
	if len(outline) <= 2 {
		return false
	}

	face, face_idx := he_empty_push_face(he)
	first_node, first_node_idx := he_empty_push_node(he)
	first_node.position = outline[0]
	first_node.original_idx = 0

	created_edges := make([dynamic]^HeEdge, 0, len(outline), temp_alloc)
	defer delete(created_edges)

	last_node := first_node
	for i in 1 ..< len(outline) {
		current_node, _ := he_empty_push_node(he)
		current_node.position = outline[i]
		current_node.original_idx = i

		edge, _ := he_empty_push_edge(he)
		edge.origin = last_node
		edge.face = face
		last_node.edge = edge
		// Fill twin, next and prev finally
		append(&created_edges, edge)

		last_node = current_node
	}
	// Push edge between first and last
	edge, _ := he_empty_push_edge(he)
	edge.origin = last_node
	edge.face = face
	last_node.edge = edge
	// Fill twin, next and prev finally
	append(&created_edges, edge)

	created_twin_edges := make([dynamic]^HeEdge, 0, len(created_edges), temp_alloc)
	defer delete(created_twin_edges)

	// connect next and previous of inner circle and create outer twin edges
	for i in 0 ..< len(created_edges) {
		a := created_edges[i]
		b := created_edges[(i + 1) % len(created_edges)]
		face.inner = a

		a.next = b
		b.prev = a

		twin_edge, _ := he_empty_push_edge(he)
		twin_edge.origin = b.origin
		twin_edge.twin = a
		twin_edge.face = nil
		face.outer = twin_edge
		append(&created_twin_edges, twin_edge)

		a.twin = twin_edge
	}

	// connect twin edges
	for i in 0 ..< len(created_twin_edges) {
		a := created_twin_edges[i]
		b := created_twin_edges[(i + 1) % len(created_twin_edges)]

		a.next = b
		b.prev = a
	}

	return true
}

he_query_all_outgoing_edges :: proc(node: ^HeNode) -> []^HeEdge {
	nodes := make([dynamic]^HeEdge, context.temp_allocator)
	defer delete(nodes)

	start_edge := node.edge
	append(&nodes, start_edge)

	current_edge := start_edge
	for {
		if current_edge == nil {
			break
		}

		current_edge = current_edge.twin.next
		if current_edge == start_edge {
			break
		}
		append(&nodes, current_edge)
	}

	return slice.clone(nodes[:])
}

he_query_outgoing_edge_for_face :: proc(node: ^HeNode, face: ^HeFace) -> (^HeEdge, bool) {
	outgoing_edges := he_query_all_outgoing_edges(node)
	defer delete(outgoing_edges)

	for edge in outgoing_edges {
		if edge.face == face {
			return edge, true
		}
	}

	return nil, false
}

he_query_all_faces_for_node :: proc(node: ^HeNode) -> map[^HeFace]bool {
	outgoing_edges := he_query_all_outgoing_edges(node)
	defer delete(outgoing_edges)

	set := make(map[^HeFace]bool)

	for edge in outgoing_edges {
		if edge.face != nil {
			set[edge.face] = true
		}
	}

	return set
}

he_match_face_for_node :: proc(a, b: ^HeNode) -> (^HeFace, bool) {
	a_faces := he_query_all_faces_for_node(a)
	b_faces := he_query_all_faces_for_node(b)
	defer delete(a_faces)
	defer delete(b_faces)


	for k, v in a_faces {
		if k in b_faces {
			// return face that matches both
			return k, true
		}
	}

	return nil, false
}

he_split_face_by_nodes :: proc(he: ^HeContainer, start: ^HeNode, end: ^HeNode) {
	common_face, ok := he_match_face_for_node(start, end)
	if !ok {
		return
	}
	fmt.printfln("Common Face:")
	he_print_face(common_face, 10)

	new_edge, _ := he_empty_push_edge(he)
	new_twin, _ := he_empty_push_edge(he)

	new_edge.twin = new_twin
	new_twin.twin = new_edge
	new_edge.origin = start
	new_twin.origin = end

	// Get previous edges
	end_edge, end_found := he_query_outgoing_edge_for_face(end, common_face)
	if !end_found {return}
	end_prev := end_edge.prev

	start_edge, start_found := he_query_outgoing_edge_for_face(start, common_face)
	if !start_found {return}
	start_prev := start_edge.prev

	start.edge = new_edge
	end.edge = new_twin

	// Reconnect edges
	start_prev.next = new_edge
	new_edge.prev = start_prev
	new_edge.next = end_edge
	end_edge.prev = new_edge

	end_prev.next = new_twin
	new_twin.prev = end_prev
	new_twin.next = start_edge
	start_edge.prev = new_twin

	new_face, _ := he_empty_push_face(he)
	old_face := end_prev.face

	current_edge := end_prev
	for {
		current_edge.face = old_face
		current_edge.face.inner = current_edge
		current_edge.face.outer = current_edge.twin

		current_edge = current_edge.next
		if current_edge == end_prev {
			break
		}
	}

	current_edge = start_prev
	for {
		current_edge.face = new_face
		current_edge.face.inner = current_edge
		current_edge.face.outer = current_edge.twin

		current_edge = current_edge.next
		if current_edge == start_prev {
			break
		}
	}
}

he_get_nodes :: proc(
	he: ^HeContainer,
	allocator: runtime.Allocator = context.allocator,
) -> []^HeNode {
	nodes_len := len(he.nodes)
	nodes := make([]^HeNode, nodes_len)
	for i in 0 ..< nodes_len {
		nodes[i] = &he.nodes[i]
	}
	return nodes
}

he_get_faces :: proc(
	he: ^HeContainer,
	allocator: runtime.Allocator = context.allocator,
) -> []^HeFace {
	faces_len := len(he.faces)
	faces := make([]^HeFace, faces_len, allocator)
	for i in 0 ..< faces_len {
		faces[i] = &he.faces[i]
	}
	return faces
}

he_collect_edges_for_face :: proc(face: ^HeFace) -> []^HeEdge {
	edges := make([dynamic]^HeEdge, context.temp_allocator)
	defer delete(edges)

	start := face.inner
	append(&edges, start)

	// loop in a circle
	current := start
	for {
		current = current.next
		if current == start {
			break
		}

		append(&edges, current)
	}


	return slice.clone(edges[:])
}

he_print_face :: proc(face: ^HeFace, idx: int = 0) {
	edges := he_collect_edges_for_face(face)
	defer delete(edges)

	fmt.printf("Face %d: ", idx)
	for edge in edges {
		fmt.printf("%d->", edge.origin.original_idx)
	}
	fmt.printf("\n")
}

he_print :: proc(he: ^HeContainer) {
	faces := he_get_faces(he)
	defer delete(faces)

	for face, i in faces {
		he_print_face(face, i)
	}
}

he_destroy :: proc(he: ^HeContainer) {
	delete(he.edges)
	delete(he.faces)
	delete(he.nodes)
}
