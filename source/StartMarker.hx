package;

import flixel.FlxSprite;
import openfl.display.BitmapData;
import openfl.utils.AssetType;
import openfl.utils.Assets;
#if sys
import sys.FileSystem;
#end

class StartMarker extends FlxSprite
{
	static inline var PATH:String = "assets/images/cuadroblanco.png";

	public function new()
	{
		super();
		antialiasing = false;

		if (Assets.exists(PATH, AssetType.IMAGE))
			loadGraphic(PATH);
		#if sys
		else if (FileSystem.exists(AppDir.of(PATH)))
			loadGraphic(BitmapData.fromFile(AppDir.of(PATH)), false, 0, 0, false, PATH);
		#end
		else
			makeGraphic(32, 32, 0x80FFFFFF);

		scale.set(2.3, 2.3);
	}

	public function placeOn(tile:BoardTile)
	{
		setPosition(tile.hexCenterX() - width / 2, tile.hexCenterY() - height / 2);
	}
}
