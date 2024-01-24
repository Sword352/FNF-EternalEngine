package funkin.states.menus;

import flixel.text.FlxText;
import flixel.tweens.FlxTween;
import flixel.group.FlxSpriteGroup;

import funkin.states.substates.ResetScoreScreen;
import funkin.objects.sprites.DancingSprite;

class StoryMenu extends MusicBeatState {
    var weekSprites:FlxSpriteGroup;
    var difficultySprite:FlxSprite;
    var arrows:FlxSpriteGroup;

    var yellowOverlay:FlxSprite;
    var scoreText:FlxText;
    var tagline:FlxText;

    var songDisplay:FlxText;
    var tracks:FlxText;

    var charactersData:Map<String, StoryCharacterData> = [];
    var characters:FlxTypedSpriteGroup<StoryMenuCharacter>;

    var weeks:Array<WeekStructure>;
    var difficulties:Array<String>;

    var currentDifficulty:Int = 0;
    var currentSelection:Int = 0;

    var intendedScore:Float;
    var lerpScore:Float;

    var flashTimer:Float = 0;
    var doFlash:Bool = false;

    var allowInputs:Bool = true;
    var error:Bool = false;

    #if ENGINE_SCRIPTING
    var overrideCode:Bool = false;
    #end

    override function create():Void {
        weeks = loadWeeks();

        if (weeks == null || weeks.length < 1) {
            trace("Error loading weeks, going back to the Main Menu.");

            error = true;
            // persistentUpdate = false; // this does not seems to work??
            FlxG.switchState(new MainMenu());
            return;
        }

        PlayState.gameMode = STORY;

        #if ENGINE_DISCORD_RPC
        DiscordPresence.presence.details = "Story Menu";
        #end

        super.create();

        #if ENGINE_SCIRPTING
        initStateScript();
        hxsCall("onCreate");

        if (overrideCode) {
            hxsCall("onCreatePost");
            return;
        }
        #end

        Tools.playMusicCheck("freakyMenu");
        Conductor.music = FlxG.sound.music;
        Conductor.bpm = 102;

        // load menu characters
        var cacheHelper:FlxSprite = null;

        for (week in weeks) {
            if (week.characters == null)
                continue;

            for (character in week.characters) {
                if (character == "#NONE" || charactersData.exists(character))
                    continue;

                if (cacheHelper == null) {
                    cacheHelper = new FlxSprite();
                    cacheHelper.alpha = 0.00001;
                    add(cacheHelper);
                }

                var data:Dynamic = Tools.parseYAML(FileTools.getContent(Assets.yaml('images/menus/story/characters/${character}')));
                charactersData.set(character, data);

                // does this really cache all spritesheets?
                // TODO: test if it does
                cacheHelper.frames = Assets.getSparrowAtlas('menus/story/characters/${data.image ?? character}');
                @:privateAccess cacheHelper.drawComplex(camera);
            }
        }

        weekSprites = new FlxSpriteGroup();
        add(weekSprites);

        yellowOverlay = new FlxSprite(0, 56);
        yellowOverlay.makeRect(FlxG.width, 400, 0xFFF9CF51);

        tracks = new FlxText(FlxG.width * 0.05, yellowOverlay.x + yellowOverlay.height + 100, 0, "TRACKS");
        tracks.setFormat(Assets.font("vcr"), 44, 0xFFe55777);
        add(tracks);

        songDisplay = new FlxText(tracks.x, tracks.y + 50);
        songDisplay.setFormat(tracks.font, 32, tracks.color, CENTER);
        add(songDisplay);

        for (week in weeks) {
            // using OffsetSprite in case people wanna make those animated
            var sprite:OffsetSprite = new OffsetSprite();
            sprite.loadGraphic(Assets.image('menus/story/${week.image}'));
            sprite.ID = weeks.indexOf(week);
            sprite.y = sprite.ID * 120 + 480;
            sprite.screenCenter(X);
            weekSprites.add(sprite);
        }

        add(yellowOverlay);

        arrows = new FlxSpriteGroup();
        add(arrows);

        for (i in 0...2) {
            var direction:String = (i == 0) ? "left" : "right";

            var arrow:OffsetSprite = new OffsetSprite((FlxG.width * 0.8) + (150 * i), yellowOverlay.y + yellowOverlay.height + 10);
            arrow.frames = Assets.getSparrowAtlas("menus/story/ui");
            arrow.animation.addByPrefix("normal", 'arrow ${direction}', 0);
            arrow.animation.addByPrefix("press", 'arrow push ${direction}', 0);
            arrow.animation.play("normal", true);
            arrow.ID = i;
            arrows.add(arrow);
        }

        add(difficultySprite = new OffsetSprite());

        scoreText = new FlxText(10, 10);
        scoreText.setFormat(tracks.font, 32);
        add(scoreText);

        tagline = new FlxText(0, 10);
        tagline.setFormat(tracks.font, 32, FlxColor.WHITE, RIGHT);
        tagline.alpha = 0.7;
        add(tagline);

        characters = new FlxTypedSpriteGroup<StoryMenuCharacter>();
        for (i in 0...3) characters.add(new StoryMenuCharacter());
        add(characters);

        persistentUpdate = true;
        changeSelection();

        #if ENGINE_SCRIPTING
        hxsCall("onCreatePost");
        #end
    }

