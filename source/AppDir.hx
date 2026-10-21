package;

import haxe.io.Path;
#if sys
import lime.system.System;
#end

class AppDir
{
	public static function of(path:String):String
	{
		#if sys
		return Path.join([System.applicationDirectory, path]);
		#else
		return path;
		#end
	}
}
