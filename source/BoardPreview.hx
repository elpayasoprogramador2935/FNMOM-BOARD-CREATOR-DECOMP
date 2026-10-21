package;

import openfl.display.BitmapData;
import openfl.geom.Matrix;

private typedef Piece = {image:BitmapData, x:Float, y:Float};

class BoardPreview
{
	static inline var SCALE:Float = 2.5;
	static inline var MARGIN:Int = 8;

	static var tileImages:Map<String, BitmapData> = new Map();
	static var charImages:Map<String, BitmapData> = new Map();

	public static function render(json:Dynamic, width:Int, height:Int):BitmapData
	{
		var canvas = new BitmapData(width, height, true, 0xFF15151B);
		var pieces:Array<Piece> = [];

		var tiles:Array<Dynamic> = json.tiles;
		for (saved in tiles)
			pieces.push(piece(tileImage(Std.string(saved[2])), saved[0], saved[1]));

		for (group in [json.villains, json.actorsPosition])
		{
			for (name in Reflect.fields(group))
			{
				var position:Array<Dynamic> = Reflect.field(group, name);
				pieces.push(piece(charImage(name), position[0], position[1]));
			}
		}

		if (pieces.length == 0)
			return canvas;

		var left = Math.POSITIVE_INFINITY;
		var top = Math.POSITIVE_INFINITY;
		var right = Math.NEGATIVE_INFINITY;
		var bottom = Math.NEGATIVE_INFINITY;

		for (item in pieces)
		{
			left = Math.min(left, item.x);
			top = Math.min(top, item.y);
			right = Math.max(right, item.x + item.image.width * SCALE);
			bottom = Math.max(bottom, item.y + item.image.height * SCALE);
		}

		var zoom = Math.min((width - MARGIN * 2) / (right - left), (height - MARGIN * 2) / (bottom - top));
		var offsetX = (width - (right - left) * zoom) / 2;
		var offsetY = (height - (bottom - top) * zoom) / 2;

		for (item in pieces)
		{
			var matrix = new Matrix();
			matrix.scale(SCALE * zoom, SCALE * zoom);
			matrix.translate(offsetX + (item.x - left) * zoom, offsetY + (item.y - top) * zoom);
			canvas.draw(item.image, matrix, null, null, null, true);
		}

		return canvas;
	}

	static function piece(image:BitmapData, x:Float, y:Float):Piece
	{
		return {
			image: image,
			x: x + image.width / 2 - image.width * SCALE / 2,
			y: y + image.height / 2 - image.height * SCALE / 2
		};
	}

	static function tileImage(material:String):BitmapData
	{
		if (!tileImages.exists(material))
		{
			var tile = new BoardTile(0, 0, material);
			tileImages.set(material, tile.updateFramePixels().clone());
			tile.destroy();
		}
		return tileImages.get(material);
	}

	static function charImage(name:String):BitmapData
	{
		if (!charImages.exists(name))
		{
			var char = new GodziChar(0, 0, name);
			charImages.set(name, char.updateFramePixels().clone());
			char.destroy();
		}
		return charImages.get(name);
	}
}
