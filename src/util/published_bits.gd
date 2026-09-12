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

## TWO PUBLISHED FORMS, AND THIS READS BOTH.
##
##   nested     "d_m": {"dec": -0.0620788664732796, "hex": "0xbfafc8cd1a8d0ca1"}
##   flat _bits  "min_nonzero_magnitude": 9.02759206434e-312,
##              "min_nonzero_bits": "0x000001a96de74c92"
##   flat _hex   "origin": [-1809292.9365744274, 2356726.304046243],
##              "origin_hex": ["0xc13b9b8cefc35778", "0x4141fafb26eafcbf"]
##
## LOOK AT THE SECOND ONE AGAIN: the value is `min_nonzero_magnitude` and the
## pattern is `min_nonzero_bits`. The sibling's name is NOT derivable from the
## field's name -- it is `min_nonzero` plus a suffix, and the field is
## `min_nonzero` plus a different one. So the flat form is not a convention a
## reader can follow; it is a pairing a reader has to be told, out of band, per
## field. The first cut of this file assumed `<name>_bits`, found nothing, and
## returned NAN -- conservative, and still wrong, and it would have stayed
## invisible until the re-vendor because the fixture in hand publishes no
## pattern at all for the lookup to miss.
##
## THREE, not two. Decision 985's amendment published the nested form in the
## conformance vectors and the `_hex` form in the rows' parent block -- the same
## amendment, two shapes -- and the fixture manifest's subnormal fix published
## `_bits`. Reading all three costs two branches and means the emitting side can
## settle the convention at whichever re-emission is already happening, rather
## than at one this reader forced.
##
## THE PARALLEL-ARRAY CASE IS WHY `_hex` CANNOT SIMPLY BE RENAMED AWAY: `origin`
## is two numbers and `origin_hex` is two patterns, position for position. A
## nested form would put the pairing inside each element instead, which is the
## better shape and is a change to how the block is read, not a rename.
##
## NESTED IS THE BETTER OF THE TWO AND THE REASON IS THE FAILURE MODE, not
## taste. Under the flat form the decimal remains a well-formed, plausible
## float sitting at the name a reader will reach for: a consumer that has never
## heard of the convention gets a slightly wrong number, silently, which is the
## exact defect the bits exist to end. Under the nested form that consumer gets
## a Dictionary where it wanted a float and fails at the first read. The
## convention that cannot be missed is the one where missing it is loud.
const BITS_SUFFIX := "_bits"
const HEX_SUFFIX := "_hex"

## The keys of the nested form.
const NESTED_HEX := "hex"
const NESTED_DEC := "dec"


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
## A published scalar whose pattern sits under a key the value's name does not
## predict. The pairing is the CALLER'S to state, because nothing in the
## document says it.
##
## This is the flat form's real cost and the reason it is worth a sentence: a
## reader that guesses the sibling's name gets NAN on a value that is published,
## and every guess is silently plausible. `of` guesses the two spellings that
## have appeared so far; anything else comes through here.
static func of_named(block: Dictionary, bits_key: String) -> float:
    if not block.has(bits_key):
        return NAN
    var v: Variant = block[bits_key]
    return NAN if typeof(v) == TYPE_ARRAY else of_hex(str(v))


static func of(block: Dictionary, name: String) -> float:
    # Nested first. A value published both ways is published nested, because
    # that is the form whose pairing is structural rather than by convention.
    var nested: Variant = block.get(name, null)
    if typeof(nested) == TYPE_DICTIONARY and (nested as Dictionary).has(NESTED_HEX):
        return of_hex(str((nested as Dictionary)[NESTED_HEX]))
    if block.has(name + BITS_SUFFIX):
        return of_hex(str(block[name + BITS_SUFFIX]))
    if block.has(name + HEX_SUFFIX):
        var h: Variant = block[name + HEX_SUFFIX]
        # Scalar only here. The parallel-array form is a different question --
        # which element -- and `of_element` is where that is asked.
        if typeof(h) != TYPE_ARRAY:
            return of_hex(str(h))
    return NAN


## One element of a parallel-array publication: `origin` beside `origin_hex`,
## position for position. NAN when there is no pattern at that position.
##
## SEPARATE FROM `of` BECAUSE THE QUESTION IS DIFFERENT. `of` asks "what is this
## value"; this asks "what is the i-th value", and a caller that forgot the
## index would otherwise get element zero of a two-element corner and be off by
## a whole axis rather than by an ulp.
static func of_element(block: Dictionary, name: String, index: int) -> float:
    var h: Variant = block.get(name + HEX_SUFFIX, null)
    if typeof(h) != TYPE_ARRAY:
        return NAN
    var a: Array = h
    if index < 0 or index >= a.size():
        return NAN
    return of_hex(str(a[index]))


## Is this name published in a form that survives the reader? A value with no
## pattern beside it is NAKED -- readable only through a decimal this engine
## may not return exactly, whether or not it happens to today.
##
## Short round decimals come back exactly and a naked one is not yet WRONG. It
## is unprotected, which is a different and more durable statement: `0.18` is
## exact and the calibrated value that replaces it will not be.
static func is_protected(block: Dictionary, name: String) -> bool:
    var nested: Variant = block.get(name, null)
    if typeof(nested) == TYPE_DICTIONARY and (nested as Dictionary).has(NESTED_HEX):
        return true
    # A PAIR PUBLISHED NESTED PER ELEMENT, which is what `parent.origin` became
    # when 31efcab retired the parallel-array form. Every element must carry a
    # pattern: a corner with one axis protected and one bare is not protected,
    # and reading it as though it were would take the bare axis from its decimal.
    if typeof(nested) == TYPE_ARRAY and not (nested as Array).is_empty():
        var every := true
        for e in (nested as Array):
            if typeof(e) != TYPE_DICTIONARY or not (e as Dictionary).has(NESTED_HEX):
                every = false
                break
        if every:
            return true
        # FALLS THROUGH RATHER THAN REFUSING. An array of bare numbers is the
        # retired parallel form, and it is protected iff `<name>_hex` sits
        # beside it. Returning false here read the old convention as naked and
        # would have had this client report a correctly-published corner as
        # unprotected -- on the one artefact the convention was invented for.
    return block.has(name + BITS_SUFFIX) or block.has(name + HEX_SUFFIX)


## Why a `NAN` from `of` happened, for a caller that has to report it.
static func why_absent(block: Dictionary, name: String) -> String:
    var nested: Variant = block.get(name, null)
    if typeof(nested) == TYPE_DICTIONARY:
        if (nested as Dictionary).has(NESTED_HEX):
            return ("%s publishes a pattern and it is not 16 digits: %s"
                    % [name, str((nested as Dictionary)[NESTED_HEX])])
        return "%s is a block and carries no `%s`" % [name, NESTED_HEX]
    var key := name + BITS_SUFFIX
    if block.has(key):
        return "%s is present and is not a 16-digit pattern: %s" % [key, str(block[key])]
    if block.has(name + HEX_SUFFIX):
        return ("%s%s is an array; read it with `of_element` and an index"
                % [name, HEX_SUFFIX])
    if block.has(name):
        return ("%s is published as a bare decimal, with no `%s`, no `%s` and no `%s` block "
                + "beside it; this engine cannot read a decimal back exactly and will not guess"
                ) % [name, name + BITS_SUFFIX, name + HEX_SUFFIX, NESTED_HEX]
    return "neither %s nor %s is published here" % [name, key]
