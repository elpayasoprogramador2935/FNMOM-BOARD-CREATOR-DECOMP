package;

import HexGrid.Cell;
import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.addons.ui.FlxUI;
import flixel.addons.ui.FlxUIButton;
import flixel.addons.ui.FlxUICheckBox;
import flixel.addons.ui.FlxUIInputText;
import flixel.addons.ui.FlxUIState;
import flixel.addons.ui.FlxUITabMenu;
import flixel.math.FlxPoint;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import haxe.Json;
import haxe.Timer;
import haxe.io.Path;
import openfl.display.PNGEncoderOptions;
import openfl.utils.AssetType;
import openfl.utils.Assets;
#if sys
import sys.FileSystem;
#end
#if html5
import openfl.net.FileReference;
#end

typedef Snapshot = {tiles:Array<Array<Dynamic>>, chars:Array<Array<Dynamic>>, movemap:Map<String, Array<Dynamic>>};

var globalChars:Array<GodziChar> = [];
var currentTile:Int = 0;
var currentChar:Int = 0;
var isEnemy:Bool = false;
var shitshit:Array<Dynamic> = [];
var moveMap:Map<BoardTile, Array<Int>> = new Map();
var tabs:Array<{name:String, label:String}> = [
	{name: "Data", label: "Data"},
	{name: "Tile", label: "Tile"},
	{name: "Order", label: "Order"},
	{name: "Movemap", label: "Movemap"},
	{name: "Characters", label: "Characters"}
];
var leTiles:Array<BoardTile> = [];
var camGame:FlxCamera;
var camHUD:FlxCamera;
var camFollow:FlxObject;
var UI_box:FlxUITabMenu;
var tilePalette:Palette;
var connections:Connections;
var charPalette:Palette;
var boardName:FlxUIInputText;
var currentTileText:FlxText;
var enemyButton:FlxUICheckBox;
var metaaaaa:Dynamic;
var tileGhost:BoardTile;
var charGhost:GodziChar;

class PlayState extends FlxUIState
{
	static inline var DEFAULT_NAME:String = "NAME-YOUR-MAP-DUDE";
	static inline var DATA_SUFFIX:String = "-DATA";
	static inline var DOUBLE_CLICK:Float = 0.35;
	static inline var ERASE_STEP:Float = 20;

	var hasTurnButton:FlxUICheckBox;
	var boards:BoardModal;
	var startMark:StartMarker;
	var lastClickTile:BoardTile;
	var lastClickTime:Float = 0;
	var dragging:Bool = false;
	var dragCell:{x:Float, y:Float};
	var painting:Bool = false;
	var draggingChar:Bool = false;
	var paletteDrag:Bool = false;
	var showIds:Bool = false;
	var undoStack:Array<Snapshot> = [];
	var redoStack:Array<Snapshot> = [];
	var strokeSaved:Bool = false;
	var dragSaved:Bool = false;
	var moveSaved:Bool = false;
	var idBoxes:Array<FlxSprite> = [];
	var idTexts:Array<FlxText> = [];
	var grabX:Float = 0;
	var grabY:Float = 0;
	var lastCell:Cell;
	var erasing:Bool = false;
	var eraseSaved:Bool = false;
	var eraseX:Float = 0;
	var eraseY:Float = 0;
	var hudMouse:FlxPoint = FlxPoint.get();
	var lastMouseX:Float = 0;
	var lastMouseY:Float = 0;

