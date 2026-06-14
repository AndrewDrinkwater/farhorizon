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


func test_all_stop_only_under_way() -> void:
	var underway := Travel.available(_ctx({"in_transit": true}))
	assert_true(underway["all_stop"])
	var idle := Travel.available(_ctx({}))
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


func test_lay_in_allowed_for_a_free_point_with_no_id() -> void:
	# A free-space waypoint has no id but still enables lay-in (ADR 0020).
	assert_true(Travel.available(_ctx({"has_nav_selection": true}))["lay_in"],
		"a selected waypoint (no id) can be laid in")
	assert_false(Travel.available(_ctx({"has_nav_selection": false}))["lay_in"],
		"nothing selected -> cannot")


func test_scan_needs_an_in_range_blip_and_runs_while_moving() -> void:
	var ok := _ctx({
		"nav_target_is_contact": true, "nav_target_in_range": true,
		"nav_target_tier": Sensors.Tier.BLIP,
	})
	assert_true(Travel.available(ok)["scan"], "in-range BLIP contact -> can scan")
	assert_false(Travel.available(_merge(ok, {"nav_target_in_range": false}))["scan"],
		"out of range -> cannot scan")
	assert_false(Travel.available(_merge(ok, {"nav_target_tier": Sensors.Tier.IDENTIFIED}))["scan"],
		"already identified -> cannot scan")
	assert_true(Travel.available(_merge(ok, {"in_transit": true}))["scan"],
		"under way -> CAN scan (ADR 0017: concurrent with flight)")
	assert_false(Travel.available(_merge(ok, {"scanning": true}))["scan"],
		"already scanning -> cannot start another")
	assert_false(Travel.available(_merge(ok, {"in_transition": true}))["scan"],
		"mid dock/land transition -> cannot scan")
	assert_false(Travel.available(_ctx({"nav_target_is_contact": false}))["scan"],
		"not a contact -> no scan")


func _merge(base: Dictionary, overrides: Dictionary) -> Dictionary:
	var d := base.duplicate(true)
	d.merge(overrides, true)
	return d


func test_land_needs_holding_at_a_landable_body() -> void:
	assert_true(Travel.available(_ctx({"location": HOLD, "landable_here": true}))["land"],
		"holding at a landable body -> can land")
	assert_false(Travel.available(_ctx({"location": HOLD, "landable_here": false}))["land"],
		"not landable -> cannot")
	assert_false(Travel.available(_ctx({"location": DEEP, "landable_here": true}))["land"],
		"must be holding first")
	assert_false(Travel.available(_ctx({"location": HOLD, "landable_here": true, "in_transition": true}))["land"],
		"mid-transition -> busy")


func test_take_off_and_move_only_when_landed() -> void:
	var landed := _ctx({"location": Travel.Location.LANDED})
	assert_true(Travel.available(landed)["take_off"], "landed -> can take off")
	assert_false(Travel.available(landed)["move"], "nowhere else to move")
	assert_true(Travel.available(_merge(landed, {"has_other_site": true}))["move"],
		"another site -> can move")
	assert_false(Travel.available(_ctx({"location": HOLD}))["take_off"], "not landed -> no take off")
	assert_false(Travel.available(_merge(landed, {"in_transition": true}))["take_off"],
		"mid-transition -> busy")


func test_space_orders_unavailable_while_landed() -> void:
	var landed := _ctx({"location": Travel.Location.LANDED, "has_nav_selection": true, "has_course": true})
	assert_false(Travel.available(landed)["lay_in"], "no space plotting while landed")
	assert_false(Travel.available(landed)["engage"], "no engaging while landed")
