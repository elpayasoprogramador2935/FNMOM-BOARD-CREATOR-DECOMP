package;

import flixel.FlxBasic;
import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.addons.ui.FlxUIButton;
import flixel.group.FlxGroup;
import flixel.math.FlxPoint;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import haxe.Json;
import haxe.Timer;
import haxe.io.Path;
import openfl.display.BitmapData;
#if html5
import openfl.events.Event;
import openfl.net.FileFilter;
import openfl.net.FileReference;
#end

class BoardModal extends FlxGroup
{
	static inline var COLS:Int = 4;
	static inline var ROWS:Int = 3;
	static inline var PAGE_SIZE:Int = COLS * ROWS;
	static inline var GAP:Int = 14;
	static inline var PADDING:Int = 8;
	static inline var NAME_HEIGHT:Int = 22;
	static inline var DOUBLE_CLICK:Float = 0.35;
	static inline var NORMAL:FlxColor = 0xFF2B2B33;
	static inline var HOVER:FlxColor = 0xFF3A3A48;
	static inline var CHOSEN:FlxColor = 0xFF1E5FA8;

	public var isOpen(default, null):Bool = false;

	var suffix:String;
	var load:String->Void;
	var hud:FlxCamera;

	var files:Array<String> = [];
	var thumbs:Map<String, FlxSprite> = new Map();
	var selected:Int = -1;
	var page:Int = 0;
	var armed:Bool = false;
	var lastIndex:Int = -1;
	var lastClick:Float = 0;
	var mouse:FlxPoint = FlxPoint.get();

	var gridX:Int = 0;
	var gridY:Int = 0;
	var cardWidth:Int = 0;
	var cardHeight:Int = 0;
	var thumbWidth:Int = 0;
	var thumbHeight:Int = 0;

	var backdrop:FlxSprite;
	var border:FlxSprite;
	var panel:FlxSprite;
	var title:FlxText;
	var pageLabel:FlxText;
	var emptyLabel:FlxText;
	var cards:Array<FlxSprite> = [];
	var labels:Array<FlxText> = [];

	var saveButton:FlxUIButton;
	var prevButton:FlxUIButton;
	var nextButton:FlxUIButton;
	var openButton:FlxUIButton;
	var deleteButton:FlxUIButton;
	var closeButton:FlxUIButton;
	#if html5
	var importButton:FlxUIButton;
	var importing:FileReference;
	#end

	public function new(suffix:String, load:String->Void, save:Void->Void, hud:FlxCamera)
	{
		super();
		this.suffix = suffix;
		this.load = load;
		this.hud = hud;

		backdrop = block(0xB0000000);
		border = block(0xFF4A4A5A);
		panel = block(0xFF1B1B22);

		title = new FlxText(0, 0, 0, "Boards", 20);
		add(title);

		emptyLabel = new FlxText(0, 0, 0, "No boards yet. Use Save here to create the first one.", 14);
		add(emptyLabel);

		for (i in 0...PAGE_SIZE)
		{
			cards.push(block(FlxColor.WHITE));

			var label = new FlxText(0, 0, 0, "", 12);
			add(label);
			labels.push(label);
		}

		pageLabel = new FlxText(0, 0, 90, "", 12);
		pageLabel.alignment = CENTER;
		add(pageLabel);

		saveButton = button("Save here", 100, save);
		#if html5
		importButton = button("Import", 100, importBoard);
		#end
		prevButton = button("Prev", 70, function() turn(-1));
		nextButton = button("Next", 70, function() turn(1));
		openButton = button("Open", 100, openSelected);
		deleteButton = button("Delete", 100, removeSelected);
		closeButton = button("Close", 100, close);

		visible = false;
		active = false;
	}

	override public function add(basic:FlxBasic):FlxBasic
	{
		basic.cameras = [hud];
		return super.add(basic);
	}