	override function create()
	{
		super.create();
		playTheme();

		metaaaaa = {
			villains: new Map<String, Array<Dynamic>>(),
			tiles: [],
			movemap: new Map<String, Array<Dynamic>>(),
			actorsPosition: new Map<String, Array<Dynamic>>()
		};

		FlxG.mouse.visible = true;

		camGame = FlxG.camera;
		camHUD = new FlxCamera();
		FlxG.cameras.add(camHUD, false);
		camHUD.bgColor = FlxColor.TRANSPARENT;

		camFollow = new FlxObject(0, 0, 1, 1);
		camFollow.setPosition(FlxG.width / 2, FlxG.height / 2);
		add(camFollow);

		camGame.follow(camFollow, null, 0.05);
		camGame.focusOn(camFollow.getPosition());

		UI_box = new FlxUITabMenu(null, null, tabs, null, true);
		UI_box.cameras = [camHUD];
		UI_box.resize(300, 420);
		UI_box.x = 890;
		UI_box.y = 10;
		UI_box.scrollFactor.set();
		add(UI_box);

		connections = new Connections(camGame, function() return leTiles, function():Map<String, Array<Dynamic>> return metaaaaa.movemap, pushUndo);

		boards = new BoardModal(DATA_SUFFIX, loadBoard, saveInFolder, camHUD);
		startMark = new StartMarker();

		for (name in ["data", "tile", "order", "movemap", "characters"])
			makeTabs(UI_box, name);

		currentTileText = new FlxText(950, 600, 0, "Current tile " + currentTile, 25);
		currentTileText.cameras = [camHUD];
		add(currentTileText);

		boardName = new FlxUIInputText((FlxG.width - 300) / 2, 10, 300, DEFAULT_NAME, 16);
		boardName.cameras = [camHUD];
		add(boardName);

		buildPalettes();
		add(boards);
	}

