package funkin.objects.notes;

import flixel.FlxCamera;
import flixel.math.FlxRect;
import funkin.objects.sprites.TiledSprite;
import funkin.objects.sprites.OffsetSprite;
import eternal.NoteSkin;

class Note extends OffsetSprite {
    public static final directions:Array<String> = ["left", "down", "up", "right"];

    public static var safeZoneOffset(get, never):Float;
    inline static function get_safeZoneOffset():Float
        return 166.66 * Conductor.playbackRate;

    public var goodHit:Bool = false;
    public var missed:Bool = false;

    public var canBeHit(get, default):Bool = false;
    public var late(get, default):Bool = false;

    public var time:Float = 0;
    public var direction:Int = 0;

    public var parentStrumline:StrumLine;
    public var strumline:Int = 0;

    public var length(default, set):Float = 0;
    public var sustain(default, null):Sustain;
    public var isSustainNote(get, never):Bool;

    public var type(default, set):String;
    public var skin(default, set):String;

    public var animSuffix:String;
    public var noSingAnim:Bool = false;
    public var noMissAnim:Bool = false;

    public var followX:Bool = true;
    public var followY:Bool = true;
    public var followAlpha:Bool = true;
    public var followSpeed:Bool = true;

    public var offsetX:Float = 0;
    public var offsetY:Float = 0;

    public var lateKillOffset:Float = 0;
    public var spawnTimeOffset:Float = 0;

    public var alphaMult:Float = 1;
    public var lateAlpha:Float = 0.3;
    public var sustainAlpha:Float = 0.6;

    public var holdBehindStrum:Bool = Settings.get("hold notes behind receptors");
    public var quantizeSustain:Bool = false;
    public var baseVisible:Bool = true;

    public var autoDistance:Bool = true;
    public var autoClipSustain:Bool = true;
    public var flipSustain:Bool = true;
    public var overrideSustain:Bool = false;
    public var killIfMissed:Bool = true;
    public var noStrumFollow:Bool = false;

    public var scrollMult(get, default):Float = ((Settings.get("downscroll")) ? -1 : 1);
    public var scrollSpeed(get, default):Float = 1;
    public var distance(get, default):Float = 0;

    public var downscroll(get, never):Bool;

    public function new(time:Float = 0, direction:Int = 0, skin:String = "default"):Void {
        super();

        this.time = time;
        this.direction = direction;
        this.skin = skin;

        resetPosition();
        moves = false;
    }

    public function follow(receptor:FlxSprite):Void {
        if (followX)
            x = receptor.x + offsetX;

        if (followY)
            y = receptor.y + offsetY + distance;

        if (followAlpha) {
            alpha = receptor.alpha * alphaMult;
            if (isSustainNote)
                sustain.alpha = sustainAlpha * alpha;
        }
    }

    public function clipSustain(receptor:FlxSprite):Void {
        var receptorCenter:Float = receptor.y + (receptor.height * 0.5);
        var tail:FlxSprite = sustain.tail;

        var tailRect:FlxRect = (tail.clipRect ?? FlxRect.get(0, 0, tail.frameWidth));
        var sustainRect:FlxRect = (sustain.clipRect ?? FlxRect.get());

        if (downscroll) {
            sustainRect.height = sustain.height - Math.max(sustain.y + sustain.height - receptorCenter, 0);
            tailRect.height = (receptorCenter - tail.y) / tail.scale.y;
            tailRect.y = tail.frameHeight - tailRect.height;
        } else {
            sustainRect.y = Math.max(receptorCenter - sustain.y, 0);
            sustainRect.height = sustain.height - sustainRect.y;

            tailRect.y = (receptorCenter - tail.y) / tail.scale.y;
            tailRect.height = tail.frameHeight - tailRect.y;
        }

        sustain.clipRect = sustainRect;
        tail.clipRect = tailRect;
    }

