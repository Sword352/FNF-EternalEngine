package funkin.music;

import flixel.sound.FlxSound;
import flixel.util.FlxSignal.FlxTypedSignal;

// TODO: maybe bpm-based timing like guitar hero, so it allows for the notes to automatically be conform to the bpm
// Aka if you are in the chart editor and the user changes the bpm
class Conductor {
    public static final MEASURE_LENGTH:Int = 16;

    public static var active:Bool = true;
    public static var music:FlxSound;
  
    public static final onStep:FlxTypedSignal<Int->Void> = new FlxTypedSignal();
    public static final onBeat:FlxTypedSignal<Int->Void> = new FlxTypedSignal();
    public static final onMeasure:FlxTypedSignal<Int->Void> = new FlxTypedSignal();

    public static var position:Float = 0;
    public static var offset:Float = 0;
    // public static var playbackRate(default, set):Float = 1;
    
    public static var bpm(default, set):Float = 100;
    public static var crochet(default, null):Float = 0;
    public static var stepCrochet(default, null):Float = 0;

    public static var currentStep(default, null):Int;
    public static var currentBeat(default, null):Int;
    public static var currentMeasure(default, null):Int;

    public static var decimalStep(default, null):Float;
    public static var decimalBeat(default, null):Float;
    public static var decimalMeasure(default, null):Float;

    private static var previousStep:Int = -1;
    private static var previousBeat:Int = -1;
    private static var previousMeasure:Int = -1;

    public static function update(elapsed:Float):Void {
        if (!active)
            return;

        if (music != null)
            position = music.time - offset;
        else
            position += elapsed * 1000;

        decimalStep = position / stepCrochet;
        currentStep = Math.floor(decimalStep);

        decimalBeat = decimalStep / 4;
        currentBeat = Math.floor(decimalBeat);

        decimalMeasure = decimalBeat / 4;
        currentMeasure = Math.floor(decimalMeasure);

        if (currentStep > previousStep) {
            previousStep = currentStep;
            onStep.dispatch(currentStep);
        }

        if (currentStep % 4 == 0 && currentBeat > previousBeat) {
            previousBeat = currentBeat;
            onBeat.dispatch(currentBeat);
        }

        if (currentBeat % 4 == 0 && currentMeasure > previousMeasure) {
            previousMeasure = currentMeasure;
            onMeasure.dispatch(currentMeasure);
        }
    }

    public static function reset():Void {
        resetPosition();
        resetCallbacks();
        
        music = null;
        bpm = 100;
        // playbackRate = 1;
    }

    public static function resetPosition():Void {
        position = 0;
        currentStep = 0;
        decimalStep = 0;
        currentBeat = 0;
        decimalBeat = 0;
        currentMeasure = 0;
        decimalMeasure = 0;
        resetPreviousPosition();
    }

    public static function resetPreviousPosition():Void {
        previousStep = -1;
        previousBeat = -1;
        previousMeasure = -1;
    }

    public static function resetCallbacks():Void {
        onStep.removeAll();
        onBeat.removeAll();
        onMeasure.removeAll();
    }

    public static function timeToStep(time:Float, ?bpm:Float):Int {
        return Math.floor(time / (bpm == null ? stepCrochet : calculateStepCrochet(bpm)));
    }

    public static function timeToBeat(time:Float, ?bpm:Float):Int {
        return Math.floor(timeToStep(time, bpm) / 4);
    }

    public static function timeToMeasure(time:Float, ?bpm:Float):Int {
        return Math.floor(timeToBeat(time, bpm) / 4);
    }

    public static function calculateStepCrochet(bpm:Float):Float {
        return calculateCrochet(bpm) / 4;
    }

    public static function calculateCrochet(bpm:Float):Float {
        return calculateBeatTime(bpm) * 1000;
    }

    public static function calculateBeatTime(bpm:Float):Float {
        return 60 / bpm;
    }

    public static function calculateMeasureTime(bpm:Float):Float {
        return (calculateCrochet(bpm) / 4) * MEASURE_LENGTH;
    }

    static function set_bpm(b:Float):Float {
        crochet = calculateCrochet(b);
        stepCrochet = crochet / 4;
        return bpm = b;
    }

    /*
    static function set_playbackRate(v:Float):Float {
        bpm *= v;
        return playbackRate = v;
    }
    */
}