	override function update(elapsed:Float)
	{
		if (boards.isOpen)
		{
			boards.update(elapsed);
			return;
		}

		super.update(elapsed);
		var typing = isTyping();

		if (shortcutHeld())
		{
			if (FlxG.keys.justPressed.S)
				saveInFolder();

			if (!typing && !FlxG.mouse.pressed)
			{
				if (FlxG.keys.justPressed.Z && !FlxG.keys.pressed.SHIFT)
					undo();
				else if (FlxG.keys.justPressed.Y || (FlxG.keys.justPressed.Z && FlxG.keys.pressed.SHIFT))
					redo();
			}
		}

		FlxG.watch.addQuick("cur tab", UI_box.selected_tab_id);
		FlxG.watch.addQuick("cur tile", currentTile);

		switch (UI_box.selected_tab_id)
		{
			case "Order":
				if (FlxG.mouse.justPressed && !mouseOverUI())
				{
					var hit = tileAt(FlxG.mouse.x, FlxG.mouse.y);
					var now = Timer.stamp();

					if (hit != null && hit == lastClickTile && now - lastClickTime < DOUBLE_CLICK)
					{
						makeStart(hit);
						hit = null;
					}

					lastClickTile = hit;
					lastClickTime = now;
				}

			case "Characters":
				if (!typing && FlxG.keys.justPressed.ESCAPE)
					dropCharBrush();

				if (FlxG.mouse.justPressedRight && !mouseOverUI())
				{
					var hit = charAt(FlxG.mouse.x, FlxG.mouse.y);
					if (hit != null)
						removeChar(hit);
				}

				if (charGhost != null)
				{
					charGhost.setPosition(FlxG.mouse.x - charGhost.width / 2, FlxG.mouse.y - charGhost.height / 2);
				}
				else
				{
					if (FlxG.mouse.justPressed && !mouseOverUI())
					{
						var picked = charAt(FlxG.mouse.x, FlxG.mouse.y);
						currentChar = picked != null ? picked.ID : -1;

						if (picked != null)
						{
							grabX = FlxG.mouse.x - picked.x;
							grabY = FlxG.mouse.y - picked.y;
							draggingChar = true;
							moveSaved = false;

							enemyButton.checked = picked.isEnemy;
							hasTurnButton.checked = picked.hasTurns;
						}
					}

					if (!FlxG.mouse.pressed)
						draggingChar = false;
				}

				var hover = charPalette.hovered();
				if (FlxG.mouse.justPressed && hover >= 0)
				{
					charPalette.selected = hover;
					pickChar(charPalette.names[hover]);
					paletteDrag = true;
				}

				if (paletteDrag && !FlxG.mouse.pressed)
				{
					if (!mouseOverUI())
						placeChar();

					dropCharBrush();
				}

				if (FlxG.mouse.wheel != 0 && mouseOverUI())
					charPalette.scrollBy(FlxG.mouse.wheel);

				if (globalChars[currentChar] != null)
				{
					var character = globalChars[currentChar];
					currentTileText.text = "Current char " + character.curChar;

					if (draggingChar)
					{
						var nx = FlxG.mouse.x - grabX;
						var ny = FlxG.mouse.y - grabY;

						if (nx != character.x || ny != character.y)
						{
							if (!moveSaved)
							{
								pushUndo();
								moveSaved = true;
							}

							character.setPosition(nx, ny);
						}
					}
				}
				else
				{
					currentTileText.text = "Current char none";
					currentTile = leTiles.length - 1;
				}

			case "Tile":
				if (!typing && FlxG.keys.justPressed.ESCAPE)
					dropTileBrush();

				if (FlxG.mouse.justPressedRight && !mouseOverUI() && tileAt(FlxG.mouse.x, FlxG.mouse.y) != null)
				{
					erasing = true;
					eraseSaved = false;
					eraseX = FlxG.mouse.x;
					eraseY = FlxG.mouse.y;
				}

				if (!FlxG.mouse.pressedRight)
					erasing = false;

				if (erasing)
					eraseTiles();

				var hover = tilePalette.hovered();
				if (FlxG.mouse.justPressed && hover >= 0)
				{
					if (hover == tilePalette.selected)
						dropTileBrush();
					else
					{
						tilePalette.selected = hover;
						pickTile(tilePalette.names[hover]);
					}
				}

				if (FlxG.mouse.wheel != 0 && mouseOverUI())
					tilePalette.scrollBy(FlxG.mouse.wheel);

				if (tileGhost != null)
				{
					var cell = hexCenter(FlxG.mouse.x, FlxG.mouse.y, tileGhost);
					tileGhost.centerOn(cell.x, cell.y);

					if (FlxG.mouse.justPressed && !mouseOverUI())
					{
						painting = true;
						strokeSaved = false;
						lastCell = null;
					}

					if (!FlxG.mouse.pressed)
						painting = false;

					if (painting)
						paintTiles();
				}
				else
				{
					if (FlxG.mouse.justPressed && !mouseOverUI())
					{
						var picked = tileAt(FlxG.mouse.x, FlxG.mouse.y);
						if (picked != null)
						{
							currentTile = picked.ID;
							dragCell = hexCenter(FlxG.mouse.x, FlxG.mouse.y, picked);
							dragging = true;
							dragSaved = false;
						}
					}

					if (!FlxG.mouse.pressed)
						dragging = false;
				}

				if (leTiles[currentTile] != null)
				{
					currentTileText.text = "Current tile " + currentTile;

					if (dragging)
					{
						var tile = leTiles[currentTile];
						var cell = hexCenter(FlxG.mouse.x, FlxG.mouse.y, tile);
						if (cell.x != dragCell.x || cell.y != dragCell.y)
						{
							if (!dragSaved)
							{
								pushUndo();
								dragSaved = true;
							}

							tile.centerOn(cell.x, cell.y);
							dragCell = cell;
						}
					}
				}
				else
				{
					currentTileText.text = "Current tile none";
					currentTile = leTiles.length - 1;
				}
		}

		connections.update(UI_box.selected_tab_id == "Movemap", mouseOverUI());

		tilePalette.layout(UI_box.selected_tab_id == "Tile");
		charPalette.layout(UI_box.selected_tab_id == "Characters");

		for (i in 0...charPalette.items.length)
			cast(charPalette.items[i], GodziChar).setPicked(i == charPalette.selected);

		var selecting = UI_box.selected_tab_id == "Characters" && charGhost == null;
		for (character in globalChars)
			character.setPicked(selecting && character.ID == currentChar);

		FlxG.mouse.getScreenPosition(camHUD, hudMouse);

		if (FlxG.mouse.pressedMiddle)
		{
			camFollow.x -= (hudMouse.x - lastMouseX) / camGame.zoom;
			camFollow.y -= (hudMouse.y - lastMouseY) / camGame.zoom;
		}

		lastMouseX = hudMouse.x;
		lastMouseY = hudMouse.y;

		if (FlxG.mouse.wheel != 0 && !mouseOverUI())
			camGame.zoom = Math.max(0.1, camGame.zoom + FlxG.mouse.wheel * 0.05);
	}