    public inline function findRating(ratings:Array<Rating>):Rating {
        var diff:Float = (Math.abs(Conductor.time - time) / Conductor.playbackRate);
        var rating:Rating = null;

        var i:Int = ratings.length - 1;

        while (i >= 0) {
            if (diff <= ratings[i].hitWindow)
                rating = ratings[i];

            i--;
        }

        return rating ?? ratings[ratings.length - 1];
    }

    public inline function resetPosition():Void {
        // making sure it goes off screen
        this.x = -FlxG.width;
        this.y = -FlxG.height;
    }

    public inline function resetTypeProps():Void {
        animSuffix = null;
        noSingAnim = false;
        noMissAnim = false;
    }

    public function getScrollSpeed(mult:Float = 1):Float {
        var receptor:Receptor = parentStrumline?.receptors.members[direction];
        var speed:Float = (followSpeed && parentStrumline != null) ? ((receptor.scrollSpeed ?? parentStrumline.scrollSpeed) * mult) : (@:bypassAccessor this.scrollSpeed);
        return Math.abs(speed * scrollMult);
    }

    override function update(elapsed:Float):Void {
        if (isSustainNote && sustain.exists && sustain.active)
            sustain.update(elapsed);

        super.update(elapsed);
    }

    override function draw():Void {
        if (isSustainNote && sustain.exists && sustain.visible && !holdBehindStrum)
            sustain.draw();

        if (baseVisible)
            super.draw();
    }

    override function destroy():Void {
        sustain = FlxDestroyUtil.destroy(sustain);
        parentStrumline = null;
        skin = null;
        type = null;

        super.destroy();
    }

    function set_length(v:Float):Float {
        if (v >= 100) {
            if (sustain == null)
                sustain = new Sustain(this);
        } else if (isSustainNote) {
            sustain.destroy();
            sustain = null;
        }

        return length = v;
    }

    function set_type(v:String):String {
        resetTypeProps();

        if (v != null) {
            switch (v) {
                case "Alt Animation":
                    animSuffix = "-alt";
                case "No Animation":
                    noSingAnim = true;
            }
        }

        return type = v;
    }

    function set_skin(v:String):String {
        if (v != null) {
            switch (v) {
                // case "name" to hardcode your noteskins
                case "default":
                    // default noteskin
                    var dir:String = directions[direction];

                    frames = Assets.getSparrowAtlas("notes/notes");
                    animation.addByPrefix(dir, '${dir}0', 0);
                    animation.addByPrefix(dir + " hold", '${dir} hold piece', 0);
                    animation.addByPrefix(dir + " end", '${dir} hold end', 0);
                    playAnimation(dir, true);

                    scale.set(0.7, 0.7);
                    updateHitbox();
                default:
                    // softcoded noteskin
                    var config:NoteSkinConfig = NoteSkin.get(v);
                    if (config == null || config.note == null)
                        return set_skin("default");

                    var dir:String = directions[direction];
                    NoteSkin.applyGenericSkin(this, config.note, dir, dir);

                    quantizeSustain = config.note.tiledSustain ?? false;
                    sustainAlpha = config.note.sustainAlpha ?? 0.6;
            }
        }

        return skin = v;
    }

    inline function get_distance():Float {
        if (!autoDistance)
            return this.distance;

        var conductorTime:Float = (Conductor.updateInterp ? Conductor.interpTime : Conductor.time);
        return FlxMath.signOf(scrollMult) * ((time - conductorTime) * scrollSpeed);
    }

    inline function get_scrollSpeed():Float
        return getScrollSpeed(0.45);

    inline function get_scrollMult():Float {
        var receptor:Receptor = parentStrumline?.receptors.members[direction];
        return (followSpeed && parentStrumline != null) ? (receptor.scrollMult ?? parentStrumline.scrollMult) : this.scrollMult;
    }

    inline function get_late():Bool {
        return this.late || (Conductor.time - time) > safeZoneOffset;
    }

