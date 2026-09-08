@tool
class_name AceFileUtil extends Node

const ADDON_PARENT_DIR :String = "addons/"

class Zip:
	static func extract_all_from_zip(zip_file: String, dest_dir: String, subfolder: String="") -> void:
		var reader: ZIPReader = ZIPReader.new()
		reader.open(zip_file)

		var root_dir: DirAccess = DirAccess.open(dest_dir)
		var zip_file_path:String = ""
		var files: Array[String] = []
		files.assign(reader.get_files())


		if(subfolder.contains(ADDON_PARENT_DIR)):
			# Filter all the files that have the addons subfolder
			files = files.filter(func(file): return file.contains(subfolder))

			var _zip_file_index:int = files[0].find(ADDON_PARENT_DIR)
			zip_file_path = files[0].substr(0, _zip_file_index + ADDON_PARENT_DIR.length())

			AceLog.printLog(["Zip File Path: %s" % zip_file_path], AceLog.LOG_LEVEL.DEBUG)

			#Remove everything including and before the addons/ folder in the subfolder path
			var subFileList: Array = files.map(func(file) -> String:
				var index: int = file.find(ADDON_PARENT_DIR)
				return file.substr(index + ADDON_PARENT_DIR.length())
			)

			var newFiles: Array[String] = []
			newFiles.assign(subFileList)
			files = newFiles

		else:
			AceLog.printLog(["The subfolder %s does not contain the required addons/ parent folder. Ignoring subfolder." % subfolder], AceLog.LOG_LEVEL.WARN)

		
		AceLog.printLog(["Extracting files from zip: %s" % zip_file, files ], AceLog.LOG_LEVEL.DEBUG)
		for file_path in files:
			if file_path.ends_with("/"):
				# It's a directory
				root_dir.make_dir_recursive(file_path)
				continue
			if file_path.ends_with(".zip"):
				AceLog.printLog(["Skipping zip file: %s" % file_path], AceLog.LOG_LEVEL.DEBUG)
				continue
			 # Ensure the directory structure exists before writing the file 
		
			root_dir.make_dir_recursive(root_dir.get_current_dir().path_join(file_path).get_base_dir())
			var file = FileAccess.open(root_dir.get_current_dir().path_join(file_path), FileAccess.WRITE)
			var buffer = reader.read_file(zip_file_path + file_path)
			file.store_buffer(buffer)
		
		#Delete Zip File after extraction
		AceLog.printLog(["Deleting zip file: %s" % zip_file], AceLog.LOG_LEVEL.DEBUG)
		DirAccess.remove_absolute(zip_file)
	

	static func read_zip_file(zip_file: String, file: String) -> PackedByteArray:
		var reader: ZIPReader = ZIPReader.new()
		var err = reader.open(zip_file)
		if err != OK:
			return PackedByteArray()
		var res = reader.read_file(file)
		reader.close()
		return res

class Config:
	static func load_config(path: String) -> ConfigFile:
		var config = ConfigFile.new()
		var err = config.load(path)
		if err != OK:
			AceLog.printLog(["Failed to load config file at path: %s. Error code: %d" % [path, err]], AceLog.LOG_LEVEL.ERROR)
			return null
		
		return config
	
	static func save_config(config: ConfigFile, path: String) -> bool:
		var err = config.save(path)
		if err != OK:
			AceLog.printLog(["Failed to save config file at path: %s. Error code: %d" % [path, err]], AceLog.LOG_LEVEL.ERROR)
			return false
		
		return true

