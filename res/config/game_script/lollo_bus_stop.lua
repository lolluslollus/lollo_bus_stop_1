local arrayUtils = require('lollo_bus_stop.arrayUtils')
local constants = require('lollo_bus_stop.constants')
local edgeUtils = require('lollo_bus_stop.edgeUtils')
local logger = require('lollo_bus_stop.logger')
local moduleHelpers = require('lollo_bus_stop.moduleHelpers')
local pitchHelpers = require('lollo_bus_stop.pitchHelper')
local streetUtils = require('lollo_bus_stop.streetUtils')
local transfUtils = require('lollo_bus_stop.transfUtils')
local transfUtilsUG = require('transf')


local _eventId = '__lolloStreetsidePassengerStopsEvent__'
local _eventProperties = {
    segmentRemoved = { conName = nil, eventName = 'segmentRemoved' },
    conBuilt = { conName = nil, eventName = 'conBuilt' },
    ploppableStreetsidePassengerStationBuilt = { conName = nil, eventName = 'ploppableStreetsidePassengerStationBuilt' },
    firstOuterSplitDone = { conName = nil, eventName = 'firstOuterSplitDone'},
    secondOuterSplitDone = { conName = nil, eventName = 'secondOuterSplitDone' },
    firstInnerSplitDone = { conName = nil, eventName = 'firstInnerSplitDone'},
    secondInnerSplitDone = { conName = nil, eventName = 'secondInnerSplitDone' },
    snappyConBuilt = { conName = nil, eventName = 'snappyConBuilt'},
}

local _guiConstants = {
    _ploppablePassengersModelId = false,
}