    inline function get_downscroll():Bool
        return scrollMult < 0;

    inline function get_isSustainNote():Bool
        return sustain != null;

    function get_canBeHit():Bool {
        if (goodHit || missed)
            return false;

        if (parentStrumline != null)
            return (parentStrumline.cpu && time <= Conductor.time)
                || (!parentStrumline.cpu && Math.abs(Conductor.time - time) <= safeZoneOffset);

        return this.canBeHit;
    }

    override function set_cameras(v:Array<FlxCamera>):Array<FlxCamera> {
        if (isSustainNote)
            sustain.cameras = v;
        return super.set_cameras(v);
    }

    override function set_camera(v:FlxCamera):FlxCamera {
        if (isSustainNote)
            sustain.camera = v;
        return super.set_camera(v);
    }
}

class Sustain extends TiledSprite {
    public var tail(default, null):FlxSprite;
    public var parent:Note;

    public function new(parent:Note):Void {
        super(null, 0, 0, false, true);

        tail = new FlxSprite();
        alpha = 0.6;

        this.parent = parent;
        reloadGraphic();
    }

    override function update(elapsed:Float):Void {
        if (tail.exists && tail.active)
            tail.update(elapsed);

        if (!parent.overrideSustain)
            updateSustain();

        super.update(elapsed);
    }

    override function draw():Void {
        super.draw();

        if (tail.exists && tail.visible)
            tail.draw();
    }

    override function destroy():Void {
        tail = FlxDestroyUtil.destroy(tail);
        parent = null;

        super.destroy();
    }

    inline function updateSustain():Void {
        height = (parent.length * parent.scrollSpeed) - tail.height;

        // quantize the sustain, useful for noteskins with patterns
        if (!parent.downscroll && parent.quantizeSustain)  {
            var tileHeight:Float = graphic.height * scale.y;
            height = Math.fround(height / tileHeight) * tileHeight;
        }

        setPosition(parent.x + ((parent.width - width) * 0.5), parent.y + (parent.height * 0.5));
        if (parent.downscroll)
            y -= height;

        tail.setPosition(x, (parent.downscroll) ? (y - tail.height) : (y + height));
        flipY = (parent.flipSustain && parent.downscroll);
    }

    public inline function reloadGraphic():Void {
        var dir:String = Note.directions[parent.direction];

        // TODO: find a better solution (FlxTiledSprite does not support animations at the moment)
        frames = parent.frames;
        animation.copyFrom(parent.animation);
        animation.play(dir + " hold", true);
        loadFrame(frame ?? parent.frame);

        tail.frames = parent.frames;
        tail.animation.copyFrom(parent.animation);
        tail.animation.play(dir + " end", true);

        scale.set(parent.scale.x, parent.scale.y);
        tail.scale.set(scale.x, scale.y);
        updateHitbox();

        antialiasing = tail.antialiasing = parent.antialiasing;
    }

    override function updateHitbox():Void {
        width = graphic.width * scale.x;
        tail.updateHitbox();
    }

    override function set_height(v:Float):Float {
        if (!regen)
            regen = (v != height && v > 0);

        return height = v;
    }

    override function set_flipX(v:Bool):Bool {
        if (tail != null)
            tail.flipX = v;
        return super.set_flipX(v);
    }

    override function set_flipY(v:Bool):Bool {
        if (tail != null)
            tail.flipY = v;
        return super.set_flipY(v);
    }

    override function set_alpha(v:Float):Float {
        if (tail != null)
            tail.alpha = v;
        return super.set_alpha(v);
    }

    override function set_cameras(v:Array<FlxCamera>):Array<FlxCamera> {
        if (tail != null)
            tail.cameras = v;
        return super.set_cameras(v);
    }

    override function set_camera(v:FlxCamera):FlxCamera {
        if (tail != null)
            tail.camera = v;
        return super.set_camera(v);
    }
}