	override function draw()
	{
		super.draw();

		var tab = UI_box.selected_tab_id;

		connections.draw(tab == "Movemap");

		if (leTiles.length > 0)
		{
			startMark.placeOn(leTiles[0]);
			startMark.draw();
		}

		if (showIds || tab == "Order")
			drawIds();

		if (tab == "Tile" && tileGhost != null && !mouseOverUI())
			tileGhost.draw();
		else if (tab == "Characters" && charGhost != null && !mouseOverUI())
			charGhost.draw();
	}

	function dropTileBrush()
	{
		if (tileGhost != null)
			tileGhost.destroy();

		tileGhost = null;
		tilePalette.selected = -1;
	}

	function dropCharBrush()
	{
		if (charGhost != null)
			charGhost.destroy();

		charGhost = null;
		charPalette.selected = -1;
		paletteDrag = false;
	}

	function playTheme()
	{
		var name = 'music_theme_${FlxG.random.int(1, 12)}';

		#if html5
		var formats = ["mp3", "ogg"];
		#else
		var formats = ["ogg", "mp3"];
		#end

		for (format in formats)
		{
			var path = 'assets/music/$name.$format';
			if (Assets.exists(path))
			{
				FlxG.sound.playMusic(path);
				return;
			}
		}
	}

	function materialNames():Array<String>
	{
		var folder = "assets/images/materials";
		var names = [
			for (path in Assets.list(AssetType.IMAGE))
				if (Path.directory(path) == folder && Path.extension(path) == "png")
					Path.withoutExtension(Path.withoutDirectory(path))
		];

		#if sys
		var disk = AppDir.of(folder);
		if (FileSystem.exists(disk))
		{
			for (file in FileSystem.readDirectory(disk))
			{
				var name = Path.withoutExtension(file);
				if (Path.extension(file) == "png" && !names.contains(name))
					names.push(name);
			}
		}
		#end

		names.sort(Reflect.compare);
		return names;
	}

	function characterNames():Array<String>
	{
		var names:Array<String> = [];
		var atlas = Xml.parse(Assets.getText("assets/images/characters/SelectionMap2.xml")).firstElement();
		var idle = ~/^(.+) idle\d*$/;

		for (frame in atlas.elements())
		{
			var frameName = frame.get("name");
			if (frameName != null && idle.match(frameName) && !names.contains(idle.matched(1)))
				names.push(idle.matched(1));
		}

		names.sort(Reflect.compare);
		return names;
	}

	function buildPalettes()
	{
		tilePalette = new Palette(this, camHUD, UI_box.x + 10, UI_box.y + 70, 2);
		for (name in materialNames())
			tilePalette.add(name, new BoardTile(0, 0, name));

		charPalette = new Palette(this, camHUD, UI_box.x + 10, UI_box.y + 125, 4);
		for (name in characterNames())
			charPalette.add(name, new GodziChar(0, 0, name));
	}

	function shortcutHeld():Bool
	{
		#if mac
		return FlxG.keys.pressed.CONTROL || FlxG.keys.pressed.WINDOWS;
		#else
		return FlxG.keys.pressed.CONTROL;
		#end
	}

	function isTyping():Bool
	{
		return boardName.hasFocus || tilePalette.typing || charPalette.typing;
	}

