class_name CameraRig
extends Node3D

## Two cameras over one basin: free-fly and top-down orthographic. M1.
##
## The ortho camera is not a convenience -- it is the one that makes a
## heightfield legible as a map, and it is how a hillshade gets read against
## known geography. The free-fly camera is how relief gets read at all.
##
## Both are framed from the mesh's own AABB rather than from constants, so a
## different stride or a different basin still starts with the terrain on
## screen. A hardcoded camera position is the first thing that breaks when the
## data changes and the last thing anyone suspects.

@export var move_speed_m: float = 40000.0
@export var fast_multiplier: float = 6.0

var fly: Camera3D
var ortho: Camera3D
var _using_ortho := true
var _extent := Vector3.ONE


func setup(aabb: AABB) -> void:
    _extent = aabb.size
    var span: float = max(_extent.x, _extent.z)

    ortho = Camera3D.new()
    ortho.projection = Camera3D.PROJECTION_ORTHOGONAL
    ortho.size = span * 1.05
    ortho.far = span * 4.0
    ortho.position = Vector3(aabb.get_center().x, aabb.end.y + span, aabb.get_center().z)
    ortho.rotation_degrees = Vector3(-90, 0, 0)   # north up
    add_child(ortho)

    fly = Camera3D.new()
    fly.projection = Camera3D.PROJECTION_PERSPECTIVE
    fly.far = span * 4.0
    fly.near = 10.0
    fly.position = Vector3(aabb.get_center().x, aabb.end.y + span * 0.35,
                           aabb.end.z + span * 0.45)
    fly.look_at_from_position(fly.position, aabb.get_center(), Vector3.UP)
    add_child(fly)

    _apply()


func toggle() -> void:
    _using_ortho = not _using_ortho
    _apply()


func using_ortho() -> bool:
    return _using_ortho


func _apply() -> void:
    if ortho:
        ortho.current = _using_ortho
    if fly:
        fly.current = not _using_ortho


func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_TAB:
            toggle()


func _process(delta: float) -> void:
    var cam := ortho if _using_ortho else fly
    if cam == null:
        return
    var dir := Vector3.ZERO
    if Input.is_key_pressed(KEY_W): dir -= cam.global_transform.basis.z
    if Input.is_key_pressed(KEY_S): dir += cam.global_transform.basis.z
    if Input.is_key_pressed(KEY_A): dir -= cam.global_transform.basis.x
    if Input.is_key_pressed(KEY_D): dir += cam.global_transform.basis.x
    if dir == Vector3.ZERO:
        return
    var speed := move_speed_m * (fast_multiplier if Input.is_key_pressed(KEY_SHIFT) else 1.0)
    cam.position += dir.normalized() * speed * delta
