package;

import flixel.addons.ui.FlxUI;
import flixel.addons.ui.FlxUIButton;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import haxe.io.Path;
#if html5
import openfl.events.Event;
import openfl.net.FileFilter;
import openfl.net.FileReference;
#end

class BoardList
{
	static inline var ROWS:Int = 10;
	static inline var ROW_HEIGHT:Int = 22;

	var suffix:String;
	var open:String->Void;

	var files:Array<String> = [];
	var rows:Array<FlxUIButton> = [];
	var status:FlxText;
	var deleteButton:FlxUIButton;
	var selected:Int = -1;
	var scroll:Int = 0;
	var armed:Bool = false;
	#if html5
	var importing:FileReference;
	#end

	public function new(suffix:String, open:String->Void)
	{
		this.suffix = suffix;
		this.open = open;
	}

	public function build(group:FlxUI, x:Float, y:Float, save:Void->Void)
	{
		status = new FlxText(x, y, 280);
		group.add(status);

		for (i in 0...ROWS)
		{
			var row = new FlxUIButton(x, y + 17 + i * ROW_HEIGHT, "", function() pick(scroll + i));
			row.resize(280, 20);
			rows.push(row);
			group.add(row);
		}

		var top = y + 23 + ROWS * ROW_HEIGHT;
		var openButton = new FlxUIButton(x, top, "Open", load);
		deleteButton = new FlxUIButton(x + 71, top, "Delete", removeSelected);
		#if html5
		var thirdButton = new FlxUIButton(x + 142, top, "Import", importBoard);
		#else
		var thirdButton = new FlxUIButton(x + 142, top, "Refresh", function() refresh());
		#end
		var saveButton = new FlxUIButton(x + 213, top, "Save here", save);

		for (button in [openButton, deleteButton, thirdButton, saveButton])
		{
			button.resize(66, 24);
			group.add(button);
		}

		refresh();
	}

	public function refresh(?keep:String)
	{
		var name = keep != null ? keep : (selected >= 0 ? files[selected] : null);

		files = [for (file in BoardStore.list()) if (StringTools.endsWith(Path.withoutExtension(file), suffix)) file];
		files.sort(Reflect.compare);
		selected = name != null ? files.indexOf(name) : -1;

		if (selected >= 0)
			scroll = Std.int(Math.min(Math.max(scroll, selected - ROWS + 1), selected));
		scroll = Std.int(Math.min(scroll, Math.max(0, files.length - ROWS)));

		disarm();
	}

	public function scrollBy(wheel:Int)
	{
		scroll = Std.int(Math.min(Math.max(0, scroll - wheel), Math.max(0, files.length - ROWS)));
	}

	public function update()
	{
		status.text = files.length == 0 ? "No boards in " + BoardStore.LOCATION : "Saved boards: " + files.length;

		for (i in 0...ROWS)
		{
			var index = scroll + i;
			var row = rows[i];
			row.visible = index < files.length;
			row.active = row.visible;

			if (!row.visible)
				continue;

			row.label.text = title(files[index]);
			row.color = index == selected ? FlxColor.CYAN : FlxColor.WHITE;
		}
	}

	function pick(index:Int)
	{
		if (index >= files.length)
			return;

		selected = index;
		disarm();
	}

	function load()
	{
		if (selected >= 0)
			open(files[selected]);
	}

	function removeSelected()
	{
		if (selected < 0)
			return;

		if (!armed)
		{
			armed = true;
			deleteButton.label.text = "Sure?";
			return;
		}

		BoardStore.delete(files[selected]);
		selected = -1;
		refresh();
	}

	#if html5
	function importBoard()
	{
		importing = new FileReference();
		importing.addEventListener(Event.SELECT, function(_) importing.load());
		importing.addEventListener(Event.COMPLETE, function(_)
		{
			var name = Path.withoutExtension(importing.name);
			if (!StringTools.endsWith(name, suffix))
				name += suffix;

			BoardStore.write(name + ".json", importing.data.toString());
			refresh(name + ".json");
		});
		importing.browse([new FileFilter("Board", "*.json")]);
	}
	#end

	function disarm()
	{
		armed = false;

		if (deleteButton != null)
			deleteButton.label.text = "Delete";
	}

	function title(file:String):String
	{
		var name = Path.withoutExtension(file);
		return StringTools.endsWith(name, suffix) ? name.substr(0, name.length - suffix.length) : name;
	}
}