class File:
	static func file_exists(path: String) -> bool:
		return FileAccess.file_exists(path)
	
	static func create_file(path: String, accessMode: FileAccess.ModeFlags = FileAccess.READ) -> FileAccess:
		var file = FileAccess.open(path, accessMode)
		return file
	
	static func move_folder(editor_interface: EditorInterface, from_dir: String, to_dir: String, ignore_file_ext: Array[String]=[]):
		AceLog.printLog(["Moving files from %s to %s" % [from_dir, to_dir]], AceLog.LOG_LEVEL.DEBUG)
		# Ensure source exists
		if not DirAccess.dir_exists_absolute(from_dir):
			printerr("Source directory does not exist: ", from_dir)
			return

		# Create destination if it doesn't exist
		if not DirAccess.dir_exists_absolute(to_dir):
			DirAccess.make_dir_recursive_absolute(to_dir)

		# 1. Copy files and subfolders
		var dir = DirAccess.open(from_dir)
		if dir:
			dir.list_dir_begin()
			var file_name = dir.get_next()
			while file_name != "":
				if file_name != "." and file_name != ".." and !_should_ignore_file(file_name, ignore_file_ext):
					var old_path = from_dir.path_join(file_name)
					var new_path = to_dir.path_join(file_name)
					
					if dir.current_is_dir():
						# Recursive call for subdirectories
						move_folder(editor_interface, old_path, new_path, ignore_file_ext)
						# Cleanup: Remove the original source folder once contents are moved
						_remove_recursive(old_path)
					else:
						# DirAccess.copy_absolute automatically overwrites existing files
						DirAccess.copy_absolute(old_path, new_path)
				file_name = dir.get_next()
				
		# 2. Cleanup: Remove the original source folder once contents are moved
		# _remove_recursive(from_dir)

		# 3. scan for changes
		if editor_interface != null:
			editor_interface.get_resource_filesystem().scan()

	static func delete_matching_items(target_dir: String, substring: String):
		AceLog.printLog(["Deleting files matching '%s' in directory: %s" % [substring, target_dir]], AceLog.LOG_LEVEL.DEBUG)
		var dir = DirAccess.open(target_dir)
		if not dir:
			AceLog.printLog(["Critical Error: Could not open root directory: %s" % target_dir], AceLog.LOG_LEVEL.ERROR)
			return

		# 1. Handle matching files
		for file_name in dir.get_files():
			if substring in file_name:
				var err = dir.remove(file_name)
				if err != OK:
					AceLog.printLog(["Failed to delete file: %s in directory: %s. Error code: %d" % [file_name, target_dir, err]], AceLog.LOG_LEVEL.ERROR)

		# 2. Handle subdirectories
		for dir_name in dir.get_directories():
			var full_path = target_dir.path_join(dir_name)
			
			if substring in dir_name:
				# If the folder name matches, wipe it entirely
				_delete_recursive(full_path)
			else:
				# If not, look inside it for matches
				delete_matching_items(full_path, substring)

	static func _delete_recursive(path: String):
		var dir = DirAccess.open(path)
		if dir:
			# Empty the files first
			for file in dir.get_files():
				var err = dir.remove(file)
				if err != OK:
					AceLog.printLog(["Error deleting file '", file, "' in '", path, "'. Error code: ", err], AceLog.LOG_LEVEL.ERROR)
			
			# Recurse into sub-folders
			for sub_dir in dir.get_directories():
				_delete_recursive(path.path_join(sub_dir))
			
		# Finally, delete the (now empty) folder
		var err = DirAccess.remove_absolute(path)
		if err != OK:
			AceLog.printLog(["Failed to remove directory '", path, "'. Error code: ", err], AceLog.LOG_LEVEL.ERROR)
		else:
			AceLog.printLog(["Successfully deleted: ", path], AceLog.LOG_LEVEL.INFO)

	static func _should_ignore_file(file_name: String, ignore_file_ext: Array[String]) -> bool:
		AceLog.printLog(["Checking if file should be ignored: %s" % file_name], AceLog.LOG_LEVEL.DEBUG)
		for ignore in ignore_file_ext:
			if file_name == ignore or file_name.ends_with(ignore):
				AceLog.printLog(["Ignoring file: %s due to matching ignore pattern: %s" % [file_name, ignore]], AceLog.LOG_LEVEL.DEBUG)
				return true
		return false
	static func _remove_recursive(path: String):
		var dir = DirAccess.open(path)
		if dir:
			dir.list_dir_begin()
			var file_name = dir.get_next()
			while file_name != "":
				if file_name != "." and file_name != "..":
					var full_path = path.path_join(file_name)
					if dir.current_is_dir():
						_remove_recursive(full_path)
					else:
						DirAccess.remove_absolute(full_path)
				file_name = dir.get_next()
			DirAccess.remove_absolute(path)
