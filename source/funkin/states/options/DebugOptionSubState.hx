package funkin.states.options;

import funkin.objects.options.BoolOptionItem;

class DebugOptionSubState extends BaseOptionSubState {
    override function create():Void {
        var option:BoolOptionItem = new BoolOptionItem("editor access");
        option.description = "If enabled, allow access to debug editors.";
        addOption(option);

        #if sys
        var option:BoolOptionItem = new BoolOptionItem("overwrite chart files");
        option.description = "If enabled, overwrite the file of charts using legacy format once\nthey get loaded.";
        addOption(option);
        #end
        
        super.create();
    }
}