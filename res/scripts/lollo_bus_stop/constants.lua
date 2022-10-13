return {
    cargoNodeZ = -2,
    outerEdgeX = 1, -- 1 is enough for straightaways, curves need more than 10. The longer this is, the more buildings will be destroyed; 10 is a killer already.
    -- outerEdgeXCon = 0.7, -- we make this smaller then outerEdgeX so we can snap in curves -- useless, curves fail anyway
    outerEdgeXCon = 1,
    innerEdgeX = 0.5,
    innerEdgeXCon = 0.5,
    vehicleNodeZ = 0,
    minInitialEdgeLength = 2.5, -- must be >= 2 * outerEdgeX

    eventId = '__lolloBusStopEvent__',
    eventProperties = {
        edgesRemoved = { conName = nil, eventName = 'edgesRemoved' },
        conBuilt = { conName = nil, eventName = 'conBuilt' },
        conParamsUpdated = { conName = nil, eventName = 'conParamsUpdated' },
        ploppableStreetsidePassengerStationBuilt = { conName = nil, eventName = 'ploppableStreetsidePassengerStationBuilt' },
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

    parametricConFileName = 'station/street/lollo_bus_stop/stop_3.con',
}
