package;

import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.addons.ui.FlxUI;
import flixel.addons.ui.FlxUIButton;
import flixel.addons.ui.FlxUICheckBox;
import flixel.addons.ui.FlxUITabMenu;
import flixel.text.FlxText;
import flixel.util.FlxColor;

typedef Link = {a:Int, b:Int, twoWay:Bool};

class Connections
{
	static var OPPOSITE:Array<Int> = [1, 0, 5, 4, 3, 2];

	var camera:FlxCamera;
	var getTiles:Void->Array<BoardTile>;
	var getMovemap:Void->Map<String, Array<Dynamic>>;
	var beforeChange:Void->Void;

	var links:Array<Link> = [];
	var source:BoardTile;
	var hoverTile:BoardTile;
	var hoverLink:Link;
	var showAlways:Bool = false;

	var lines:Array<Line> = [];
	var dot:FlxSprite;
	var count:FlxText;

	public function new(camera:FlxCamera, getTiles:Void->Array<BoardTile>, getMovemap:Void->Map<String, Array<Dynamic>>, beforeChange:Void->Void)
	{
		this.beforeChange = beforeChange;
		this.camera = camera;
		this.getTiles = getTiles;
		this.getMovemap = getMovemap;

		dot = new FlxSprite();
		dot.makeGraphic(1, 1, FlxColor.WHITE);
	}

	public function buildTab(box:FlxUITabMenu)
	{
		var help = new FlxText(10, 25, 280, "Drag from one tile to another to connect them.\nRight click on a line to delete it.\nESC cancels the connection you are drawing.");
		count = new FlxText(10, 85, 0, "Connections: 0");

		var everywhere = new FlxUICheckBox(10, 110, null, null, "Show connections in every tab", 200);
		everywhere.callback = function()
		{
			showAlways = everywhere.checked;
		};

		var clearButton = new FlxUIButton(10, 145, "Clear connections", function()
		{
			beforeChange();
			var movemap = getMovemap();
			for (key in [for (k in movemap.keys()) k])
				movemap.remove(key);
		});

		clearButton.resize(120, 24);

		var group = new FlxUI(null, box);
		group.name = "Movemap";
		group.add(help);
		group.add(count);
		group.add(everywhere);
		group.add(clearButton);
		box.addGroup(group);
	}

	public function update(active:Bool, overUI:Bool)
	{
		var tiles = getTiles();
		var movemap = getMovemap();
		links = collect(tiles, movemap);

		if (!active)
		{
			source = null;
			hoverTile = null;
			hoverLink = null;
			return;
		}

		var mx = FlxG.mouse.x;
		var my = FlxG.mouse.y;
		hoverTile = overUI ? null : BoardTile.at(tiles, mx, my);
		hoverLink = (overUI || source != null) ? null : linkAt(tiles, mx, my);

		var changed = false;

		if (FlxG.keys.justPressed.ESCAPE)
			source = null;

		if (source != null)
		{
			if (!FlxG.mouse.pressed)
			{
				if (hoverTile != null && hoverTile != source)
				{
					beforeChange();
					connect(movemap, source, hoverTile);
					changed = true;
				}
				source = null;
			}
		}
		else if (FlxG.mouse.justPressed && hoverTile != null)
		{
			source = hoverTile;
		}

		if (FlxG.mouse.justPressedRight && hoverLink != null)
		{
			beforeChange();
			disconnect(movemap, hoverLink.a, hoverLink.b);
			hoverLink = null;
			changed = true;
		}

		if (changed)
			links = collect(tiles, movemap);

		count.text = "Connections: " + links.length;
	}

	public function draw(active:Bool)
	{
		if (!active && !showAlways)
			return;

		var tiles = getTiles();
		var thickness = 3 / camera.zoom;

		for (i in 0...links.length)
		{
			var link = links[i];
			var color = link == hoverLink ? FlxColor.YELLOW : (link.twoWay ? FlxColor.CYAN : FlxColor.ORANGE);
			drawLine(i, tiles[link.a].hexCenterX(), tiles[link.a].hexCenterY(), tiles[link.b].hexCenterX(), tiles[link.b].hexCenterY(), color, thickness);
		}

		if (!active)
			return;

		for (tile in tiles)
			drawDot(tile.hexCenterX(), tile.hexCenterY(), 8 / camera.zoom, FlxColor.WHITE);

		if (hoverTile != null && hoverTile != source)
			drawDot(hoverTile.hexCenterX(), hoverTile.hexCenterY(), 14 / camera.zoom, FlxColor.YELLOW);

		if (source != null)
		{
			var valid = hoverTile != null && hoverTile != source;
			var tx = valid ? hoverTile.hexCenterX() : FlxG.mouse.x;
			var ty = valid ? hoverTile.hexCenterY() : FlxG.mouse.y;

			drawLine(links.length, source.hexCenterX(), source.hexCenterY(), tx, ty, valid ? FlxColor.LIME : FlxColor.WHITE, thickness);
			drawDot(source.hexCenterX(), source.hexCenterY(), 14 / camera.zoom, FlxColor.LIME);
		}
	}

	public static function fill(movemap:Map<String, Array<Dynamic>>, tiles:Array<BoardTile>)
	{
		for (tile in tiles)
			entry(movemap, tile.ID);
	}

