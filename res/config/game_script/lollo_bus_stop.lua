local arrayUtils = require('lollo_bus_stop.arrayUtils')
local constants = require('lollo_bus_stop.constants')
local edgeUtils = require('lollo_bus_stop.edgeUtils')
local logger = require('lollo_bus_stop.logger')
local transfUtils = require('lollo_bus_stop.transfUtils')


local _eventId = '__lolloStreetsidePassengerStopsEvent__'
local _eventProperties = {
--     streetsideBusStopBuilt = { conName = 'station/street/lollo_bus_stop/lollo_lorry_bay_with_edges.con', eventName = 'streetsideBusStopBuilt' },
--     ploppableModularCargoStationBuilt = { conName = 'station/street/lollo_bus_stop/lollo_lorry_bay_with_edges_ploppable.con', eventName = 'ploppableModularCargoStationBuilt' },
--     ploppableStreetsideCargoStationBuilt = { conName = nil, eventName = 'ploppableStreetsideCargoStationBuilt' },
    ploppableStreetsidePassengerStationBuilt = { conName = nil, eventName = 'ploppableStreetsidePassengerStationBuilt' },
    splitRequested = { conName = nil, eventName = 'splitRequested'},
}

local _guiConstants = {
    _ploppablePassengersModelId = false,
}


