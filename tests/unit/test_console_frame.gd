extends GutTest
## Console frame (ADR 0034): the frame owns five fixed-size boxes (a console only
## sets title + content), the bottom band is identical on every console, and each
## side is a collapsible drawer that starts collapsed with its handle protruding.

var _frame: ConsoleFrame


func before_each() -> void:
	_frame = ConsoleFrame.new()
	add_child_autofree(_frame)  # _ready builds the boxes


func test_owns_the_fixed_boxes() -> void:
	for box: TPanel in [_frame.left(), _frame.right(), _frame.secondary(), _frame.control(), _frame.info()]:
		assert_not_null(box, "box exists")
		assert_not_null(box.content(), "box has a content container to fill")
	assert_not_null(_frame.toast(), "notification toast")
	assert_not_null(_frame.console_select(), "console-select slot")
	assert_not_null(_frame.centre(), "centre slot")


func test_bottom_boxes_have_fixed_sizes() -> void:
	assert_eq(_frame.control().custom_minimum_size, Vector2(ConsoleFrame.CONTROL_W, ConsoleFrame.BOX_H))
	assert_eq(_frame.secondary().custom_minimum_size, Vector2(ConsoleFrame.SIDE_WIDTH, ConsoleFrame.BOX_H))
	assert_eq(_frame.info().custom_minimum_size, Vector2(ConsoleFrame.SIDE_WIDTH, ConsoleFrame.BOX_H))


func test_drawers_start_collapsed_with_visible_handles() -> void:
	assert_false(_frame._left_col.visible, "left drawer starts collapsed (peek)")
	assert_false(_frame._right_col.visible, "right drawer starts collapsed (peek)")
	assert_true(_frame._left_handle.visible, "handle always available to extend it")
	assert_true(_frame._right_handle.visible, "handle always available to extend it")


func test_handle_toggles_the_drawer() -> void:
	_frame._toggle_side(true)
	assert_true(_frame._left_col.visible, "toggling extends the drawer")
	_frame._toggle_side(true)
	assert_false(_frame._left_col.visible, "toggling again collapses it")