	static function entry(movemap:Map<String, Array<Dynamic>>, id:Int):Array<Dynamic>
	{
		var key = Std.string(id);
		if (!movemap.exists(key))
			movemap.set(key, [null, null, null, null, null, null]);

		return movemap.get(key);
	}

	static function unlink(movemap:Map<String, Array<Dynamic>>, id:Int, slot:Int)
	{
		var mine = movemap.get(Std.string(id));
		if (mine == null || mine[slot] == null)
			return;

		var other = Std.string(mine[slot]);
		mine[slot] = null;

		var theirs = movemap.get(other);
		if (theirs != null && theirs[OPPOSITE[slot]] == id)
			theirs[OPPOSITE[slot]] = null;
	}

	static function disconnect(movemap:Map<String, Array<Dynamic>>, a:Int, b:Int)
	{
		for (slot in 0...6)
		{
			var mine = movemap.get(Std.string(a));
			if (mine != null && mine[slot] == b)
				unlink(movemap, a, slot);

			var theirs = movemap.get(Std.string(b));
			if (theirs != null && theirs[slot] == a)
				unlink(movemap, b, slot);
		}
	}

	static function connect(movemap:Map<String, Array<Dynamic>>, a:BoardTile, b:BoardTile)
	{
		var dx = b.hexCenterX() - a.hexCenterX();
		var dy = b.hexCenterY() - a.hexCenterY();
		if (dx * dx + dy * dy < 1)
			return;

		var slot = slotToward(dx, dy, a.stepX(), a.stepY());

		disconnect(movemap, a.ID, b.ID);
		unlink(movemap, a.ID, slot);
		unlink(movemap, b.ID, OPPOSITE[slot]);

		entry(movemap, a.ID)[slot] = b.ID;
		entry(movemap, b.ID)[OPPOSITE[slot]] = a.ID;
	}

	static function slotToward(dx:Float, dy:Float, sx:Float, sy:Float):Int
	{
		var vx:Array<Float> = [0.0, 0.0, sx, sx, -sx, -sx];
		var vy:Array<Float> = [-sy, sy, -sy / 2, sy / 2, -sy / 2, sy / 2];
		var best = 0;
		var bestAlong = Math.NEGATIVE_INFINITY;

		for (i in 0...6)
		{
			var along = (dx * vx[i] + dy * vy[i]) / Math.sqrt(vx[i] * vx[i] + vy[i] * vy[i]);
			if (along > bestAlong)
			{
				best = i;
				bestAlong = along;
			}
		}
		return best;
	}

	function collect(tiles:Array<BoardTile>, movemap:Map<String, Array<Dynamic>>):Array<Link>
	{
		var found:Array<Link> = [];

		for (key in movemap.keys())
		{
			var id = Std.parseInt(key);
			if (id == null || id >= tiles.length)
				continue;

			var slots = movemap.get(key);
			for (slot in 0...6)
			{
				var other:Null<Int> = slots[slot];
				if (other == null || other >= tiles.length)
					continue;

				var back = movemap.get(Std.string(other));
				var twoWay = back != null && back[OPPOSITE[slot]] == id;
				if (twoWay && id > other)
					continue;

				found.push({a: id, b: other, twoWay: twoWay});
			}
		}
		return found;
	}

	function linkAt(tiles:Array<BoardTile>, px:Float, py:Float):Link
	{
		var found:Link = null;
		var closest = 10 / camera.zoom;

		for (link in links)
		{
			var distance = distanceToSegment(px, py, tiles[link.a].hexCenterX(), tiles[link.a].hexCenterY(), tiles[link.b].hexCenterX(), tiles[link.b].hexCenterY());
			if (distance < closest)
			{
				found = link;
				closest = distance;
			}
		}
		return found;
	}

	function distanceToSegment(px:Float, py:Float, x1:Float, y1:Float, x2:Float, y2:Float):Float
	{
		var dx = x2 - x1;
		var dy = y2 - y1;
		var lengthSquared = dx * dx + dy * dy;
		var t = lengthSquared == 0 ? 0 : Math.max(0, Math.min(1, ((px - x1) * dx + (py - y1) * dy) / lengthSquared));
		var nearestX = x1 + t * dx;
		var nearestY = y1 + t * dy;

		return Math.sqrt((px - nearestX) * (px - nearestX) + (py - nearestY) * (py - nearestY));
	}

	function drawLine(index:Int, x1:Float, y1:Float, x2:Float, y2:Float, color:FlxColor, thickness:Float)
	{
		while (index >= lines.length)
			lines.push(new Line());

		var dx = x2 - x1;
		var dy = y2 - y1;
		var line = lines[index];

		line.setPosition(x1, y1 - 0.5);
		line.scale.set(Math.sqrt(dx * dx + dy * dy), thickness);
		line.angle = Math.atan2(dy, dx) * 180 / Math.PI;
		line.color = color;
		line.draw();
	}

	function drawDot(cx:Float, cy:Float, size:Float, color:FlxColor)
	{
		dot.setPosition(cx - 0.5, cy - 0.5);
		dot.scale.set(size, size);
		dot.color = color;
		dot.draw();
	}
}

private class Line extends FlxSprite
{
	public function new()
	{
		super();
		makeGraphic(1, 1, FlxColor.WHITE);
		origin.set(0, 0.5);
	}

	override public function isOnScreen(?camera:FlxCamera):Bool
	{
		return true;
	}
}
