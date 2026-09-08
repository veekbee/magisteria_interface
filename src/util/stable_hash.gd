class_name StableHash
extends RefCounted

## THE MIXER, IN ONE PLACE. Deterministic, portable, and not the engine's.
##
## `String.hash()` and `RandomNumberGenerator` are engine internals free to
## change between versions, and anything seeded on them moves when Godot
## updates. Placement, the detail function and any later position-seeded
## quantity all need the same guarantee and the same answers, so they use this
## and there is exactly one of it.
##
## THIRTY-TWO BITS ON PURPOSE, in a language whose ints are 64-bit signed. Every
## multiplier is under 2^31 and every step masks back, so nothing here depends
## on how a wider int would have overflowed.
##
## THIS FILE IS THE IMPLEMENTATION AND `VegetationScatter` FORWARDS TO IT. The
## placement statics were written there first and are cited by section number
## from three other files; moving the names would have broken those citations
## for no gain, so the names stay where readers already look and the arithmetic
## lives here. The gate checks the two agree rather than trusting the forward.

## Mixing is done in 32 bits with every product masked, because GDScript ints
## are 64-bit and a multiplier over 2^31 would overflow the signed range rather
## than wrap into it. Both multipliers used here are under 2^31 for that
## reason, and the mask is the full 32 bits rather than 31 -- a narrower one
## would be a different mixer and would move every plant.
const MASK := 0xFFFFFFFF
const SPAN := 4294967296.0


## A 32-bit avalanche.
static func mix32(value: int) -> int:
    var x: int = value & MASK
    x = ((x ^ (x >> 16)) * 0x21f0aaad) & MASK
    x = ((x ^ (x >> 15)) * 0x735a2d97) & MASK
    return (x ^ (x >> 15)) & MASK


## One hash over an ordered list of integers. Order matters and is the point:
## `[x, y]` and `[y, x]` are different ground.
static func over(parts: Array) -> int:
    var h: int = 0x9e3779b9
    for p in parts:
        h = mix32(h ^ mix32(int(p)))
    return h


## The same hash over exactly three parts, without the array. Identical output
## to `over([a, b, c])` -- the gate checks that rather than trusting it -- and
## it exists because the array is not free in a loop that runs per instance.
static func of3(a: int, b: int, c: int) -> int:
    var h: int = 0x9e3779b9
    h = mix32(h ^ mix32(a))
    h = mix32(h ^ mix32(b))
    return mix32(h ^ mix32(c))


## The hash read as a fraction of 1, which is the form a rank, a jitter and a
## noise lattice all want.
static func unit(h: int) -> float:
    return float(h & MASK) / SPAN


## FNV-1a over a string's UTF-8 bytes. For keying on a name rather than on a
## position -- small, specified elsewhere, and ours.
static func of_name(name: String) -> int:
    var h: int = 0x811c9dc5
    for b in name.to_utf8_buffer():
        h = ((h ^ int(b)) * 16777619) & MASK
    return h
