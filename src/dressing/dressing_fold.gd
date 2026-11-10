class_name DressingFold
extends RefCounted

## THE CLIENT'S FOLD OF A COMMITTED DRESSING — `docs/roadmap/client.md` G-9, W2
## (decision 2129 (b), §25 backlog 730). NOTHING HERE DRAWS.
##
## A dressing is a DATED EVENT LOG, not a table of states. "At year Y" is
## therefore a fold: every row dated at or before Y, applied in file order,
## because the log is written forward and file order within a year is the
## generator's order. This class is the client's own implementation of that
## fold, and §25 backlog 730's committed `fold_<year>.json` is what judges it.
##
## WHY A REIMPLEMENTATION AND NOT A READ. The point of W2 is that two
## independent implementations of the same rule agree. If the client read the
## reference and drew it, the viewer would be showing the humans lane's answer
## and the comparison would compare a file with itself -- a control that cannot
## fail, which is the defect class this project keeps meeting. So the fold is
## written here from the rules, and the reference is the external check on it.
##
## THE RULES, AND THEY ARE ASYMMETRIC. Each is load-bearing and none is
## guessable from the others:
##
##   * `cleared` REPLACES the whole state -- every field back to its default --
##     and sets `since` to the clearing year. It then applies nothing else from
##     its own row.
##   * `zoned` sets `zone` FROM THE ROW'S `class` AND NEVER THE TILE'S CLASS, so
##     an unbuilt tile under a label stays unbuilt in the fold (decision 2097).
##   * `built`, `densified` and `filtered` set the class.
##   * `built`, `filtered` and `renewed` set `since`. **`densified` DOES NOT**,
##     and that is the rule as written rather than an oversight: `since` is the
##     year the tile's STRATUM began, and densifying keeps the stratum it has.
##     Confirmed against the data by the manager at W2's construal -- all 9,018
##     densified rows here, and all 46,557 in the sprawled dressing, carry a
##     stratum and none changes the tile's current one.
##   * `renewed` resets `since` WITHOUT touching the class.
##   * `sink_designated` sets `sink`.
##   * every event then copies whichever of `stratum`, `density_per_km2`,
##     `storeys`, `feature` and `route` its own row carries -- which is why
##     `feature_placed` and `route_laid` leave the class alone, and why a tile
##     can stand at 1890 with a feature on it and a null class.
##
## A TILE APPEARS IN THE FOLD IF ANY ROW DATES AT OR BEFORE THE YEAR, even when
## nothing was ever built on it: a `zoned`-only tile is present with a null
## class. That is why the fold's tile count is not a count of built tiles.
##
## `era` IS NOT IN THE FOLDED STATE. The log's rows carry one; the reference's
## state does not (decision 2129's correction), so neither does this.

const DIR := "res://assets/dressing/da6-compact/"

## The folded state's fields, which are the reference's own set. `tile` is NOT
## among them: it is the key a state is stored under, not part of the state.
const STATE_KEYS: Array[String] = ["class", "density_per_km2", "feature", "route", "since",
        "sink", "storeys", "stratum", "zone"]

## The fields an event copies from its own row when the row carries them. ORDER
## IS IRRELEVANT HERE and the set is not: a field absent from a row must keep
## its previous value rather than revert to a default.
const CARRIED: Array[String] = ["stratum", "density_per_km2", "storeys", "feature", "route"]


## One row per line, parsed once. Read once and folded many times: re-reading
## 7.2 MB per year would be four times the work for the same answer.
static func read_rows(path: String) -> Array:
    var out: Array = []
    if not FileAccess.file_exists(path):
        return out
    var text := FileAccess.get_file_as_string(path)
    for line in text.split("\n"):
        var s := (line as String).strip_edges()
        if s.is_empty():
            continue
        var parsed = JSON.parse_string(s)
        if typeof(parsed) == TYPE_DICTIONARY:
            out.append(parsed)
    return out


