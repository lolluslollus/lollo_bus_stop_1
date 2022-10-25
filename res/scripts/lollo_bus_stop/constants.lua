return {
    cargoNodeZ = -2,
    outerEdgeX = 1, -- 1 is enough for straightaways, curves need more than 10. The longer this is, the more buildings will be destroyed; 10 is a killer already.
    outerEdgeXManualCon = 1,
    innerEdgeX = 0.5,
    innerEdgeXManualCon = 0.5,
    vehicleNodeZ = 0,
    minInitialEdgeLength = 2.5, -- must be >= 2 * outerEdgeX

    eventId = '__lolloBusStopEvent__',
    eventProperties = {
        edgesRemoved = { conName = nil, eventName = 'edgesRemoved' },
        conBuilt = { conName = nil, eventName = 'conBuilt' },
        conParamsUpdated = { conName = nil, eventName = 'conParamsUpdated' },
        ploppableStreetsidePassengerStationRemoved = { conName = nil, eventName = 'ploppableStreetsidePassengerStationRemoved' },
        firstOuterSplitDone = { conName = nil, eventName = 'firstOuterSplitDone'},
        secondOuterSplitDone = { conName = nil, eventName = 'secondOuterSplitDone' },
        firstInnerSplitDone = { conName = nil, eventName = 'firstInnerSplitDone'},
        secondInnerSplitDone = { conName = nil, eventName = 'secondInnerSplitDone' },
        snappyConBuilt = { conName = nil, eventName = 'snappyConBuilt'},
        snappyRoadsBuilt = { conName = nil, eventName = 'snappyRoadsBuilt'},
        initialEdgeObjectPlaced = { conName = nil, eventName = 'initialEdgeObjectPlaced' },
        setStateWorking = { conName = nil, eventName = 'setStateWorking' },
    },

    idTransf = {
        1, 0, 0, 0,
        0, 1, 0, 0,
        0, 0, 1, 0,
        0, 0, 0, 1,
    },

    autoPlacingConFileName = 'station/street/lollo_bus_stop/autoPlacingStop_dynamic.con',
    manualPlacingConFileName = 'station/street/lollo_bus_stop/manualPlacingStop_dynamic.con',
}
