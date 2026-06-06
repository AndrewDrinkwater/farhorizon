extends GutTest
## Pure order-availability rules (ADR 0015). Only context-appropriate orders are
## legal — this is the single source of truth the Helm + FlightController share.

const DEEP := Travel.Location.DEEP_SPACE
const HOLD := Travel.Location.HOLDING
const DOCK := Travel.Location.DOCKED


func _ctx(overrides: Dictionary) -> Dictionary:
	var base := {
		"location": DEEP,
		"location_can_dock": false,
		"in_transit": false,
		"has_course": false,
		"nav_target_id": "",
		"nav_target_is_here": false,
	}
	base.merge(overrides, true)
	return base


func test_lay_in_needs_a_target_elsewhere_and_not_under_way() -> void:
	assert_true(Travel.available(_ctx({"nav_target_id": "verdant"}))["lay_in"], "target selected -> can lay in")
	assert_false(Travel.available(_ctx({}))["lay_in"], "no target -> cannot")
	assert_false(Travel.available(_ctx({"nav_target_id": "verdant", "nav_target_is_here": true}))["lay_in"],
		"already there -> cannot plot to here")
	assert_false(Travel.available(_ctx({"nav_target_id": "verdant", "in_transit": true}))["lay_in"],
		"under way -> cannot re-plot")


func test_engage_needs_course_not_under_way_not_docked() -> void:
	assert_true(Travel.available(_ctx({"has_course": true}))["engage"], "laid-in course -> can engage")
	assert_false(Travel.available(_ctx({}))["engage"], "no course -> cannot engage")
	assert_false(Travel.available(_ctx({"has_course": true, "in_transit": true}))["engage"],
		"already under way -> cannot engage")
	assert_false(Travel.available(_ctx({"has_course": true, "location": DOCK}))["engage"],
		"docked -> must undock first")


func test_belay_and_all_stop_only_under_way() -> void:
	var underway := Travel.available(_ctx({"in_transit": true}))
	assert_true(underway["belay"])
	assert_true(underway["all_stop"])
	var idle := Travel.available(_ctx({}))
	assert_false(idle["belay"])
	assert_false(idle["all_stop"])


func test_dock_needs_holding_at_a_station() -> void:
	assert_true(Travel.available(_ctx({"location": HOLD, "location_can_dock": true}))["dock"],
		"holding at a station -> can dock")
	assert_false(Travel.available(_ctx({"location": HOLD, "location_can_dock": false}))["dock"],
		"holding at a non-station -> cannot dock")
	assert_false(Travel.available(_ctx({"location": DEEP, "location_can_dock": true}))["dock"],
		"deep space -> cannot dock")


func test_undock_only_when_docked() -> void:
	assert_true(Travel.available(_ctx({"location": DOCK}))["undock"])
	assert_false(Travel.available(_ctx({"location": HOLD}))["undock"])
