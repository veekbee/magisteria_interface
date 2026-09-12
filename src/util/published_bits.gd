class_name PublishedBits
extends RefCounted

## A float64 out of the IEEE-754 pattern an artefact publishes it as.
##
## WHY AN ARTEFACT PUBLISHES BITS AT ALL. Godot's decimal-to-double conversion
## is not correctly rounded, and the error is not a uniform ulp. Measured in
## 4.7.2: a plain decimal is exact through seventeen digits after the point and
## degrades from the eighteenth, reaching 35% by 1e-17; and EVERY subnormal
## decimal parses to exactly zero -- `1e-310` as readily as `5e-324` -- in the
## source lexer and the JSON parser alike. So a number whose exact value is
## load-bearing cannot be written down in this language, and the emitting side
## publishes the pattern instead: decision 985's `origin_hex` for the lattice
## corner, and `min_nonzero_bits` beside every declared minimum.
##
## THE DECIMAL IS NOT A FALLBACK, AND THAT IS THE WHOLE POINT OF THIS FILE.
## Reading the decimal when the bits are absent is the behaviour that makes the
## bits pointless: it is exactly the case where the value is small, which is
## exactly the case where the decimal is wrong, and the wrong answer arrives
## looking like a number rather than like an absence. `of` returns NAN when it
## has no bits to read, and the caller decides what to do about a field it
## cannot have. Measured against the fixture in hand: `node.streamflow`'s
## published `min_nonzero_magnitude` is `5e-324` and reads back as 0.0 -- a
## field whose name is a minimum NON-ZERO magnitude, arriving as zero.

## Where the bits live, given the name of the decimal beside them. A convention
## rather than a guess: the emitting side names the pair this way, and a reader
## that took the sibling's name from somewhere else would silently stop finding
## it the day either name moved.
const BITS_SUFFIX := "_bits"


## The float64 a 16-hex-digit pattern denotes. NAN for anything that is not one.
##
## STRICT ABOUT THE WIDTH, because a short pattern is the interesting failure:
## `"0x1"` left-padded is the bottom denormal and `"0x1"` truncated from a
## longer string is whatever survived the truncation, and nothing downstream
## can tell those apart. So a pattern that is not exactly sixteen digits after
## an optional `0x` is refused rather than padded.
static func of_hex(hex: String) -> float:
    var t := hex.strip_edges().to_lower()
    if t.begins_with("0x"):
        t = t.substr(2)
    if t.length() != 16:
        return NAN
    for i in 16:
        if not ("0123456789abcdef".contains(t[i])):
            return NAN
    var b := PackedByteArray()
    b.resize(8)
    b.encode_u32(0, t.substr(8, 8).hex_to_int())
    b.encode_u32(4, t.substr(0, 8).hex_to_int())
    return b.decode_double(0)


## The bits of a float64, for a message that has to show WHICH value it means.
##
## Every message in this repo that prints a number under discussion here prints
## this instead of the number: two decimals that print identically and differ in
## the last place is the shape decision 985 spent three re-vendors on, and a
## comparison whose failure message cannot show the difference is a comparison
## somebody turns off.
static func to_hex(v: float) -> String:
    var b := PackedByteArray()
    b.resize(8)
    b.encode_double(0, v)
    return "0x%08x%08x" % [b.decode_u32(4), b.decode_u32(0)]


## A published scalar out of `block`, read from `<name>_bits` and NEVER from
## `<name>`. NAN when the bits are absent or malformed.
##
## The decimal is not consulted even to cross-check, because a cross-check that
## passes on every ordinary value and fails only on the values the bits exist
## for is a check that fires only when it is wrong to fire.
static func of(block: Dictionary, name: String) -> float:
    var key := name + BITS_SUFFIX
    if not block.has(key):
        return NAN
    return of_hex(str(block[key]))


## Why a `NAN` from `of` happened, for a caller that has to report it.
static func why_absent(block: Dictionary, name: String) -> String:
    var key := name + BITS_SUFFIX
    if not block.has(key):
        if block.has(name):
            return ("%s is published as a decimal and not as %s; this engine cannot read a "
                    + "decimal back exactly and will not guess") % [name, key]
        return "neither %s nor %s is published here" % [name, key]
    return "%s is present and is not a 16-digit pattern: %s" % [key, str(block[key])]