function data()
    local _utils = {
        -- this is no good, it bulldozes the houses.
        -- Plus, it fails at random.
        buildSnappyRoadsUNUSED = function(oldNode0Id, oldNode1Id, conId, fileName, conParams)
            logger.print('buildSnappyRoads starting, stationConId =') logger.debugPrint(conId)
            logger.print('oldNode0Id =', oldNode0Id) logger.print('oldNode1Id =', oldNode1Id)
            local con = api.engine.getComponent(conId, api.type.ComponentType.CONSTRUCTION)
            if con == nil then
                logger.warn('cannot find con')
                return
            end

            local getNewNodeIds = function()
                local frozenNodeIds = con.frozenNodes
                local frozenEdgeIds = con.frozenEdges
                local endNodeIdsUnsorted = {}
                for _, edgeId in pairs(frozenEdgeIds) do
                    local baseEdge = api.engine.getComponent(edgeId, api.type.ComponentType.BASE_EDGE)
                    if baseEdge == nil then
                        logger.warn('baseEdge is NIL, edgeId = ' .. (edgeId or 'NIL'))
                        return nil, nil
                    end
                    if not(arrayUtils.arrayHasValue(frozenNodeIds, baseEdge.node0)) then
                        arrayUtils.addUnique(endNodeIdsUnsorted, baseEdge.node0)
                    end
                    if not(arrayUtils.arrayHasValue(frozenNodeIds, baseEdge.node1)) then
                        arrayUtils.addUnique(endNodeIdsUnsorted, baseEdge.node1)
                    end
                end
                logger.print('endNodeIdsUnsorted =') logger.debugPrint(endNodeIdsUnsorted)
                if (#endNodeIdsUnsorted ~= 2) then
                    logger.warn('endNodeIdsUnsorted has ~= 2 items') logger.warningDebugPrint(endNodeIdsUnsorted)
                end

                local baseEndNode0 = api.engine.getComponent(endNodeIdsUnsorted[1], api.type.ComponentType.BASE_NODE)
                local baseEndNode1 = api.engine.getComponent(endNodeIdsUnsorted[2], api.type.ComponentType.BASE_NODE)
                local baseOldNode0 = api.engine.getComponent(oldNode0Id, api.type.ComponentType.BASE_NODE)
                local baseOldNode1 = api.engine.getComponent(oldNode1Id, api.type.ComponentType.BASE_NODE)
                if baseOldNode0 == nil or baseOldNode1 == nil then
                    logger.warn('cannot find node0Id or node1Id')
                    return nil, nil
                end
                local endNode0Id = endNodeIdsUnsorted[1]
                local endNode1Id = endNodeIdsUnsorted[2]
                logger.print('newNode0Id before swapping =', endNode0Id, 'newNode1Id =', endNode1Id)
                local distance00 = transfUtils.getPositionsDistance(baseOldNode0.position, baseEndNode0.position)
                local distance01 = transfUtils.getPositionsDistance(baseOldNode0.position, baseEndNode1.position)
                local distance10 = transfUtils.getPositionsDistance(baseOldNode1.position, baseEndNode0.position)
                local distance11 = transfUtils.getPositionsDistance(baseOldNode1.position, baseEndNode1.position)
                logger.print('distances =') logger.debugPrint({distance00, distance01, distance10, distance11})
                if distance00 > distance01 then
                    if distance11 < distance10 then
                        logger.warn('something is fishy swapping end nodes')
                    end
                    endNode0Id, endNode1Id = endNode1Id, endNode0Id
                    baseEndNode0, baseEndNode1 = baseEndNode1, baseEndNode0
                    logger.print('swapping end nodes, newNode0Id after swapping =', endNode0Id, 'newNode1Id =', endNode1Id)
                    local distance00 = transfUtils.getPositionsDistance(baseOldNode0.position, baseEndNode0.position)
                    local distance01 = transfUtils.getPositionsDistance(baseOldNode0.position, baseEndNode1.position)
                    local distance10 = transfUtils.getPositionsDistance(baseOldNode1.position, baseEndNode0.position)
                    local distance11 = transfUtils.getPositionsDistance(baseOldNode1.position, baseEndNode1.position)
                    logger.print('distances after swapping =') logger.debugPrint({distance00, distance01, distance10, distance11})
                end

                return endNode0Id, endNode1Id
            end
            local newNode0Id, newNode1Id = getNewNodeIds()
            if newNode0Id == nil or newNode1Id == nil then return end

            local oldEdge0Id = edgeUtils.getConnectedEdgeIds({oldNode0Id})[1]
            local oldEdge1Id = edgeUtils.getConnectedEdgeIds({oldNode1Id})[1]
            logger.print('oldEdge0Id =', oldEdge0Id)
            logger.print('oldEdge1Id =', oldEdge1Id)
            local oldBaseEdge0 = api.engine.getComponent(oldEdge0Id, api.type.ComponentType.BASE_EDGE)
            local oldBaseEdge1 = api.engine.getComponent(oldEdge1Id, api.type.ComponentType.BASE_EDGE)
            local oldEdge0Street = api.engine.getComponent(oldEdge0Id, api.type.ComponentType.BASE_EDGE_STREET)
            local oldEdge1Street = api.engine.getComponent(oldEdge1Id, api.type.ComponentType.BASE_EDGE_STREET)

            local newEdge0 = api.type.SegmentAndEntity.new()
            newEdge0.entity = -1
            newEdge0.type = 0 -- 0 is api.type.enum.Carrier.ROAD, 1 is api.type.enum.Carrier.RAIL
            newEdge0.comp = oldBaseEdge0
            logger.print('newEdge0.comp before =') logger.debugPrint(newEdge0.comp)
            if newEdge0.comp.node0 == oldNode0Id then newEdge0.comp.node0 = newNode0Id
            elseif newEdge0.comp.node0 == oldNode1Id then newEdge0.comp.node0 = newNode1Id
            elseif newEdge0.comp.node1 == oldNode0Id then newEdge0.comp.node1 = newNode0Id
            elseif newEdge0.comp.node1 == oldNode1Id then newEdge0.comp.node1 = newNode1Id
            end
            logger.print('newEdge0.comp after =') logger.debugPrint(newEdge0.comp)
            if type(oldBaseEdge0.objects) == 'table' then
                local edgeObjects = {}
                for _, edgeObj in pairs(oldBaseEdge0.objects) do
                    table.insert(edgeObjects, { edgeObj[1], edgeObj[2] })
                end
                newEdge0.comp.objects = edgeObjects -- LOLLO NOTE cannot insert directly into edge0.comp.objects. Different tables are handled differently...
            end
            newEdge0.playerOwned = api.engine.getComponent(oldEdge0Id, api.type.ComponentType.PLAYER_OWNED)
            newEdge0.streetEdge = oldEdge0Street

            local newEdge1 = api.type.SegmentAndEntity.new()
            newEdge1.entity = -2
            newEdge1.type = 0 -- 0 is api.type.enum.Carrier.ROAD, 1 is api.type.enum.Carrier.RAIL
            newEdge1.comp = oldBaseEdge1
            logger.print('newEdge1.comp before =') logger.debugPrint(newEdge1.comp)
            if newEdge1.comp.node0 == oldNode0Id then newEdge1.comp.node0 = newNode0Id
            elseif newEdge1.comp.node0 == oldNode1Id then newEdge1.comp.node0 = newNode1Id
            elseif newEdge1.comp.node1 == oldNode0Id then newEdge1.comp.node1 = newNode0Id
            elseif newEdge1.comp.node1 == oldNode1Id then newEdge1.comp.node1 = newNode1Id
            end
            logger.print('newEdge1.comp after =') logger.debugPrint(newEdge1.comp)
            if type(oldBaseEdge1.objects) == 'table' then
                local edgeObjects = {}
                for _, edgeObj in pairs(oldBaseEdge1.objects) do
                    table.insert(edgeObjects, { edgeObj[1], edgeObj[2] })
                end
                newEdge1.comp.objects = edgeObjects -- LOLLO NOTE cannot insert directly into edge0.comp.objects. Different tables are handled differently...
            end
            newEdge1.playerOwned = api.engine.getComponent(oldEdge1Id, api.type.ComponentType.PLAYER_OWNED)
            newEdge1.streetEdge = oldEdge1Street

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
            context.gatherBuildings = true -- default is false
            -- context.gatherFields = true -- default is true
            context.player = api.engine.util.getPlayer()
            api.cmd.sendCommand(
                api.cmd.make.buildProposal(proposal, context, true), -- the 3rd param is "ignore errors"; wrong proposals will be discarded anyway
                function(result, success)
                    logger.print('buildSnappyRoads callback, success =', success) -- logger.debugPrint(result)
                    if not(success) then
                        logger.warn('buildSnappyRoads failed, proposal =') logger.warningDebugPrint(proposal)
                        logger.warn('buildSnappyRoads failed, result =') logger.warningDebugPrint(result)
                    else
                        xpcall(
                            function()
                                if result
                                and result.resultProposalData
                                and result.resultProposalData.errorState
                                and not(result.resultProposalData.errorState.critical)
                                then
                                    collectgarbage() -- LOLLO TODO this is a stab in the dark to try and avoid crashes in the following
                                    -- UG TODO there is no such thing in the new api,
                                    -- nor an upgrade event, both would be useful
                                    local paramsNoSeed = arrayUtils.cloneDeepOmittingFields(conParams, {'seed'})
                                    logger.print('about to upgrade con, stationConId =', conId, 'fileName =', fileName)
                                    local upgradedConId = game.interface.upgradeConstruction(
                                        conId,
                                        fileName,
                                        paramsNoSeed
                                    )
                                    logger.print('upgradeConstruction succeeded, conId =', upgradedConId or 'NIL')
                                else
                                    logger.warn('cannot upgrade construction')
                                end
                            end,
                            function(error)
                                logger.warn(error)
                            end
                        )

                    end
                end
            )
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
        -- this is not so good, UG TODO must make a proper upfront estimator
        getIsProposalOK = function(proposal, context)
            logger.print('getIsProposalOK starting')
            if not(proposal) then logger.err('getIsProposalOK got no proposal') return false end
            if not(context) then logger.err('getIsProposalOK got no context') return false end

            local isErrorsOtherThanCollision = false
            local isWarnings = false
            xpcall(
                function()
                    -- this tries to build the construction, it calls con.updateFn()
                    local proposalData = api.engine.util.proposal.makeProposalData(proposal, context)
                    -- logger.print('getIsProposalOK proposalData =') logger.debugPrint(proposalData)

                    if proposalData.errorState ~= nil then
                        if proposalData.errorState.critical == true then
                            logger.print('proposalData.errorState.critical is true')
                            isErrorsOtherThanCollision = true
                        else
                            for _, message in pairs(proposalData.errorState.messages or {}) do
                                logger.print('looping over messages, message found =', message)
                                if message ~= 'Collision' then
                                    isErrorsOtherThanCollision = true
                                    break
                                end
                            end
                            for _, warning in pairs(proposalData.errorState.warnings or {}) do
                                logger.print('looping over warnings, warning found =', warning)
                                isWarnings = true
                                break
                            end
                        end
                    end
                end,
                function(error)
                    isErrorsOtherThanCollision = true
                    logger.xpWarningHandler(error)
                end
            )
            logger.print('getIsProposalOK isErrorsOtherThanCollision =', isErrorsOtherThanCollision)
            logger.print('getIsProposalOK isWarnings =', isWarnings)
            return not(isErrorsOtherThanCollision) and not(isWarnings)
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
                logger.print('nodeId found, it is ' .. tostring(nodeIds[1]))
                return nodeIds[1]
            end
        end,
        -- get data to start the second split after the first succeeded
        getSplit1Data = function(transf1, node0EdgeIds)
            logger.print('getSplit1Data starting')
            local edgeId2BeSplit = nil
            local nodeBetween = nil
            logger.print('outerTransf1[13] =', transf1[13])
            logger.print('outerTransf1[14] =', transf1[14])
            logger.print('outerTransf1[15] =', transf1[15])
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
                        logger.print('testNodeBetween =') logger.debugPrint(testNodeBetween)
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
        upgradeCon = function(conId, conParams)
            -- LOLLO TODO to prevent random crashes, try calling this across a call to the GUI thread and back to the worker thread
            logger.print('upgradeCon starting, conId =', (conId or 'NIL'))
            local con = api.engine.getComponent(conId, api.type.ComponentType.CONSTRUCTION)
            if con == nil then
                logger.warn('upgradeCon cannot find con')
                return
            end

            xpcall(
                function()
                    collectgarbage() -- LOLLO TODO this is a stab in the dark to try and avoid crashes in the following
                    -- UG TODO there is no such thing in the new api,
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
                end
            )
        end,
    }
    local _actions = {
        buildConstruction = function(outerNode0Id, outerNode1Id, streetType)
            logger.print('buildConstruction starting, streetType =') logger.debugPrint(streetType)

            local baseNode0 = api.engine.getComponent(outerNode0Id, api.type.ComponentType.BASE_NODE)
            local baseNode1 = api.engine.getComponent(outerNode1Id, api.type.ComponentType.BASE_NODE)
            if baseNode0 == nil or baseNode1 == nil then
                logger.warn('cannot find outerNode0Id or outerNode1Id')
                return
            end
            local getConTransf = function()
                local x0 = baseNode0.position.x
                local x1 = baseNode1.position.x
                local y0 = baseNode0.position.y
                local y1 = baseNode1.position.y
                local z0 = baseNode0.position.z
                local z1 = baseNode1.position.z
                local xMid = (x0 + x1) / 2
                local yMid = (y0 + y1) / 2
                local zMid = (z0 + z1) / 2
                local vecX0 = {-constants.outerEdgeX, 0, 0} -- transforms to {x0, y0, z0}
                local vecX1 = {constants.outerEdgeX, 0, 0} -- transforms to {x1, y1, z1}
                local ipotenusaYX = math.sqrt((x1 - x0)^2 + (y1 - y0)^2)
                local sinYX = (y1-y0) / ipotenusaYX
                local cosYX = (x1-x0) / ipotenusaYX
                logger.print('ipotenusaYX =', ipotenusaYX, 'sinYX =', sinYX, 'cosYX =', cosYX)
                local vecY0 = {0, 1, 0} -- transforms to {xMid - sinYX, yMid + cosYX, zMid}
                local vecZ0 = {0, 0, 1} -- transforms to {xMid, yMid, zMid + 1}
                local ipotenusaZX = math.sqrt((x1 - x0)^2 + (z1 - z0)^2)
                local sinZX = (z1-z0) / ipotenusaZX
                local cosZX = (x1-x0) / ipotenusaZX
                local vecZTilted = {0, 0, 1} -- transforms to {xMid - sinZX, yMid, zMid + cosZX}
                --[[
                    x = vecXYZ.x * transf[1] + vecXYZ.y * transf[5] + vecXYZ.z * transf[9] + transf[13],
                    y = vecXYZ.x * transf[2] + vecXYZ.y * transf[6] + vecXYZ.z * transf[10] + transf[14],
                    z = vecXYZ.x * transf[3] + vecXYZ.y * transf[7] + vecXYZ.z * transf[11] + transf[15]
                ]]
                local unknownTransf = {}
                unknownTransf[4] = 0
                unknownTransf[8] = 0
                unknownTransf[12] = 0
                unknownTransf[16] = 1
                unknownTransf[13] = xMid
                unknownTransf[14] = yMid
                unknownTransf[15] = zMid
                -- solving for vecX0
                -- local xyz = {x0, y0, z0}
                unknownTransf[1] = (x0 - xMid) / (-constants.outerEdgeX)
                unknownTransf[2] = (y0 - yMid) / (-constants.outerEdgeX)
                unknownTransf[3] = (z0 - zMid) / (-constants.outerEdgeX)
                -- solving for vecX1 (same result)
                -- unknownTransf[1] = (x1 - xMid) / constants.outerEdgeX
                -- unknownTransf[2] = (y1 - yMid) / constants.outerEdgeX
                -- unknownTransf[3] = (z1 - zMid) / constants.outerEdgeX
                -- solving for vecY0
                -- local xyz = {xMid - sinYX, yMid + cosYX, zMid}
                -- unknownTransf[5] = (y1 > y0) and (-math.abs(sinYX)) or (math.abs(sinYX))
                -- unknownTransf[6] = (x1 > x0) and (math.abs(cosYX)) or (-math.abs(cosYX))
                unknownTransf[5] = -sinYX
                unknownTransf[6] = cosYX
                unknownTransf[7] = 0
                -- solving for vecZ0 vertical
                -- this makes buildings vertical, the points match
                unknownTransf[9] = 0
                unknownTransf[10] = 0
                unknownTransf[11] = 1
                logger.print('unknownTransf straight =') logger.debugPrint(unknownTransf)
                -- solving for vecZ0 tilted
                -- this makes buildings perpendicular to the road, the points match. Curves seem to get less angry.
                -- LOLLO TODO decide on this or its twin above
                unknownTransf[9] = -sinZX
                unknownTransf[10] = 0
                unknownTransf[11] = cosZX
                logger.print('unknownTransf tilted =') logger.debugPrint(unknownTransf)

                local conTransf = unknownTransf
                logger.print('conTransf =') logger.debugPrint(conTransf)
                local vecX0Transformed = transfUtils.getVecTransformed(transfUtils.oneTwoThree2XYZ(vecX0), conTransf)
                local vecX1Transformed = transfUtils.getVecTransformed(transfUtils.oneTwoThree2XYZ(vecX1), conTransf)
                local vecYTransformed = transfUtils.getVecTransformed(transfUtils.oneTwoThree2XYZ(vecY0), conTransf)
                local vecZ0Transformed = transfUtils.getVecTransformed(transfUtils.oneTwoThree2XYZ(vecZ0), conTransf)
                if logger.getIsExtendedLog() then
                    print('vecX0 straight and transformed =') debugPrint(vecX0) debugPrint(vecX0Transformed)
                    print('should be') debugPrint({x0, y0, z0})
                    print('vecX1 straight and transformed =') debugPrint(vecX1) debugPrint(vecX1Transformed)
                    print('should be') debugPrint({x1, y1, z1})
                    print('vecY0 straight and transformed =') debugPrint(vecY0) debugPrint(vecYTransformed)
                    print('should be') debugPrint({xMid - sinYX, yMid + cosYX, zMid})
                    print('vecZ0 straight and transformed =') debugPrint(vecZ0) debugPrint(vecZ0Transformed)
                    print('should be (vertical)') debugPrint({xMid, yMid, zMid + 1})
                    print('or, it should be (perpendicular)') debugPrint({xMid - sinZX, yMid, zMid + cosZX})
                    print('x0, x1 =', x0, x1)
                    print('y0, y1 =', y0, y1)
                    print('z0, z1 =', z0, z1)
                    print('xMid, yMid, zMid =', xMid, yMid, zMid)
                end
                return conTransf
            end
            local conTransf = getConTransf()

            local newCon = api.type.SimpleProposal.ConstructionEntity.new()
            newCon.fileName = 'station/street/lollo_bus_stop/stop_2.con'
            -- newCon.fileName = 'station/street/lollo_bus_stop/stop_3.con' -- LOLLO TODO try the new parametric construction so it sticks to curves
            local allStreetData = streetUtils.getGlobalStreetData()
            -- logger.print('allStreetData =') logger.debugPrint(allStreetData)
            local streetTypeFileName = api.res.streetTypeRep.getName(streetType)
            if type(streetTypeFileName) ~= 'string' then
                logger.warn('cannot find street type', streetType or 'NIL')
                return
            end
            local streetTypeIndexBase0 = arrayUtils.findIndex(allStreetData, 'fileName', streetTypeFileName) - 1 -- base 0
            if streetTypeIndexBase0 < 0 then
                logger.warn('cannot find street type index', streetType or 'NIL')
                return
            end
            local newParams = {
                lolloBusStop_testHuge = 12345678901234567890, -- it becomes 1.2345678901235e+19 at first, -2147483648 at the first upgrade
                lolloBusStop_testVeryLarge = 100000000.123455, -- it becomes 1.2345678901235e+19
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

                lolloBusStop_bothSides = 0,
                lolloBusStop_direction = 0,
                lolloBusStop_driveOnLeft = 0,
                lolloBusStop_model = 5, -- it's easier to see transf problems
                lolloBusStop_outerNode0Id = outerNode0Id, -- this stays across upgrades because it's an integer
                lolloBusStop_outerNode1Id = outerNode1Id, -- idem
                lolloBusStop_pitch = pitchHelpers.getDefaultPitchParamValue(),
                -- lolloBusStop_snapNodes = 3,
                lolloBusStop_snapNodes = 0,
                -- LOLLO TODO This needs upgradeConstruction anyway, and it fails in curves even with shorter con edges. Check it.
                -- The sharper the bends, the more the trouble - and some crashes appear.
                -- On a deeper analysis, the transf is not good for curves, and I doubt it can be adjusted
                lolloBusStop_streetType_ = streetTypeIndexBase0,
                lolloBusStop_tramTrack = 0,
                seed = math.abs(math.ceil(conTransf[13] * 1000)),
            }
            -- these work
            moduleHelpers.setIntParamsFromFloat(newParams, 'testVeryLargeInt1', 'testVeryLargeDec1', -15000.00000001, 'lolloBusStop_')
            moduleHelpers.setIntParamsFromFloat(newParams, 'testVeryLargeInt2', 'testVeryLargeDec2', -15000.000000001, 'lolloBusStop_')
            moduleHelpers.setIntParamsFromFloat(newParams, 'testVeryLargeInt3', 'testVeryLargeDec3', -15000.0000000001, 'lolloBusStop_')
            moduleHelpers.setIntParamsFromFloat(newParams, 'testVeryLargeInt4', 'testVeryLargeDec4', 15000.00000001, 'lolloBusStop_')
            moduleHelpers.setIntParamsFromFloat(newParams, 'testVeryLargeInt5', 'testVeryLargeDec5', 15000.000000001, 'lolloBusStop_')
            moduleHelpers.setIntParamsFromFloat(newParams, 'testVeryLargeInt6', 'testVeryLargeDec6', 15000.0000000001, 'lolloBusStop_')
            moduleHelpers.setIntParamsFromFloat(newParams, 'testVeryLargeInt7', 'testVeryLargeDec7', 1.5000e-5, 'lolloBusStop_')
            -- clone your own variable, it's safer than cloning newCon.params, which is userdata
            local conParamsBak = arrayUtils.cloneDeepOmittingFields(newParams)
            newCon.params = newParams
            -- logger.print('just made conParamsBak, it is') logger.debugPrint(conParamsBak)
            newCon.playerEntity = api.engine.util.getPlayer()
            newCon.transf = api.type.Mat4f.new(
                api.type.Vec4f.new(conTransf[1], conTransf[2], conTransf[3], conTransf[4]),
                api.type.Vec4f.new(conTransf[5], conTransf[6], conTransf[7], conTransf[8]),
                api.type.Vec4f.new(conTransf[9], conTransf[10], conTransf[11], conTransf[12]),
                api.type.Vec4f.new(conTransf[13], conTransf[14], conTransf[15], conTransf[16])
            )
            local proposal = api.type.SimpleProposal.new()
            proposal.constructionsToAdd[1] = newCon

            local context = api.type.Context:new()
            -- context.checkTerrainAlignment = true -- default is false
            -- context.cleanupStreetGraph = true -- default is false
            -- context.gatherBuildings = true -- default is false
            -- context.gatherFields = true -- default is true
            context.player = api.engine.util.getPlayer()
            local isProposalOK = _utils.getIsProposalOK(proposal, context)
            if not(isProposalOK) then
                logger.warn('buildConstruction made a dangerous proposal')
                -- LOLLO TODO at this point, the con was not built but the splits are already in place: fix the road
                return
            end
            api.cmd.sendCommand(
                -- LOLLO TODO let's try without force and see if the random crashes go away. Not a good idea
                -- coz it fails to build very often, because of collisions
                api.cmd.make.buildProposal(proposal, context, true), -- the 3rd param is "ignore errors"; wrong proposals will be discarded anyway
                function(result, success)
                    logger.print('buildConstruction callback, success =', success)
                    -- logger.debugPrint(result)
                    if success then
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
                                        conTransf = conTransf,
                                    }
                                ))
                            end,
                            logger.xpErrorHandler
                        )
                    else
                        logger.warn('buildConstruction callback failed')
                        logger.warn('buildConstruction proposal =') logger.warningDebugPrint(proposal)
                        logger.warn('buildConstruction result =') logger.warningDebugPrint(result)
                        -- LOLLO TODO at this point, the con was not built but the splits are already in place: fix the road
                    end
                end
            )
        end,
        buildSnappyConstruction = function(oldConId, conParams, conTransf)
            logger.print('buildSnappyConstruction starting, oldConId =', oldConId or 'NIL')
            logger.print('conParams =') logger.debugPrint(conParams)
            logger.print('conTransf =') logger.debugPrint(conTransf)

            if not(edgeUtils.isValidAndExistingId(oldConId)) then
                logger.err('buildSnappyConstruction got an invalid conId =', oldConId or 'NIL')
                return
            end
            local oldCon = api.engine.getComponent(oldConId, api.type.ComponentType.CONSTRUCTION)
            if not(oldCon) then
                logger.err('buildSnappyConstruction got an invalid con =')
                return
            end

            local newCon = api.type.SimpleProposal.ConstructionEntity.new()
            newCon.fileName = oldCon.fileName
            local newParams = conParams
            newParams.lolloBusStop_snapNodes = 3
            newParams.seed = conParams.seed + 1
            -- clone your own variable, it's safer than cloning newCon.params, which is userdata
            local conParamsBak = arrayUtils.cloneDeepOmittingFields(newParams)
            logger.print('buildSnappyConstruction just made conParamsBak, it is') logger.debugPrint(conParamsBak)
            newCon.params = newParams
            newCon.playerEntity = api.engine.util.getPlayer()
            newCon.transf = api.type.Mat4f.new(
                api.type.Vec4f.new(conTransf[1], conTransf[2], conTransf[3], conTransf[4]),
                api.type.Vec4f.new(conTransf[5], conTransf[6], conTransf[7], conTransf[8]),
                api.type.Vec4f.new(conTransf[9], conTransf[10], conTransf[11], conTransf[12]),
                api.type.Vec4f.new(conTransf[13], conTransf[14], conTransf[15], conTransf[16])
            )
            local proposal = api.type.SimpleProposal.new()
            proposal.constructionsToAdd[1] = newCon
            proposal.constructionsToRemove = { oldConId }
            proposal.old2new = { {oldConId, 1} } -- LOLLO TODO check this

            local context = api.type.Context:new()
            -- context.checkTerrainAlignment = true -- default is false
            -- context.cleanupStreetGraph = true -- default is false
            -- context.gatherBuildings = true -- default is false
            -- context.gatherFields = true -- default is true
            context.player = api.engine.util.getPlayer()
            local isProposalOK = _utils.getIsProposalOK(proposal, context)
            if not(isProposalOK) then
                logger.warn('buildSnappyConstruction made a dangerous proposal')
                return
            end
            api.cmd.sendCommand(
                -- LOLLO TODO let's try without force and see if the random crashes go away, yes they do, some of them.
                -- Only checking for collisions won't do, we may have to use a parametric con since the transf cannot be perfect in curves
                api.cmd.make.buildProposal(proposal, context, false), -- the 3rd param is "ignore errors"; wrong proposals will be discarded anyway
                function(result, success)
                    logger.print('buildSnappyConstruction callback, success =', success) -- logger.debugPrint(result)
                    if success then
                        local newConId = result.resultEntities[1]
                        logger.print('buildSnappyConstruction succeeded, stationConId = ', newConId)
                        xpcall(
                            function ()
                                api.cmd.sendCommand(api.cmd.make.sendScriptEvent(
                                    string.sub(debug.getinfo(1, 'S').source, 1),
                                    _eventId,
                                    _eventProperties.snappyConBuilt.eventName,
                                    {
                                        conId = newConId,
                                        conParams = conParamsBak,
                                    }
                                ))
                            end,
                            logger.xpErrorHandler
                        )
                    else
                        logger.warn('buildSnappyConstruction callback failed')
                        logger.warn('buildSnappyConstruction proposal =') logger.warningDebugPrint(proposal)
                        logger.warn('buildSnappyConstruction result =') logger.warningDebugPrint(result)
                    end
                end
            )
        end,
        bulldozeConstruction = function(constructionId)
            -- print('constructionId =', constructionId)
            if type(constructionId) ~= 'number' or constructionId < 0 then
                logger.warn('bulldozeConstruction got an invalid conId')
                return
            end
    
            local oldConstruction = api.engine.getComponent(constructionId, api.type.ComponentType.CONSTRUCTION)
            if not(oldConstruction) or not(oldConstruction.params) then
                logger.warn('bulldozeConstruction got no con or a broken con')
                logger.warn('oldConstruction =') logger.warningDebugPrint(oldConstruction)
                return
            end
    
            local proposal = api.type.SimpleProposal.new()
            -- LOLLO NOTE there are asymmetries how different tables are handled.
            -- This one requires this system, UG says they will document it or amend it.
            proposal.constructionsToRemove = { constructionId }
            -- proposal.constructionsToRemove[1] = constructionId -- fails to add
            -- proposal.constructionsToRemove:add(constructionId) -- fails to add
    
            api.cmd.sendCommand(
                api.cmd.make.buildProposal(proposal, nil, true), -- the 3rd param is "ignore errors"; wrong proposals will be discarded anyway
                function(result, success)
                    if not(success) then
                        logger.warn('bulldozeConstruction callback: failed to build')
                        logger.warn('bulldozeConstruction proposal =') logger.warningDebugPrint(proposal)
                        logger.warn('bulldozeConstruction result =') logger.warningDebugPrint(result)
                    else
                        logger.print('bulldozeConstruction callback succeeded')
                    end
                end
            )
        end,
        removeEdge = function(oldEdgeId, successEventName, successEventArgs)
            logger.print('removeEdge starting')
            -- removes an edge even if it has a street type, which has changed or disappeared
            if not(edgeUtils.isValidAndExistingId(oldEdgeId)) then return end

            local proposal = api.type.SimpleProposal.new()
            local oldBaseEdge = api.engine.getComponent(oldEdgeId, api.type.ComponentType.BASE_EDGE)
            logger.print('oldBaseEdge =') logger.debugPrint(oldBaseEdge)
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
                for edgeObj = 1, #oldBaseEdge.objects do
                    proposal.streetProposal.edgeObjectsToRemove[#proposal.streetProposal.edgeObjectsToRemove+1] = oldBaseEdge.objects[edgeObj][1]
                end
            end

            api.cmd.sendCommand(
                api.cmd.make.buildProposal(proposal, nil, true),
                function(result, success)
                    if not(success) then
                        logger.warn('removeEdge failed, proposal = ') logger.warningDebugPrint(proposal)
                        logger.warn('removeEdge failed, result = ') logger.warningDebugPrint(result)
                    else
                        logger.print('removeEdge succeeded, result =') --logger.debugPrint(result)
                        if not(successEventName) then return end

                        xpcall(
                            function ()
                                api.cmd.sendCommand(api.cmd.make.sendScriptEvent(
                                    string.sub(debug.getinfo(1, 'S').source, 1),
                                    _eventId,
                                    successEventName,
                                    successEventArgs
                                ))
                            end,
                            logger.xpErrorHandler
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
                    if not(success) then
                        logger.warn('replaceEdgeWithSame failed, proposal = ') logger.warningDebugPrint(proposal)
                        logger.warn('replaceEdgeWithSame failed, result = ') logger.warningDebugPrint(result)
                    else
                        logger.print('replaceEdgeWithSame succeeded, result =') --logger.debugPrint(result)
                        if not(successEventName) then return end

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
                            logger.xpErrorHandler
                        )
                    end
                end
            )
        end,
        splitEdge = function(wholeEdgeId, nodeBetween, successEventName, successEventArgs)
            logger.print('splitEdge starting')
            if not(edgeUtils.isValidAndExistingId(wholeEdgeId)) or type(nodeBetween) ~= 'table' then return end
    
            local oldBaseEdge = api.engine.getComponent(wholeEdgeId, api.type.ComponentType.BASE_EDGE)
            local oldBaseEdgeStreet = api.engine.getComponent(wholeEdgeId, api.type.ComponentType.BASE_EDGE_STREET)
            -- save a crash when a modded road underwent a breaking change, so it has no oldEdgeStreet
            if oldBaseEdge == nil or oldBaseEdgeStreet == nil then return end
    
            local node0 = api.engine.getComponent(oldBaseEdge.node0, api.type.ComponentType.BASE_NODE)
            local node1 = api.engine.getComponent(oldBaseEdge.node1, api.type.ComponentType.BASE_NODE)
            if node0 == nil or node1 == nil then return end
    
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
            newEdge0.playerOwned = api.engine.getComponent(wholeEdgeId, api.type.ComponentType.PLAYER_OWNED)
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
            newEdge1.playerOwned = api.engine.getComponent(wholeEdgeId, api.type.ComponentType.PLAYER_OWNED)
            newEdge1.streetEdge = oldBaseEdgeStreet
    
            if type(oldBaseEdge.objects) == 'table' then
                -- local edge0StationGroups = {}
                -- local edge1StationGroups = {}
                local edge0Objects = {}
                local edge1Objects = {}
                for _, edgeObj in pairs(oldBaseEdge.objects) do
                    local edgeObjPosition = edgeUtils.getObjectPosition(edgeObj[1])
                    -- logger.print('edge object position =') logger.debugPrint(edgeObjPosition)
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
                    else
                        logger.print('splitEdge succeeded, result =') -- logger.debugPrint(result)
                        if not(successEventName) then return end

                        xpcall(
                            function ()
                                local newlyBuiltNodeId = _utils.getNewlyBuiltNodeId(result)
                                if edgeUtils.isValidAndExistingId(newlyBuiltNodeId) then
                                    if not(successEventArgs.outerNode0Id) then
                                        successEventArgs.outerNode0Id = newlyBuiltNodeId
                                        successEventArgs.outerNode0EdgeIds = edgeUtils.getConnectedEdgeIds({newlyBuiltNodeId})
                                    elseif not(successEventArgs.outerNode1Id) then
                                        successEventArgs.outerNode1Id = newlyBuiltNodeId
                                        successEventArgs.outerNode1EdgeIds = edgeUtils.getConnectedEdgeIds({newlyBuiltNodeId})
                                    elseif not(successEventArgs.innerNode0Id) then
                                        successEventArgs.innerNode0Id = newlyBuiltNodeId
                                        successEventArgs.innerNode0EdgeIds = edgeUtils.getConnectedEdgeIds({newlyBuiltNodeId})
                                    elseif not(successEventArgs.innerNode1Id) then
                                        successEventArgs.innerNode1Id = newlyBuiltNodeId
                                        successEventArgs.innerNode1EdgeIds = edgeUtils.getConnectedEdgeIds({newlyBuiltNodeId})
                                    end
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
                            -- LOLLO TODO check for crashes with and without this
                            local edgeObjectTransf_yz0 = transfUtils.getTransfZShiftedBy(edgeObjectTransf_y0, -streetTypeProps.sidewalkHeight)
                            logger.print('edgeObjectTransf =') logger.debugPrint(edgeObjectTransf)
                            logger.print('edgeObjectTransf_y0 =') logger.debugPrint(edgeObjectTransf_y0)
                            logger.print('edgeObjectTransf_yz0 =') logger.debugPrint(edgeObjectTransf_yz0)
                            _actions.replaceEdgeWithSame(
                                edgeId,
                                edgeObjectId,
                                _eventProperties.ploppableStreetsidePassengerStationBuilt.eventName,
                                {
                                    edgeObjectTransf = edgeObjectTransf_yz0,
                                    streetType = baseEdgeStreet.streetType,
                                }
                            )
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
                    -- LOLLO if everything else works, add a function to rebuild the road after deleting.
                    -- The params with the node ids are in place.
                    if name == _eventProperties.ploppableStreetsidePassengerStationBuilt.eventName then
                        if not(edgeUtils.isValidAndExistingId(args.edgeId)) or edgeUtils.isEdgeFrozen(args.edgeId) then
                            logger.warn('edge invalid or frozen')
                            return
                        end

                        local length = edgeUtils.getEdgeLength(args.edgeId)
                        if length < constants.outerEdgeX * 2 then
                            -- LOLLO TODO if everything else works, join adjacent edges until one is long enough
                            logger.warn('edge too short')
                            return
                        end

                        local outerTransf0 = transfUtils.getTransfXShiftedBy(args.edgeObjectTransf, constants.outerEdgeX)
                        local outerTransf1 = transfUtils.getTransfXShiftedBy(args.edgeObjectTransf, -constants.outerEdgeX)
                        local innerTransf0 = transfUtils.getTransfXShiftedBy(args.edgeObjectTransf, constants.innerEdgeX)
                        local innerTransf1 = transfUtils.getTransfXShiftedBy(args.edgeObjectTransf, -constants.innerEdgeX)
                        -- these are identical to the ones above, except they only have the position
                        local outerPos0 = transfUtils.getVec123Transformed({constants.outerEdgeX, 0, 0}, args.edgeObjectTransf)
                        local outerPos1 = transfUtils.getVec123Transformed({-constants.outerEdgeX, 0, 0}, args.edgeObjectTransf)
                        local innerPos0 = transfUtils.getVec123Transformed({constants.innerEdgeX, 0, 0}, args.edgeObjectTransf)
                        local innerPos1 = transfUtils.getVec123Transformed({-constants.innerEdgeX, 0, 0}, args.edgeObjectTransf)
                        logger.print('outerTransf0 =') logger.debugPrint(outerTransf0)
                        logger.print('outerTransf1 =') logger.debugPrint(outerTransf1)
                        logger.print('outerPos0 =') logger.debugPrint(outerPos0)
                        logger.print('outerPos1 =') logger.debugPrint(outerPos1)
                        logger.print('innerTransf0 =') logger.debugPrint(innerTransf0)
                        logger.print('innerTransf1 =') logger.debugPrint(innerTransf1)
                        logger.print('innerPos0 =') logger.debugPrint(innerPos0)
                        logger.print('innerPos1 =') logger.debugPrint(innerPos1)

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
                                innerTransf0 = innerTransf0,
                                innerTransf1 = innerTransf1,
                                outerTransf0 = outerTransf0,
                                outerTransf1 = outerTransf1,
                                transfMid = args.edgeObjectTransf,
                            }
                        )
                    elseif name == _eventProperties.firstOuterSplitDone.eventName then
                        -- find out which edge needs splitting
                        logger.print('args.outerNode0EdgeIds') logger.debugPrint(args.outerNode0EdgeIds)
                        if #args.outerNode0EdgeIds == 0 then
                            logger.warn('cannot find an edge for the second split')
                            return
                        end
                        local edgeIdToBeSplit, nodeBetween = _utils.getSplit1Data(
                            args.outerTransf1,
                            args.outerNode0EdgeIds
                        )
                        if not(edgeIdToBeSplit) then
                            logger.warn('cannot decide on an edge id for the second split')
                            return
                        end
                        if not(nodeBetween) then
                            logger.warn('cannot find out nodeBetween')
                            return
                        end

                        logger.print('final second outer nodeBetween =') logger.debugPrint(nodeBetween)
                        _actions.splitEdge(edgeIdToBeSplit, nodeBetween, _eventProperties.secondOuterSplitDone.eventName, args)
                    elseif name == _eventProperties.secondOuterSplitDone.eventName then
                        local edgeIdsBetweenNodes = _utils.getEdgeIdsLinkingNodes(args.outerNode0Id, args.outerNode1Id)
                        if #edgeIdsBetweenNodes ~= 1 then
                            logger.warn('no edges or too many edges found between outerNode0Id and outerNode1Id')
                            return
                        end

                        _actions.removeEdge(edgeIdsBetweenNodes[1], _eventProperties.segmentRemoved.eventName, args)
                    elseif name == _eventProperties.segmentRemoved.eventName then
                        _actions.buildConstruction(args.outerNode0Id, args.outerNode1Id, args.streetType)
                    elseif name == _eventProperties.conBuilt.eventName then
                        -- _actions.buildSnappyConstruction(args.conId, args.conParams, args.conTransf)
                        -- _utils.upgradeCon(args.conId, args.conParams)
                    elseif name == _eventProperties.snappyConBuilt.eventName then
                        -- _utils.upgradeCon(args.conId, args.conParams)
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
