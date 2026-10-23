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

		var area = bounds(pieces);
		var zoom = Math.min((width - MARGIN * 2) / (area.right - area.left), (height - MARGIN * 2) / (area.bottom - area.top));
		var offsetX = (width - (area.right - area.left) * zoom) / 2;
		var offsetY = (height - (area.bottom - area.top) * zoom) / 2;

		for (item in pieces)
		{
			var matrix = new Matrix();
			matrix.scale(SCALE * zoom, SCALE * zoom);
			matrix.translate(offsetX + (item.x - area.left) * zoom, offsetY + (item.y - area.top) * zoom);
			canvas.draw(item.image, matrix, null, null, null, true);
		}

		return canvas;
	}

	public static function capture(tiles:Array<BoardTile>, chars:Array<GodziChar>):BitmapData
	{
		var pieces:Array<Piece> = [];

		for (tile in tiles)
			pieces.push(piece(tileImage(tile.material), tile.x, tile.y));

		for (char in chars)
		{
			pieces.push({
				image: charImage(char.curChar),
				x: char.x - char.offset.x + char.origin.x * (1 - SCALE),
				y: char.y - char.offset.y + char.origin.y * (1 - SCALE)
			});
		}

		var area = bounds(pieces);
		var canvas = new BitmapData(Math.ceil(area.right - area.left), Math.ceil(area.bottom - area.top), true, 0);

		for (item in pieces)
		{
			var matrix = new Matrix();
			matrix.scale(SCALE, SCALE);
			matrix.translate(Math.round(item.x - area.left), Math.round(item.y - area.top));
			canvas.draw(item.image, matrix);
		}

		return canvas;
	}

	static function bounds(pieces:Array<Piece>)
	{
		var area = {
			left: Math.POSITIVE_INFINITY,
			top: Math.POSITIVE_INFINITY,
			right: Math.NEGATIVE_INFINITY,
			bottom: Math.NEGATIVE_INFINITY
		};

		for (item in pieces)
		{
			area.left = Math.min(area.left, item.x);
			area.top = Math.min(area.top, item.y);
			area.right = Math.max(area.right, item.x + item.image.width * SCALE);
			area.bottom = Math.max(area.bottom, item.y + item.image.height * SCALE);
		}

		return area;
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
