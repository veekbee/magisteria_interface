# magisteria_interface

The Godot client for the **magisteria** Colorado River Basin world simulation. Code, scenes and
build machinery live here. **The design corpus does not.**

## Layout

```
contract/     the vendored artefact and its pin
src/          GDScript — contract loader, UI
scenes/       Godot scenes
assets/       terrain and fixture fetched not committed; families commit normally
tools/        the contract check, and M5 build machinery
tests/        headless GDScript tests, no framework
```

## License

MIT — see `LICENSE`. Permissive by intent: this is a transducer, and the project's interest is in
as many of them existing as possible.

## No addons, of any kind

No third-party terrain plugins — a plugin's asset pipeline fights the ruled export formats. No
test framework either: `godot --headless --script` with hand-rolled asserts covers the loader and
the inspector. Revisit only if the test surface grows enough to justify the version coupling.
