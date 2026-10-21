package;

import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.addons.ui.FlxUIInputText;
import flixel.math.FlxPoint;
import flixel.text.FlxText;

class Palette
{
	static inline var COLS:Int = 4;
	static inline var CELL:Int = 70;

	public var names:Array<String> = [];
	public var items:Array<FlxSprite> = [];
	public var selected:Int = -1;
	public var typing(get, never):Bool;

	var state:FlxState;
	var camera:FlxCamera;
	var rows:Int;
	var scroll:Int = 0;
	var back:FlxSprite;
	var mark:FlxSprite;
	var label:FlxText;
	var search:FlxUIInputText;
	var query:String = "";
	var shown:Array<Int> = [];
	var pointer:FlxPoint = FlxPoint.get();

	public function new(state:FlxState, camera:FlxCamera, x:Float, y:Float, rows:Int)
	{
		this.state = state;
		this.camera = camera;
		this.rows = rows;

		back = new FlxSprite(x, y);
		back.makeGraphic(COLS * CELL, rows * CELL, 0x40000000);
		back.cameras = [camera];
		state.add(back);

		mark = new FlxSprite();
		mark.makeGraphic(CELL - 4, CELL - 4, 0x66FFFFFF);
		mark.cameras = [camera];
		state.add(mark);

		label = new FlxText(x, y - 22, COLS * CELL, "", 12);
		label.cameras = [camera];
		state.add(label);

		search = new FlxUIInputText(x, y - 46, COLS * CELL, "", 12);
		search.cameras = [camera];
		state.add(search);
	}

	public function add(name:String, sprite:FlxSprite)
	{
		var fit = Math.min((CELL - 14) / sprite.frameWidth, (CELL - 14) / sprite.frameHeight);
		sprite.scale.set(fit, fit);
		sprite.updateHitbox();
		sprite.cameras = [camera];
		state.add(sprite);

		names.push(name);
		items.push(sprite);
		shown.push(items.length - 1);
	}

	public function hovered():Int
	{
		FlxG.mouse.getScreenPosition(camera, pointer);
		var col = Math.floor((pointer.x - back.x) / CELL);
		var row = Math.floor((pointer.y - back.y) / CELL);
		var pos = (row + scroll) * COLS + col;

		if (col < 0 || col >= COLS || row < 0 || row >= rows || pos >= shown.length)
			return -1;
		return shown[pos];
	}

	public function scrollBy(wheel:Int)
	{
		var last = Std.int(Math.max(0, Math.ceil(shown.length / COLS) - rows));
		scroll = Std.int(Math.min(last, Math.max(0, scroll - wheel)));
	}

	public function layout(show:Bool)
	{
		back.visible = show;
		label.visible = show;
		search.visible = show;
		search.active = show;
		mark.visible = false;

		if (!show && search.hasFocus)
			search.hasFocus = false;

		if (search.text != query)
		{
			query = search.text;
			filter();
		}

		var hover = hovered();
		label.text = hover >= 0 ? names[hover] : (selected >= 0 ? names[selected] : "");

		for (item in items)
			item.visible = false;

		for (pos in 0...shown.length)
		{
			var row = Std.int(pos / COLS) - scroll;
			if (!show || row < 0 || row >= rows)
				continue;

			var index = shown[pos];
			var item = items[index];
			item.visible = true;

			var cx = back.x + (pos % COLS) * CELL + CELL / 2;
			var cy = back.y + row * CELL + CELL / 2;
			item.setPosition(cx - item.width / 2, cy - item.height / 2);

			if (index == selected)
			{
				mark.visible = true;
				mark.setPosition(cx - mark.width / 2, cy - mark.height / 2);
			}
		}
	}

	function filter()
	{
		var text = StringTools.trim(query).toLowerCase();
		shown = [for (i in 0...names.length) if (names[i].toLowerCase().indexOf(text) >= 0) i];
		scroll = 0;
	}

	function get_typing():Bool
	{
		return search.hasFocus;
	}
}