function data()
    local _utils = {
        getNewlyBuildEdgeId = function(result)
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
        getWhichEdgeGetsEdgeObjectAfterSplit = function(edgeObjPosition, node0pos, node1pos, nodeBetween)
            local result = {
                assignToSide = nil,
            }
            -- print('LOLLO attempting to place edge object with position =')
            -- debugPrint(edgeObjPosition)
            -- print('wholeEdge.node0pos =')
            -- debugPrint(node0pos)
            -- print('nodeBetween.position =')
            -- debugPrint(nodeBetween.position)
            -- print('nodeBetween.tangent =')
            -- debugPrint(nodeBetween.tangent)
            -- print('wholeEdge.node1pos =')
            -- debugPrint(node1pos)
    
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
    
            -- print('LOLLO assignment =')
            -- debugPrint(result)
            return result
        end,
    }
    local _actions = {
        bulldozeConstruction = function(constructionId)
            -- print('constructionId =', constructionId)
            if type(constructionId) ~= 'number' or constructionId < 0 then return end
    
            local oldConstruction = api.engine.getComponent(constructionId, api.type.ComponentType.CONSTRUCTION)
            -- print('oldConstruction =')
            -- debugPrint(oldConstruction)
            if not(oldConstruction) or not(oldConstruction.params) then return end
    
            local proposal = api.type.SimpleProposal.new()
            -- LOLLO NOTE there are asymmetries how different tables are handled.
            -- This one requires this system, UG says they will document it or amend it.
            proposal.constructionsToRemove = { constructionId }
            -- proposal.constructionsToRemove[1] = constructionId -- fails to add
            -- proposal.constructionsToRemove:add(constructionId) -- fails to add
    
            api.cmd.sendCommand(
                api.cmd.make.buildProposal(proposal, nil, true), -- the 3rd param is "ignore errors"; wrong proposals will be discarded anyway
                function(res, success)
                    -- print('LOLLO _bulldozeConstruction res = ')
                    -- debugPrint(res)
                    --for _, v in pairs(res.entities) do print(v) end
                    -- print('LOLLO _bulldozeConstruction success = ')
                    -- debugPrint(success)
                end
            )
        end,
        removeEdge = function(oldEdgeId)
            logger.print('removeEdge starting')
            -- removes an edge even if it has a street type, which has changed or disappeared
            if not(edgeUtils.isValidAndExistingId(oldEdgeId))
            then return end
    
            local conIdToBeRemoved = nil
            local conId = api.engine.system.streetConnectorSystem.getConstructionEntityForEdge(oldEdgeId)
            if edgeUtils.isValidAndExistingId(conId) then
                local conData = api.engine.getComponent(conId, api.type.ComponentType.CONSTRUCTION)
                if conData and conData.frozenEdges then
                    -- if conData.fileName ~= 'lollo_street_chunks.con'
                    -- and conData.fileName ~= 'lollo_street_chunks_2.con' then
                    --     logger.warn('attempting to remove a frozen edge, remove its construction instead')
                    --     return
                    -- else
                        conIdToBeRemoved = conId
                        logger.print('conIdToBeRemoved =') logger.debugPrint(conIdToBeRemoved)
                    -- end
                end
            end
    
            local proposal = api.type.SimpleProposal.new()
            if conIdToBeRemoved then
                proposal.constructionsToRemove = { conIdToBeRemoved }
            else
                local oldBaseEdge = api.engine.getComponent(oldEdgeId, api.type.ComponentType.BASE_EDGE)
                logger.print('oldEdge =') logger.debugPrint(oldBaseEdge)
                local oldEdgeStreet = api.engine.getComponent(oldEdgeId, api.type.ComponentType.BASE_EDGE_STREET)
                logger.print('oldEdgeStreet =') logger.debugPrint(oldEdgeStreet)
                -- save a crash when a modded road underwent a breaking change, so it has no oldEdgeStreet
                if oldBaseEdge == nil or oldEdgeStreet == nil then return end
    
                local orphanNodeIds = {}
                local _map = api.engine.system.streetSystem.getNode2SegmentMap()
                if #_map[oldBaseEdge.node0] == 1 then
                    orphanNodeIds[#orphanNodeIds+1] = oldBaseEdge.node0
                end
                if #_map[oldBaseEdge.node1] == 1 then
                    orphanNodeIds[#orphanNodeIds+1] = oldBaseEdge.node1
                end
    
                proposal.streetProposal.edgesToRemove[1] = oldEdgeId
                for i = 1, #orphanNodeIds, 1 do
                    proposal.streetProposal.nodesToRemove[i] = orphanNodeIds[i]
                end
    
                if oldBaseEdge.objects then
                    for o = 1, #oldBaseEdge.objects do
                        proposal.streetProposal.edgeObjectsToRemove[#proposal.streetProposal.edgeObjectsToRemove+1] = oldBaseEdge.objects[o][1]
                    end
                end
            end
    
            api.cmd.sendCommand(
                api.cmd.make.buildProposal(proposal, nil, true),
                function(res, success)
                    -- print('LOLLO res = ') -- debugPrint(res)
                    -- print('LOLLO _replaceEdgeWithStreetType success = ') -- debugPrint(success)
                    if not(success) then
                        -- this fails if there are more than one contiguous invalid segments.
                        -- the message is
                        -- can't connect edge at position (-2170.3 / -2674.84 / 35.4797)
                        -- to get past this, we should navigate everywhere, checking for the street types
                        -- that can be either gone missing, or have been changed.
                        -- Then we should replace them with their own new version (streetTypeId = oldEdgeStreet.streetType),
                        -- or remove them
                        logger.warn('streetTuning.removeEdge failed, proposal = ') debugPrint(proposal)
                    end
                end
            )
        end,
        -- replaces a street segment with an identical one, without destroying the buildings
        -- removes the given object
        -- and raises the given event
        replaceEdgeWithSame = function(oldEdgeId, objectIdToBeRemoved, successEventName, successEventArgs)
            logger.print('replaceEdgeWithSame starting')
            if not(edgeUtils.isValidAndExistingId(oldEdgeId)) then return end

            local oldBaseEdge = api.engine.getComponent(oldEdgeId, api.type.ComponentType.BASE_EDGE)
            local oldEdgeStreet = api.engine.getComponent(oldEdgeId, api.type.ComponentType.BASE_EDGE_STREET)
            -- save a crash when a modded road underwent a breaking change, so it has no oldEdgeStreet
            if oldBaseEdge == nil or oldEdgeStreet == nil then return end

            local newEdge = api.type.SegmentAndEntity.new()
            newEdge.entity = -1
            newEdge.type = 0 -- 0 is api.type.enum.Carrier.ROAD, 1 is api.type.enum.Carrier.RAIL
            newEdge.comp = oldBaseEdge
            if type(oldBaseEdge.objects) == 'table' then
                local edgeObjects = {}
                for _, edgeObj in pairs(oldBaseEdge.objects) do
                    if edgeObj[1] ~= objectIdToBeRemoved then
                        table.insert(edgeObjects, { edgeObj[1], edgeObj[2] })
                    end
                end
                newEdge.comp.objects = edgeObjects -- LOLLO NOTE cannot insert directly into edge0.comp.objects. Different tables are handled differently...
            end
            newEdge.playerOwned = api.engine.getComponent(oldEdgeId, api.type.ComponentType.PLAYER_OWNED)
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
            --[[ local sampleNewEdge =
            {
            entity = -1,
            comp = {
                node0 = 13010,
                node1 = 18753,
                tangent0 = {
                x = -32.318000793457,
                y = 81.757850646973,
                z = 3.0953373908997,
                },
                tangent1 = {
                x = -34.457527160645,
                y = 80.931526184082,
                z = -1.0708819627762,
                },
                type = 0,
                typeIndex = -1,
                objects = { },
            },
            type = 0,
            params = {
                streetType = 23,
                hasBus = false,
                tramTrackType = 0,
                precedenceNode0 = 2,
                precedenceNode1 = 2,
            },
            playerOwned = nil,
            streetEdge = {
                streetType = 23,
                hasBus = false,
                tramTrackType = 0,
                precedenceNode0 = 2,
                precedenceNode1 = 2,
            },
            trackEdge = {
                trackType = -1,
                catenary = false,
            },
            } ]]
    
            api.cmd.sendCommand(
                api.cmd.make.buildProposal(proposal, nil, true),
                function(result, success)
                    -- print('LOLLO res = ')
                    -- debugPrint(res)
                    --for _, v in pairs(res.entities) do print(v) end
                    -- print('LOLLO success = ')
                    -- debugPrint(success)
                    if not(success) then
                        logger.warn('replaceEdgeWithSame failed, proposal = ') debugPrint(proposal)
                    else
                        logger.print('replaceEdgeWithSame succeeded, result =') --debugPrint(result)
                        if not(successEventName) then return end

                        xpcall(
                            function ()
                                local newlyBuiltEdgeId = _utils.getNewlyBuildEdgeId(result)
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
                            logger.xpErrorHandler
                        )
                    end
                end
            )
        end,
        splitEdge = function(wholeEdgeId, nodeBetween)
            if not(edgeUtils.isValidAndExistingId(wholeEdgeId)) or type(nodeBetween) ~= 'table' then return end
    
            local oldBaseEdge = api.engine.getComponent(wholeEdgeId, api.type.ComponentType.BASE_EDGE)
            local oldBaseEdgeStreet = api.engine.getComponent(wholeEdgeId, api.type.ComponentType.BASE_EDGE_STREET)
            -- save a crash when a modded road underwent a breaking change, so it has no oldEdgeStreet
            if oldBaseEdge == nil or oldBaseEdgeStreet == nil then return end
    
            local node0 = api.engine.getComponent(oldBaseEdge.node0, api.type.ComponentType.BASE_NODE)
            local node1 = api.engine.getComponent(oldBaseEdge.node1, api.type.ComponentType.BASE_NODE)
            if node0 == nil or node1 == nil then return end
    
            if not(edgeUtils.isXYZSame(nodeBetween.refPosition0, node0.position)) and not(edgeUtils.isXYZSame(nodeBetween.refPosition0, node1.position)) then
                print('WARNING: splitEdge cannot find the nodes')
            end
            local isNodeBetweenOrientatedLikeMyEdge = edgeUtils.isXYZSame(nodeBetween.refPosition0, node0.position)
            local distance0 = isNodeBetweenOrientatedLikeMyEdge and nodeBetween.refDistance0 or nodeBetween.refDistance1
            local distance1 = isNodeBetweenOrientatedLikeMyEdge and nodeBetween.refDistance1 or nodeBetween.refDistance0
            local tanSign = isNodeBetweenOrientatedLikeMyEdge and 1 or -1
    
            local oldTan0Length = edgeUtils.getVectorLength(oldBaseEdge.tangent0)
            local oldTan1Length = edgeUtils.getVectorLength(oldBaseEdge.tangent1)
    
            local playerOwned = api.type.PlayerOwned.new()
            playerOwned.player = api.engine.util.getPlayer()
    
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
            newEdge0.playerOwned = playerOwned
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
            newEdge1.playerOwned = playerOwned
            newEdge1.streetEdge = oldBaseEdgeStreet
    
            if type(oldBaseEdge.objects) == 'table' then
                -- local edge0StationGroups = {}
                -- local edge1StationGroups = {}
                local edge0Objects = {}
                local edge1Objects = {}
                for _, edgeObj in pairs(oldBaseEdge.objects) do
                    local edgeObjPosition = edgeUtils.getObjectPosition(edgeObj[1])
                    -- print('edge object position =') debugPrint(edgeObjPosition)
                    if type(edgeObjPosition) ~= 'table' then return end -- change nothing and leave
                    local assignment = _utils.getWhichEdgeGetsEdgeObjectAfterSplit(
                        edgeObjPosition,
                        {node0.position.x, node0.position.y, node0.position.z},
                        {node1.position.x, node1.position.y, node1.position.z},
                        nodeBetween
                    )
                    if assignment.assignToSide == 0 then
                        -- LOLLO NOTE if we skip this check,
                        -- one can split a road between left and right terminals of a streetside staion
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
            context.checkTerrainAlignment = true -- default is false, true gives smoother Z
            -- context.cleanupStreetGraph = true -- default is false
            -- context.gatherBuildings = true  -- default is false
            -- context.gatherFields = true -- default is true
            context.player = api.engine.util.getPlayer() -- default is -1
    
            api.cmd.sendCommand(
                api.cmd.make.buildProposal(proposal, context, true), -- the 3rd param is "ignore errors"; wrong proposals will be discarded anyway
                function(result, success)
                    -- print('LOLLO street splitter callback returned result = ')
                    -- debugPrint(result)
                    -- print('LOLLO street splitter callback returned success = ', success)
                    if not(success) then
                        print('Warning: streetTuning.splitEdge failed, proposal = ') debugPrint(proposal)
                    end
                end
            )
        end,
    }
    return {
        guiHandleEvent = function(id, name, args)
            -- LOLLO NOTE param can have different types, even boolean, depending on the event id and name
            if (name ~= 'builder.apply' or id ~= 'streetTerminalBuilder') then return end

            -- waypoint or streetside stations have been built
            xpcall(
                function()
                    logger.print('guiHandleEvent caught id =', id, 'name =', name, 'args =') -- logger.debugPrint(args)
                    if (args and args.proposal and args.proposal.proposal
                    and args.proposal.proposal.edgeObjectsToAdd
                    and args.proposal.proposal.edgeObjectsToAdd[1]
                    and args.proposal.proposal.edgeObjectsToAdd[1].modelInstance)
                    then
                        if _guiConstants._ploppablePassengersModelId
                        and args.proposal.proposal.edgeObjectsToAdd[1].modelInstance.modelId == _guiConstants._ploppablePassengersModelId then
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
                                return
                            end

                            _actions.replaceEdgeWithSame(edgeId, edgeObjectId, _eventProperties.ploppableStreetsidePassengerStationBuilt.eventName, {edgeObjectTransf = edgeObjectTransf})
                        end
                    end
                end,
                logger.xpErrorHandler
            )
        end,
        guiInit = function()
            _guiConstants._ploppablePassengersModelId = api.res.modelRep.find('station/bus/lollo_bus_stop/small_mid.mdl')
        end,
        handleEvent = function(src, id, name, args)
            if (id ~= _eventId) then return end
            logger.print('handleEvent starting, src =', src, ', id =', id, ', name =', name, ', args =') logger.debugPrint(args)
            if type(args) ~= 'table' then return end

            xpcall(
                function()
                    if name == _eventProperties.ploppableStreetsidePassengerStationBuilt.eventName then
                        if not(edgeUtils.isValidAndExistingId(args.edgeId)) or edgeUtils.isEdgeFrozen(args.edgeId) then return end

                        local length = edgeUtils.getEdgeLength(args.edgeId)
                        if length < constants.outerEdgeX * 2 then return end -- LOLLO TODO join adjacent edges until one is long enough

                        local transf0 = transfUtils.getTransfXShiftedBy(args.edgeObjectTransf, constants.outerEdgeX)
                        local transf1 = transfUtils.getTransfXShiftedBy(args.edgeObjectTransf, -constants.outerEdgeX)
                        -- these are identical to the ones above, except they only have the position
                        local pos0 = transfUtils.getVec123Transformed({constants.outerEdgeX, 0, 0}, args.edgeObjectTransf)
                        local pos1 = transfUtils.getVec123Transformed({-constants.outerEdgeX, 0, 0}, args.edgeObjectTransf)
                        logger.print('transf0 =') logger.debugPrint(transf0)
                        logger.print('transf1 =') logger.debugPrint(transf1)
                        logger.print('pos0 =') logger.debugPrint(pos0)
                        logger.print('pos1 =') logger.debugPrint(pos1)

                        -- local nodeBetween = edgeUtils.getNodeBetweenByPosition(
                        --     args.edgeId,
                        --     -- LOLLO NOTE position and transf are always very similar
                        --     {
                        --         x = args.edgeObjectTransf[13],
                        --         y = args.edgeObjectTransf[14],
                        --         z = args.edgeObjectTransf[15],
                        --     }
                        -- )
                        -- logger.print('nodeBetween =') logger.debugPrint(nodeBetween)
                        -- _actions.splitEdge(args.edgeId, nodeBetween)

                        -- LOLLO TODO now, make two splits
                    end
                end,
                logger.xpErrorHandler
            )
        end,
        -- update = function()
        -- end,
        -- guiUpdate = function()
        -- end,
    }
end