	function drawIds()
	{
		for (i in 0...leTiles.length)
		{
			var tile = leTiles[i];
			var label = Std.string(tile.ID);

			if (i >= idBoxes.length)
			{
				idBoxes.push(new FlxSprite());
				idTexts.push(null);
			}

			var box = idBoxes[i];
			var text = idTexts[i];

			if (text == null || text.text != label)
			{
				if (text != null)
					text.destroy();

				text = new FlxText(0, 0, 0, label, 16);
				idTexts[i] = text;
				box.makeGraphic(label.length * 10 + 12, 24, FlxColor.WHITE);
			}

			box.color = tile.ID == 0 ? FlxColor.GREEN : FlxColor.BLACK;

			var cx = tile.hexCenterX();
			var cy = tile.hexCenterY();

			box.setPosition(cx - box.width / 2, cy - box.height / 2);
			box.draw();

			text.setPosition(cx - text.width / 2, cy - text.height / 2);
			text.draw();
		}
	}

	function mouseOverUI():Bool
	{
		return FlxG.mouse.overlaps(UI_box, camHUD) || FlxG.mouse.overlaps(boardName, camHUD);
	}

	function tileAt(px:Float, py:Float):BoardTile
	{
		return BoardTile.at(leTiles, px, py);
	}

	function charAt(px:Float, py:Float):GodziChar
	{
		var found:GodziChar = null;
		var closest = Math.POSITIVE_INFINITY;

		for (character in globalChars)
		{
			var dx = px - (character.x + character.width / 2);
			var dy = py - (character.y + character.height / 2);
			var dist = dx * dx + dy * dy;
			var inside = Math.abs(dx) <= character.width * character.scale.x / 2 && Math.abs(dy) <= character.height * character.scale.y / 2;

			if (inside && dist <= closest)
			{
				found = character;
				closest = dist;
			}
		}
		return found;
	}

	function hexCenter(px:Float, py:Float, tile:BoardTile):{x:Float, y:Float}
	{
		var grid = new HexGrid(tile);
		var cell = grid.cellAt(px, py);
		return {x: grid.centerX(cell), y: grid.centerY(cell)};
	}

	function occupied(grid:HexGrid, cell:Cell):Bool
	{
		for (tile in leTiles)
		{
			var at = grid.cellAt(tile.hexCenterX(), tile.hexCenterY());
			if (at.n == cell.n && at.m == cell.m)
				return true;
		}
		return false;
	}

	function paintTiles()
	{
		var grid = new HexGrid(tileGhost);
		var cell = grid.cellAt(FlxG.mouse.x, FlxG.mouse.y);

		if (lastCell == null)
			placeTile(grid, cell);
		else if (cell.n != lastCell.n || cell.m != lastCell.m)
		{
			for (step in HexGrid.line(lastCell, cell))
				placeTile(grid, step);
		}

		lastCell = cell;
	}

	function placeTile(grid:HexGrid, cell:Cell)
	{
		if (occupied(grid, cell))
			return;

		if (!strokeSaved)
		{
			pushUndo();
			strokeSaved = true;
		}

		var tile = new BoardTile(0, 0, tileGhost.material);
		tile.scale.set(2.5, 2.5);
		tile.centerOn(grid.centerX(cell), grid.centerY(cell));
		tile.ID = leTiles.length;
		addTile(tile);
	}

	function eraseTiles()
	{
		var mx = FlxG.mouse.x;
		var my = FlxG.mouse.y;
		var samples = Std.int(Math.max(1, Math.ceil(Math.sqrt((mx - eraseX) * (mx - eraseX) + (my - eraseY) * (my - eraseY)) / ERASE_STEP)));

		for (i in 1...samples + 1)
		{
			var hit = tileAt(eraseX + (mx - eraseX) * i / samples, eraseY + (my - eraseY) * i / samples);
			if (hit == null)
				continue;

			if (!eraseSaved)
			{
				pushUndo();
				eraseSaved = true;
			}
			removeTile(hit);
		}

		eraseX = mx;
		eraseY = my;
	}