    override function update(elapsed:Float):Void {
        if (error)
            return;

        #if ENGINE_SCRIPTING
        hxsCall("onUpdate", [elapsed]);
        super.update(elapsed);

        if (overrideCode) {
            hxsCall("onUpdatePost", [elapsed]);
            return;
        }
        #else
        super.update(elapsed);
        #end

        if (allowInputs) {
            if (controls.justPressed("back")) {
                allowInputs = false;
                FlxG.sound.play(Assets.sound("cancelMenu"));
                FlxG.switchState(new MainMenu());
            }
    
            if (controls.justPressed("accept"))
                accept();
    
            if (weekSprites.length > 1 && controls.anyJustPressed(["up", "down"]))
                changeSelection((controls.lastAction == "up") ? -1 : 1);

            if (difficulties.length > 1 && controls.anyJustPressed(["left", "right"]))
                changeDifficulty((controls.lastAction == "left") ? -1 : 1);

            if (FlxG.keys.justPressed.R) {
                persistentUpdate = false;

                var screen:ResetScoreScreen = new ResetScoreScreen();
                screen.songs = [for (s in weeks[currentSelection].songs) s.folder];
                screen.difficulty = difficulties[currentDifficulty];
                screen.display = '"Week ${currentSelection + 1}" with difficulty "${screen.difficulty}"';
                screen.onReset = updateScore;
                screen.story = true;
                openSubState(screen);
            }
        }

        if (doFlash) {
            flashTimer += elapsed;
            if (flashTimer >= 0.05) {
                var sprite:FlxSprite = weekSprites.members[currentSelection];
                sprite.color = (sprite.color == FlxColor.WHITE) ? FlxColor.CYAN : FlxColor.WHITE;
                flashTimer = 0;
            }
        }

        lerpScore = Math.floor(Tools.lerp(lerpScore, intendedScore, 10));
        if (lerpScore != intendedScore && Math.abs(lerpScore - intendedScore) <= 10)
            lerpScore = intendedScore;

        scoreText.text = 'SCORE: ${lerpScore}';

        for (sprite in weekSprites) {
            sprite.y = Tools.lerp(sprite.y, sprite.ID * 120 + 480, 8.5);
            sprite.visible = (sprite.y > yellowOverlay.y);
        }

        for (arrow in arrows) {
            var animation:String = (controls.pressed((arrow.ID == 0) ? "left" : "right")) ? "press" : "normal";
            if (arrow.animation.name != animation)
                arrow.animation.play(animation, true);
        }

        #if ENGINE_SCRIPTING
        hxsCall("onUpdatePost", [elapsed]);
        #end
    }

    override function beatHit(currentBeat:Int):Void {
        for (character in characters)
            if (character.danceAnimations.length > 0 && character.animation.name != "confirm")
                character.dance(currentBeat, true);

        super.beatHit(currentBeat);
    }

