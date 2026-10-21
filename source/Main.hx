package;

import flixel.FlxGame;
import openfl.display.Sprite;
#if html5
import js.Browser;
import js.html.KeyboardEvent;
#end

class Main extends Sprite
{
	public function new()
	{
		super();
		addChild(new FlxGame(0, 0, PlayState, 60, 60, true));

		#if html5
		Browser.document.addEventListener("contextmenu", function(event) event.preventDefault());
		Browser.document.addEventListener("keydown", function(event)
		{
			var key:KeyboardEvent = cast event;
			if ((key.ctrlKey || key.metaKey) && key.key == "s")
				event.preventDefault();
		});
		#end
	}
}
