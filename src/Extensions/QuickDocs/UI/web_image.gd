extends TextureButton


func display(link: String):
	var http_request = $HTTPRequest
	var error = http_request.request(link)
	if error != OK:
		push_error("An error occurred in the HTTP request.")


# Called when the HTTP request is completed.
func _on_http_request_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		push_error("Image couldn't be downloaded. Try a different image.")

	var image = Image.new()
	var error = image.load_png_from_buffer(body)
	if error != OK:
		push_error("Couldn't load the image.")

	var img_texture = ImageTexture.create_from_image(image)

	texture_normal = img_texture
	$AcceptDialog/TextureRect.texture = img_texture


func _on_pressed() -> void:
	$AcceptDialog.popup_centered()