	function addTile(tile:BoardTile)
	{
		if (globalChars.length > 0)
			insert(members.indexOf(globalChars[0]), tile);
		else
			add(tile);
		leTiles.push(tile);
	}

	function removeTile(tile:BoardTile)
	{
		var gone = tile.ID;
		leTiles.remove(tile);
		remove(tile, true);
		tile.destroy();

		for (i in 0...leTiles.length)
			leTiles[i].ID = i;

		var old:Map<String, Array<Dynamic>> = metaaaaa.movemap;
		var shifted = new Map<String, Array<Dynamic>>();
		for (key in old.keys())
		{
			var id = Std.parseInt(key);
			if (id == gone)
				continue;

			var dirs:Array<Dynamic> = [for (d in old.get(key)) d == null || d == gone ? null : (d > gone ? Std.int(d) - 1 : d)];
			shifted.set(Std.string(id > gone ? id - 1 : id), dirs);
		}
		metaaaaa.movemap = shifted;

		currentTile = Std.int(Math.min(currentTile, leTiles.length - 1));
	}

	function makeStart(tile:BoardTile)
	{
		var picked = tile.ID;
		if (picked == 0)
			return;

		pushUndo();

		var first = leTiles[0];
		leTiles[0] = tile;
		leTiles[picked] = first;
		tile.ID = 0;
		first.ID = picked;

		var old:Map<String, Array<Dynamic>> = metaaaaa.movemap;
		var swapped = new Map<String, Array<Dynamic>>();
		for (key in old.keys())
		{
			var id = Std.parseInt(key);
			var dirs:Array<Dynamic> = [for (d in old.get(key)) d == null ? null : (d == 0 ? picked : (d == picked ? 0 : d))];
			swapped.set(Std.string(id == 0 ? picked : (id == picked ? 0 : id)), dirs);
		}
		metaaaaa.movemap = swapped;

		currentTile = 0;
	}

	function placeChar()
	{
		pushUndo();

		var character = new GodziChar(charGhost.x, charGhost.y, charGhost.curChar, enemyButton.checked, true, hasTurnButton.checked);
		character.ID = globalChars.length;
		add(character);
		globalChars.push(character);
		currentChar = -1;
	}

	function removeChar(character:GodziChar)
	{
		pushUndo();

		globalChars.remove(character);
		remove(character, true);
		character.destroy();

		for (i in 0...globalChars.length)
			globalChars[i].ID = i;

		currentChar = -1;
	}

	function pickTile(material:String)
	{
		if (tileGhost != null)
			tileGhost.destroy();

		tileGhost = new BoardTile(0, 0, material);
		tileGhost.scale.set(2.5, 2.5);
		tileGhost.alpha = 0.5;
		dragging = false;
	}

	function pickChar(name:String)
	{
		if (charGhost != null)
			charGhost.destroy();

		charGhost = new GodziChar(0, 0, name);
		charGhost.alpha = 0.5;
		draggingChar = false;
	}

	function loadBoard(file:String)
	{
		var json = Json.parse(BoardStore.read(file));
		pushUndo();
		clearBoard();

		var fileName = Path.withoutExtension(file);
		boardName.text = StringTools.endsWith(fileName, DATA_SUFFIX) ? fileName.substr(0, fileName.length - DATA_SUFFIX.length) : fileName;
		metaaaaa.tiles = json.tiles;

		for (name in Reflect.fields(json.villains))
			metaaaaa.villains.set(name, Reflect.field(json.villains, name));
		for (name in Reflect.fields(json.actorsPosition))
			metaaaaa.actorsPosition.set(name, Reflect.field(json.actorsPosition, name));
		for (name in Reflect.fields(json.movemap))
			metaaaaa.movemap.set(name, Reflect.field(json.movemap, name));

		for (i in 0...metaaaaa.tiles.length)
		{
			var saved:Array<Dynamic> = metaaaaa.tiles[i];
			var tile = new BoardTile(saved[0], saved[1], Std.string(saved[2]));
			tile.scale.set(2.5, 2.5);
			tile.ID = i;
			addTile(tile);
		}

		currentTile = leTiles.length - 1;

		var villains:Map<String, Array<Dynamic>> = metaaaaa.villains;
		for (name in villains.keys())
		{
			var position = villains.get(name);
			var character = new GodziChar(position[0], position[1], name, true, true, position[2] != false);
			add(character);
			globalChars.push(character);
		}

		var actors:Map<String, Array<Dynamic>> = metaaaaa.actorsPosition;
		for (name in actors.keys())
		{
			if (name != "selector")
			{
				var position = actors.get(name);
				var character = new GodziChar(position[0], position[1], name, false, true, position[2] != false);
				add(character);
				globalChars.push(character);
			}
		}

		for (i in 0...globalChars.length)
			globalChars[i].ID = i;

		currentChar = -1;
	}

