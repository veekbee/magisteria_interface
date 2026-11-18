class_name StatsPanel
extends RefCounted

## THE YEAR'S PANEL AND THE NEXT YEAR'S DEMAND — §25 backlog 752, decision
## 2149 (4), from a session's `year_<Y>/stats.json`.
##
## This builds LINES rather than drawing. The view draws them. That split is
## deliberate: the panel's claim is *what it shows*, and a headless suite can
## assert on lines where it cannot assert on pixels. A panel that drew directly
## would be tested by reading the code that draws it, which is not a test.
##
## ⚠ THE BUILT COUNT IS THE LEDGER'S, AND THIS PANEL COMPUTES NOTHING.
## §25 backlog 750 reconciled the two counts and gave the rule: the ledger's
## `built_tiles` equals the fold's classed tiles plus its feature tiles with no
## class inside the window and not a sparse field. The generator carries both
## numbers and its own `agree`. So this panel **reads** the ledger's count,
## shows the rule's parts beside it, and shows whether they agree — and never
## adds, subtracts or recounts anything. The previous arrangement (decision 2149
## (4), §9 (D)) was to show both side by side *until reconciled*; 750 reconciled
## them, and the dispatch's words are that the panel's count is the ledger's,
## not a count of its own.
##
## Why that matters more than it looks: a panel that recomputed the count would
## be a second implementation of a rule that already has one, and the two would
## agree right up to the year they did not — with no way to tell which was
## wrong. Reading the generator's own figure means a disagreement is the
## generator's to explain, and `agree` is the instrument that says so.
##
## ⚠ EVERY FIELD IS NAMED. Unknown keys are ignored, never rendered (752's
## construal Q6b). An at-the-cap row's schedule-side key is read past for that
## reason and not because the row is malformed.
##
## ⚠ THE GENERATOR'S NOTES ARE DRAWN AS DATA. `quotas_note`, `strata_note`,
## `enclosed_note` and `built.rule` are the generator's own words, read from a
## local file at runtime and never copied into a source file in this tree — the
## standing the palette's class names have under decision 2129 (b). They are
## shown because the figures beside them do not mean what they appear to mean
## without them: a stratum's tile figure is a *bound*, and the enclosed count is
## *as at the last sweep's start*.

var problem: String = ""
var lines: Array = []


## Build the panel from one year's stats. A refusal lands in `problem`.
static func of(stats: Dictionary) -> StatsPanel:
    var p := StatsPanel.new()
    if stats.is_empty():
        p.problem = "No stats.json for this year, or it did not parse."
        return p
    var ledger: Dictionary = stats.get("ledger", {})
    var fabric: Dictionary = stats.get("fabric", {})
    var d1: Dictionary = stats.get("d1", {})
    var built: Dictionary = stats.get("built", {})
    for pair in [["ledger", ledger], ["fabric", fabric], ["d1", d1], ["built", built]]:
        if (pair[1] as Dictionary).is_empty():
            p.problem = "stats.json carries no `%s` block; the panel will not guess it." % pair[0]
            return p
    p._year(int(stats.get("year", 0)), ledger, d1)
    p._built(ledger, built)
    p._fabric(fabric)
    p._carried(ledger)
    p._demand(stats.get("demand", null))
    return p


func _year(y: int, ledger: Dictionary, d1: Dictionary) -> void:
    lines.append("year %d" % y)
    lines.append("  people          %.0f of %.0f" % [
            float(ledger.get("occupancy", 0.0)), float(ledger.get("capacity", 0.0))])
    lines.append("  vacancy         %.0f" % float(ledger.get("vacancy", 0.0)))
    lines.append("  arrivals plan   %.0f" % float(ledger.get("plan", 0.0)))
    # §22.7's D1 AS A RUNNING LINE, which is what decision 2149 (4) asks for: not
    # a verdict at the end but the margin every year, so the owner sees it narrow.
    var holds: bool = bool(d1.get("holds", false))
    lines.append("  D1 capacity-people %+.0f  %s" % [
            float(d1.get("capacity_less_occupancy", 0.0)),
            "holds" if holds else "FAILS"])


