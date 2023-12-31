package funkin.objects.notes;

class Splash extends OffsetSprite {
    public function new():Void {
        super();

        frames = AssetHelper.getSparrowAtlas("notes/noteSplashes");

        var animationArray:Array<String> = ["down", "up", "left", "right"];
        for (i in 0...2) {
            var index:Int = i + 1;
            for (anim in animationArray) {
                var name:String = '${anim}-${index}';
                animation.addByPrefix('${anim}-${index}', 'splash${index} ${anim}', 24, false);
                animation.play(name);
                updateHitbox();
                addOffset(name, width * 0.3, height * 0.3);
            }
        }

        animation.finish();
        alpha = 0.6;
    }

    public function pop(direction:Int):Void {
        playAnimation('${Note.directions[direction]}-${FlxG.random.int(1, 2)}', true);
        animation.curAnim.frameRate += FlxG.random.float(-2, 2);
    }

    override function update(elapsed:Float):Void {
        if (animation.curAnim.finished)
            kill();

        super.update(elapsed);
    }
}