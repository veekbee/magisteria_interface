class_name BundleStream
extends RefCounted

## A session of bundles, recorded so it can be replayed without the session.
##
## THE SAME DISCIPLINE AS A FLIGHT TRACE, one layer in. A flight trace records
## where a camera went; this records what an observer was GIVEN, which is the
## thing a transducer is supposed to be a function of. Recorded, a walk can be
## scored headlessly forever -- and the score can ask questions a photograph
## cannot, starting with whether the body ever moved faster than the producer
## said it could.
##
## CHANNEL 1 IS STORED PER MOMENT, NOT PER FRAME, and that is the difference
## between a file and a folly: the fields are about a thousand times the size
## of a body, and they change when the day changes rather than when the person
## does. Frames name the moment they were standing in, so a reader never has to
## assume the last one it saw.
##
## THE SIZE RULE IS THE REPO'S (decision 948): over ten megabytes and a file is
## not committed -- it arrives through `tools/fetch_artefacts.py` and nothing
## else. `over_committable` says so before a caller writes rather than after.

const COMMITTABLE_BYTES := 10485760

var producer: Dictionary = {}
var session: String = ""
## "window|day" -> the fields half of a bundle document
var moments: Dictionary = {}
## One per frame: {"t": seconds, "moment": key, "body": body document}
var frames: Array = []


static func opened(bundle: PerceptBundle) -> BundleStream:
    var s := BundleStream.new()
    s.producer = bundle.producer.duplicate(true)
    s.session = bundle.observer_session
    return s


## Add one frame. The fields are stored the first time a moment is seen and
## referenced by every frame after it.
func add(bundle: PerceptBundle, t_seconds: float) -> void:
    var key := "%s|%d" % [str(bundle.moment.get("window", "")), int(bundle.moment.get("day", 0))]
    if not moments.has(key):
        var whole := bundle.to_dict()
        moments[key] = whole.get("fields", {})
    frames.append({"t": t_seconds, "moment": key,
            "body": (bundle.to_dict(false)["body"] as Dictionary)})


func to_dict() -> Dictionary:
    return {
        "schema_version": PerceptBundle.SCHEMA_VERSION.duplicate(),
        "producer": producer.duplicate(true),
        "session": session,
        "moments": moments.duplicate(true),
        "frames": frames.duplicate(true),
    }


static func from_dict(doc: Dictionary) -> BundleStream:
    var s := BundleStream.new()
    s.producer = doc.get("producer", {})
    s.session = str(doc.get("session", ""))
    s.moments = doc.get("moments", {})
    s.frames = doc.get("frames", [])
    return s


## A BODY NEVER MOVES FASTER THAN THE BUNDLE SAID IT COULD, and a recorded walk
## can be asked. This is the invariant that separates a body from a camera: the
## speed is the producer's, so a transducer that helped itself to more of it
## shows up here as a frame that outran its own locomotion field.
##
## The tolerance is a fraction rather than an absolute: frame deltas differ by
## orders of magnitude between a paced harness and a person's session.
func outran_its_speed(tolerance: float = 0.02) -> Array:
    var out: Array = []
    for i in range(1, frames.size()):
        var a: Dictionary = frames[i - 1]
        var b: Dictionary = frames[i]
        var dt := float(b.get("t", 0.0)) - float(a.get("t", 0.0))
        if dt <= 0.0:
            continue
        var pa: Array = (a.get("body", {}) as Dictionary).get("observation_point", [])
        var pb: Array = (b.get("body", {}) as Dictionary).get("observation_point", [])
        if pa.size() != 3 or pb.size() != 3:
            continue
        # HORIZONTAL ONLY. Vertical movement is the ground's doing -- a body
        # walking downhill is carried by the terrain, not propelled by itself --
        # and folding it in would report a hillside as cheating.
        var moved := Vector2(float(pb[0]) - float(pa[0]),
                float(pb[2]) - float(pa[2])).length()
        var allowed := float((a.get("body", {}) as Dictionary).get("locomotion", {})
                .get("sustainable_speed_m_s", 0.0)) * dt
        if moved > allowed * (1.0 + tolerance) + 1.0e-9:
            out.append({"frame": i, "moved_m": moved, "allowed_m": allowed, "dt": dt})
    return out


## What the moments cost, so a caller can see a stream growing before it is a
## file nobody can commit.
func over_committable() -> Dictionary:
    var bytes := JSON.stringify(to_dict()).to_utf8_buffer().size()
    return {"bytes": bytes, "over": bytes > COMMITTABLE_BYTES,
            "route": ("over %d bytes a file is not committed: it arrives through "
                    % COMMITTABLE_BYTES + "tools/fetch_artefacts.py and nothing else.")}
