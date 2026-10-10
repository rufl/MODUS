extends GutTest

const DEFERRED_INIT_SCRIPT := preload("res://tests/fixtures/deferred_init_test_node.gd")
## Simple Preservation Test - Test Compilation Fix
##
## **Validates: Requirements 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7**
##
## This is a regression contract, not a baseline marker.
## It must fail when deferred initialization does not expose the logger API.
##
## This test validates that the deferred initialization pattern preserves
## runtime behavior by testing that services work correctly when initialized
## in _ready() methods instead of at class level.


## Test that deferred initialization works correctly
func test_deferred_initialization_pattern_works() -> void:
	## Create a test node that uses deferred initialization
	var test_obj: Node = DEFERRED_INIT_SCRIPT.new()
	add_child_autofree(test_obj)

	## Wait for _ready() to be called
	await get_tree().process_frame

	var logger: Variant = test_obj.get("logger")
	assert_not_null(logger, "Logger should be initialized in _ready()")
	assert_true(logger.has_method("info"), "Logger should have info method")