	public function open()
	{
		isOpen = true;
		visible = true;
		active = true;
		layout();
		refresh();
	}

	public function close()
	{
		isOpen = false;
		visible = false;
		active = false;
		disarm();
	}

	public function refresh(?keep:String)
	{
		var name = keep != null ? keep : (selected >= 0 ? files[selected] : null);

		if (keep != null)
			dropThumb(keep);

		files = [for (file in BoardStore.list()) if (StringTools.endsWith(Path.withoutExtension(file), suffix)) file];
		files.sort(Reflect.compare);
		selected = name != null ? files.indexOf(name) : -1;

		if (selected >= 0)
			page = Std.int(selected / PAGE_SIZE);

		disarm();

		if (isOpen)
			showPage();
	}

	override public function update(elapsed:Float)
	{
		super.update(elapsed);

		if (!isOpen)
			return;

		if (FlxG.keys.justPressed.ESCAPE)
		{
			close();
			return;
		}

		FlxG.mouse.getScreenPosition(hud, mouse);

		var hovered = -1;
		for (slot in 0...PAGE_SIZE)
		{
			var card = cards[slot];
			if (card.visible && mouse.x >= card.x && mouse.x < card.x + cardWidth && mouse.y >= card.y && mouse.y < card.y + cardHeight)
				hovered = page * PAGE_SIZE + slot;
		}

		for (slot in 0...PAGE_SIZE)
		{
			var index = page * PAGE_SIZE + slot;
			cards[slot].color = index == selected ? CHOSEN : (index == hovered ? HOVER : NORMAL);
		}

		if (FlxG.mouse.wheel != 0)
			turn(FlxG.mouse.wheel > 0 ? -1 : 1);

		if (FlxG.mouse.justPressed && hovered >= 0)
			pick(hovered);
	}

	function block(color:FlxColor):FlxSprite
	{
		var made = new FlxSprite().makeGraphic(1, 1, color);
		add(made);
		return made;
	}

	function button(label:String, width:Int, onClick:Void->Void):FlxUIButton
	{
		var made = new FlxUIButton(0, 0, label, onClick);
		made.resize(width, 30);
		add(made);
		return made;
	}

	function fill(sprite:FlxSprite, x:Float, y:Float, width:Float, height:Float)
	{
		sprite.setGraphicSize(width, height);
		sprite.updateHitbox();
		sprite.setPosition(x, y);
	}

	function layout()
	{
		var width = Std.int(Math.min(1040, FlxG.width - 80));
		var height = Std.int(Math.min(640, FlxG.height - 60));
		var left = Std.int((FlxG.width - width) / 2);
		var top = Std.int((FlxG.height - height) / 2);
		var right = left + width - 24;
		var bottom = top + height - 52;
		var center = left + width / 2;

		fill(backdrop, 0, 0, FlxG.width, FlxG.height);
		fill(border, left - 2, top - 2, width + 4, height + 4);
		fill(panel, left, top, width, height);
		title.setPosition(left + 24, top + 16);

		gridX = left + 24;
		gridY = top + 56;
		cardWidth = Std.int((width - 48 - GAP * (COLS - 1)) / COLS);
		cardHeight = Std.int((height - 56 - 72 - GAP * (ROWS - 1)) / ROWS);

		var newThumbWidth = cardWidth - PADDING * 2;
		var newThumbHeight = cardHeight - PADDING * 2 - NAME_HEIGHT;
		if (newThumbWidth != thumbWidth || newThumbHeight != thumbHeight)
		{
			for (file in [for (name in thumbs.keys()) name])
				dropThumb(file);

			thumbWidth = newThumbWidth;
			thumbHeight = newThumbHeight;
		}

		for (slot in 0...PAGE_SIZE)
		{
			var column = slot % COLS;
			var row = Std.int(slot / COLS);
			fill(cards[slot], gridX + column * (cardWidth + GAP), gridY + row * (cardHeight + GAP), cardWidth, cardHeight);
			labels[slot].fieldWidth = cardWidth - PADDING * 2;
		}

		emptyLabel.setPosition(left + (width - emptyLabel.width) / 2, top + height / 2 - 20);

		saveButton.setPosition(left + 24, bottom);
		#if html5
		importButton.setPosition(left + 134, bottom);
		#end
		prevButton.setPosition(center - 120, bottom);
		pageLabel.setPosition(center - 45, bottom + 8);
		nextButton.setPosition(center + 50, bottom);
		openButton.setPosition(right - 320, bottom);
		deleteButton.setPosition(right - 210, bottom);
		closeButton.setPosition(right - 100, bottom);
	}

