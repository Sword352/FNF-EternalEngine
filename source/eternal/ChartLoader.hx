package eternal;

import funkin.objects.notes.Note;
import eternal.ChartFormat.Chart;
import eternal.ChartFormat.ChartNote;
import eternal.ChartFormat.SongMetadata;

import tjson.TJSON as Json;

class ChartLoader {
    public static function getDefaultMeta():SongMetadata
        return {
            name: null,
            rawName: null,

            player: null,
            opponent: null,
            spectator: null,
            stage: null,

            instFile: "Inst",
            voiceFiles: ["Voices"]
        };
    
    public static function getDummyChart():Chart
        return {
            meta: getDefaultMeta(),

            notes: [],
            events: [],

            speed: 1,
            bpm: 100
        };

    public static function loadMetaData(song:String):SongMetadata {
        var path:String = AssetHelper.json('songs/${Tools.formatSong(song)}/meta');
        if (!FileTools.exists(path)) {
            trace('Path to ${song} has not been found, returning default metadata');
            return getDefaultMeta();
        }

        var data:SongMetadata = Json.parse(FileTools.getContent(path));

        if (data.rawName == null)
            data.rawName = song;

        if (data.name == null)
            data.name = data.rawName;

        return data;
    }

    public static function convertChart(data:Dynamic):Chart {
        var finalData:Chart = getDummyChart();

        finalData.speed = data.speed;
        finalData.bpm = data.bpm;

        finalData.meta = {
            name: data.song,
            rawName: Tools.formatSong(data.song),

            player: data.player1,
            opponent: data.player2,
            spectator: data.gfVersion ?? data.player3,
            stage: data.stage ?? "",

            instFile: "Inst",
            voiceFiles: (data.needsVoices) ? ["Voices"] : []
        };

        // Used to replace some section specific stuff with events
        var currentBPM:Float = data.bpm;
        var currentTarget:Int = -1;
        var sectCount:Int = 0;

        for (section in cast(data.notes, Array<Dynamic>)) {
            for (noteData in cast(section.sectionNotes, Array<Dynamic>)) {
                var shouldHit:Bool = section.mustHitSection;
                if (noteData[1] > 3)
                    shouldHit = !shouldHit;

                var data:ChartNote = {
                    time: noteData[0],
                    direction: Std.int(noteData[1] % 4),
                    strumline: shouldHit ? 1 : 0,
                    type: noteData[3],
                    animSuffix: (section.altAnim) ? "-alt" : null
                };

                data.length = (noteData[2] != null && noteData[2] is Float) ? noteData[2] : 0;
                finalData.notes.push(data);
            }

            var intendedTarget:Int = section.mustHitSection ? 2 : 0;
            if (intendedTarget != currentTarget) {
                finalData.events.push({
                    event: "change camera target",
                    time: Conductor.calculateMeasureTime(currentBPM) * sectCount,
                    arguments: [intendedTarget]
                });
                currentTarget = intendedTarget;
            }

            var intendedBPM:Null<Float> = section.changeBPM ? section.bpm : null;
            if (intendedBPM != null && intendedBPM != currentBPM) {
                finalData.events.push({
                    event: "change bpm",
                    time: Conductor.calculateMeasureTime(currentBPM) * sectCount,
                    arguments: [intendedBPM]
                });
                currentBPM = intendedBPM;
            }

            sectCount++;
        }

        return finalData;
    }

    public static function generateNotes(chart:Chart):Array<Note> {
        var notes:Array<Note> = [];
        var i:Int = 0;

        for (noteData in chart.notes) {
            var noteTime:Float = noteData.time - Conductor.offset;

            var note:Note = new Note(noteTime, noteData.direction);
            note.strumline = noteData.strumline;
            note.type = noteData.type;
            note.length = noteData.length;
            note.animSuffix = noteData.animSuffix;
            note.ID = i++;
            notes.push(note);
        }

        notes.sort((n1, n2) -> FlxSort.byValues(FlxSort.ASCENDING, n1.time, n2.time));
        return notes;
    }

    public static function loadChart(song:String, ?difficulty:String):Chart {
        if (difficulty == null)
            difficulty = "normal";

        var path:String = AssetHelper.json('songs/${song}/charts/${difficulty}');
        var data:Dynamic = Json.parse(FileTools.getContent(path));
        #if sys var overwrite:Bool = false; #end

        if (data.song != null) { // chart is from an engine using base game chart format
            data = convertChart(data.song);
            #if sys overwrite = Settings.get("overwrite chart files"); #end
        }
        else if (data.meta == null)
            data.meta = loadMetaData(song);

        if (data.meta.stage == null)
            data.meta.stage = "";

        // check for events
        if (data.events == null) {
            var eventsPath:String = AssetHelper.json('songs/${song}/events');
            if (FileTools.exists(eventsPath))
                data.events = Json.parse(FileTools.getContent(eventsPath));
            else
                data.events = [];
        }

        #if sys
        if (overwrite)
            sys.io.File.saveContent(path, Json.encode(data, null, false)); // overwrite the chart json
        #end

        return resolveChart(data);
    }

    inline public static function resolveChart(chart:Dynamic):Chart {
        if (chart is Chart)
            return chart;

        return {
            meta: chart.meta,

            notes: chart.notes,
            events: chart.events,

            speed: chart.speed,
            bpm: chart.bpm
        };
    }
}
