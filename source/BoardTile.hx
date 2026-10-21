package;

import flixel.FlxG;
import flixel.FlxSprite;
import openfl.display.BitmapData;
import openfl.geom.Rectangle;
import openfl.utils.AssetType;
import openfl.utils.Assets;
#if sys
import sys.FileSystem;
#end

class BoardTile extends FlxSprite
{
	static inline var DEFAULT_MATERIAL:String = "squareOrange";

	public var tileOwner:String;
	public var isEnemy:Bool = false;
	public var canGo:Bool = false;
	public var isAlly:Bool = false;
	public var material:String;
	public var hexBounds:Rectangle;

	var topEdge:Float = 0;

	public function new(x:Float, y:Float, ?material:String = DEFAULT_MATERIAL)
	{
		super(x, y);
		this.material = loadMaterial(material);
		antialiasing = false;
		measureHex();
	}

	public function setTileOwnerShip(owner:String, isEnemy:Bool, canGo:Bool)
	{
		tileOwner = owner;
		this.isEnemy = isEnemy;
		this.canGo = canGo;
	}

	function loadMaterial(name:String):String
	{
		var path = 'assets/images/materials/$name.png';

		if (Assets.exists(path, AssetType.IMAGE) || FlxG.bitmap.checkCache(path))
			loadGraphic(path);
		#if sys
		else if (FileSystem.exists(AppDir.of(path)))
			loadGraphic(BitmapData.fromFile(AppDir.of(path)), false, 0, 0, false, path);
		#end
		else
		{
			trace('el material "$name" no existe, se usa $DEFAULT_MATERIAL');
			name = DEFAULT_MATERIAL;
			loadGraphic('assets/images/materials/$name.png');
		}
		return name;
	}

	function measureHex()
	{
		hexBounds = pixels.getColorBoundsRect(0x80000000, 0x80000000, true);
		if (hexBounds.width == 0)
			hexBounds = new Rectangle(0, 0, frameWidth, frameHeight);

		for (i in 0...Std.int(hexBounds.width))
		{
			if ((pixels.getPixel32(Std.int(hexBounds.x) + i, Std.int(hexBounds.y)) >>> 24) >= 128)
				topEdge++;
		}
		if (topEdge == 0)
			topEdge = hexBounds.width / 2;
	}

	public function hexCenterX():Float
	{
		return x + width / 2 + (hexBounds.x + hexBounds.width / 2 - width / 2) * scale.x;
	}

	public function hexCenterY():Float
	{
		return y + height / 2 + (hexBounds.y + hexBounds.height / 2 - height / 2) * scale.y;
	}

	public function stepX():Int
	{
		return Math.round((hexBounds.width + topEdge) / 2 * scale.x);
	}

	public function stepY():Int
	{
		return Math.round(hexBounds.height * scale.y);
	}

	public function centerOn(cx:Float, cy:Float)
	{
		x = Math.round(x + cx - hexCenterX());
		y = Math.round(y + cy - hexCenterY());
	}

	public static function at(tiles:Array<BoardTile>, px:Float, py:Float):BoardTile
	{
		var found:BoardTile = null;
		var closest = Math.POSITIVE_INFINITY;

		for (tile in tiles)
		{
			var dx = px - tile.hexCenterX();
			var dy = py - tile.hexCenterY();
			var dist = dx * dx + dy * dy;
			var inside = Math.abs(dx) <= tile.hexBounds.width * tile.scale.x / 2 && Math.abs(dy) <= tile.hexBounds.height * tile.scale.y / 2;

			if (inside && dist <= closest)
			{
				found = tile;
				closest = dist;
			}
		}
		return found;
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);
	}
}