	function clearBoard()
	{
		metaaaaa = {
			villains: new Map<String, Array<Dynamic>>(),
			tiles: [],
			movemap: new Map<String, Array<Dynamic>>(),
			actorsPosition: new Map<String, Array<Dynamic>>()
		};

		boardName.text = DEFAULT_NAME;
		wipe();
	}

	function wipe()
	{
		for (tile in leTiles)
		{
			remove(tile, true);
			tile.destroy();
		}
		leTiles = [];

		for (character in globalChars)
		{
			remove(character, true);
			character.destroy();
		}
		globalChars = [];

		currentTile = -1;
		currentChar = -1;
	}

	function snapshot():Snapshot
	{
		var tiles:Array<Array<Dynamic>> = [];
		for (tile in leTiles)
		{
			var entry:Array<Dynamic> = [tile.x, tile.y, tile.material];
			tiles.push(entry);
		}

		var chars:Array<Array<Dynamic>> = [];
		for (character in globalChars)
		{
			var entry:Array<Dynamic> = [character.x, character.y, character.curChar, character.isEnemy, character.hasTurns];
			chars.push(entry);
		}

		var current:Map<String, Array<Dynamic>> = metaaaaa.movemap;
		var movemap = new Map<String, Array<Dynamic>>();
		for (key in current.keys())
			movemap.set(key, current.get(key).copy());

		return {tiles: tiles, chars: chars, movemap: movemap};
	}

	function restore(state:Snapshot)
	{
		wipe();

		for (i in 0...state.tiles.length)
		{
			var saved = state.tiles[i];
			var tile = new BoardTile(saved[0], saved[1], Std.string(saved[2]));
			tile.scale.set(2.5, 2.5);
			tile.ID = i;
			addTile(tile);
		}

		for (saved in state.chars)
		{
			var character = new GodziChar(saved[0], saved[1], saved[2], saved[3], true, saved[4]);
			character.ID = globalChars.length;
			add(character);
			globalChars.push(character);
		}

		metaaaaa.movemap = state.movemap;
		dragging = false;
		draggingChar = false;
		painting = false;
		erasing = false;
	}

	function pushUndo()
	{
		undoStack.push(snapshot());
		if (undoStack.length > 100)
			undoStack.shift();

		redoStack = [];
	}

	function undo()
	{
		if (undoStack.length == 0)
			return;

		redoStack.push(snapshot());
		restore(undoStack.pop());
	}

	function redo()
	{
		if (redoStack.length == 0)
			return;

		undoStack.push(snapshot());
		restore(redoStack.pop());
	}

