extends GutTest


func test_crack_decal_texture_is_generated_procedurally() -> void:
	var panel := BreakableWoodPanel.new()

	var texture: Texture2D = panel._get_crack_texture()
	assert_not_null(texture, "Wood panels must provide a crack decal texture")
	assert_eq(texture.get_width(), 64)
	assert_eq(texture.get_height(), 64)

	var image: Image = texture.get_image()
	assert_gt(image.get_pixel(32, 6).a, 0.0, "Crack texture must contain visible crack pixels")
	assert_eq(image.get_pixel(0, 0).a, 0.0, "Crack texture must preserve transparent background")
	panel.free()
