package eternal.core;

import openfl.Assets;
import openfl.system.System;

import flixel.graphics.FlxGraphic;
import flixel.graphics.frames.FlxAtlasFrames;

import openfl.media.Sound;
import openfl.display.BitmapData;

class AssetHelper {
    // Directories
    public static final defaultDirectory:String = "assets/";

    #if ENGINE_RUNTIME_ASSETS
    public static var currentDirectory:String = defaultDirectory;
    #end

    // Asset cache
    public static var clearAssets:Bool = true;

    public static final excludeGraphics:Array<FlxGraphic> = [];
    public static final excludeSounds:Array<Sound> = [];
    public static final excludeFonts:Array<String> = [];

    private static final loadedGraphics:Map<String, FlxGraphic> = [];
    private static final loadedSounds:Map<String, Sound> = [];

    // Path shortcuts & atlas stuff
    inline public static function image(file:String, ?library:String):FlxGraphic
        return getGraphic('images/${file}', library);

    inline public static function music(file:String, ?library:String):Sound
        return getSound('music/${file}', library);

    inline public static function sound(file:String, ?library:String):Sound
        return getSound('sounds/${file}', library);

    inline public static function songAudio(song:String, file:String, ?library:String):Sound
        return getSound('songs/${song}/${file}', library);

    inline public static function json(file:String, ?library:String):String
        return getPath(file, JSON, library);

    inline public static function yaml(file:String, ?library:String):String
        return getPath(file, YAML, library);

    inline public static function xml(file:String, ?library:String):String
        return getPath(file, XML, library);

    inline public static function txt(file:String, ?library:String):String
        return getPath(file, TEXT, library);

    inline public static function font(file:String, ?library:String):String
        return getPath('fonts/${file}', FONT, library);

    #if VIDEO_CUTSCENES
    inline public static function video(file:String, ?library:String):String
        return getPath('videos/${file}', VIDEO, library);
    #end

    inline public static function getSparrowAtlas(file:String, ?library:String):FlxAtlasFrames
        return FlxAtlasFrames.fromSparrow(image(file, library), resolveAtlasData(xml('images/${file}', library)));

    inline public static function getPackerAtlas(file:String, ?library:String):FlxAtlasFrames
        return FlxAtlasFrames.fromSpriteSheetPacker(image(file, library), resolveAtlasData(txt('images/${file}', library)));

    inline public static function getAseAtlas(file:String, ?library:String):FlxAtlasFrames
        return FlxAtlasFrames.fromAseprite(image(file, library), resolveAtlasData(json('images/${file}', library)));

    public static function getPath(file:String, type:AssetType, ?library:String):String {
        var basePath:String = file;
        if (library != null)
            basePath = '${library}/' + file;

        #if ENGINE_RUNTIME_ASSETS
        var modPath:String = type.cycleExtensions(currentDirectory + basePath);
        if (FileTools.exists(modPath))
            return modPath;
        #end
        
        return type.cycleExtensions(defaultDirectory + basePath);
    }

    public static function filterPath(path:String, type:AssetType):String {
        var extensions:Array<String> = type.getExtensions();
        var ext:String = extensions.shift();

        while (!FileTools.exists(path + ext) && extensions.length > 0)
            ext = extensions.shift();

        return path + ext;
    }

    // Asset handling & cache
    public static function getGraphic(path:String, ?library:String, ?key:String):FlxGraphic {
        if (key == null)
            key = path;

        var graphic:FlxGraphic = loadedGraphics.get(key);

        if (graphic == null) {
            graphic = createGraphic(path, library);
            if (graphic != null)
                sendToCache(key, graphic, IMAGE);
        }

        return graphic;
    }

    public static function getSound(path:String, ?library:String, ?key:String):Sound {
        if (key == null)
            key = path;

        var sound:Sound = loadedSounds.get(key);

        if (sound == null) {
            sound = createSound(path, library);
            if (sound != null)
                sendToCache(key, sound, SOUND);
        }

        return sound;
    }

    public static function createGraphic(path:String, ?library:String):FlxGraphic {
        var realPath:String = getPath(path, IMAGE, library);
        
        var bitmap:BitmapData = #if ENGINE_RUNTIME_ASSETS BitmapData.fromFile(realPath) #else Assets.getBitmapData(realPath) #end ;
        if (bitmap == null) {
            trace('Invalid graphic path "${realPath}"!');
            return null;
        }
        
        var graphic:FlxGraphic = FlxGraphic.fromBitmapData(bitmap, false, null, true);
        graphic.persist = true;
        return graphic;
    }

