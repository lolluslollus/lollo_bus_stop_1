This mod slices a small piece of road in three chunks, then replaces them with a construction with three edges with the same shape and size, then adds a station to the middle one.

The mod works 95% of the times, but it crashes with "An error just occurred" when the user places the station in some particular points. These points are always the same and the error can be replicated many times. The game creates no "crash-*" savegame.
stdout.txt contains little useful information and the game script cannot catch the error.
The problem occurs just after proposalData = api.engine.util.proposal.makeProposalData(proposal, context), which should never fail in my opinion. Missing that, it happens after plopping the construction. Check out res/config/game_script/lollo_bus_stop.lua - line 619 to 624.
The error goes away if I remove the deges from the construction (the file is res/construction/station/street/lollo_bus_stop/stopParametric.script).

To reproduce this, load up the savegame attached here and look at the screenshots. Just start the game and build one of these stations where the screenshot shows.

I use build 35050 on Windows 11.
