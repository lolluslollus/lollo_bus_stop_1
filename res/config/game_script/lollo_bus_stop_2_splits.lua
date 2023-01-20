local arrayUtils = require('lollo_bus_stop.arrayUtils')
local constants = require('lollo_bus_stop.constants')
local edgeUtils = require('lollo_bus_stop.edgeUtils')
local guiHelpers = require('lollo_bus_stop.guiHelpers')
local logger = require('lollo_bus_stop.logger')
local moduleHelpers = require('lollo_bus_stop.moduleHelpers')
-- local pitchHelpers = require('lollo_bus_stop.pitchHelper')
local transfUtils = require('lollo_bus_stop.transfUtils')
local transfUtilsUG = require('transf')

-- LOLLO NOTE once the con has been built, you cannot configure it or it will unsnap and stay unsnapped.
-- Narrow angle
-- and
-- Construction not possible
-- stand in the way. This is why I use my own params gui, so I can force-snap the roads after configuring

-- LOLLO NOTE you can only update the state from the worker thread
-- We don't actually use this, as it can make trouble with uncatchable errors,
-- such as the obnoxious "an error has occurred" that can happen on evaluating or plopping a construction.
local state = { isWorking = false }

local _eventId = constants.eventId
local _eventProperties = constants.eventProperties

-- only accessible in the UI thread
local _guiData = {
    conIdAboutToBeBulldozed = false,
    conParamsMetadataSorted = {},
    ploppablePassengersModelId = false,
}

-- works as a semaphore for all functions that check state.isWorking before doing something
-- it sets the state in the worker thread and then fires a given event with the given args
-- It is redundant, see note above.
local _setStateWorking = function(isWorking, successEventName, successEventArgs)
    logger.print('_setStateWorking starting, isWorking =', tostring(isWorking or false))

    xpcall(
        function ()
            api.cmd.sendCommand(
                api.cmd.make.sendScriptEvent(
                    string.sub(debug.getinfo(1, 'S').source, 1),
                    _eventId,
                    _eventProperties.setStateWorking.eventName,
                    { isWorking = isWorking }
                ),
                function(result, success)
                    if not(successEventName) then return end

                    api.cmd.sendCommand(api.cmd.make.sendScriptEvent(
                        string.sub(debug.getinfo(1, 'S').source, 1),
                        _eventId,
                        successEventName,
                        successEventArgs
                    ))
                end
            )
        end,
        logger.xpErrorHandler
    )
end
-- Frees the semaphore.
-- It is redundant, see notes above
local _setStateReady = function()
    _setStateWorking(false)
end