    inline function changeSelection(i:Int = 0):Void {
        #if ENGINE_SCRIPTING
        if (cancellableCall("onSelectionChange", [i]))
            return;
        #end

        currentSelection = FlxMath.wrap(currentSelection + i, 0, weeks.length - 1);

        if (i != 0)
            FlxG.sound.play(Assets.sound("scrollMenu"));

        for (sprite in weekSprites) {
            sprite.ID = weekSprites.members.indexOf(sprite) - currentSelection;
            sprite.alpha = (sprite.ID == 0) ? 1 : 0.6;
        }

        tagline.text = weeks[currentSelection].tagline;
        tagline.x = FlxG.width - tagline.width - 10;

        var oldDifficulty:String = (difficulties != null) ? difficulties[currentDifficulty] : null;
        
        difficulties = weeks[currentSelection].difficulties;
        currentDifficulty = Std.int(FlxMath.bound(currentDifficulty, 0, difficulties.length - 1));

        if (difficulties.contains(oldDifficulty))
            currentDifficulty = difficulties.indexOf(oldDifficulty);

        updateDifficultySprite();

        var songList:String = "";
        for (song in weeks[currentSelection].songs)
            songList += song.name + "\n";

        songDisplay.text = songList;
        songDisplay.centerToObject(tracks, X);

        updateScore();

        var intendedCharacters:Array<String> = weeks[currentSelection].characters;
        characters.visible = intendedCharacters != null;

        if (characters.visible) {
            for (i in 0...characters.members.length) {
                var characterString:String = intendedCharacters[i];
                var character:StoryMenuCharacter = characters.members[i];
    
                character.visible = (characterString != null && characterString != "#NONE");
                if (!character.visible)
                    continue;
    
                character.setup(characterString, charactersData.get(characterString));
                character.x = (FlxG.width * 0.25) * (i + 1) - 150;
                character.centerToObject(yellowOverlay, Y);
            }
        }

        #if ENGINE_SCRIPTING
        hxsCall("onSelectionChangePost", [i]);
        #end
    }

    inline function changeDifficulty(i:Int = 0):Void {
        #if ENGINE_SCRIPTING
        if (cancellableCall("onDifficultyChange", [i]))
            return;
        #end

        currentDifficulty = FlxMath.wrap(currentDifficulty + i, 0, difficulties.length - 1);
        updateDifficultySprite();
        updateScore();

        #if ENGINE_SCRIPTING
        hxsCall("onDifficultyChangePost", [i]);
        #end
    }

    inline function updateDifficultySprite():Void {
        var graphic = Assets.image('menus/story/${difficulties[currentDifficulty]}');
        if (difficultySprite.graphic == graphic)
            return;

        FlxTween.cancelTweensOf(difficultySprite);

        difficultySprite.loadGraphic(graphic);
        difficultySprite.updateHitbox();
        difficultySprite.x = (FlxG.width * 0.825) - (difficultySprite.width * 0.5);

        var leftArrow:FlxSprite = arrows.members[0];
        var rightArrow:FlxSprite = arrows.members[1];

        leftArrow.x = difficultySprite.x - leftArrow.width - 10;
        rightArrow.x = difficultySprite.x + difficultySprite.width + 10;
        difficultySprite.y = rightArrow.y - 15;

        difficultySprite.alpha = 0;
        FlxTween.tween(difficultySprite, {y: rightArrow.y + 15, alpha: 1}, 0.07);
    }
    
    inline function updateScore():Void {
        intendedScore = 0;

        for (song in weeks[currentSelection].songs)
            intendedScore += Math.floor(HighScore.get('${song}-${difficulties[currentDifficulty]}_story').score);
    }

