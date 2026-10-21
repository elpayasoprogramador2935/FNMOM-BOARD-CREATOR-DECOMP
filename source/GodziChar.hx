package;

import flixel.FlxSprite;
import flixel.graphics.frames.FlxAtlasFrames;

class GodziChar extends FlxSprite
{
	public var curChar:String;
	public var offSets:Map<String, Array<Dynamic>> = new Map();
	public var broIsDead:Bool = false;
	public var isEnemy:Bool = false;
	public var hasTurns:Bool = true;

	var picked:Bool = false;

	public function new(x:Float, y:Float, char:String, ?isEnemy:Bool = false, ?selection:Bool = true, ?turns:Bool = true)
	{
		super(x, y);
		this.isEnemy = isEnemy;
		hasTurns = turns;
		curChar = char;
		antialiasing = false;

		if (selection)
		{
			frames = FlxAtlasFrames.fromSparrow('assets/images/characters/SelectionMap2.png', 'assets/images/characters/SelectionMap2.xml');
			animation.addByPrefix('idle', '$curChar idle', 12, false);
			animation.addByPrefix('selected', '$curChar selected', 12, false);
			animation.addByPrefix('moving', '$curChar moving', 12, false);
			animation.play('idle');
			scale.set(2.5, 2.5);
		}
		else
		{
			loadGraphic('assets/images/characters/$curChar.png');
		}
	}

	public function setPicked(value:Bool)
	{
		if (value == picked)
			return;

		picked = value;
		animation.play(picked ? 'selected' : 'idle', true);
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (picked && animation.finished && animation.exists('selected') && animation.exists('moving'))
			animation.play(animation.name == 'selected' ? 'moving' : 'selected', true);
	}
}