	function makeTabs(tabMenu:FlxUITabMenu, name:String)
	{
		switch (name)
		{
			case "data":
				var clearButton = new FlxUIButton(10, 40, "Clear map", function()
				{
					pushUndo();
					clearBoard();
				});

				clearButton.resize(120, 24);

				var idsButton = new FlxUICheckBox(10, 75, null, null, "Show tile IDs", 100);
				idsButton.checked = showIds;
				idsButton.callback = function()
				{
					showIds = idsButton.checked;
				};

				var boardsButton = new FlxUIButton(10, 110, "Boards", function() boards.open());
				boardsButton.resize(120, 24);

				var exportButton = new FlxUIButton(10, 145, "Export PNG", exportPng);
				exportButton.resize(120, 24);

				var shortcut = new FlxText(10, 180, 280, "Ctrl+S saves the current board.");

				var group = new FlxUI(null, UI_box);
				group.name = "Data";
				group.add(clearButton);
				group.add(idsButton);
				group.add(boardsButton);
				group.add(exportButton);
				group.add(shortcut);
				tabMenu.addGroup(group);

			case "tile":
				var hint = new FlxText(10, 200, 280, "Pick a tile type and click to place it; hold the click to paint.\nESC leaves place mode so you can select and drag tiles.\nRight click deletes the tile under the cursor.");

				var group = new FlxUI(null, UI_box);
				group.name = "Tile";
				group.add(hint);
				tabMenu.addGroup(group);

			case "order":
				var hint = new FlxText(10, 30, 280, "Double click a tile to make it the starting point.\nThe white square always marks tile 0. The tile that was 0 swaps IDs with the one you pick.\nIDs are always shown on this tab.");

				var group = new FlxUI(null, UI_box);
				group.name = "Order";
				group.add(hint);
				tabMenu.addGroup(group);

			case "movemap":
				connections.buildTab(tabMenu);

			case "characters":
				enemyButton = new FlxUICheckBox(10, 30, null, null, "Is enemy?", 100);
				enemyButton.checked = false;
				enemyButton.callback = function()
				{
					if (globalChars[currentChar] != null && globalChars[currentChar].isEnemy != enemyButton.checked)
					{
						pushUndo();
						globalChars[currentChar].isEnemy = enemyButton.checked;
					}
				};

				hasTurnButton = new FlxUICheckBox(130, 30, null, null, "Should this character move?", 140);
				hasTurnButton.checked = true;
				hasTurnButton.callback = function()
				{
					if (globalChars[currentChar] != null && globalChars[currentChar].hasTurns != hasTurnButton.checked)
					{
						pushUndo();
						globalChars[currentChar].hasTurns = hasTurnButton.checked;
					}
				};

				var group = new FlxUI(null, UI_box);
				group.name = "Characters";
				group.add(enemyButton);
				group.add(hasTurnButton);
				tabMenu.addGroup(group);
		}
	}

	function saveInFolder()
	{
		var name = safeName() + DATA_SUFFIX + ".json";

		var data = serialize();

		BoardStore.write(name, data);
		boards.refresh(name);

		#if html5
		new FileReference().save(data, name);
		#end
	}

	function exportPng()
	{
		if (leTiles.length == 0 && globalChars.length == 0)
			return;

		var image = BoardPreview.capture(leTiles, globalChars);
		var png = image.encode(image.rect, new PNGEncoderOptions());
		image.dispose();

		var name = safeName() + ".png";

		#if html5
		new FileReference().save(png, name);
		#elseif sys
		BoardStore.writeImage(name, png);
		#end
	}

	function safeName():String
	{
		return ~/[\\\/:*?"<>|]/g.replace(boardName.text, "_");
	}

	function serialize():String
	{
		trace(leTiles.length);

		metaaaaa.tiles = [];
		for (tile in leTiles)
		{
			var entry:Array<Dynamic> = [tile.x, tile.y, tile.material];
			metaaaaa.tiles.push(entry);
		}

		metaaaaa.villains = new Map<String, Array<Dynamic>>();
		metaaaaa.actorsPosition = new Map<String, Array<Dynamic>>();

		for (character in globalChars)
		{
			var position:Array<Dynamic> = [character.x, character.y, character.hasTurns];
			if (character.isEnemy)
				metaaaaa.villains.set(character.curChar, position);
			else
				metaaaaa.actorsPosition.set(character.curChar, position);
		}

		Connections.fill(metaaaaa.movemap, leTiles);
		return Json.stringify(metaaaaa, null, "\t");
	}
}