package util

Keyframe :: struct {
	start:    f32,
	end:      f32,
	duration: f32,
	ease_fn:  EaseFunction,
}


Keyframes :: struct {
	current: int,
	keys:    [dynamic]Keyframe,
	time:    f32,
	loop:    bool,
}


clear :: proc(kfs: ^Keyframes) {
	delete(kfs.keys)
	kfs.keys = make([dynamic]Keyframe)
}

init :: proc(loop: bool) -> Keyframes {
	frames := Keyframes{}
	frames.loop = loop
	frames.keys = make([dynamic]Keyframe)

	return frames
}

push :: proc(kfs: ^Keyframes, frame: Keyframe) {
	_ = append(&kfs.keys, frame)
}

destroy :: proc(kfs: ^Keyframes) {
	delete(kfs.keys)
}

@(private)
keyframes_reached_end :: proc(k: ^Keyframes) -> bool {
	return k.current >= len(k.keys)
}

advance :: proc(keyframes: ^Keyframes, dt: f32) {
	keyframes.time += dt

	if keyframes.loop && keyframes_reached_end(keyframes) {
		// restart
		keyframes.current = 0
	}

	for keyframes.current < len(keyframes.keys) &&
	    keyframes.time >= keyframes.keys[keyframes.current].duration {

		keyframes.time -= keyframes.keys[keyframes.current].duration
		keyframes.current += 1
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
