package lib

// Keyframe represents a fixed time duration that is mapped to a parameter.
// The parameter starts at `start` and ends at `end`. The transition takes `duration` seconds.
// The transition from start to end can be eased using the ease_fn
Keyframe :: struct {
	start:    f32,
	end:      f32,
	duration: f32,
	ease_fn:  EaseFunction,
}


// A list of multiple keyframes. Can be thought of as a player that plays a sequence of keyframes for the same parameter
Keyframes :: struct {
	current: int,
	keys:    [dynamic]Keyframe,
	time:    f32,
	loop:    bool,
}


// Clear all keyframes
clear :: proc(kfs: ^Keyframes) {
	delete(kfs.keys)
	kfs.keys = make([dynamic]Keyframe)
}

// Initialize a new keyframe
init :: proc(loop: bool) -> Keyframes {
	frames := Keyframes{}
	frames.loop = loop
	frames.keys = make([dynamic]Keyframe)

	return frames
}

// Push a keyframe onto the keyframe player
push :: proc(kfs: ^Keyframes, frame: Keyframe) {
	_ = append(&kfs.keys, frame)
}

// Delete the keyframes
destroy :: proc(kfs: ^Keyframes) {
	delete(kfs.keys)
}

@(private)
keyframes_reached_end :: proc(k: ^Keyframes) -> bool {
	return k.current >= len(k.keys)
}

advance :: proc(dt: f32, keyframes: ..^Keyframes) {
	for key in keyframes {
		key.time += dt

		if key.loop && keyframes_reached_end(key) {
			// restart
			key.current = 0
		}

		for key.current < len(key.keys) && key.time >= key.keys[key.current].duration {

			key.time -= key.keys[key.current].duration
			key.current += 1
		}
	}
}

get_value :: proc(k: ^Keyframes) -> f32 {
	if keyframes_reached_end(k) {
		return k.keys[len(k.keys) - 1].end
	}

	current_key := k.keys[k.current]

	t := k.time / k.keys[k.current].duration
	if current_key.ease_fn != nil {
		t = current_key.ease_fn(t)
	}
	return lerp(current_key.start, current_key.end, t)
}

lerp :: proc(start, end, t: f32) -> f32 {
	diff := end - start

	return t * diff + start
}
