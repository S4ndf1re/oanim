# OAnim

Manim for the brave and true(poor)

This is a hobby project. This means this will never be ready for any serious work.
Use the real [manim](https://www.manim.community/) in that case.

## Goals

- Having fun. This is inspired by tsodings recreational programming sessions
  and `panim`, though everything was created and thought of by means
  (except the plugin system, i just liked the idea that tsoding introduced).
- Learning Odin. Normally, I mostly use Rust for hobby and university projects.
  This time however, I wanted to try something new. Writing a minimal c compiler
  was my first option for a hobby project, however i really had no fun while
  writing the recursive descent parser (I know, I could have used some
  parser generator, but for some reason i wanted to experience the full thing),
  hence I switched to writing OAnim.

## Current state

I mean, see for yourself. Literally nothing works :D. Except drawing and filling
beziér curves and rectangles. A simple Keyframe system is implemented as well.
A single Plugin is loaded. This is simply a test plugin, and I plan to add more
plugins, once the default library is loaded.

- [x] Tessellation of non hole polygons
- [x] Rendering of beziér curves, both filled and outlined
- [x] Rendering of basic shapes (Connected beziér curves) (Circle + Rectangle),
      both filled and outlined

## Planned

Ok ok. I have to admit. I really love the idea of adding scripting support.
I mean the plugin support is already a good fit for this kind of tool,
however I really really like embedded scripting capabilities. And you might
have already guessed it: `umka` is my target (oh no, another tsoding reference
that he also included into `panim`). I know, a real copycat here. However,
I kind of like the concept of statically typed embeddable scripting languages,
and so far, `umka` as a concept really impressed me. Hence, this might be a good
learning experience. Maybe, I will return to my original project of compiling C
(or another language).

- [ ] Function Rendering
- [ ] Text rendering
- [ ] Tessellation of hole polygons
- [ ] Sprites
- [ ] Render To Video