func _built(ledger: Dictionary, built: Dictionary) -> void:
    # THE LEDGER'S COUNT. Read, never recomputed -- see the header.
    var n := int(built.get("ledger_tiles", ledger.get("built_tiles", 0)))
    lines.append("  built tiles     %d of %d" % [n, int(built.get("cap_tiles", 0))])
    lines.append("  built km2       %.1f of %.1f" % [
            float(built.get("built_km2", ledger.get("built_km2", 0.0))),
            float(built.get("cap_km2", 0.0))])
    var fold: Dictionary = built.get("fold", {})
    if fold.is_empty():
        lines.append("  the fold's own count is absent; agreement is unread")
        return
    # The rule's parts, so the count is legible rather than a number to trust.
    lines.append("    the rule      %d classed + %d feature in window = %d" % [
            int(fold.get("classed", 0)), int(fold.get("feature_in_window", 0)),
            int(fold.get("total", 0))])
    lines.append("    left out      %d feature outside, %d sparse" % [
            int(fold.get("feature_outside", 0)), int(fold.get("sparse", 0))])
    var agree: bool = bool(built.get("agree", false))
    lines.append("    agrees        %s" % ("yes" if agree else "NO -- the generator's two counts differ"))
    if built.has("rule"):
        lines.append("    %s" % str(built["rule"]))


func _fabric(fabric: Dictionary) -> void:
    lines.append("  density         %.2f per person-weighted km2" % float(fabric.get("density_pw", 0.0)))
    lines.append("  transit share   %.2f" % float(fabric.get("transit_share", 0.0)))
    var take: Dictionary = fabric.get("irrigated_take_km2", {})
    if take.is_empty():
        lines.append("  irrigated take  none")
    else:
        for node in take.keys():
            lines.append("  irrigated take  %.2f km2 at %s" % [float(take[node]), str(node)])


func _carried(ledger: Dictionary) -> void:
    var carried: Dictionary = ledger.get("quota_carried", {})
    if not carried.is_empty():
        lines.append("  carried quota")
        for cls in carried.keys():
            lines.append("    %-14s %.2f" % [str(cls), float(carried[cls])])
    var caps: Array = ledger.get("at_the_cap", [])
    if not caps.is_empty():
        lines.append("  at the cap")
        for row_v in caps:
            var row: Dictionary = row_v
            # `kind`, `type` and `tiles` ONLY -- see the header.
            lines.append("    %s %s, %d tiles" % [
                    str(row.get("kind", "?")), str(row.get("type", "?")),
                    int(row.get("tiles", 0))])
    var residues: Array = ledger.get("residues", [])
    if not residues.is_empty():
        lines.append("  residues")
        for row_v in residues:
            var row: Dictionary = row_v
            lines.append("    %s to %s: %.0f people, %d filtered" % [
                    str(row.get("from", "?")), str(row.get("to", "?")),
                    float(row.get("persons", 0.0)), int(row.get("filtered", 0))])


func _demand(demand_v) -> void:
    if demand_v == null or typeof(demand_v) != TYPE_DICTIONARY:
        # THE LAST YEAR HAS NO NEXT YEAR, and that is a state rather than a fault.
        lines.append("  no demand: this is the session's last year")
        return
    var demand: Dictionary = demand_v
    lines.append("next year %d  (era %s)" % [int(demand.get("year", 0)), str(demand.get("era", "?"))])
    lines.append("  arriving        %.0f" % float(demand.get("arrivals", 0.0)))
    var quotas: Dictionary = demand.get("quotas_tiles", {})
    if not quotas.is_empty():
        lines.append("  wants, in tiles")
        for cls in quotas.keys():
            lines.append("    %-14s %d" % [str(cls), int(quotas[cls])])
    if demand.has("quotas_note"):
        lines.append("    %s" % str(demand["quotas_note"]))
    var strata: Dictionary = demand.get("strata", {})
    if not strata.is_empty():
        lines.append("  by stratum")
        for s in strata.keys():
            var row: Dictionary = strata[s]
            lines.append("    %-14s %.0f people, at least %d tiles" % [
                    str(s), float(row.get("people", 0.0)), int(row.get("tiles_at_least", 0))])
        if demand.has("strata_note"):
            lines.append("    %s" % str(demand["strata_note"]))
    lines.append("  open now        %d serviceable, %d enclosed" % [
            int(demand.get("serviceable_open_tiles", 0)),
            int(demand.get("enclosed_open_tiles", 0))])
    if demand.has("enclosed_note"):
        lines.append("    %s" % str(demand["enclosed_note"]))
    lines.append("  holds releasing %d" % int(demand.get("holds_releasing", 0)))
