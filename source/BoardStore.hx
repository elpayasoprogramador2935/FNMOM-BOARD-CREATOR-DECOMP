package;

import haxe.io.Bytes;
import haxe.io.Path;
#if sys
import sys.FileSystem;
import sys.io.File;
#else
import openfl.net.SharedObject;
#end

class BoardStore
{
	#if sys
	static inline var NAME:String = "assets/data";

	public static inline var LOCATION:String = NAME;

	static var FOLDER:String = AppDir.of(NAME);

	public static function list():Array<String>
	{
		if (!FileSystem.exists(FOLDER))
			return [];

		return [for (file in FileSystem.readDirectory(FOLDER)) if (Path.extension(file) == "json") file];
	}

	public static function read(file:String):String
	{
		return File.getContent(FOLDER + "/" + file);
	}

	public static function write(file:String, content:String)
	{
		if (!FileSystem.exists(FOLDER))
			FileSystem.createDirectory(FOLDER);

		File.saveContent(FOLDER + "/" + file, content);
	}

	public static function writeImage(file:String, content:Bytes)
	{
		if (!FileSystem.exists(FOLDER))
			FileSystem.createDirectory(FOLDER);

		File.saveBytes(FOLDER + "/" + file, content);
	}

	public static function delete(file:String)
	{
		FileSystem.deleteFile(FOLDER + "/" + file);
	}
	#else
	public static inline var LOCATION:String = "browser storage";

	public static function list():Array<String>
	{
		return Reflect.fields(boards());
	}

	public static function read(file:String):String
	{
		return Reflect.field(boards(), file);
	}

	public static function write(file:String, content:String)
	{
		Reflect.setField(boards(), file, content);
		storage().flush();
	}

	public static function delete(file:String)
	{
		Reflect.deleteField(boards(), file);
		storage().flush();
	}

	static function storage():SharedObject
	{
		return SharedObject.getLocal("boardcreator");
	}

	static function boards():Dynamic
	{
		var data = storage().data;
		if (data.boards == null)
			data.boards = {};
		return data.boards;
	}
	#end
}
