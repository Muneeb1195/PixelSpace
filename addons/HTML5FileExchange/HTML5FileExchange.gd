extends Node

signal InFocus

## Godot 4 reports the web platform as "Web" (not "HTML5") and exposes it
## via the "web" feature flag. Centralize the check here.
static func is_web() -> bool:
	return OS.has_feature("web")

func _ready():
	if is_web():
		_define_js()


func _notification(notification:int) -> void:
	if notification == MainLoop.NOTIFICATION_APPLICATION_FOCUS_IN:
		emit_signal("InFocus")

func _define_js()->void:
	#Define JS script
	JavaScriptBridge.eval("""
	var fileData;
	var fileType;
	var fileName;
	var canceled;
	function upload() {
		canceled = true;
		var input = document.createElement('INPUT'); 
		input.setAttribute("type", "file");
		input.setAttribute("accept", "image/png, image/jpeg, image/webp");
		input.click();
		input.addEventListener('change', event => {
			if (event.target.files.length > 0){
				canceled = false;}
			var file = event.target.files[0];
			var reader = new FileReader();
			fileType = file.type;
			fileName = file.name;
			reader.readAsArrayBuffer(file);
			reader.onloadend = function (evt) {
				if (evt.target.readyState == FileReader.DONE) {
					fileData = evt.target.result;
				}
			}
		  });
	}
	function download(fileName, byte) {
		var buffer = Uint8Array.from(byte);
		var blob = new Blob([buffer], { type: 'image/png'});
		var link = document.createElement('a');
		link.href = window.URL.createObjectURL(blob);
		link.download = fileName;
		link.click();
	};
	""", true)
	
	
func load_image()->Image:
	if not is_web():
		return
		
	#Execute js function
	JavaScriptBridge.eval("upload();", true)	#opens promt for choosing file
	
	#label.text = "Wait for focus"
	await self.InFocus	#wait until js promt is closed
	
	#label.text = "Timer on for loading"
	await get_tree().create_timer(0.1).timeout	#give some time for async js data load
	
	if JavaScriptBridge.eval("canceled;", true):	# if File Dialog closed w/o file
		#label.text = "Canceled prompt"
		return
	
	# use data from png data
	#label.text = "Load image"
	var imageData
	while true:
		imageData = JavaScriptBridge.eval("fileData;", true)
		if imageData != null:
			break
		#label.text = "No image yet"
		await get_tree().create_timer(1.0).timeout	#need more time to load data
	
	var imageType = JavaScriptBridge.eval("fileType;", true)
	var imageName = JavaScriptBridge.eval("fileName;", true)
	
	var image = Image.new()
	var image_error
	match imageType:
		"image/png":
			image_error = image.load_png_from_buffer(imageData)
		"image/jpeg":
			image_error = image.load_jpg_from_buffer(imageData)
		"image/webp":
			image_error = image.load_webp_from_buffer(imageData)
		var invalidType:
			#label.text = "Unsupported file format - %s." % invalidType
			return
	if image_error:
		#label.text = "An error occurred while trying to display the image."
		return
	else:
		return image
		# Display texture
		var tex = ImageTexture.new()
		tex.create_from_image(image) #,0 # Flag = 0 or else export is fucked!
		Sprite2D.texture = tex
		#loadedImage = image # Keep Image for later, just in case...
		#loadedImageName = imageName
		#label.text = "Image %s loaded as %s." % [imageName, imageType]
		return
	#label.text = "Something went wrong"


func save_image(image:Image, fileName:String = "export")->void:
	if not is_web():
		return
		
	image.clear_mipmaps()
	if image.save_png("user://export_temp.png"):
		#label.text = "Error saving temp file"
		return
	var file:FileAccess
	if file.open("user://export_temp.png", FileAccess.READ):
		#label.text = "Error opening file"
		return
	var pngData = Array(file.get_buffer(file.get_length()))	#read data as PackedByteArray and convert it to Array for JS
	file.close()
	var dir : DirAccess
	dir.remove("user://export_temp.png")
	JavaScriptBridge.eval("download('%s', %s);" % [fileName, str(pngData)], true)
	#label.text = "Saving DONE"