## `p,i,j`. A STRING AND NOT THE ARRAY ITSELF, so that two equal tiles are one
## key: a Dictionary keyed on Array compares by reference for lookup purposes in
## some engine versions, and a fold that silently split one tile into two keys
## would report a tile count that looks plausible and is wrong.
static func tile_key(t) -> String:
    var a: Array = t
    return "%d,%d,%d" % [int(a[0]), int(a[1]), int(a[2])]


static func _default_state() -> Dictionary:
    return {"class": null, "stratum": null, "density_per_km2": 0.0, "storeys": 0,
            "feature": null, "route": null, "since": null, "sink": false, "zone": null}


## Each tile's state at `year`, keyed by `tile_key`.
static func fold(rows: Array, year: int) -> Dictionary:
    var state := {}
    for r: Dictionary in rows:
        if int(r["calendar_year"]) > year:
            continue
        var k := tile_key(r["tile"])
        if not state.has(k):
            state[k] = _default_state()
        var e := str(r["event"])
        if e == "cleared":
            var fresh := _default_state()
            fresh["since"] = r["calendar_year"]
            state[k] = fresh
            continue
        var s: Dictionary = state[k]
        if e == "zoned":
            s["zone"] = r["class"]
        elif e == "built" or e == "densified" or e == "filtered":
            s["class"] = r["class"]
        if e == "built" or e == "filtered" or e == "renewed":
            s["since"] = r["calendar_year"]
        for f: String in CARRIED:
            if r.has(f):
                s[f] = r[f]
        if e == "sink_designated":
            s["sink"] = true
    return state


## Is a row standing at `year`? Dated at or before it, and not removed by it.
##
## THE `removed` CLAUSE IS UNEXERCISED ON THIS DRESSING: no features or routes
## row carries the field, so nothing here has ever excluded anything, and the
## reference cannot witness whether this reads it correctly.
static func _standing(r: Dictionary, year: int) -> bool:
    if int(r["calendar_year"]) > year:
        return false
    if r.has("removed") and r["removed"] != null and int(r["removed"]) <= year:
        return false
    return true


## The features standing at `year`, IN THE REFERENCE'S ORDER: sorted by
## `feature_id` ALONE.
##
## ⚠ THE TWO LISTS SORT BY DIFFERENT KEYS, and neither is file order. Features
## go by `feature_id` only, so an id beginning `station-` sorts LAST even though
## its row is first in the file and earliest by year; routes (below) go by
## `(calendar_year, route)`. Sorting features by `(calendar_year, feature_id)` --
## the natural assumption, and the rule the routes really do use -- produces the
## wrong order. Measured at all four declared years rather than assumed, and
## ruled at §25 backlog 730's Q2.
static func features_at(rows: Array, year: int) -> Array:
    var out: Array = []
    for r: Dictionary in rows:
        if _standing(r, year):
            out.append(r)
    out.sort_custom(DressingFold._feature_before)
    return out


## The routes standing at `year`, in the reference's order: `(calendar_year,
## route)`. See the warning on `features_at` -- this is the OTHER rule.
static func routes_at(rows: Array, year: int) -> Array:
    var out: Array = []
    for r: Dictionary in rows:
        if _standing(r, year):
            out.append(r)
    out.sort_custom(DressingFold._route_before)
    return out


## `feature_id` is unique within a dressing, so this is a total order and the
## engine's sort needing no stability guarantee does not matter here.
static func _feature_before(a, b) -> bool:
    return str((a as Dictionary)["feature_id"]) < str((b as Dictionary)["feature_id"])


## `(calendar_year, route)`, and `route` is unique, so again a total order.
static func _route_before(a, b) -> bool:
    var ad: Dictionary = a
    var bd: Dictionary = b
    var ya := int(ad["calendar_year"])
    var yb := int(bd["calendar_year"])
    if ya != yb:
        return ya < yb
    return str(ad["route"]) < str(bd["route"])
