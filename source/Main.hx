package;

import funkin.states.InitState;

import openfl.display.Sprite;
import eternal.ui.Overlay;

class Main extends Sprite {
   public static var game(default, null):GameInstance;
   public static var overlay(default, null):Overlay;

   public function new():Void {
      super();

      FlxG.save.bind("misc", Tools.savePath);

      game = new GameInstance(0, 0, InitState, 60, 60, true);
      addChild(game);

      overlay = new Overlay();
      addChild(overlay);
   }

   override function __enterFrame(delta:Int):Void {
      if (FlxG.keys.justPressed.F11) {
         FlxG.fullscreen = !FlxG.fullscreen;
         FlxG.save.data.fullscreen = FlxG.fullscreen;
         FlxG.save.flush();
      }

      #if FLX_DEBUG
      overlay.visible = !game.debugger.visible;
      #end

      super.__enterFrame(delta);
   }
}

typedef GameInstance = #if ENGINE_CRASH_HANDLER eternal.core.crash.FNFGame #else flixel.FlxGame #end ;