local _utils = {
    getConOfStationGroup = function(stationGroupId)
        if not(edgeUtils.isValidAndExistingId(stationGroupId)) then return nil end

        local stationGroupProps = api.engine.getComponent(stationGroupId, api.type.ComponentType.STATION_GROUP)
        if not(stationGroupProps) then return nil end

        for _, stationId in pairs(stationGroupProps.stations) do
            if edgeUtils.isValidAndExistingId(stationId) then
                local conId = api.engine.system.streetConnectorSystem.getConstructionEntityForStation(stationId)
                if edgeUtils.isValidAndExistingId(conId) then
                    local con = api.engine.getComponent(conId, api.type.ComponentType.CONSTRUCTION)
                    if con ~= nil and con.fileName == constants.autoPlacingConFileName then
                        return conId, con
                    end
                end
            end
        end

        return nil
    end,
    -- get ids of edges that start or end at the given nodes
    getEdgeIdsLinkingNodes = function(node0Id, node1Id)
        if not(edgeUtils.isValidAndExistingId(node0Id)) or not(edgeUtils.isValidAndExistingId(node1Id)) then
            logger.warn('getEdgeIdsLinkingNodes got invalid node0Id or node1Id')
            return {}
        end

        local _map = api.engine.system.streetSystem.getNode2SegmentMap()
        local connectedEdgeIdsUserdata0 = _map[node0Id] -- userdata
        local connectedEdgeIdsUserdata1 = _map[node1Id] -- userdata
        if connectedEdgeIdsUserdata0 == nil or connectedEdgeIdsUserdata1 == nil then
            logger.warn('getEdgeIdsLinkingNodes: the edges between node0Id and node1Id are not connected to their nodes, this should never happen')
            return {}
        end
        local edgeIdsBetweenNodes = {}
        for _, edge0Id in pairs(connectedEdgeIdsUserdata0) do
            for _, edge1Id in pairs(connectedEdgeIdsUserdata1) do
                if edge0Id == edge1Id then
                    arrayUtils.addUnique(edgeIdsBetweenNodes, edge0Id)
                end
            end
        end

        return edgeIdsBetweenNodes
    end,
    getPlayerOwned = function()
        local result = api.type.PlayerOwned.new()
        result.player = api.engine.util.getPlayer()
        return result
    end,
    getStationEndNodeIds = function(con)
        local frozenNodeIds = con.frozenNodes
        local frozenEdgeIds = con.frozenEdges
        local endNodeIdsUnsorted = {}
        for _, edgeId in pairs(frozenEdgeIds) do
            local baseEdge = api.engine.getComponent(edgeId, api.type.ComponentType.BASE_EDGE)
            if baseEdge == nil then
                logger.warn('baseEdge is NIL, edgeId = ' .. (edgeId or 'NIL'))
                return { }
            end
            if not(arrayUtils.arrayHasValue(frozenNodeIds, baseEdge.node0)) then
                arrayUtils.addUnique(endNodeIdsUnsorted, baseEdge.node0)
            end
            if not(arrayUtils.arrayHasValue(frozenNodeIds, baseEdge.node1)) then
                arrayUtils.addUnique(endNodeIdsUnsorted, baseEdge.node1)
            end
        end
        logger.print('endNodeIdsUnsorted =') logger.debugPrint(endNodeIdsUnsorted)
        return endNodeIdsUnsorted
    end,
    -- this is not so good, it can crash even with xpcall and it does not always foresee all accidents
    getIsProposalOK = function(proposal, context)
        logger.print('getIsProposalOK starting with state =') logger.debugPrint(state)
        if not(proposal) then logger.err('getIsProposalOK got no proposal') return false end
        -- if not(context) then logger.err('getIsProposalOK got no context') return false end

        local isErrorsOtherThanCollision = false
        local isWarnings = false
        xpcall(
            function()
                -- this tries to build the construction, it calls con.updateFn()
                -- UG TODO this should never crash, but it crashes in the construction thread, and it is uncatchable here.
                local proposalData = api.engine.util.proposal.makeProposalData(proposal, context)
                -- logger.print('getIsProposalOK proposalData =') logger.debugPrint(proposalData)

                if proposalData.errorState ~= nil then
                    if proposalData.errorState.critical == true then
                        logger.print('proposalData.errorState.critical is true')
                        logger.print('proposalData.errorState =') logger.debugPrint(proposalData.errorState)
                        isErrorsOtherThanCollision = true
                    else
                        for _, message in pairs(proposalData.errorState.messages or {}) do
                            logger.print('looping over messages, message found =', message)
                            if message ~= 'Collision' then
                                isErrorsOtherThanCollision = true
                                logger.print('found message', message or 'NIL')
                                break
                            end
                        end
                        for _, warning in pairs(proposalData.errorState.warnings or {}) do
                            logger.print('looping over warnings, warning found =', warning)
                            if warning ~= 'Main connection will be interrupted' then
                                isWarnings = true
                                logger.print('found warning', warning or 'NIL')
                                break
                            end
                        end
                    end
                end
            end,
            function(error)
                isErrorsOtherThanCollision = true
                logger.warn('getIsProposalOK caught an exception')
                logger.xpWarningHandler(error)
            end
        )
        logger.print('getIsProposalOK isErrorsOtherThanCollision =', isErrorsOtherThanCollision)
        logger.print('getIsProposalOK isWarnings =', isWarnings)
        return not(isErrorsOtherThanCollision) -- and not(isWarnings)
    end,
    getNewlyBuiltEdgeId = function(result)
        -- result.proposal.proposal.addedSegments[1].entity is not always available, UG TODO this api should always return an edgeId
        if edgeUtils.isValidAndExistingId(result.proposal.proposal.addedSegments[1].entity) then
            return result.proposal.proposal.addedSegments[1].entity
        else
            local node0Id = result.proposal.proposal.addedSegments[1].comp.node0
            local node1Id = result.proposal.proposal.addedSegments[1].comp.node1
            if not(edgeUtils.isValidAndExistingId(node0Id)) or not(edgeUtils.isValidAndExistingId(node1Id)) then
                logger.warn('the newly built edge has invalid nodes, this should never happen')
                return nil
            end
            if not(result.proposal.proposal.addedSegments[1].comp.tangent0) or not(result.proposal.proposal.addedSegments[1].comp.tangent1) then
                logger.warn('the newly built edge has no tangents, this should never happen')
                return nil
            end
            local edgeTan0 = result.proposal.proposal.addedSegments[1].comp.tangent0 -- userdata
            local edgeTan1 = result.proposal.proposal.addedSegments[1].comp.tangent1 -- userdata

            local _map = api.engine.system.streetSystem.getNode2SegmentMap()
            local connectedEdgeIdsUserdata0 = _map[node0Id] -- userdata
            local connectedEdgeIdsUserdata1 = _map[node1Id] -- userdata
            if connectedEdgeIdsUserdata0 == nil or connectedEdgeIdsUserdata1 == nil then
                logger.warn('the newly built edge is not connected to its nodes, this should never happen')
                return nil
            end

            local edgeIdsBetweenNodes = {}
            for _, edge0Id in pairs(connectedEdgeIdsUserdata0) do
                for _, edge1Id in pairs(connectedEdgeIdsUserdata1) do
                    if edge0Id == edge1Id then
                        arrayUtils.addUnique(edgeIdsBetweenNodes, edge0Id)
                    end
                end
            end
            logger.print('edgeIdsBetweenNodes =') logger.debugPrint(edgeIdsBetweenNodes)
            if #edgeIdsBetweenNodes == 0 then
                logger.warn('cannot find the edgeId, I got no results')
                return nil
            end

            logger.print('edgeTan0 =') logger.debugPrint(edgeTan0)
            logger.print('edgeTan1 =') logger.debugPrint(edgeTan1)
            -- if #edgeIdsBetweenNodes > 1 then
                for _, edgeId in pairs(edgeIdsBetweenNodes) do
                    local testBaseEdge = api.engine.getComponent(edgeId, api.type.ComponentType.BASE_EDGE)
                    if testBaseEdge ~= nil then
                        logger.print('testBaseEdge.tangent0 =') logger.debugPrint(testBaseEdge.tangent0)
                        logger.print('testBaseEdge.tangent1 =') logger.debugPrint(testBaseEdge.tangent1)

                        if (edgeUtils.isXYZSame(testBaseEdge.tangent0, edgeTan0)
                        and edgeUtils.isXYZSame(testBaseEdge.tangent1, edgeTan1))
                        or (edgeUtils.isXYZSame(testBaseEdge.tangent0, edgeTan1)
                        and edgeUtils.isXYZSame(testBaseEdge.tangent1, edgeTan0))
                        then
                            logger.print('found the edge, it is ' .. tostring(edgeId))
                            return edgeId
                        end
                    end
                end
            -- end

            logger.warn('cannot find the new edgeId, giving up')
            return nil
        end
    end,
    getNewlyBuiltNodeId = function(result)
        -- result.proposal.proposal.addedSegments[1].entity is not always available, UG TODO this api should always return an edgeId
        if edgeUtils.isValidAndExistingId(result.proposal.proposal.addedNodes[1].entity) then
            return result.proposal.proposal.addedNodes[1].entity
        else
            local _tolerance = 0.001
            local positionXYZ = result.proposal.proposal.addedNodes[1].comp.position
            -- logger.print('positionXYZ =') logger.debugPrint(positionXYZ)
            -- logger.print('positionXYZ.z =') logger.debugPrint(positionXYZ.z)
            -- logger.print('type(positionXYZ.z) =') logger.debugPrint(type(positionXYZ.z))
            -- logger.print('tonumber(positionXYZ.z, 10)') logger.debugPrint(tonumber(positionXYZ.z, 10))
            -- logger.print('tonumber(positionXYZ.z)') logger.debugPrint(tonumber(positionXYZ.z))
            local nodeIds = edgeUtils.getNearbyObjectIds(
                transfUtils.position2Transf(positionXYZ),
                _tolerance,
                api.type.ComponentType.BASE_NODE,
                tonumber(positionXYZ.z) - _tolerance,
                tonumber(positionXYZ.z) + _tolerance
            )
            if #nodeIds ~= 1 then
                logger.warn('cannot find newly built node')
                return nil
            end
            if not(edgeUtils.isValidAndExistingId(nodeIds[1])) then
                logger.warn('newly built node is invalid')
                return nil
            end
            logger.print('nodeId found, it is ' .. tostring(nodeIds[1]))
            return nodeIds[1]
        end
    end,
    -- get data to start the second split after the first succeeded
    getSplit1Data = function(transf1, node0EdgeIds)
        logger.print('getSplit1Data starting, transf1 =') logger.debugPrint(transf1)
        local edgeId2BeSplit = nil
        local nodeBetween = nil
        local minDistance = 9999.9
        for _, edgeId in pairs(node0EdgeIds) do
            local baseEdge = api.engine.getComponent(edgeId, api.type.ComponentType.BASE_EDGE)
            if baseEdge ~= nil then
                local baseNode0 = api.engine.getComponent(baseEdge.node0, api.type.ComponentType.BASE_NODE)
                local baseNode1 = api.engine.getComponent(baseEdge.node1, api.type.ComponentType.BASE_NODE)
                logger.print('baseNode0.position =') logger.debugPrint(baseNode0.position)
                logger.print('baseNode1.position =') logger.debugPrint(baseNode1.position)
                if baseNode0 ~= nil and baseNode1 ~= nil then
                    local testNodeBetween = edgeUtils.getNodeBetweenByPosition(
                        edgeId,
                        {
                            x = transf1[13],
                            y = transf1[14],
                            z = transf1[15],
                        }
                        -- logger.getIsExtendedLog()
                    )
                    if testNodeBetween == nil then logger.print('testNodeBetween is NIL')
                    else logger.print('testNodeBetween.position =') logger.debugPrint(testNodeBetween.position)
                    end
                    if testNodeBetween ~= nil then
                        local currentDistance = transfUtils.getPositionsDistance(
                            testNodeBetween.position,
                            transfUtils.transf2Position(transf1)
                        )
                        logger.print('currentDistance =') logger.debugPrint(currentDistance)
                        if currentDistance ~= nil and currentDistance < minDistance then
                            logger.print('setting nodeBetween')
                            edgeId2BeSplit = edgeId
                            minDistance = currentDistance
                            nodeBetween = arrayUtils.cloneDeepOmittingFields(testNodeBetween)
                        end
                    end
                end
            end
        end
        return edgeId2BeSplit, nodeBetween
    end,
    getPosTransformed = function(pos, transf)
        local result = transfUtils.getVec123Transformed(pos, transf)
        return result
    end,
    getTanTransformed = function(tan, transf)
        local _rotateScaleTransf = {
            transf[1], transf[2], transf[3], transf[4],
            transf[5], transf[6], transf[7], transf[8],
            transf[9], transf[10], transf[11], transf[12],
            0, 0, 0, 1
        }

        local result = transfUtils.getVec123Transformed(tan, _rotateScaleTransf)
        return result
    end,
    getWhichEdgeGetsEdgeObjectAfterSplit = function(edgeObjPosition, node0pos, node1pos, nodeBetween)
        local result = {
            assignToSide = nil,
        }
        local edgeObjPosition_assignTo = nil
        local node0_assignTo = nil
        local node1_assignTo = nil
        -- at nodeBetween, I can draw the normal to the road:
        -- y = a + bx
        -- the angle is alpha = atan2(nodeBetween.tangent.y, nodeBetween.tangent.x) + PI / 2
        -- so b = math.tan(alpha)
        -- a = y - bx
        -- so a = nodeBetween.position.y - b * nodeBetween.position.x
        -- points under this line will go one way, the others the other way
        local alpha = math.atan2(nodeBetween.tangent.y, nodeBetween.tangent.x) + math.pi * 0.5
        local b = math.tan(alpha)
        if math.abs(b) < 1e+06 then
            local a = nodeBetween.position.y - b * nodeBetween.position.x
            if a + b * edgeObjPosition[1] > edgeObjPosition[2] then -- edgeObj is below the line
                edgeObjPosition_assignTo = 0
            else
                edgeObjPosition_assignTo = 1
            end
            if a + b * node0pos[1] > node0pos[2] then -- wholeEdge.node0pos is below the line
                node0_assignTo = 0
            else
                node0_assignTo = 1
            end
            if a + b * node1pos[1] > node1pos[2] then -- wholeEdge.node1pos is below the line
                node1_assignTo = 0
            else
                node1_assignTo = 1
            end
        -- if b grows too much, I lose precision, so I approximate it with the y axis
        else
            -- print('alpha =', alpha, 'b =', b)
            if edgeObjPosition[1] > nodeBetween.position.x then
                edgeObjPosition_assignTo = 0
            else
                edgeObjPosition_assignTo = 1
            end
            if node0pos[1] > nodeBetween.position.x then
                node0_assignTo = 0
            else
                node0_assignTo = 1
            end
            if node1pos[1] > nodeBetween.position.x then
                node1_assignTo = 0
            else
                node1_assignTo = 1
            end
        end

        if edgeObjPosition_assignTo == node0_assignTo then
            result.assignToSide = 0
        elseif edgeObjPosition_assignTo == node1_assignTo then
            result.assignToSide = 1
        end

        -- logger.print('LOLLO assignment =') logger.debugPrint(result)
        return result
    end,
    -- guiWaitLockingThread = function(isExitFunc)
    --     if isExitFunc() then return end

    --     local _intervalMsec = 100
    --     local exitMsec = math.ceil(os.clock() * 1000) + _intervalMsec
    --     while true do
    --         if math.ceil(os.clock() * 1000) > exitMsec then
    --             logger.print('checking if we can stop waiting')
    --             if isExitFunc() then return end
    --             exitMsec = exitMsec + _intervalMsec
    --         end
    --     end
    -- end,
}
local _actions = {
    buildConstruction = function(outerNode0Id, outerNode1Id, streetType, groundBridgeTunnel012, bridgeOrTunnelType, tramTrackType, hasBus, edgeData4Con)
        logger.print('buildConstruction starting, streetType =', streetType, 'groundBridgeTunnel012 =', groundBridgeTunnel012, 'bridgeOrTunnelType =', bridgeOrTunnelType, 'tramTrackType =', tramTrackType, 'hasBus =', hasBus)
        logger.print('edgeData4Con =') logger.debugPrint(edgeData4Con)
        if not(edgeUtils.isValidAndExistingId(outerNode0Id)) or not(edgeUtils.isValidAndExistingId(outerNode1Id)) then
            logger.warn('buildConstruction received an invalid node id')
            _setStateReady()
            return
        end

        local baseNode0 = api.engine.getComponent(outerNode0Id, api.type.ComponentType.BASE_NODE)
        local baseNode1 = api.engine.getComponent(outerNode1Id, api.type.ComponentType.BASE_NODE)
        if baseNode0 == nil or baseNode1 == nil then
            logger.warn('cannot find outerNode0Id or outerNode1Id')
            _setStateReady()
            return
        end

        local conTransf_lua = transfUtils.getTransf2FitObjectBetweenPositions(baseNode0.position, baseNode1.position, constants.outerEdgeX * 2) --, logger)
        local _inverseConTransf = transfUtils.getInverseTransf(conTransf_lua)
        logger.print('_inverseConTransf =') logger.debugPrint(_inverseConTransf)

        local newCon = api.type.SimpleProposal.ConstructionEntity.new()
        -- newCon.fileName = constants.manualPlacingConFileName
        newCon.fileName = constants.autoPlacingConFileName
        --[[
            LOLLO NOTE
            In postRunFn, api.res.streetTypeRep.getAll() only returns street types,
            which are available in the present game.
            In other lua states, eg in game_script, it returns all street types, which have ever been present in the game,
            including those from inactive mods.
            This is why we read the data from the table that we set in postRunFn, and not from the api.
        ]]
        local globalBridgeData = arrayUtils.cloneDeepOmittingFields(api.res.constructionRep.get(api.res.constructionRep.find(constants.autoPlacingConFileName)).updateScript.params.globalBridgeData, nil, true)
        local globalTunnelData = arrayUtils.cloneDeepOmittingFields(api.res.constructionRep.get(api.res.constructionRep.find(constants.autoPlacingConFileName)).updateScript.params.globalTunnelData, nil, true)
        local globalStreetData = arrayUtils.cloneDeepOmittingFields(api.res.constructionRep.get(api.res.constructionRep.find(constants.autoPlacingConFileName)).updateScript.params.globalStreetData, nil, true)

        local bridgeTypeFileName = groundBridgeTunnel012 == 1 and type(bridgeOrTunnelType) == 'number' and bridgeOrTunnelType > -1 and api.res.bridgeTypeRep.getName(bridgeOrTunnelType) or nil
        logger.print('bridgeTypeFileName =', bridgeTypeFileName or 'NIL')
        local bridgeTypeIndexBase0 = 0 -- no bridge
        if type(bridgeTypeFileName) == 'string' then
            local index = arrayUtils.findIndex(globalBridgeData, 'fileName', bridgeTypeFileName) -- the first item is no bridge
            logger.print('index =', index)
            if index > 0 then
                bridgeTypeIndexBase0 = index - 1 -- base 0
            end
        end

        local tunnelTypeFileName = groundBridgeTunnel012 == 2 and type(bridgeOrTunnelType) == 'number' and bridgeOrTunnelType > -1 and api.res.tunnelTypeRep.getName(bridgeOrTunnelType) or nil
        logger.print('tunnelTypeFileName =', tunnelTypeFileName or 'NIL')
        local tunnelTypeIndexBase0 = 0 -- no tunnel
        if type(tunnelTypeFileName) == 'string' then
            local index = arrayUtils.findIndex(globalTunnelData, 'fileName', tunnelTypeFileName) -- the first item is no tunnel
            logger.print('index =', index)
            if index > 0 then
                tunnelTypeIndexBase0 = index - 1 -- base 0
            end
        end

        -- logger.print('buildConstruction: the api found ' .. #api.res.streetTypeRep.getAll() .. ' street types')
        local streetTypeFileName = api.res.streetTypeRep.getName(streetType)
        if type(streetTypeFileName) ~= 'string' then
            logger.warn('cannot find street type', streetType or 'NIL')
            _setStateReady()
            return
        end
        local streetTypeIndexBase0 = arrayUtils.findIndex(globalStreetData, 'fileName', streetTypeFileName) - 1 -- base 0
        if streetTypeIndexBase0 < 0 then
            logger.warn('cannot find street type index', streetType or 'NIL')
            _setStateReady()
            return
        end
        local _pitchAngle = math.atan2(
            edgeData4Con.outerNode1Pos[3] - edgeData4Con.outerNode0Pos[3],
            math.sqrt((edgeData4Con.outerNode1Pos[1] - edgeData4Con.outerNode0Pos[1])^2 + (edgeData4Con.outerNode1Pos[2] - edgeData4Con.outerNode0Pos[2])^2)
                -- * ((edgeData4Con.outerNode1Pos[1] > edgeData4Con.outerNode0Pos[1]) and 1 or -1)
        )

        local _, conParamsMetadataIndexed = moduleHelpers.getAutoPlacingParamsMetadata()
        local newParams = {
            -- lolloBusStop_testHuge = 12345678901234567890, -- it becomes 1.2345678901235e+19 at first, -2147483648 at the first upgrade
            -- it will not change if no params are declared with the construction.
            -- lolloBusStop_testVeryLarge = 100000000.123455, -- this works
            -- these disappear at the first upgrade
            -- lolloBusStop_testTable = {123, 456},
            -- lolloBusStop_testDec = {-123.456},
            -- lolloBusStop_testStr = '-123.456',
            -- lolloBusStop_testStrTab1 = {'-123.456'},
            -- lolloBusStop_testStrTab2 = {'-123.456, 124.457'},
            -- state = {
            --     lolloBusStop_testTable = {123, 456},
            --     lolloBusStop_testDec = {-123.456},
            --     lolloBusStop_testStr = '-123.456',
            --     lolloBusStop_testStrTab1 = {'-123.456'},
            --     lolloBusStop_testStrTab2 = {'-123.456, 124.457'},
            -- },
            -- paramLOL = {
            --     lolloBusStop_testTable = {123, 456},
            --     lolloBusStop_testDec = {-123.456},
            --     lolloBusStop_testStr = '-123.456',
            --     lolloBusStop_testStrTab1 = {'-123.456'},
            --     lolloBusStop_testStrTab2 = {'-123.456, 124.457'},
            -- },

            lolloBusStop_bothSides = conParamsMetadataIndexed['lolloBusStop_bothSides'].defaultIndex,
            lolloBusStop_bridgeOrTunnelType = groundBridgeTunnel012 == 0 and 0 or (groundBridgeTunnel012 == 1 and bridgeTypeIndexBase0 or tunnelTypeIndexBase0),
            lolloBusStop_groundBridgeTunnel012 = groundBridgeTunnel012,
            lolloBusStop_direction = conParamsMetadataIndexed['lolloBusStop_direction'].defaultIndex,
            lolloBusStop_driveOnLeft = conParamsMetadataIndexed['lolloBusStop_driveOnLeft'].defaultIndex,
            lolloBusStop_hasBus = hasBus,
            lolloBusStop_model = conParamsMetadataIndexed['lolloBusStop_model'].defaultIndex,
            -- these make no sense coz they will be replaced with operations outside the station
            -- lolloBusStop_outerNode0Id = outerNode0Id, -- this stays across upgrades because it's an integer
            -- lolloBusStop_outerNode1Id = outerNode1Id, -- idem
            lolloBusStop_outerNode0Pos_absolute = (edgeData4Con.outerNode0Pos), -- arrayUtils.cloneOmittingFields(edgeData4Con.outerNode0Pos),
            lolloBusStop_outerNode1Pos_absolute = (edgeData4Con.outerNode1Pos), --arrayUtils.cloneOmittingFields(edgeData4Con.outerNode1Pos),
            lolloBusStop_freeNodes = 3,
            -- lolloBusStop_freeNodes = 0,
            lolloBusStop_snapNodes = 3,
            -- lolloBusStop_snapNodes = 0,
            lolloBusStop_streetType = streetTypeIndexBase0,
            lolloBusStop_tramTrack = tramTrackType,
            seed = math.abs(math.ceil(conTransf_lua[13] * 100)),
            lolloBusStop_edge0Tan0 = _utils.getTanTransformed(edgeData4Con.edge0Tan0, _inverseConTransf),
            lolloBusStop_edge0Tan1 = _utils.getTanTransformed(edgeData4Con.edge0Tan1, _inverseConTransf),
            lolloBusStop_edge1Tan0 = _utils.getTanTransformed(edgeData4Con.edge1Tan0, _inverseConTransf),
            lolloBusStop_edge1Tan1 = _utils.getTanTransformed(edgeData4Con.edge1Tan1, _inverseConTransf),
            lolloBusStop_edge2Tan0 = _utils.getTanTransformed(edgeData4Con.edge2Tan0, _inverseConTransf),
            lolloBusStop_edge2Tan1 = _utils.getTanTransformed(edgeData4Con.edge2Tan1, _inverseConTransf),
            lolloBusStop_innerNode0Pos = _utils.getPosTransformed(edgeData4Con.innerNode0Pos, _inverseConTransf),
            lolloBusStop_innerNode1Pos = _utils.getPosTransformed(edgeData4Con.innerNode1Pos, _inverseConTransf),
            lolloBusStop_outerNode0Pos = _utils.getPosTransformed(edgeData4Con.outerNode0Pos, _inverseConTransf),
            lolloBusStop_outerNode1Pos = _utils.getPosTransformed(edgeData4Con.outerNode1Pos, _inverseConTransf),
            -- lolloBusStop_pitch = pitchHelpers.getDefaultPitchParamValue(),
            -- lolloBusStop_pitchAngle = pitchHelpers.getDefaultPitchParamValue(),
            lolloBusStop_pitchAngle = _pitchAngle,
        }
        logger.print('lolloBusStop_model =', newParams.lolloBusStop_model or 'NIL')
        -- these work but we don't need them anymore, since we moved to parameterless con
        --[[
        moduleHelpers.setIntParamsFromFloat(newParams, 'edge0Tan0X', _utils.getTanTransformed(edgeData4Con.edge0Tan0, _inverseConTransf)[1], 'lolloBusStop_')
        moduleHelpers.setIntParamsFromFloat(newParams, 'edge0Tan0Y', _utils.getTanTransformed(edgeData4Con.edge0Tan0, _inverseConTransf)[2], 'lolloBusStop_')
        moduleHelpers.setIntParamsFromFloat(newParams, 'edge0Tan0Z', _utils.getTanTransformed(edgeData4Con.edge0Tan0, _inverseConTransf)[3], 'lolloBusStop_')
        moduleHelpers.setIntParamsFromFloat(newParams, 'edge0Tan1X', _utils.getTanTransformed(edgeData4Con.edge0Tan1, _inverseConTransf)[1], 'lolloBusStop_')
        moduleHelpers.setIntParamsFromFloat(newParams, 'edge0Tan1Y', _utils.getTanTransformed(edgeData4Con.edge0Tan1, _inverseConTransf)[2], 'lolloBusStop_')
        moduleHelpers.setIntParamsFromFloat(newParams, 'edge0Tan1Z', _utils.getTanTransformed(edgeData4Con.edge0Tan1, _inverseConTransf)[3], 'lolloBusStop_')

        moduleHelpers.setIntParamsFromFloat(newParams, 'edge1Tan0X', _utils.getTanTransformed(edgeData4Con.edge1Tan0, _inverseConTransf)[1], 'lolloBusStop_')
        moduleHelpers.setIntParamsFromFloat(newParams, 'edge1Tan0Y', _utils.getTanTransformed(edgeData4Con.edge1Tan0, _inverseConTransf)[2], 'lolloBusStop_')
        moduleHelpers.setIntParamsFromFloat(newParams, 'edge1Tan0Z', _utils.getTanTransformed(edgeData4Con.edge1Tan0, _inverseConTransf)[3], 'lolloBusStop_')
        moduleHelpers.setIntParamsFromFloat(newParams, 'edge1Tan1X', _utils.getTanTransformed(edgeData4Con.edge1Tan1, _inverseConTransf)[1], 'lolloBusStop_')
        moduleHelpers.setIntParamsFromFloat(newParams, 'edge1Tan1Y', _utils.getTanTransformed(edgeData4Con.edge1Tan1, _inverseConTransf)[2], 'lolloBusStop_')
        moduleHelpers.setIntParamsFromFloat(newParams, 'edge1Tan1Z', _utils.getTanTransformed(edgeData4Con.edge1Tan1, _inverseConTransf)[3], 'lolloBusStop_')

        moduleHelpers.setIntParamsFromFloat(newParams, 'edge2Tan0X', _utils.getTanTransformed(edgeData4Con.edge2Tan0, _inverseConTransf)[1], 'lolloBusStop_')
        moduleHelpers.setIntParamsFromFloat(newParams, 'edge2Tan0Y', _utils.getTanTransformed(edgeData4Con.edge2Tan0, _inverseConTransf)[2], 'lolloBusStop_')
        moduleHelpers.setIntParamsFromFloat(newParams, 'edge2Tan0Z', _utils.getTanTransformed(edgeData4Con.edge2Tan0, _inverseConTransf)[3], 'lolloBusStop_')
        moduleHelpers.setIntParamsFromFloat(newParams, 'edge2Tan1X', _utils.getTanTransformed(edgeData4Con.edge2Tan1, _inverseConTransf)[1], 'lolloBusStop_')
        moduleHelpers.setIntParamsFromFloat(newParams, 'edge2Tan1Y', _utils.getTanTransformed(edgeData4Con.edge2Tan1, _inverseConTransf)[2], 'lolloBusStop_')
        moduleHelpers.setIntParamsFromFloat(newParams, 'edge2Tan1Z', _utils.getTanTransformed(edgeData4Con.edge2Tan1, _inverseConTransf)[3], 'lolloBusStop_')

        moduleHelpers.setIntParamsFromFloat(newParams, 'innerNode0PosX', _utils.getPosTransformed(edgeData4Con.innerNode0Pos, _inverseConTransf)[1], 'lolloBusStop_')
        moduleHelpers.setIntParamsFromFloat(newParams, 'innerNode0PosY', _utils.getPosTransformed(edgeData4Con.innerNode0Pos, _inverseConTransf)[2], 'lolloBusStop_')
        moduleHelpers.setIntParamsFromFloat(newParams, 'innerNode0PosZ', _utils.getPosTransformed(edgeData4Con.innerNode0Pos, _inverseConTransf)[3], 'lolloBusStop_')

        moduleHelpers.setIntParamsFromFloat(newParams, 'innerNode1PosX', _utils.getPosTransformed(edgeData4Con.innerNode1Pos, _inverseConTransf)[1], 'lolloBusStop_')
        moduleHelpers.setIntParamsFromFloat(newParams, 'innerNode1PosY', _utils.getPosTransformed(edgeData4Con.innerNode1Pos, _inverseConTransf)[2], 'lolloBusStop_')
        moduleHelpers.setIntParamsFromFloat(newParams, 'innerNode1PosZ', _utils.getPosTransformed(edgeData4Con.innerNode1Pos, _inverseConTransf)[3], 'lolloBusStop_')

        moduleHelpers.setIntParamsFromFloat(newParams, 'outerNode0PosX', _utils.getPosTransformed(edgeData4Con.outerNode0Pos, _inverseConTransf)[1], 'lolloBusStop_')
        moduleHelpers.setIntParamsFromFloat(newParams, 'outerNode0PosY', _utils.getPosTransformed(edgeData4Con.outerNode0Pos, _inverseConTransf)[2], 'lolloBusStop_')
        moduleHelpers.setIntParamsFromFloat(newParams, 'outerNode0PosZ', _utils.getPosTransformed(edgeData4Con.outerNode0Pos, _inverseConTransf)[3], 'lolloBusStop_')

        moduleHelpers.setIntParamsFromFloat(newParams, 'outerNode1PosX', _utils.getPosTransformed(edgeData4Con.outerNode1Pos, _inverseConTransf)[1], 'lolloBusStop_')
        moduleHelpers.setIntParamsFromFloat(newParams, 'outerNode1PosY', _utils.getPosTransformed(edgeData4Con.outerNode1Pos, _inverseConTransf)[2], 'lolloBusStop_')
        moduleHelpers.setIntParamsFromFloat(newParams, 'outerNode1PosZ', _utils.getPosTransformed(edgeData4Con.outerNode1Pos, _inverseConTransf)[3], 'lolloBusStop_')

        moduleHelpers.setIntParamsFromFloat(newParams, 'sidewalkHeight', _sidewalkHeight, 'lolloBusStop_')
        moduleHelpers.setIntParamsFromFloat(newParams, 'pitchAngle', _pitchAngle, 'lolloBusStop_')
        ]]
        -- logger.print('newParams =') logger.debugPrint(newParams)
        -- clone your own variable, it's safer than cloning newCon.params, which is userdata
        local conParamsBak = arrayUtils.cloneDeepOmittingFields(newParams)
        newCon.params = newParams
        -- logger.print('just made conParamsBak, it is') logger.debugPrint(conParamsBak)
        newCon.playerEntity = api.engine.util.getPlayer()
        newCon.transf = api.type.Mat4f.new(
            api.type.Vec4f.new(conTransf_lua[1], conTransf_lua[2], conTransf_lua[3], conTransf_lua[4]),
            api.type.Vec4f.new(conTransf_lua[5], conTransf_lua[6], conTransf_lua[7], conTransf_lua[8]),
            api.type.Vec4f.new(conTransf_lua[9], conTransf_lua[10], conTransf_lua[11], conTransf_lua[12]),
            api.type.Vec4f.new(conTransf_lua[13], conTransf_lua[14], conTransf_lua[15], conTransf_lua[16])
        )
        local proposal = api.type.SimpleProposal.new()
        proposal.constructionsToAdd[1] = newCon

        local context = api.type.Context:new()
        -- context.checkTerrainAlignment = true -- default is false
        -- context.cleanupStreetGraph = true -- default is false
        -- context.gatherBuildings = true -- default is false
        -- context.gatherFields = true -- default is true
        context.player = api.engine.util.getPlayer()
        -- context = nil

        if not(_utils.getIsProposalOK(proposal, context)) then
            logger.warn('buildConstruction made a dangerous proposal')
            -- LOLLO TODO at this point, the con was not built but the splits are already in place: fix the road
            _setStateReady()
            return
        end
        api.cmd.sendCommand(
            -- let's try without force and see if the random crashes go away. Not a good idea
            -- coz it fails to build very often, because of collisions
            api.cmd.make.buildProposal(proposal, context, true), -- the 3rd param is "ignore errors"; wrong proposals will be discarded anyway
            function(result, success)
                logger.print('buildConstruction callback, success =', success)
                -- logger.debugPrint(result)
                if not(success) then
                    logger.warn('buildConstruction callback failed')
                    logger.warn('buildConstruction proposal =') logger.warningDebugPrint(proposal)
                    logger.warn('buildConstruction result =') logger.warningDebugPrint(result)
                    _setStateReady()
                    -- LOLLO TODO at this point, the con was not built but the splits are already in place: fix the road
                else
                    local conId = result.resultEntities[1]
                    logger.print('buildConstruction succeeded, stationConId = ', conId)
                    xpcall(
                        function ()
                            api.cmd.sendCommand(api.cmd.make.sendScriptEvent(
                                string.sub(debug.getinfo(1, 'S').source, 1),
                                _eventId,
                                _eventProperties.conBuilt.eventName,
                                {
                                    conId = conId,
                                    conParams = conParamsBak,
                                    conTransf = conTransf_lua,
                                }
                            ))
                        end,
                        function(error)
                            logger.xpErrorHandler(error)
                            _setStateReady()
                        end
                    )
                end
            end
        )
    end,
    -- LOLLO NOTE the new autoPlacing construction does not play well with curves, unless I rebuild adjacent roads snappy.
    -- I tried Proposal instead of SimpleProposal but it is not meant to be.
    -- The trouble seems to be with collisions between external edges and inner edges.
    buildSnappyRoads = function(conParams, conId)
        logger.print('buildSnappyRoads starting, stationConId =', conId or 'NIL')
        if type(conParams) ~= 'table' then
            logger.warn('buildSnappyRoads received no table for conParams')
            _setStateReady()
            return
        end
        local outerNode0Pos = conParams['lolloBusStop_outerNode0Pos_absolute']
        local outerNode1Pos = conParams['lolloBusStop_outerNode1Pos_absolute']
        logger.print('lolloBusStop_outerNode0Pos_absolute =') logger.debugPrint(outerNode0Pos)
        logger.print('lolloBusStop_outerNode1Pos_absolute =') logger.debugPrint(outerNode1Pos)
        if type(outerNode0Pos) ~= 'table' or type(outerNode1Pos) ~= 'table' then
            logger.warn('buildSnappyRoads did not receive outerNode0Pos or outerNode1Pos')
            _setStateReady()
            return
        end
        if not(edgeUtils.isValidAndExistingId(conId)) then
            logger.warn('buildSnappyRoads received an invalid conId')
            _setStateReady()
            return
        end
        local con = api.engine.getComponent(conId, api.type.ComponentType.CONSTRUCTION)
        if con == nil then
            logger.warn('buildSnappyRoads cannot find con')
            _setStateReady()
            return
        end

        local getEndAndNeighbourNodeIds = function()
            local endNodeIdsUnsorted = _utils.getStationEndNodeIds(con)
            if (#endNodeIdsUnsorted ~= 2) then
                logger.warn('endNodeIdsUnsorted has ~= 2 items') logger.warningDebugPrint(endNodeIdsUnsorted)
                return nil, nil
            end

            local baseEndNode0 = api.engine.getComponent(endNodeIdsUnsorted[1], api.type.ComponentType.BASE_NODE)
            local baseEndNode1 = api.engine.getComponent(endNodeIdsUnsorted[2], api.type.ComponentType.BASE_NODE)
            local _tolerance = 0.1
            local nearbyNodes0 = edgeUtils.getNearbyObjects(
                transfUtils.position2Transf(outerNode0Pos),
                _tolerance,
                api.type.ComponentType.BASE_NODE,
                outerNode0Pos[3] - _tolerance,
                outerNode0Pos[3] + _tolerance
            )
            local neighbourNode0Id, baseNeighbourNode0
            for nodeId, nodeProps in pairs(nearbyNodes0) do
                if nodeId ~= endNodeIdsUnsorted[1] and nodeId ~= endNodeIdsUnsorted[2] and edgeUtils.isValidAndExistingId(nodeId) then
                    neighbourNode0Id, baseNeighbourNode0 = nodeId, nodeProps
                end
            end
            local nearbyNodes1 = edgeUtils.getNearbyObjects(
                transfUtils.position2Transf(outerNode1Pos),
                _tolerance,
                api.type.ComponentType.BASE_NODE,
                outerNode1Pos[3] - _tolerance,
                outerNode1Pos[3] + _tolerance
            )
            local neighbourNode1Id, baseNeighbourNode1
            for nodeId, nodeProps in pairs(nearbyNodes1) do
                if nodeId ~= endNodeIdsUnsorted[1] and nodeId ~= endNodeIdsUnsorted[2] and edgeUtils.isValidAndExistingId(nodeId) then
                    neighbourNode1Id, baseNeighbourNode1 = nodeId, nodeProps
                end
            end

            if neighbourNode0Id == nil or baseNeighbourNode0 == nil or neighbourNode1Id == nil or baseNeighbourNode1 == nil then
                logger.warn('cannot find node0Id or node1Id')
                return nil, nil
            end
            local endNode0Id = endNodeIdsUnsorted[1]
            local endNode1Id = endNodeIdsUnsorted[2]
            logger.print('newNode0Id before swapping =', endNode0Id, 'newNode1Id =', endNode1Id)
            -- take the nearest, a bit redundant since I used getNearby, maniman
            local distance00 = transfUtils.getPositionsDistance(baseNeighbourNode0.position, baseEndNode0.position)
            local distance01 = transfUtils.getPositionsDistance(baseNeighbourNode0.position, baseEndNode1.position)
            local distance10 = transfUtils.getPositionsDistance(baseNeighbourNode1.position, baseEndNode0.position)
            local distance11 = transfUtils.getPositionsDistance(baseNeighbourNode1.position, baseEndNode1.position)
            logger.print('distances =') logger.debugPrint({distance00, distance01, distance10, distance11})
            if distance00 > distance01 then
                if distance11 < distance10 then
                    logger.warn('something is fishy swapping end nodes')
                end
                endNode0Id, endNode1Id = endNode1Id, endNode0Id
                baseEndNode0, baseEndNode1 = baseEndNode1, baseEndNode0
                logger.warn('swapping end nodes, newNode0Id after swapping =', endNode0Id, 'newNode1Id =', endNode1Id)
                local distance00 = transfUtils.getPositionsDistance(baseNeighbourNode0.position, baseEndNode0.position)
                local distance01 = transfUtils.getPositionsDistance(baseNeighbourNode0.position, baseEndNode1.position)
                local distance10 = transfUtils.getPositionsDistance(baseNeighbourNode1.position, baseEndNode0.position)
                local distance11 = transfUtils.getPositionsDistance(baseNeighbourNode1.position, baseEndNode1.position)
                logger.print('distances after swapping =') logger.debugPrint({distance00, distance01, distance10, distance11})
            end

            return endNode0Id, endNode1Id, neighbourNode0Id, neighbourNode1Id
        end
        local newNode0Id, newNode1Id, oldNode0Id, oldNode1Id = getEndAndNeighbourNodeIds()
        if newNode0Id == nil or newNode1Id == nil or oldNode0Id == nil or oldNode1Id == nil then
            logger.warn('buildSnappyRoads cannot find its node ids')
            _setStateReady()
            return
        end

        local oldEdge0Id = edgeUtils.getConnectedEdgeIds({oldNode0Id})[1]
        local oldEdge1Id = edgeUtils.getConnectedEdgeIds({oldNode1Id})[1]
        logger.print('oldEdge0Id =', oldEdge0Id)
        logger.print('oldEdge1Id =', oldEdge1Id)
        if edgeUtils.isEdgeFrozen(oldEdge0Id) or edgeUtils.isEdgeFrozen(oldEdge1Id) then
            logger.warn('buildSnappyRoads cannot modify a frozen edge')
            _setStateReady()
            return
        end
        local oldBaseEdge0 = api.engine.getComponent(oldEdge0Id, api.type.ComponentType.BASE_EDGE)
        local oldBaseEdge1 = api.engine.getComponent(oldEdge1Id, api.type.ComponentType.BASE_EDGE)
        local oldEdge0Street = api.engine.getComponent(oldEdge0Id, api.type.ComponentType.BASE_EDGE_STREET)
        local oldEdge1Street = api.engine.getComponent(oldEdge1Id, api.type.ComponentType.BASE_EDGE_STREET)

        local getNewEdge = function(oldBaseEdge, oldEdgeStreet, entity)
            local newEdge = api.type.SegmentAndEntity.new()
            newEdge.entity = entity
            newEdge.type = 0 -- 0 is api.type.enum.Carrier.ROAD, 1 is api.type.enum.Carrier.RAIL
            newEdge.comp = oldBaseEdge
            logger.print('newEdge.comp before =') logger.debugPrint(newEdge.comp)
            if newEdge.comp.node0 == oldNode0Id then newEdge.comp.node0 = newNode0Id
            elseif newEdge.comp.node0 == oldNode1Id then newEdge.comp.node0 = newNode1Id
            elseif newEdge.comp.node1 == oldNode0Id then newEdge.comp.node1 = newNode0Id
            elseif newEdge.comp.node1 == oldNode1Id then newEdge.comp.node1 = newNode1Id
            end
            logger.print('newEdge.comp after =') logger.debugPrint(newEdge.comp)
            if type(oldBaseEdge.objects) == 'table' then
                local edgeObjects = {}
                for _, edgeObj in pairs(oldBaseEdge.objects) do
                    table.insert(edgeObjects, { edgeObj[1], edgeObj[2] })
                end
                newEdge.comp.objects = edgeObjects -- LOLLO NOTE cannot insert directly into edge0.comp.objects. Different tables are handled differently...
            end
            -- newEdge0.playerOwned = api.engine.getComponent(oldEdge0Id, api.type.ComponentType.PLAYER_OWNED)
            newEdge.playerOwned = _utils.getPlayerOwned()
            newEdge.streetEdge = oldEdgeStreet
            return newEdge
        end
        local newEdge0 = getNewEdge(oldBaseEdge0, oldEdge0Street, -1)
        local newEdge1 = getNewEdge(oldBaseEdge1, oldEdge1Street, -2)

        local proposal = api.type.SimpleProposal.new()
        proposal.streetProposal.nodesToRemove[1] = oldNode0Id
        proposal.streetProposal.nodesToRemove[2] = oldNode1Id
        proposal.streetProposal.edgesToRemove[1] = oldEdge0Id
        proposal.streetProposal.edgesToRemove[2] = oldEdge1Id
        proposal.streetProposal.edgesToAdd[1] = newEdge0
        proposal.streetProposal.edgesToAdd[2] = newEdge1

        local context = api.type.Context:new()
        -- context.checkTerrainAlignment = true -- default is false
        context.cleanupStreetGraph = true
        -- context.gatherBuildings = true -- default is false
        -- context.gatherFields = true -- default is true
        context.player = api.engine.util.getPlayer()

        api.cmd.sendCommand(
            api.cmd.make.buildProposal(proposal, context, true), -- the 3rd param is "ignore errors"; wrong proposals will be discarded anyway
            function(result, success)
                logger.print('buildSnappyRoads callback, success =', success) -- logger.debugPrint(result)
                if not(success) then
                    logger.warn('buildSnappyRoads failed, proposal =') logger.warningDebugPrint(proposal)
                    logger.warn('buildSnappyRoads failed, result =') logger.warningDebugPrint(result)
                    _setStateReady()
                else
                    xpcall(
                        function ()
                            api.cmd.sendCommand(api.cmd.make.sendScriptEvent(
                                string.sub(debug.getinfo(1, 'S').source, 1),
                                _eventId,
                                _eventProperties.snappyRoadsBuilt.eventName,
                                {}
                            ))
                        end,
                        function(error)
                            logger.xpErrorHandler(error)
                            _setStateReady()
                        end
                    )
                end
            end
        )
    end,
    bulldozeConstructionUNUSED = function(constructionId)
        -- print('constructionId =', constructionId)
        if type(constructionId) ~= 'number' or constructionId < 0 then
            logger.warn('bulldozeConstruction got an invalid conId')
            _setStateReady()
            return
        end

        local oldConstruction = api.engine.getComponent(constructionId, api.type.ComponentType.CONSTRUCTION)
        if not(oldConstruction) or not(oldConstruction.params) then
            logger.warn('bulldozeConstruction got no con or a broken con')
            logger.warn('oldConstruction =') logger.warningDebugPrint(oldConstruction)
            _setStateReady()
            return
        end

        local proposal = api.type.SimpleProposal.new()
        -- LOLLO NOTE there are asymmetries how different tables are handled.
        -- This one requires this system, UG says they will document it or amend it.
        proposal.constructionsToRemove = { constructionId }
        -- proposal.constructionsToRemove[1] = constructionId -- fails to add
        -- proposal.constructionsToRemove:add(constructionId) -- fails to add

        local context = api.type.Context:new()
        -- context.checkTerrainAlignment = true -- default is false
        -- context.cleanupStreetGraph = true
        -- context.gatherBuildings = true -- default is false
        -- context.gatherFields = true -- default is true
        context.player = api.engine.util.getPlayer()

        api.cmd.sendCommand(
            api.cmd.make.buildProposal(proposal, context, true), -- the 3rd param is "ignore errors"; wrong proposals will be discarded anyway
            function(result, success)
                if not(success) then
                    logger.warn('bulldozeConstruction callback: failed to build')
                    logger.warn('bulldozeConstruction proposal =') logger.warningDebugPrint(proposal)
                    logger.warn('bulldozeConstruction result =') logger.warningDebugPrint(result)
                    _setStateReady()
                else
                    logger.print('bulldozeConstruction callback succeeded')
                end
            end
        )
    end,
    removeEdges = function(oldEdgeIds, successEventName, successEventArgs)
        logger.print('removeEdges starting, oldEdgeIds =') logger.debugPrint(oldEdgeIds)
        -- removes edges even if they have a street type, which has changed or disappeared
        if not(oldEdgeIds) then
            logger.warn('removeEdges got no oldEdgeIds')
            _setStateReady()
            return
        end
        for _, oldEdgeId in pairs(oldEdgeIds) do
            if not(edgeUtils.isValidAndExistingId(oldEdgeId)) then
                logger.warn('removeEdges got an invalid oldEdgeId')
                _setStateReady()
                return
            end
            if edgeUtils.isEdgeFrozen(oldEdgeId) then
                logger.warn('removeEdges got a frozen oldEdgeId')
                _setStateReady()
                return
            end
        end

        local proposal = api.type.SimpleProposal.new()
        local _map = api.engine.system.streetSystem.getNode2SegmentMap()
        local _isNodeAttachedToSomethingElse = function(edgeIds)
            for _, edgeId in pairs(edgeIds) do
                if arrayUtils.findIndex(oldEdgeIds, nil, edgeId) == -1 then return true end
            end
            return false
        end
        local orphanNodeIds_Indexed = {}
        for _, oldEdgeId in pairs(oldEdgeIds) do
            local oldBaseEdge = api.engine.getComponent(oldEdgeId, api.type.ComponentType.BASE_EDGE)
            -- logger.print('oldBaseEdge =') logger.debugPrint(oldBaseEdge)
            local oldEdgeStreet = api.engine.getComponent(oldEdgeId, api.type.ComponentType.BASE_EDGE_STREET)
            -- logger.print('oldEdgeStreet =') logger.debugPrint(oldEdgeStreet)
            -- save a crash when a modded road underwent a breaking change, so it has no oldEdgeStreet
            if oldBaseEdge ~= nil and oldEdgeStreet ~= nil then
                if not(_isNodeAttachedToSomethingElse(_map[oldBaseEdge.node0])) then
                    orphanNodeIds_Indexed[oldBaseEdge.node0] = true
                end
                if not(_isNodeAttachedToSomethingElse(_map[oldBaseEdge.node1])) then
                    orphanNodeIds_Indexed[oldBaseEdge.node1] = true
                end

                proposal.streetProposal.edgesToRemove[#proposal.streetProposal.edgesToRemove + 1] = oldEdgeId

                if oldBaseEdge.objects then
                    for edgeObj = 1, #oldBaseEdge.objects do
                        proposal.streetProposal.edgeObjectsToRemove[#proposal.streetProposal.edgeObjectsToRemove + 1] = oldBaseEdge.objects[edgeObj][1]
                    end
                end
            else
                if oldBaseEdge == nil then logger.warn('removeEdges found oldBaseEdge == nil for edgeId =', oldEdgeId or 'NIL') end
                if oldEdgeStreet == nil then logger.warn('removeEdges found oldEdgeStreet == nil for edgeId =', oldEdgeId or 'NIL') end
            end
        end
        for nodeId, _ in pairs(orphanNodeIds_Indexed) do
            proposal.streetProposal.nodesToRemove[#proposal.streetProposal.nodesToRemove + 1] = nodeId
        end
        -- logger.print('proposal =') logger.debugPrint(proposal)

        local context = api.type.Context:new()
        -- context.checkTerrainAlignment = true -- default is false
        -- context.cleanupStreetGraph = true
        -- context.gatherBuildings = true -- default is false
        -- context.gatherFields = true -- default is true
        context.player = api.engine.util.getPlayer()

        api.cmd.sendCommand(
            api.cmd.make.buildProposal(proposal, context, true),
            function(result, success)
                if not(success) then
                    logger.warn('removeEdges failed, proposal = ') logger.warningDebugPrint(proposal)
                    logger.warn('removeEdges failed, result = ') logger.warningDebugPrint(result)
                    _setStateReady()
                else
                    logger.print('removeEdges succeeded, result =') --logger.debugPrint(result)
                    if not(successEventName) then _setStateReady() return end

                    xpcall(
                        function ()
                            api.cmd.sendCommand(api.cmd.make.sendScriptEvent(
                                string.sub(debug.getinfo(1, 'S').source, 1),
                                _eventId,
                                successEventName,
                                successEventArgs
                            ))
                        end,
                        function(error)
                            logger.xpErrorHandler(error)
                            _setStateReady()
                        end
                    )
                end
            end
        )
    end,
    -- replaces a street segment with an identical one, without destroying the buildings
    -- removes the given object
    -- and raises the given event
    replaceEdgeWithSame = function(oldEdgeId, objectIdToBeRemoved, successEventName, successEventArgs)
        logger.print('replaceEdgeWithSame starting')
        logger.print('objectIdToBeRemoved =', objectIdToBeRemoved or 'NIL')
        logger.print('successEventName =', successEventName or 'NIL')
        logger.print('successEventArgs =') logger.debugPrint(successEventArgs)
        if not(edgeUtils.isValidAndExistingId(oldEdgeId)) then
            logger.warn('replaceEdgeWithSame received an invalid oldEdgeId')
            _setStateReady()
            return
        end
        if edgeUtils.isEdgeFrozen(oldEdgeId) then
            logger.warn('replaceEdgeWithSame received a frozen oldEdgeId')
            _setStateReady()
            return
        end

        local oldBaseEdge = api.engine.getComponent(oldEdgeId, api.type.ComponentType.BASE_EDGE)
        local oldEdgeStreet = api.engine.getComponent(oldEdgeId, api.type.ComponentType.BASE_EDGE_STREET)
        -- save a crash when a modded road underwent a breaking change, so it has no oldEdgeStreet
        if oldBaseEdge == nil or oldEdgeStreet == nil then
            logger.warn('replaceEdgeWithSame cannot find oldBaseEdge or oldBaseEdgeStreet')
            _setStateReady()
            return
        end

        local newEdge = api.type.SegmentAndEntity.new()
        newEdge.entity = -1
        newEdge.type = 0 -- 0 is api.type.enum.Carrier.ROAD, 1 is api.type.enum.Carrier.RAIL
        newEdge.comp = oldBaseEdge
        logger.print('oldBaseEdge =') logger.debugPrint(oldBaseEdge)
        if oldBaseEdge.objects ~= nil then -- userdata
            local edgeObjects = {}
            for _, edgeObj in pairs(oldBaseEdge.objects) do
                if edgeObj[1] ~= objectIdToBeRemoved then
                    logger.print('replaceEdgeWithSame preserving object') logger.debugPrint(edgeObj)
                    table.insert(edgeObjects, { edgeObj[1], edgeObj[2] })
                end
            end
            newEdge.comp.objects = edgeObjects -- LOLLO NOTE cannot insert directly into edge0.comp.objects. Different tables are handled differently...
        end
        -- newEdge.playerOwned = api.engine.getComponent(oldEdgeId, api.type.ComponentType.PLAYER_OWNED)
        newEdge.playerOwned = _utils.getPlayerOwned()
        newEdge.streetEdge = oldEdgeStreet

        local proposal = api.type.SimpleProposal.new()
        proposal.streetProposal.edgesToRemove[1] = oldEdgeId
        proposal.streetProposal.edgesToAdd[1] = newEdge

        -- if objectIdToBeRemoved and oldBaseEdge.objects then
        --     for o = 1, #oldBaseEdge.objects do
        --         proposal.streetProposal.edgeObjectsToRemove[#proposal.streetProposal.edgeObjectsToRemove+1] = oldBaseEdge.objects[o][1]
        --     end
        -- end
        local i = 1
        for _, edgeObj in pairs(oldBaseEdge.objects) do
            if edgeObj[1] == objectIdToBeRemoved then
                proposal.streetProposal.edgeObjectsToRemove[i] = edgeObj[1]
                i = i + 1
            end
        end
        -- logger.print('proposal =') logger.debugPrint(proposal)

        local context = api.type.Context:new()
        -- context.checkTerrainAlignment = true -- default is false, true gives smoother Z
        -- context.cleanupStreetGraph = true -- default is false
        -- context.gatherBuildings = true  -- default is false
        -- context.gatherFields = true -- default is true
        context.player = api.engine.util.getPlayer() -- default is -1

        api.cmd.sendCommand(
            api.cmd.make.buildProposal(proposal, context, true),
            function(result, success)
                if not(success) then
                    logger.warn('replaceEdgeWithSame failed, proposal = ') logger.warningDebugPrint(proposal)
                    logger.warn('replaceEdgeWithSame failed, result = ') logger.warningDebugPrint(result)
                    _setStateReady()
                else
                    logger.print('replaceEdgeWithSame succeeded, result =') --logger.debugPrint(result)
                    if not(successEventName) then _setStateReady() return end

                    xpcall(
                        function ()
                            local newlyBuiltEdgeId = _utils.getNewlyBuiltEdgeId(result)
                            if edgeUtils.isValidAndExistingId(newlyBuiltEdgeId) then
                                successEventArgs.edgeId = newlyBuiltEdgeId
                                api.cmd.sendCommand(api.cmd.make.sendScriptEvent(
                                    string.sub(debug.getinfo(1, 'S').source, 1),
                                    _eventId,
                                    successEventName,
                                    successEventArgs
                                ))
                            end
                        end,
                        function(error)
                            logger.xpErrorHandler(error)
                            _setStateReady()
                        end
                    )
                end
            end
        )
    end,
    splitEdge = function(wholeEdgeId, nodeBetween, successEventName, successEventArgs)
        logger.print('splitEdge starting')
        if not(edgeUtils.isValidAndExistingId(wholeEdgeId)) then
            logger.warn('splitEdge received an invalid wholeEdgeId')
            _setStateReady()
            return
        end
        if edgeUtils.isEdgeFrozen(wholeEdgeId) then
            logger.warn('splitEdge received a frozen wholeEdgeId')
            _setStateReady()
            return
        end
        if type(nodeBetween) ~= 'table' then
            logger.warn('splitEdge received an invalid nodeBetween')
            _setStateReady()
            return
        end

        local oldBaseEdge = api.engine.getComponent(wholeEdgeId, api.type.ComponentType.BASE_EDGE)
        local oldBaseEdgeStreet = api.engine.getComponent(wholeEdgeId, api.type.ComponentType.BASE_EDGE_STREET)
        -- save a crash when a modded road underwent a breaking change, so it has no oldEdgeStreet
        if oldBaseEdge == nil or oldBaseEdgeStreet == nil then
            logger.warn('splitEdge cannot find oldBaseEdge or oldBaseEdgeStreet')
            _setStateReady()
            return
        end

        if not(edgeUtils.isValidAndExistingId(oldBaseEdge.node0)) or not(edgeUtils.isValidAndExistingId(oldBaseEdge.node1)) then
            logger.warn('splitEdge found invalid baseEdge nodes')
            _setStateReady()
            return
        end
        local node0 = api.engine.getComponent(oldBaseEdge.node0, api.type.ComponentType.BASE_NODE)
        local node1 = api.engine.getComponent(oldBaseEdge.node1, api.type.ComponentType.BASE_NODE)
        if node0 == nil or node1 == nil then
            logger.warn('splitEdge cannot find baseEdge nodes')
            _setStateReady()
            return
        end

        if not(edgeUtils.isXYZSame(nodeBetween.refPosition0, node0.position)) and not(edgeUtils.isXYZSame(nodeBetween.refPosition0, node1.position)) then
            logger.warn('splitEdge cannot find the nodes')
        end
        local isNodeBetweenOrientatedLikeMyEdge = edgeUtils.isXYZSame(nodeBetween.refPosition0, node0.position)
        local distance0 = isNodeBetweenOrientatedLikeMyEdge and nodeBetween.refDistance0 or nodeBetween.refDistance1
        local distance1 = isNodeBetweenOrientatedLikeMyEdge and nodeBetween.refDistance1 or nodeBetween.refDistance0
        local tanSign = isNodeBetweenOrientatedLikeMyEdge and 1 or -1

        local oldTan0Length = edgeUtils.getVectorLength(oldBaseEdge.tangent0)
        local oldTan1Length = edgeUtils.getVectorLength(oldBaseEdge.tangent1)

        local newNodeBetween = api.type.NodeAndEntity.new()
        newNodeBetween.entity = -3
        newNodeBetween.comp.position = api.type.Vec3f.new(nodeBetween.position.x, nodeBetween.position.y, nodeBetween.position.z)

        local newEdge0 = api.type.SegmentAndEntity.new()
        newEdge0.entity = -1
        newEdge0.type = 0 -- 0 is api.type.enum.Carrier.ROAD, 1 is api.type.enum.Carrier.RAIL
        newEdge0.comp.node0 = oldBaseEdge.node0
        newEdge0.comp.node1 = -3
        newEdge0.comp.tangent0 = api.type.Vec3f.new(
            oldBaseEdge.tangent0.x * distance0 / oldTan0Length,
            oldBaseEdge.tangent0.y * distance0 / oldTan0Length,
            oldBaseEdge.tangent0.z * distance0 / oldTan0Length
        )
        newEdge0.comp.tangent1 = api.type.Vec3f.new(
            nodeBetween.tangent.x * distance0 * tanSign,
            nodeBetween.tangent.y * distance0 * tanSign,
            nodeBetween.tangent.z * distance0 * tanSign
        )
        newEdge0.comp.type = oldBaseEdge.type -- respect bridge or tunnel
        newEdge0.comp.typeIndex = oldBaseEdge.typeIndex -- respect bridge or tunnel type
        -- newEdge0.playerOwned = api.engine.getComponent(wholeEdgeId, api.type.ComponentType.PLAYER_OWNED)
        newEdge0.playerOwned = _utils.getPlayerOwned()
        newEdge0.streetEdge = oldBaseEdgeStreet

        local newEdge1 = api.type.SegmentAndEntity.new()
        newEdge1.entity = -2
        newEdge1.type = 0 -- 0 is api.type.enum.Carrier.ROAD, 1 is api.type.enum.Carrier.RAIL
        newEdge1.comp.node0 = -3
        newEdge1.comp.node1 = oldBaseEdge.node1
        newEdge1.comp.tangent0 = api.type.Vec3f.new(
            nodeBetween.tangent.x * distance1 * tanSign,
            nodeBetween.tangent.y * distance1 * tanSign,
            nodeBetween.tangent.z * distance1 * tanSign
        )
        newEdge1.comp.tangent1 = api.type.Vec3f.new(
            oldBaseEdge.tangent1.x * distance1 / oldTan1Length,
            oldBaseEdge.tangent1.y * distance1 / oldTan1Length,
            oldBaseEdge.tangent1.z * distance1 / oldTan1Length
        )
        newEdge1.comp.type = oldBaseEdge.type
        newEdge1.comp.typeIndex = oldBaseEdge.typeIndex
        -- newEdge1.playerOwned = api.engine.getComponent(wholeEdgeId, api.type.ComponentType.PLAYER_OWNED)
        newEdge1.playerOwned = _utils.getPlayerOwned()
        newEdge1.streetEdge = oldBaseEdgeStreet

        if type(oldBaseEdge.objects) == 'table' then
            -- local edge0StationGroups = {}
            -- local edge1StationGroups = {}
            local edge0Objects = {}
            local edge1Objects = {}
            for _, edgeObj in pairs(oldBaseEdge.objects) do
                local edgeObjPosition = edgeUtils.getObjectPosition(edgeObj[1])
                -- logger.print('edge object position =') logger.debugPrint(edgeObjPosition)
                if type(edgeObjPosition) ~= 'table' then
                    logger.warn('splitEdge found type(edgeObjPosition) ~= table')
                    _setStateReady()
                    return
                end -- change nothing and leave
                local assignment = _utils.getWhichEdgeGetsEdgeObjectAfterSplit(
                    edgeObjPosition,
                    {node0.position.x, node0.position.y, node0.position.z},
                    {node1.position.x, node1.position.y, node1.position.z},
                    nodeBetween
                )
                if assignment.assignToSide == 0 then
                    -- LOLLO NOTE if we skip this check,
                    -- one can split a road between left and right terminals of a streetside station
                    -- and add more terminals on the new segments.
                    -- local stationGroupId = api.engine.system.stationGroupSystem.getStationGroup(edgeObj[1])
                    -- if arrayUtils.arrayHasValue(edge1StationGroups, stationGroupId) then return end -- don't split station groups
                    -- if edgeUtils.isValidId(stationGroupId) then table.insert(edge0StationGroups, stationGroupId) end
                    table.insert(edge0Objects, { edgeObj[1], edgeObj[2] })
                elseif assignment.assignToSide == 1 then
                    -- local stationGroupId = api.engine.system.stationGroupSystem.getStationGroup(edgeObj[1])
                    -- if arrayUtils.arrayHasValue(edge0StationGroups, stationGroupId) then return end -- don't split station groups
                    -- if edgeUtils.isValidId(stationGroupId) then table.insert(edge1StationGroups, stationGroupId) end
                    table.insert(edge1Objects, { edgeObj[1], edgeObj[2] })
                else
                    -- print('don\'t change anything and leave')
                    -- print('LOLLO error, assignment.assignToSide =', assignment.assignToSide)
                    logger.warn('splitEdge cannot find the side to assign to the edge object')
                    _setStateReady()
                    return -- change nothing and leave
                end
            end
            newEdge0.comp.objects = edge0Objects -- LOLLO NOTE cannot insert directly into edge0.comp.objects. Different tables are handled differently...
            newEdge1.comp.objects = edge1Objects
        end

        local proposal = api.type.SimpleProposal.new()
        proposal.streetProposal.edgesToAdd[1] = newEdge0
        proposal.streetProposal.edgesToAdd[2] = newEdge1
        proposal.streetProposal.edgesToRemove[1] = wholeEdgeId
        proposal.streetProposal.nodesToAdd[1] = newNodeBetween

        local context = api.type.Context:new()
        -- context.checkTerrainAlignment = true -- default is false, true gives smoother Z
        -- context.cleanupStreetGraph = true -- default is false
        -- context.gatherBuildings = true  -- default is false
        -- context.gatherFields = true -- default is true
        context.player = api.engine.util.getPlayer() -- default is -1

        api.cmd.sendCommand(
            api.cmd.make.buildProposal(proposal, context, true), -- the 3rd param is "ignore errors"; wrong proposals will be discarded anyway
            function(result, success)
                if not(success) then
                    logger.warn('splitEdge failed, proposal = ') logger.warningDebugPrint(proposal)
                    logger.warn('splitEdge failed, result = ') logger.warningDebugPrint(result)
                    _setStateReady()
                else
                    logger.print('splitEdge succeeded, result =') -- logger.debugPrint(result)
                    if not(successEventName) then _setStateReady() return end

                    xpcall(
                        function ()
                            local newlyBuiltNodeId = _utils.getNewlyBuiltNodeId(result)
                            if not(edgeUtils.isValidAndExistingId(newlyBuiltNodeId)) then
                                logger.warn('splitEdge failed to find newlyBuiltNodeId')
                                _setStateReady()
                                return
                            end

                            if not(successEventArgs.outerNode0Id) then
                                successEventArgs.outerNode0Id = newlyBuiltNodeId
                                successEventArgs.outerNode0EdgeIds = edgeUtils.getConnectedEdgeIds({newlyBuiltNodeId})
                            elseif not(successEventArgs.outerNode1Id) then
                                successEventArgs.outerNode1Id = newlyBuiltNodeId
                                successEventArgs.outerNode1EdgeIds = edgeUtils.getConnectedEdgeIds({newlyBuiltNodeId})
                            -- elseif not(successEventArgs.innerNode0Id) then
                            --     successEventArgs.innerNode0Id = newlyBuiltNodeId
                            --     successEventArgs.innerNode0EdgeIds = edgeUtils.getConnectedEdgeIds({newlyBuiltNodeId})
                            -- elseif not(successEventArgs.innerNode1Id) then
                            --     successEventArgs.innerNode1Id = newlyBuiltNodeId
                            --     successEventArgs.innerNode1EdgeIds = edgeUtils.getConnectedEdgeIds({newlyBuiltNodeId})
                            end
                            api.cmd.sendCommand(api.cmd.make.sendScriptEvent(
                                string.sub(debug.getinfo(1, 'S').source, 1),
                                _eventId,
                                successEventName,
                                successEventArgs
                            ))
                        end,
                        function(error)
                            logger.xpErrorHandler(error)
                            _setStateReady()
                        end
                    )
                end
            end
        )
    end,
    upgradeConUNUSED = function(conId, conParams)
        logger.print('upgradeCon starting, conId =', (conId or 'NIL'))
        local con = api.engine.getComponent(conId, api.type.ComponentType.CONSTRUCTION)
        if con == nil then
            logger.warn('upgradeCon cannot find con')
            _setStateReady()
            return
        end

        xpcall(
            function()
                collectgarbage() -- this is a stab in the dark to try and avoid crashes in the following
                -- UG TODO there is no such thing as game.interface.upgradeConstruction() in the new api,
                -- nor an upgrade event, both would be useful
                local paramsNoSeed = arrayUtils.cloneDeepOmittingFields(conParams, {'seed'})
                logger.print('paramsNoSeed =') logger.debugPrint(paramsNoSeed)
                logger.print('about to upgrade con, stationConId =', conId, 'con.fileName =', con.fileName)
                local upgradedConId = game.interface.upgradeConstruction(
                    conId,
                    con.fileName,
                    paramsNoSeed
                )
                logger.print('upgradeCon succeeded, conId =', (upgradedConId or 'NIL'))
            end,
            function(error)
                logger.warn('upgradeCon failed')
                logger.warn(error)
                _setStateReady()
            end
        )
    end,
    updateConstruction = function(oldConId, paramKey, newParamValueIndexBase0)
        logger.print('updateConstruction starting, conId =', oldConId or 'NIL', 'paramKey =', paramKey or 'NIL', 'newParamValueIndexBase0 =', newParamValueIndexBase0 or 'NIL')

        if not(edgeUtils.isValidAndExistingId(oldConId)) then
            logger.warn('updateConstruction received an invalid conId')
            _setStateReady()
            return
        end
        local oldCon = api.engine.getComponent(oldConId, api.type.ComponentType.CONSTRUCTION)
        if oldCon == nil then
            logger.warn('updateConstruction cannot get the con')
            _setStateReady()
            return
        end

        local newCon = api.type.SimpleProposal.ConstructionEntity.new()
        newCon.fileName = oldCon.fileName
        local newParams = arrayUtils.cloneDeepOmittingFields(oldCon.params, nil, true)
        newParams[paramKey] = newParamValueIndexBase0
        -- deal with bridges
        if paramKey == 'lolloBusStop_bridgeOrTunnelType' then
            if newParamValueIndexBase0 == 0 then
                newParams['lolloBusStop_groundBridgeTunnel012'] = 0 -- no bridge
            else
                newParams['lolloBusStop_groundBridgeTunnel012'] = 1 -- bridge
            end
        end
        newParams.seed = newParams.seed + 1
        -- clone your own variable, it's safer than cloning newCon.params, which is userdata
        local conParamsBak = arrayUtils.cloneDeepOmittingFields(newParams)
        newCon.params = newParams
        logger.print('oldCon.params =') logger.debugPrint(oldCon.params)
        logger.print('newCon.params =') logger.debugPrint(newCon.params)
        newCon.playerEntity = api.engine.util.getPlayer()
        newCon.transf = oldCon.transf
        local conTransf_lua = transfUtilsUG.new(newCon.transf:cols(0), newCon.transf:cols(1), newCon.transf:cols(2), newCon.transf:cols(3))

        local proposal = api.type.SimpleProposal.new()
        proposal.constructionsToAdd[1] = newCon
        proposal.constructionsToRemove = { oldConId }
        -- proposal.old2new = { oldConId, 1 } -- this is wrong and makes trouble like
        -- C:\GitLab-Runner\builds\1BJoMpBZ\0\ug\urban_games\train_fever\src\Game\UrbanSim\StockListUpdateHelper.cpp:166: __cdecl StockListUpdateHelper::~StockListUpdateHelper(void) noexcept(false): Assertion `0 <= pr.second && pr.second < (int)m_data->addedEntities->size()' failed.

        local context = api.type.Context:new()
        -- context.checkTerrainAlignment = true -- default is false
        -- context.cleanupStreetGraph = true -- default is false
        -- context.gatherBuildings = true -- default is false
        -- context.gatherFields = true -- default is true
        context.player = api.engine.util.getPlayer()
        -- Sometimes, the game fails in the following; UG does not handle the failure graacefully and the game crashes with "an error just occurred" and no useful info.
        if not(_utils.getIsProposalOK(proposal, context)) then
            logger.warn('updateConstruction made a dangerous proposal')
            -- LOLLO TODO give feedback
            _setStateReady()
            return
        end

        api.cmd.sendCommand(
            api.cmd.make.buildProposal(proposal, context, true), -- the 3rd param is "ignore errors"; wrong proposals will be discarded anyway
            function(result, success)
                logger.print('updateConstruction callback, success =', success)
                -- logger.debugPrint(result)
                if not(success) then
                    logger.warn('updateConstruction callback failed')
                    logger.warn('updateConstruction proposal =') logger.warningDebugPrint(proposal)
                    logger.warn('updateConstruction result =') logger.warningDebugPrint(result)
                    _setStateReady()
                    -- LOLLO TODO give feedback
                else
                    local newConId = result.resultEntities[1]
                    logger.print('updateConstruction succeeded, stationConId = ', newConId)
                    xpcall(
                        function ()
                            api.cmd.sendCommand(api.cmd.make.sendScriptEvent(
                                string.sub(debug.getinfo(1, 'S').source, 1),
                                _eventId,
                                _eventProperties.conBuilt.eventName,
                                {
                                    conId = newConId,
                                    conParams = conParamsBak,
                                    conTransf = conTransf_lua,
                                }
                            ))
                        end,
                        function(error)
                            logger.xpErrorHandler(error)
                            _setStateReady()
                        end
                    )
                end
            end
        )
    end,
}
local _handlers = {
    guiHandleParamValueChanged = function(stationGroupId, paramsMetadata, paramKey, newParamValueIndexBase0)
        logger.print('guiHandleParamValueChanged firing')
        logger.print('stationGroupId =') logger.debugPrint(stationGroupId)
        logger.print('paramsMetadata =') logger.debugPrint(paramsMetadata)
        logger.print('paramKey =') logger.debugPrint(paramKey)
        logger.print('newParamValueIndexBase0 =') logger.debugPrint(newParamValueIndexBase0)
        local conId = _utils.getConOfStationGroup(stationGroupId)
        if not(edgeUtils.isValidAndExistingId(conId)) then
            logger.warn('guiHandleParamValueChanged got no con or no valid con')
            return
        end
        -- _utils.guiWaitLockingThread(function() return (state ~= nil and not(state.isWorking)) end)
        -- if state == nil or state.isWorking then
        --     logger.print('busy, ignoring param value change')
        --     -- LOLLO TODO see if you can wait, it's nicer than not responding; although this does not seem to be a problem anymore
        --     return
        -- end
        _setStateWorking(
            true,
            _eventProperties.conParamsUpdated.eventName,
            {
                conId = conId,
                paramKey = paramKey,
                newParamValueIndexBase0 = newParamValueIndexBase0,
            }
        )
    end,
}

function data()
    return {
        guiHandleEvent = function(id, name, args)
            -- logger.print('guiHandleEvent caught id =', id, 'name =', name, 'args =') -- logger.debugPrint(args)
            -- LOLLO NOTE param can have different types, even boolean, depending on the event id and name
            if (name == 'select' and id == 'mainView') then
                -- select happens after idAdded, which looks like:
                -- id =	temp.view.entity_28693	name =	idAdded
                -- id =	temp.view.entity_26372	name =	idAdded
                xpcall(
                    function()
                        logger.print('guiHandleEvent caught id =', id, 'name =', name, 'args =') logger.debugPrint(args)
                        local conId, con = _utils.getConOfStationGroup(args) -- args is stationGroupId, when I select my station
                        if not(conId) or not(con) then return end

                        logger.print('selected one of my stations, it has conId =', conId, 'and con.fileName =', con.fileName)
                        if not(_guiData.conParamsMetadataSorted) then
                            logger.print('_guiConstants.conParams is not available')
                            return
                        end

                        guiHelpers.addConConfigToWindow(args, _handlers.guiHandleParamValueChanged, _guiData.conParamsMetadataSorted, con.params)
                    end,
                    logger.xpErrorHandler
                )
            elseif (name == 'builder.apply' and id == 'streetTerminalBuilder') then
                -- waypoint or streetside stations have been built
                xpcall(
                    function()
                        logger.print('guiHandleEvent caught id =', id, 'name =', name, 'args =') -- logger.debugPrint(args)
                        if (args and args.proposal and args.proposal.proposal
                        and args.proposal.proposal.edgeObjectsToAdd
                        and args.proposal.proposal.edgeObjectsToAdd[1]
                        and args.proposal.proposal.edgeObjectsToAdd[1].modelInstance)
                        then
                            if _guiData.ploppablePassengersModelId
                            and args.proposal.proposal.edgeObjectsToAdd[1].modelInstance.modelId == _guiData.ploppablePassengersModelId
                            then
                                -- logger.print('args =') logger.debugPrint(args)
                                local edgeObjectId = args.proposal.proposal.edgeObjectsToAdd[1].resultEntity
                                logger.print('edgeObjectId =') logger.debugPrint(edgeObjectId)
                                local edgeId = args.proposal.proposal.edgeObjectsToAdd[1].segmentEntity
                                logger.print('edgeId =') logger.debugPrint(edgeId)
                                local edgeObjectTransf = edgeUtils.getObjectTransf(edgeObjectId)
                                logger.print('edgeObjectTransf =') logger.debugPrint(edgeObjectTransf)
                                if not(edgeUtils.isValidAndExistingId(edgeId))
                                or edgeUtils.isEdgeFrozen(edgeId)
                                or not(edgeUtils.isValidAndExistingId(edgeObjectId))
                                or not(edgeObjectTransf)
                                then
                                    return false
                                end
                                -- _utils.guiWaitLockingThread(function() logger.print('state =') logger.debugPrint(state) return (state ~= nil and not(state.isWorking)) end)
                                -- if state == nil or state.isWorking then
                                --     logger.print('busy, leaving')
                                --     -- LOLLO NOTE this could interfere and delaying is not trivial, so I use a model that clearly says "bulldoze me"
                                --     -- _actions.replaceEdgeWithSame(edgeId, edgeObjectId)
                                --     return false
                                -- end

                                local edgeLength = edgeUtils.getEdgeLength(edgeId)
                                if edgeLength < constants.minInitialEdgeLength then
                                    guiHelpers.showWarningWindowWithGoto(_('EdgeTooShort'))
                                    _actions.replaceEdgeWithSame(edgeId, edgeObjectId, _eventProperties.setStateWorking.eventName, {isWorking = false})
                                    return false
                                end
                                -- LOLLO TODO try forbidding building too close to another station (only this type? Or also the stock type?)
                                -- it won't fix the uncatchable error but it might be useful.
                                local baseEdge = api.engine.getComponent(edgeId, api.type.ComponentType.BASE_EDGE)
                                -- logger.print('baseEdge =') logger.debugPrint(baseEdge)
                                local baseEdgeStreet = api.engine.getComponent(edgeId, api.type.ComponentType.BASE_EDGE_STREET)
                                -- logger.print('baseEdgeStreet =') logger.debugPrint(baseEdgeStreet)
                                local streetTypeProps = api.res.streetTypeRep.get(baseEdgeStreet.streetType)
                                -- logger.print('streetTypeProps =') logger.debugPrint(streetTypeProps)
                                local yShift = -(streetTypeProps.streetWidth + streetTypeProps.sidewalkWidth) / 2
                                logger.print('baseEdge.objects[1][2] =', baseEdge.objects[1][2])
                                -- if baseEdge.objects[1][2] == 1 then yShift = -yShift end -- NO!
                                local edgeObjectTransf_y0 = transfUtils.getTransfYShiftedBy(edgeObjectTransf, yShift)
                                local edgeObjectTransf_yz0 = transfUtils.getTransfZShiftedBy(edgeObjectTransf_y0, -streetTypeProps.sidewalkHeight)
                                logger.print('edgeObjectTransf =') logger.debugPrint(edgeObjectTransf)
                                logger.print('edgeObjectTransf_y0 =') logger.debugPrint(edgeObjectTransf_y0)
                                logger.print('edgeObjectTransf_yz0 =') logger.debugPrint(edgeObjectTransf_yz0)
                                _setStateWorking(
                                    true,
                                    _eventProperties.initialEdgeObjectPlaced.eventName,
                                    {
                                        edgeId = edgeId,
                                        edgeObjectId = edgeObjectId,
                                        edgeObjectTransf = edgeObjectTransf_yz0,
                                        bridgeOrTunnelType = baseEdge.typeIndex,
                                        groundBridgeTunnel012 = baseEdge.type,
                                        streetType = baseEdgeStreet.streetType,
                                        tramTrackType = baseEdgeStreet.tramTrackType,
                                        hasBus = baseEdgeStreet.hasBus,
                                    }
                                )
                            end
                        end
                    end,
                    logger.xpErrorHandler
                )
            elseif (name == 'builder.proposalCreate' and id == 'bulldozer') then
                if args == nil or args.proposal == nil or args.proposal.toRemove == nil or args.proposal.toRemove[1] == nil then
                    _guiData.conIdAboutToBeBulldozed = false
                    return
                end
                -- logger.print('guiHandleEvent caught id =', id, 'name =', name, 'args =') logger.debugPrint(args)
                local conId = args.proposal.toRemove[1]
                if not(edgeUtils.isValidAndExistingId(conId)) then
                    _guiData.conIdAboutToBeBulldozed = false
                    return
                end
                local con = api.engine.getComponent(conId, api.type.ComponentType.CONSTRUCTION)
                if con == nil or not(arrayUtils.arrayHasValue({constants.autoPlacingConFileName, constants.manualPlacingConFileName}, con.fileName)) then
                    _guiData.conIdAboutToBeBulldozed = false
                    return
                end

                logger.print('you are about to bulldoze the construction with id') logger.debugPrint(conId)
                _guiData.conIdAboutToBeBulldozed = conId
            elseif (name == 'builder.apply' and id == 'bulldozer') then
                -- LOLLO NOTE
                -- Here, the station has been bulldozed.
                -- Its data has been lost already, except something about an expiring station group.
                -- I could try some hack to rebuild the road after bulldozing the station, but a bit of manuality will do fine
                xpcall(
                    function()
                        logger.print('guiHandleEvent caught id =', id, 'name =', name, 'args =') --logger.debugPrint(args)
                        if not(_guiData.conIdAboutToBeBulldozed) then return end

                        if args == nil
                        or args.proposal == nil
                        or args.proposal.toRemove == nil
                        or args.proposal.toRemove[1] ~= _guiData.conIdAboutToBeBulldozed
                        then
                            _guiData.conIdAboutToBeBulldozed = false
                            return
                        end

                        _guiData.conIdAboutToBeBulldozed = false
                        logger.print('you have bulldozed the construction with id') logger.debugPrint(args.proposal.toRemove[1])
                        -- local gameTimeSec = api.engine.getComponent(api.engine.util.getWorld(), api.type.ComponentType.GAME_TIME).gameTime -- number
                        -- local expiredStationGroupIds = api.engine.system.stationGroupSystem.getExpiredStationGroups(gameTimeSec * 1000) -- userdata indexed in base 1

                        local getNode0IdNode1Id = function()
                            local removedNodeIds = {}
                            for i = 1, #args.proposal.proposal.removedNodes, 1 do
                                local nodeProps = args.proposal.proposal.removedNodes[i]
                                removedNodeIds[#removedNodeIds+1] = -nodeProps.entity -1
                            end
                            local remainingNodeIds = {}
                            for i = 1, #args.proposal.proposal.removedSegments, 1 do
                                local segmentProps = args.proposal.proposal.removedSegments[i]
                                for _, nodeId in pairs({segmentProps.comp.node0, segmentProps.comp.node1}) do
                                    if not(arrayUtils.arrayHasValue(removedNodeIds, nodeId)) then
                                        remainingNodeIds[#remainingNodeIds+1] = nodeId
                                    end
                                end
                            end
                            if #remainingNodeIds ~= 2 then
                                logger.warn('cannot rebuild road, there are ~= 2 remainingNodeIds') logger.warningDebugPrint(remainingNodeIds)
                                return false
                            end
                            -- if #removedNodeIds ~= 2 then
                            --     logger.warn('cannot rebuild road, there are ~= 2 removedNodeIds') logger.warningDebugPrint(removedNodeIds)
                            --     return false
                            -- end
                            return remainingNodeIds[1], remainingNodeIds[2]
                        end
                        local node0Id, node1Id = getNode0IdNode1Id()
                        if not(node0Id) or not(node1Id) then return end

                        local getEdgeProps = function()
                            local tan0, tan1
                            local totalLength = 0
                            local removedSegments = {}
                            local compType
                            local compTypeIndex
                            local streetType
                            local hasBus
                            local tramTrackType
                            -- keep the outer segments
                            for i = 1, #args.proposal.proposal.removedSegments, 1 do
                                local segmentProps = args.proposal.proposal.removedSegments[i]
                                if segmentProps.comp.node0 == node0Id then
                                    tan0 = transfUtils.getVectorMultiplied(segmentProps.comp.tangent0, 1)
                                elseif segmentProps.comp.node1 == node0Id then
                                    tan0 = transfUtils.getVectorMultiplied(segmentProps.comp.tangent1, -1)
                                end
                                if segmentProps.comp.node0 == node1Id then
                                    tan1 = transfUtils.getVectorMultiplied(segmentProps.comp.tangent0, -1)
                                elseif segmentProps.comp.node1 == node1Id then
                                    tan1 = transfUtils.getVectorMultiplied(segmentProps.comp.tangent1, 1)
                                end

                                totalLength = totalLength + (transfUtils.getVectorLength(segmentProps.comp.tangent0) + transfUtils.getVectorLength(segmentProps.comp.tangent1)) / 2

                                removedSegments[#removedSegments+1] = segmentProps

                                if i == 1 then
                                    compType = segmentProps.comp.type -- ground, bridge or tunnel
                                    compTypeIndex = segmentProps.comp.typeIndex -- bridge or tunnel type
                                    streetType = segmentProps.streetEdge.streetType
                                    hasBus = segmentProps.streetEdge.hasBus
                                    tramTrackType = segmentProps.streetEdge.tramTrackType
                                end
                            end
                            if #removedSegments ~= 3 then
                                logger.warn('cannot rebuild road, there are ~= 3 removedSegments') logger.warningDebugPrint(removedSegments)
                                return false
                            end
                            local tan0Adjusted = transfUtils.getVectorMultiplied(tan0, totalLength / transfUtils.getVectorLength(tan0))
                            local tan1Adjusted = transfUtils.getVectorMultiplied(tan1, totalLength / transfUtils.getVectorLength(tan1))
                            return tan0Adjusted, tan1Adjusted, compType, compTypeIndex, streetType, hasBus, tramTrackType
                        end
                        local tan0, tan1, compType, compTypeIndex, streetType, hasBus, tramTrackType = getEdgeProps()
                        if not(tan0) or not(tan1) or not(streetType) then return end

                        local makeEdge = function()
                            local newEdge = api.type.SegmentAndEntity.new()
                            newEdge.entity = -1
                            newEdge.comp.node0 = node0Id
                            newEdge.comp.node1 = node1Id
                            newEdge.comp.tangent0 = api.type.Vec3f.new(tan0.x, tan0.y, tan0.z)
                            newEdge.comp.tangent1 = api.type.Vec3f.new(tan1.x, tan1.y, tan1.z)
                            newEdge.comp.type = compType
                            newEdge.comp.typeIndex = compTypeIndex
                            newEdge.type = 0 -- 0 is api.type.enum.Carrier.ROAD, 1 is api.type.enum.Carrier.RAIL
                            newEdge.streetEdge = api.type.BaseEdgeStreet.new()
                            newEdge.streetEdge.streetType = streetType
                            newEdge.streetEdge.hasBus = hasBus or false -- this is always false coz the hasBus in constructions is broken
                            newEdge.streetEdge.tramTrackType = tramTrackType or 0

                            local proposal = api.type.SimpleProposal.new()
                            proposal.streetProposal.edgesToAdd[1] = newEdge

                            local context = api.type.Context:new()
                            -- context.checkTerrainAlignment = true -- default is false
                            -- context.cleanupStreetGraph = true -- default is false
                            -- context.gatherBuildings = true -- default is false
                            -- context.gatherFields = true -- default is true
                            -- context.player = api.engine.util.getPlayer()
                            api.cmd.sendCommand(
                                api.cmd.make.buildProposal(proposal, context, true), -- the 3rd param is "ignore errors"; wrong proposals will be discarded anyway
                                function(result, success)
                                    logger.print('rebuildRoad callback, success =', success)
                                    -- logger.debugPrint(result)
                                    if not(success) then
                                        logger.warn('rebuildRoad callback failed')
                                        logger.warn('rebuildRoad proposal =') logger.warningDebugPrint(proposal)
                                        logger.warn('rebuildRoad result =') logger.warningDebugPrint(result)
                                        -- LOLLO TODO give feedback
                                    end
                                end
                            )
                        end
                        makeEdge()
                    end,
                    function(error)
                        logger.warn('cannot rebuild road')
                        logger.xpErrorHandler(error)
                    end
                )
            end
        end,
        guiInit = function()
            -- logger.print('guiInit starting')
            _guiData.ploppablePassengersModelId = api.res.modelRep.find('station/bus/lollo_bus_stop/initialStation.mdl')
            _guiData.conParamsMetadataSorted = moduleHelpers.getAutoPlacingParamsMetadata()
            -- logger.print('guiInit ending')
        end,
        -- guiUpdate = function()
        -- end,
        handleEvent = function(src, id, name, args)
            if (id ~= _eventId) then return end
            logger.print('handleEvent starting, src =', src, ', id =', id, ', name =', name, ', args =') logger.debugPrint(args)
            if type(args) ~= 'table' then return end
            logger.print('state =') logger.debugPrint(state)

            xpcall(
                function()
                    if name == _eventProperties.initialEdgeObjectPlaced.eventName then
                        _actions.replaceEdgeWithSame(
                            args.edgeId,
                            args.edgeObjectId,
                            _eventProperties.ploppableStreetsidePassengerStationRemoved.eventName,
                            {
                                edgeObjectTransf = args.edgeObjectTransf,
                                streetType = args.streetType,
                                bridgeOrTunnelType = args.bridgeOrTunnelType,
                                groundBridgeTunnel012 = args.groundBridgeTunnel012,
                                tramTrackType = args.tramTrackType,
                                hasBus = args.hasBus,
                            }
                        )
                    elseif name == _eventProperties.ploppableStreetsidePassengerStationRemoved.eventName then
                        if not(edgeUtils.isValidAndExistingId(args.edgeId)) or edgeUtils.isEdgeFrozen(args.edgeId) then
                            logger.warn('edge invalid or frozen')
                            _setStateReady()
                            return
                        end

                        local length = edgeUtils.getEdgeLength(args.edgeId)
                        if length < constants.minInitialEdgeLength then
                            logger.warn('edge too short')
                            _setStateReady()
                            return
                        end

                        local outerTransf0 = transfUtils.getTransfXShiftedBy(args.edgeObjectTransf, constants.outerEdgeX)
                        local outerTransf1 = transfUtils.getTransfXShiftedBy(args.edgeObjectTransf, -constants.outerEdgeX)
                        -- these are identical to the ones above, except they only have the position
                        local outerPos0 = transfUtils.getVec123Transformed({constants.outerEdgeX, 0, 0}, args.edgeObjectTransf)
                        local outerPos1 = transfUtils.getVec123Transformed({-constants.outerEdgeX, 0, 0}, args.edgeObjectTransf)
                        logger.print('outerTransf0 =') logger.debugPrint(outerTransf0)
                        logger.print('outerTransf1 =') logger.debugPrint(outerTransf1)
                        logger.print('outerPos0 =') logger.debugPrint(outerPos0)
                        logger.print('outerPos1 =') logger.debugPrint(outerPos1)

                        local nodeBetween = edgeUtils.getNodeBetweenByPosition(
                            args.edgeId,
                            {
                                x = outerTransf0[13],
                                y = outerTransf0[14],
                                z = outerTransf0[15],
                            }
                        )
                        logger.print('first outer nodeBetween =') logger.debugPrint(nodeBetween)
                        _actions.splitEdge(
                            args.edgeId,
                            nodeBetween,
                            _eventProperties.firstOuterSplitDone.eventName,
                            {
                                streetType = args.streetType,
                                bridgeOrTunnelType = args.bridgeOrTunnelType,
                                groundBridgeTunnel012 = args.groundBridgeTunnel012,
                                tramTrackType = args.tramTrackType,
                                hasBus = args.hasBus,
                                outerTransf0 = outerTransf0,
                                outerTransf1 = outerTransf1,
                                transfMid = args.edgeObjectTransf,
                            }
                        )
                    elseif name == _eventProperties.firstOuterSplitDone.eventName then
                        -- find out which edge needs splitting
                        logger.print('args.outerNode0EdgeIds =') logger.debugPrint(args.outerNode0EdgeIds)
                        if #args.outerNode0EdgeIds == 0 then
                            logger.warn('cannot find an edge for the second split')
                            _setStateReady()
                            return
                        end
                        local edgeIdToBeSplit, nodeBetween = _utils.getSplit1Data(
                            args.outerTransf1,
                            args.outerNode0EdgeIds
                        )
                        if not(edgeIdToBeSplit) then
                            logger.warn('cannot decide on an edge id for the second outer split')
                            _setStateReady()
                            return
                        end
                        if not(nodeBetween) then
                            logger.warn('cannot find out nodeBetween for the second outer split')
                            _setStateReady()
                            return
                        end

                        logger.print('final second outer nodeBetween =') logger.debugPrint(nodeBetween)
                        _actions.splitEdge(edgeIdToBeSplit, nodeBetween, _eventProperties.secondOuterSplitDone.eventName, args)
                    elseif name == _eventProperties.secondOuterSplitDone.eventName then
                        local _getEdgeData = function()
                            logger.print('_getEdgeData starting')
                            local edgeIdsBetweenNodes = _utils.getEdgeIdsLinkingNodes(args.outerNode0Id, args.outerNode1Id)
                            logger.print('edgeIdsBetweenNodes =') logger.debugPrint(edgeIdsBetweenNodes)
                            if #edgeIdsBetweenNodes ~= 1 then
                                logger.warn('no edges or too many edges found between outerNode0Id and outerNode1Id')
                                return false
                            end

                            local outerBaseNode0 = api.engine.getComponent(args.outerNode0Id, api.type.ComponentType.BASE_NODE)
                            local outerBaseNode1 = api.engine.getComponent(args.outerNode1Id, api.type.ComponentType.BASE_NODE)
                            local edge0Base = api.engine.getComponent(edgeIdsBetweenNodes[1], api.type.ComponentType.BASE_EDGE)
                            if outerBaseNode0 == nil or outerBaseNode1 == nil or edge0Base == nil then
                                logger.warn('some edges or nodes cannot be read')
                                return false
                            end

                            local isEdgeNodesOK = true
                            if not(
                                (edge0Base.node0 == args.outerNode0Id and edge0Base.node1 == args.outerNode1Id)
                                or (edge0Base.node1 == args.outerNode0Id and edge0Base.node0 == args.outerNode1Id)
                            ) then
                                isEdgeNodesOK = false
                                logger.warn('### edge0 nodes are screwed up, edge0Base =') logger.warningDebugPrint(edge0Base)
                            end
                            if not(isEdgeNodesOK) then
                                return false
                            end

                            local is0To1 = (edge0Base.node0 == args.outerNode0Id and edge0Base.node1 == args.outerNode1Id)
                            local pos0XYZ = is0To1 and outerBaseNode0.position or outerBaseNode1.position
                            local pos1XYZ = is0To1 and outerBaseNode1.position or outerBaseNode0.position
                            -- local tan0XYZ = is0To1 and edge0Base.tangent0 or transfUtils.getVectorMultiplied(edge0Base.tangent1, -1) -- NO!
                            -- local tan1XYZ = is0To1 and edge0Base.tangent1 or transfUtils.getVectorMultiplied(edge0Base.tangent0, -1) -- NO!
                            -- local tan0XYZ = is0To1 and edge0Base.tangent0 or edge0Base.tangent1 -- NO!
                            -- local tan1XYZ = is0To1 and edge0Base.tangent1 or edge0Base.tangent0 -- NO!
                            -- local tan0XYZ = is0To1 and edge0Base.tangent0 or transfUtils.getVectorMultiplied(edge0Base.tangent1, -1) -- NO
                            -- local tan1XYZ = is0To1 and edge0Base.tangent1 or transfUtils.getVectorMultiplied(edge0Base.tangent0, -1) -- NO
                            local tan0XYZ = edge0Base.tangent0 -- works
                            local tan1XYZ = edge0Base.tangent1 -- works

                            logger.print('pos0XYZ, pos1XYZ, tan0XYZ, tan1XYZ, edgeIdsBetweenNodes, is0To1 =') logger.debugPrint(pos0XYZ) logger.debugPrint(pos1XYZ) logger.debugPrint(tan0XYZ) logger.debugPrint(tan1XYZ) logger.debugPrint(edgeIdsBetweenNodes) logger.debugPrint(is0To1)
                            return pos0XYZ, pos1XYZ, tan0XYZ, tan1XYZ, edgeIdsBetweenNodes, is0To1
                        end
                        local pos0XYZ, pos1XYZ, tan0XYZ, tan1XYZ, edgeIdsToBeRemoved, is0To1 = _getEdgeData()
                        if not(pos0XYZ) or not(pos1XYZ) or not(tan0XYZ) or not(tan1XYZ) then _setStateReady() return end

                        -- between the two cuts, I am going to place three edges, not one: calculate their positions and tangents
                        local _innerX0To1 = constants.innerEdgeX / constants.outerEdgeX / 2
                        logger.print('_innerX0To1  =', _innerX0To1)
                        local nodeBetween0 = edgeUtils.getNodeBetween(pos0XYZ, pos1XYZ, tan0XYZ, tan1XYZ, _innerX0To1)
                        logger.print('nodeBetween0 would be =') logger.debugPrint(nodeBetween0)
                        local nodeBetween1 = edgeUtils.getNodeBetween(pos0XYZ, pos1XYZ, tan0XYZ, tan1XYZ, (1 - _innerX0To1))
                        logger.print('nodeBetween1 would be =') logger.debugPrint(nodeBetween1)

                        if nodeBetween0 == nil or nodeBetween1 == nil then
                            logger.warn('some edges cannot be split')
                            _setStateReady()
                            return
                        end
                        local isNodeBetweenOrientatedLikeMyEdge0 = edgeUtils.isXYZSame(nodeBetween0.refPosition0, pos0XYZ)
                        local distance00 = isNodeBetweenOrientatedLikeMyEdge0 and nodeBetween0.refDistance0 or nodeBetween0.refDistance1
                        local tanSign0 = isNodeBetweenOrientatedLikeMyEdge0 and 1 or -1

                        local isNodeBetweenOrientatedLikeMyEdge1 = edgeUtils.isXYZSame(nodeBetween1.refPosition1, pos1XYZ)
                        local distance11 = isNodeBetweenOrientatedLikeMyEdge1 and nodeBetween1.refDistance1 or nodeBetween1.refDistance0
                        local tanSign1 = isNodeBetweenOrientatedLikeMyEdge1 and 1 or -1

                        local distance01 = (isNodeBetweenOrientatedLikeMyEdge0 and nodeBetween0.refDistance1 or nodeBetween0.refDistance0) - distance11
                        local distance10 = (isNodeBetweenOrientatedLikeMyEdge1 and nodeBetween1.refDistance0 or nodeBetween1.refDistance1) - distance00

                        logger.print('isNodeBetweenOrientatedLikeMyEdge0 =', isNodeBetweenOrientatedLikeMyEdge0, 'isNodeBetweenOrientatedLikeMyEdge1 =', isNodeBetweenOrientatedLikeMyEdge1)

                        args.edgeData4Con = {
                            outerNode0Pos = transfUtils.xYZ2OneTwoThree(pos0XYZ),
                            innerNode0Pos = transfUtils.xYZ2OneTwoThree(nodeBetween0.position),
                            innerNode1Pos = transfUtils.xYZ2OneTwoThree(nodeBetween1.position),
                            outerNode1Pos = transfUtils.xYZ2OneTwoThree(pos1XYZ),
                            edge0Tan0 = transfUtils.getVectorMultiplied(transfUtils.xYZ2OneTwoThree(tan0XYZ), _innerX0To1),
                            edge0Tan1 = transfUtils.getVectorMultiplied(transfUtils.xYZ2OneTwoThree(nodeBetween0.tangent), distance00 * tanSign0),
                            edge1Tan0 = transfUtils.getVectorMultiplied(transfUtils.xYZ2OneTwoThree(nodeBetween0.tangent), distance01 * tanSign0),
                            edge1Tan1 = transfUtils.getVectorMultiplied(transfUtils.xYZ2OneTwoThree(nodeBetween1.tangent), distance10 * tanSign1),
                            edge2Tan0 = transfUtils.getVectorMultiplied(transfUtils.xYZ2OneTwoThree(nodeBetween1.tangent), distance11 * tanSign1),
                            edge2Tan1 = transfUtils.getVectorMultiplied(transfUtils.xYZ2OneTwoThree(tan1XYZ), _innerX0To1),
                        }

                        _actions.removeEdges(edgeIdsToBeRemoved, _eventProperties.edgesRemoved.eventName, args)
                    elseif name == _eventProperties.edgesRemoved.eventName then
                        _actions.buildConstruction(args.outerNode0Id, args.outerNode1Id, args.streetType, args.groundBridgeTunnel012, args.bridgeOrTunnelType, args.tramTrackType, args.hasBus, args.edgeData4Con)
                    elseif name == _eventProperties.conBuilt.eventName then
                        -- _actions.upgradeCon(args.conId, args.conParams)
                        _actions.buildSnappyRoads(args.conParams, args.conId)
                    elseif name == _eventProperties.snappyConBuilt.eventName then
                        -- _actions.upgradeCon(args.conId, args.conParams)
                    elseif name == _eventProperties.snappyRoadsBuilt.eventName then
                        _setStateReady()
                    elseif name == _eventProperties.setStateWorking.eventName then
                        state.isWorking = args.isWorking
                    elseif name == _eventProperties.conParamsUpdated.eventName then
                        _actions.updateConstruction(args.conId, args.paramKey, args.newParamValueIndexBase0)
                    end
                end,
                function(error)
                    _setStateReady()
                    logger.xpErrorHandler(error)
                end
            )
        end,
        load = function(loadedState)
            -- fires once in the worker thread, at game load, and many times in the UI thread
            if loadedState then
                state = {}
                state.isWorking = loadedState.isWorking or false
            else
                state = {
                    isWorking = false,
                }
            end
            if not(api.gui) then -- this is the one call from the worker thread, when starting
                -- (there are actually two calls on start, not one, never mind)
                -- loadedState is the last saved state from the save file (eg lollo-test-01.sav.lua)
                -- use it to reset the state if it gets stuck, which should never happen
                state = {
                    isWorking = false,
                }
                logger.print('script.load firing from the worker thread, state =') logger.debugPrint(state)
            end
        end,
        save = function()
            -- only fires when the worker thread changes the state
            if not state then state = {} end
            if not state.isWorking then state.isWorking = false end
            return state
        end,
        -- update = function()
        -- end,
    }
end