    public static function createSound(path:String, ?library:String):Sound {
        var realPath:String = getPath(path, SOUND, library);
        if (realPath.contains(":"))
            realPath = realPath.substring(realPath.indexOf(":") + 1);

        if (!FileTools.exists(realPath)) {
            trace('Invalid sound path "${realPath}"!');
            return null;
        }

        return #if ENGINE_RUNTIME_ASSETS Sound.fromFile(realPath) #else Assets.getSound(realPath) #end ;
    }

    inline public static function sendToCache(key:String, asset:Any, type:AssetType):Void {
        if (key == null || asset == null || type == null)
            return;
        
        switch type {
            case IMAGE:
                loadedGraphics.set(key, asset);
            case SOUND:
                loadedSounds.set(key, asset);
            default:
                trace("Cannot register asset of type " + type + " to the cache!");
        }
    }

    inline private static function resolveAtlasData(key:String):String {
        #if ENGINE_RUNTIME_ASSETS
        // TODO: maybe find a better solution?
        // Replaced assets like the alphabet would make the game freeze for some seconds due to `FileTools.getContent`
        return (key.startsWith(currentDirectory) && currentDirectory != defaultDirectory) ? FileTools.getContent(key) : key;
        #else
        return key;
        #end
    }

    // Assets clearing
    inline public static function freeMemory():Void {
        if (!clearAssets)
            return;

        // Clear the cache entirely
        clearCache();
        // Clear the OpenFL cache
        Assets.cache.clear();

        // Clear any graphics registered into Flixel's cache
        FlxG.bitmap.dumpCache();
        FlxG.bitmap.clearUnused();
        FlxG.bitmap.clearCache();
    }

    inline public static function freeMemoryPost(?_):Void {
        // If it is false, set it to true
        clearAssets = true;
        // Run the garbage collector
        System.gc();
    }

    inline public static function clearCache():Void {
        clearSounds();
        clearGraphics();
        clearFonts();
    }

    public static function clearSounds():Void {
        for (key in loadedSounds.keys()) {
            var sound:Sound = loadedSounds.get(key);
            if (excludeSounds.contains(sound))
                continue;

            Assets.cache.removeSound(key);
            sound.close();

            loadedSounds.remove(key);
        }
    }
    
    public static function clearGraphics():Void {
        @:privateAccess
        for (key in FlxG.bitmap._cache.keys()) {
            var graphic:FlxGraphic = FlxG.bitmap.get(key);
            if (excludeGraphics.contains(graphic))
                continue;

            FlxG.bitmap.removeKey(key);
            graphic.dump();
            graphic.destroy();
        }

        for (key in loadedGraphics.keys()) {
            var graphic:FlxGraphic = loadedGraphics.get(key);
            if (excludeGraphics.contains(graphic))
                continue;

            if (graphic.bitmap != null) {
                graphic.dump();
                graphic.destroy();
            }

            loadedGraphics.remove(key);
        }
    }

    public static function clearFonts():Void {
        var cache:openfl.utils.AssetCache = cast Assets.cache;
        for (key in cache.font.keys())
            if (!excludeFonts.contains(key))
                cache.font.remove(key);
    }
}

enum abstract AssetType(String) from String to String {
    var IMAGE = "image";
    var SOUND = "sound";
    var FONT = "font";

    var XML = "xml";
    var TEXT = "txt";
    var JSON = "json";
    var YAML = "yaml";

    #if ENGINE_SCRIPTING
    var SCRIPT = "script";
    #end
    #if VIDEO_CUTSCENES
    var VIDEO = "video";
    #end

    var NONE = "none";

    public function getExtensions():Array<String> {
        return switch (this:AssetType) {
            case IMAGE:  [".png"];
            case SOUND:  [".ogg", ".wav"];
            case FONT:   [".ttf", ".otf"];

            case XML:    [".xml"];
            case TEXT:   [".txt"];
            case JSON:   [".json", ".jsonc"];
            case YAML:   [".yaml", ".yml"];

            #if ENGINE_SCRIPTING
            case SCRIPT: [".hx", ".hxs", ".hscript"];
            #end
            #if VIDEO_CUTSCENES
            case VIDEO: [".mp4", ".webm", ".mov", ".avi"];
            #end

            case NONE:   [""];
        }
    }

    public function cycleExtensions(path:String):String {
        for (ext in getExtensions())
            if (FileTools.exists(path + ext))
                return path + ext;

        return path;
    }
}
