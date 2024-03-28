package eternal.core.scripting;

#if ENGINE_SCRIPTING
import hscript.Parser;
import hscript.Interp;

class HScript {
    public static final importPresets:Map<String, Dynamic> = [
        // Flixel
        "FlxG" => flixel.FlxG,
        "FlxSprite" => flixel.FlxSprite,
        "FlxText" => flixel.text.FlxText,
        "FlxSound" => flixel.sound.FlxSound,
        "FlxTween" => flixel.tweens.FlxTween,
        "FlxEase" => flixel.tweens.FlxEase,
        "FlxTimer" => flixel.util.FlxTimer,
        "FlxMath" => flixel.math.FlxMath,
        "FlxPoint" => flixel.math.FlxPoint.FlxPoint_HSC,
        "FlxGroup" => flixel.group.FlxGroup,
        "FlxAxes" => flixel.util.FlxAxes.FlxAxes_HSC,
        "FlxColor" => flixel.util.FlxColor.FlxColor_HSC,
        "FlxTweenType" => flixel.tweens.FlxTween.FlxTweenType_HSC,

        // Eternal
        #if ENGINE_DISCORD_RPC "DiscordPresence" => DiscordPresence, #end

        // Funkin
        "Settings" => Settings,
        "Conductor" => Conductor,
        "OffsetSprite" => funkin.objects.OffsetSprite,
        "DancingSprite" => funkin.objects.DancingSprite,

        // Transition stuff
        "Transition" => Transition,
        "TranitionState" => TransitionState,
        "TransitionSubState" => TransitionSubState,

        #if ENGINE_MODDING
        // Custom state and substate
        "ModState" => eternal.core.scripting.ScriptableState.ModState, "ModSubState" => eternal.core.scripting.ScriptableState.ModSubState,
        #end

        // Misc
        "PlayState" => funkin.states.PlayState,
        "FlxRuntimeShader" => flixel.addons.display.FlxRuntimeShader,
        "ShaderFilter" => openfl.filters.ShaderFilter,

        // Tools
        "Std" => Std,
        "Math" => Math,
        "Tools" => Tools,
        "StringTools" => StringTools,

        "Assets" => Assets,
        "Paths" => Assets, // base game compat
        "OpenFLAssets" => openfl.Assets,
        "FileTools" => FileTools,

        #if sys
        "Sys" => Sys, "File" => sys.io.File, "FileSystem" => sys.FileSystem,
        #end

        "Reflect" => Reflect,
        "Type" => Type,
    ];

    // allows for static variables in scripts
    public static final sharedFields:Map<String, Dynamic> = [];

    public var alive(default, null):Bool = false;
    // public var priority(default, set):Int = -1; // TODO

    public var parser(default, null):Parser;
    public var interp(default, null):Interp;

    public var script(default, null):String;
    public var path(default, null):String;

    public var object(get, set):Dynamic;
    public var parent:ScriptPack;

    public function new(path:String):Void {
        this.path = path;

        parser = new Parser();
        interp = new Interp();
        parser.allowJSON = parser.allowMetadata = parser.allowTypes = true;
        interp.allowPublicVariables = interp.allowStaticVariables = true;
        interp.staticVariables = sharedFields;
        
        try {
            script = FileTools.getContent(this.path);
            interp.execute(parser.parseString(script, this.path.substring(this.path.lastIndexOf("/") + 1)));

            alive = true;
            applyPresets();
        }
        catch (e) {
            trace('Failed to load script "${path}"! [${e.message}]');
            destroy();
            return;
        }
    }

    public function set(key:String, obj:Dynamic):Dynamic {
        if (alive) interp.variables.set(key, obj);
        return obj;
    }

    public inline function get(key:String):Null<Dynamic>
        return alive ? interp.variables.get(key) : null;

    public inline function exists(key:String):Bool
        return alive ? interp.variables.exists(key) : false;

    public function call(func:String, ?args:Array<Dynamic>):Dynamic {
        if (!exists(func))
            return null;

        var func:Dynamic = get(func);
        try return Reflect.callMethod(null, func, args)
        catch (e) {
            trace('${path}: Failed to call "${func}"! [${e.message}]');
            return null;
        }
    }

    public function destroy():Void {
        if (interp != null)
            call("onDestroy");

        if (parent != null) {
            parent.scripts.remove(this);
            parent = null;
        }

        alive = false;
        parser = null;
        interp = null;
        script = null;
        path = null;
    }

    inline function applyPresets():Void {
        for (i in importPresets.keys())
            set(i, importPresets.get(i));

        // allows to load modules from other scripts
        set("importModule", (module:String) -> {
            var path:String = Assets.script(module);
            if (!FileTools.exists(path)) {
                trace('Could not find module "${module}"!');
                return;
            }

            var moduleScript:HScript = new HScript(path);
            if (!moduleScript.alive) return;

            for (customClass in moduleScript.interp.customClasses.keys())
                set(customClass, moduleScript.interp.customClasses.get(customClass));

            // add the script to the pack as well in case it has code outside of classes
            parent?.addScript(moduleScript);
        });

        // allows to close the script at any time
        set("closeScript", destroy);
    }

    inline function set_object(v:Dynamic):Dynamic {
        if (interp != null)
            interp.scriptObject = v;
        return v;
    }

    inline function get_object():Dynamic
        return interp?.scriptObject ?? null;
}
#end