    inline function accept():Void {
        #if ENGINE_SCRIPTING
        if (cancellableCall("onAccept"))
            return;
        #end

        allowInputs = false;
        FlxG.sound.play(Assets.sound("confirmMenu"));

        weekSprites.members[currentSelection].color = FlxColor.CYAN;
        doFlash = !Settings.get("disable flashing lights");

        for (character in characters)
            if (character.animation.exists("confirm"))
                character.playAnimation("confirm", true);

        var songs:Array<String> = [for (s in weeks[currentSelection].songs) s.folder];
        TransitionSubState.onComplete.add(() -> PlayState.load(songs.shift(), difficulties[currentDifficulty]));
        PlayState.songPlaylist = songs;

        new FlxTimer().start(1, (_) -> FlxG.switchState(new PlayState()));

        #if ENGINE_SCRIPTING
        hxsCall("onAcceptPost");
        #end
    }

    override function destroy():Void {
        weeks = null;
        difficulties = null;
        charactersData = null;

        super.destroy();
    }

    public static function loadWeeks():Array<WeekStructure> {
        var allWeeks:String = Assets.getPath("data/weeks", NONE);

        if (!FileTools.exists(allWeeks) || !FileTools.isDirectory(allWeeks))
            return null;

        var list:Array<WeekStructure> = [];

        var foundWeeks:Array<String> = [];
        var orderPath:String = Assets.txt("data/weeks/weekOrder");

        if (FileTools.exists(orderPath)) {
            foundWeeks = FileTools.getContent(orderPath).split("\n").map((f) -> {
                f = f.trim();
                if (!f.endsWith(".yaml") && !f.endsWith(".yml"))
                    f += ".yml";
                return f;
            });
        }
        else
            foundWeeks = FileTools.readDirectory(allWeeks);

        for (file in foundWeeks) {
            var data = Tools.parseYAML(FileTools.getContent(allWeeks + "/" + file));

            var songs:Array<WeekSong> = cast data.songs;
            if (songs == null)
                continue;

            for (song in songs) {
                if (song.folder == null && song.name == null) {
                    songs.remove(song);
                    continue;
                }

                if (song.folder != null && song.name == null)
                    song.name = song.folder;
                else if (song.folder == null && song.name != null)
                    song.folder = song.name;
            }

            if (songs.length < 1)
                continue;

            list.push({
                songs: songs,
                difficulties: data.difficulties ?? ["Easy", "Normal", "Hard"],
                image: data.image ?? "week",
                tagline: data.tagline ?? "",
                characters: data.characters
            });
        }

        return list;
    }
}

private class StoryMenuCharacter extends DancingSprite {
    var globalOffsets:Array<Float> = [0, 0];
    var character:String;

    public function setup(character:String, data:StoryCharacterData):Void {
        if (this.character == character)
            return;

        this.character = character;

        frames = Assets.getSparrowAtlas('menus/story/characters/${data.image ?? character}');
        Tools.addYamlAnimations(this, data.animations);

        danceAnimations = data.danceAnimations ?? ["idle"];
        beat = data.danceBeat ?? 1;

        if (data.globalOffsets != null) {
            globalOffsets[0] = data.globalOffsets[0] ?? 0;
            globalOffsets[1] = data.globalOffsets[1] ?? 0;
        }
        else
            globalOffsets[0] = globalOffsets[1] = 0;

        flipX = data.flipX ?? false;

        scale.set(data.scale ?? 1, data.scale ?? 1);
        updateHitbox();

        forceDance(true);
        animation.finish();
        
        currentDance = 0;
    }

    override function forceDance(forced:Bool = false):Void {
        super.forceDance(forced);
        offset.add(globalOffsets[0], globalOffsets[1]);
    }

    override function destroy():Void {
        globalOffsets = null;
        character = null;
        super.destroy();
    }
}

@:structInit class WeekStructure {
    public var songs:Array<WeekSong>;
    public var difficulties:Array<String>;

    public var image:String;
    public var tagline:String;
    public var characters:Array<String>;
}

typedef WeekSong = {
    var name:String;
    var folder:String;
}

typedef StoryCharacterData = {
    var ?image:String;
    var animations:Array<YAMLAnimation>;

    var ?danceAnimations:Array<String>;
    var ?danceBeat:Float;

    var ?globalOffsets:Array<Float>;
    var ?scale:Float;
    var ?flipX:Bool;
}