	function showPage()
	{
		var pages = pageCount();
		page = Std.int(Math.min(page, pages - 1));

		for (thumb in thumbs)
			thumb.visible = false;

		for (slot in 0...PAGE_SIZE)
		{
			var index = page * PAGE_SIZE + slot;
			var card = cards[slot];
			var label = labels[slot];
			card.visible = label.visible = index < files.length;

			if (!card.visible)
				continue;

			var thumb = thumbFor(files[index]);
			thumb.visible = true;
			thumb.setPosition(card.x + PADDING, card.y + PADDING);

			label.text = ellipsize(displayName(files[index]), 30);
			label.setPosition(card.x + PADDING, card.y + cardHeight - PADDING - NAME_HEIGHT + 4);
		}

		title.text = "Boards (" + files.length + ")";
		pageLabel.text = "Page " + (page + 1) + " / " + pages;
		pageLabel.visible = pages > 1;
		prevButton.visible = prevButton.active = pages > 1;
		nextButton.visible = nextButton.active = pages > 1;
		emptyLabel.visible = files.length == 0;
	}

	function pageCount():Int
	{
		return Std.int(Math.max(1, Math.ceil(files.length / PAGE_SIZE)));
	}

	function turn(step:Int)
	{
		page = Std.int(Math.max(0, Math.min(page + step, pageCount() - 1)));
		disarm();
		showPage();
	}

	function pick(index:Int)
	{
		var now = Timer.stamp();
		var again = index == lastIndex && now - lastClick < DOUBLE_CLICK;

		selected = index;
		lastIndex = index;
		lastClick = now;
		disarm();

		if (again)
			openSelected();
	}

	function openSelected()
	{
		if (selected < 0)
			return;

		var file = files[selected];
		close();
		load(file);
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

		var file = files[selected];
		BoardStore.delete(file);
		dropThumb(file);
		selected = -1;
		refresh();
	}

	function disarm()
	{
		armed = false;
		deleteButton.label.text = "Delete";
	}

	function thumbFor(file:String):FlxSprite
	{
		var thumb = thumbs.get(file);

		if (thumb == null)
		{
			thumb = new FlxSprite();
			thumb.loadGraphic(preview(file), false, 0, 0, true);
			thumbs.set(file, thumb);
			add(thumb);
		}
		return thumb;
	}

	function preview(file:String):BitmapData
	{
		try
		{
			return BoardPreview.render(Json.parse(BoardStore.read(file)), thumbWidth, thumbHeight);
		}
		catch (error:Dynamic)
		{
			return new BitmapData(thumbWidth, thumbHeight, true, 0xFF15151B);
		}
	}

	function dropThumb(file:String)
	{
		var thumb = thumbs.get(file);
		if (thumb == null)
			return;

		remove(thumb, true);
		thumb.destroy();
		thumbs.remove(file);
	}

	function displayName(file:String):String
	{
		var name = Path.withoutExtension(file);
		return StringTools.endsWith(name, suffix) ? name.substr(0, name.length - suffix.length) : name;
	}

	function ellipsize(text:String, limit:Int):String
	{
		return text.length > limit ? text.substr(0, limit - 3) + "..." : text;
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
}
