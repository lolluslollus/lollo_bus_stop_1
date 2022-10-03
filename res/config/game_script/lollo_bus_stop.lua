local arrayUtils = require('lollo_bus_stop.arrayUtils')
local constants = require('lollo_bus_stop.constants')
local edgeUtils = require('lollo_bus_stop.edgeUtils')
local logger = require('lollo_bus_stop.logger')
local streetUtils = require('lollo_bus_stop.streetUtils')
local transfUtils = require('lollo_bus_stop.transfUtils')
local transfUtilsUG = require('transf')


local _eventId = '__lolloStreetsidePassengerStopsEvent__'
local _eventProperties = {
    buildConRequested = { conName = nil, eventName = 'buildConRequested' },
    ploppableStreetsidePassengerStationBuilt = { conName = nil, eventName = 'ploppableStreetsidePassengerStationBuilt' },
    removeEdgeBetween = { conName = nil, eventName = 'removeEdgeBetween' },
    secondSplitRequested = { conName = nil, eventName = 'secondSplitRequested'},
}

local _guiConstants = {
    _ploppablePassengersModelId = false,
}


function data()
    local _utils = {
        buildSnappyRoads = function(oldNode0Id, oldNode1Id, conId, fileName, paramsBak)
            -- LOLLO TODO the construction does not connect to the network, fix it
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
            -- context.cleanupStreetGraph = true
            -- context.gatherBuildings = true -- default is false
            -- context.gatherFields = true -- default is true
            context.player = api.engine.util.getPlayer()
            -- if true then return end -- LOLLO TODO remove after testing
            api.cmd.sendCommand(
                api.cmd.make.buildProposal(proposal, context, true), -- the 3rd param is "ignore errors"; wrong proposals will be discarded anyway
                function(result, success)
                    logger.print('buildSnappyRoads callback, success =', success)
                    -- logger.debugPrint(result)
                    if not(success) then
                        logger.warn('result =') logger.warningDebugPrint(result)
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
                                    logger.print('stationConId =') logger.debugPrint(conId)
                                    logger.print('result.resultEntities[1] =') logger.debugPrint(result.resultEntities[1])
                                    local upgradedConId = game.interface.upgradeConstruction(
                                        conId,
                                        fileName,
                                        paramsBak
                                    )
                                    logger.print('upgradeConstruction succeeded') logger.debugPrint(upgradedConId)
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
        buildConstruction = function(node0Id, node1Id, transf0, transf1, transfMid, streetType)
            -- LOLLO TODO the construction does not connect to the network, fix it
            logger.print('buildConstruction starting, streetType =') logger.debugPrint(streetType)
            logger.print('transfMid =') logger.debugPrint(transfMid)
            -- local conTransf = { }
            -- for i = 1, 16, 1 do
            --     conTransf[i] = (transf0[i] + transf1[i]) / 2
            -- end
            
            local conTransf = transfMid
            local baseNode0 = api.engine.getComponent(node0Id, api.type.ComponentType.BASE_NODE)
            local baseNode1 = api.engine.getComponent(node1Id, api.type.ComponentType.BASE_NODE)
            if baseNode0 == nil or baseNode1 == nil then
                logger.warn('cannot find node0Id or node1Id')
                return
            end
            -- LOLLO TODO find out why we need this bodge, it's probably the same thing that make the splitter change z
            local zMid = (baseNode0.position.z + baseNode1.position.z) / 2
            local zShift = zMid - transfMid[15]
            conTransf = transfUtils.getTransfZShiftedBy(conTransf, zShift)
            conTransf = transfUtilsUG.mul(conTransf, {-1, 0, 0, 0,  0, -1, 0, 0,  0, 0, 1, 0,  0, 0, 0, 1})

            local newCon = api.type.SimpleProposal.ConstructionEntity.new()
            newCon.fileName = 'station/street/lollo_bus_stop/stop_2.con'
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
            newCon.params = {
                lolloBusStop_streetType_ = streetTypeIndexBase0,
                seed = math.abs(math.ceil(conTransf[13] * 1000)),
            }
            local paramsBak = arrayUtils.cloneDeepOmittingFields(newCon.params, {'seed'})
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
            api.cmd.sendCommand(
                api.cmd.make.buildProposal(proposal, context, true), -- the 3rd param is "ignore errors"; wrong proposals will be discarded anyway
                function(result, success)
                    logger.print('buildConstruction callback, success =', success)
                    -- logger.debugPrint(result)
                    if success then
                        local stationConId = result.resultEntities[1]
                        logger.print('buildConstruction succeeded, stationConId = ', stationConId)
                        _utils.buildSnappyRoads(node0Id, node1Id, stationConId, newCon.fileName, paramsBak)
                    else
                        logger.warn('result =') logger.warningDebugPrint(result)
                    end
                end
            )
        end,

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
                        logger.warn('removeEdge failed, proposal = ') debugPrint(proposal)
                    else
                        logger.print('removeEdge succeeded, result =') --debugPrint(result)
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
            -- context.checkTerrainAlignment = true -- default is false, true gives smoother Z
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
                        logger.warn('splitEdge failed, proposal = ') debugPrint(proposal)
                    else
                        logger.print('replaceEdgeWithSame succeeded, result =') --debugPrint(result)
                        if not(successEventName) then return end

                        xpcall(
                            function ()
                                local newlyBuiltNodeId = _utils.getNewlyBuiltNodeId(result)
                                if edgeUtils.isValidAndExistingId(newlyBuiltNodeId) then
                                    if not(successEventArgs.node0Id) then
                                        successEventArgs.node0Id = newlyBuiltNodeId
                                        successEventArgs.node0EdgeIds = edgeUtils.getConnectedEdgeIds({newlyBuiltNodeId})
                                    else
                                        successEventArgs.node1Id = newlyBuiltNodeId
                                        successEventArgs.node1EdgeIds = edgeUtils.getConnectedEdgeIds({newlyBuiltNodeId})
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

                        local nodeBetween = edgeUtils.getNodeBetweenByPosition(
                            args.edgeId,
                            {
                                x = transf0[13],
                                y = transf0[14],
                                z = transf0[15],
                            }
                        )
                        logger.print('first nodeBetween =') logger.debugPrint(nodeBetween)
                        _actions.splitEdge(
                            args.edgeId,
                            nodeBetween,
                            _eventProperties.secondSplitRequested.eventName,
                            {
                                streetType = args.streetType,
                                transf0 = transf0,
                                transf1 = transf1,
                                transfMid = args.edgeObjectTransf,
                            }
                        )
                    elseif name == _eventProperties.secondSplitRequested.eventName then
                        -- find out which edge needs splitting
                        logger.print('args.node0EdgeIds') logger.debugPrint(args.node0EdgeIds)
                        if #args.node0EdgeIds == 0 then
                            logger.warn('cannot find an edge for the second split')
                            return
                        end
                        local edgeId2BeSplit = nil
                        local nodeBetween = nil
                        logger.print('args.transf1[13] =', args.transf1[13])
                        logger.print('args.transf1[14] =', args.transf1[14])
                        logger.print('args.transf1[15] =', args.transf1[15])
                        for _, edgeId in pairs(args.node0EdgeIds) do
                            local minDistance = 9999.9
                            local baseEdge = api.engine.getComponent(edgeId, api.type.ComponentType.BASE_EDGE)
                            if baseEdge ~= nil then
                                local baseNode0 = api.engine.getComponent(baseEdge.node0, api.type.ComponentType.BASE_NODE)
                                local baseNode1 = api.engine.getComponent(baseEdge.node1, api.type.ComponentType.BASE_NODE)
                                logger.print('baseNode0 =') logger.debugPrint(baseNode0)
                                logger.print('baseNode1 =') logger.debugPrint(baseNode1)
                                if baseNode0 ~= nil and baseNode1 ~= nil then
                                    local testNodeBetween = edgeUtils.getNodeBetweenByPosition(
                                        edgeId,
                                        {
                                            x = args.transf1[13],
                                            y = args.transf1[14],
                                            z = args.transf1[15],
                                        }
                                        -- logger.getIsExtendedLog()
                                    )
                                    logger.print('testNodeBetween =') logger.debugPrint(testNodeBetween)
                                    if testNodeBetween ~= nil then
                                        local currentDistance = transfUtils.getPositionsDistance(testNodeBetween.position, transfUtils.transf2Position(args.transf1))
                                        logger.print('currentDistance =') logger.debugPrint(currentDistance)
                                        if currentDistance ~= nil and currentDistance < minDistance then
                                            edgeId2BeSplit = edgeId
                                            minDistance = currentDistance
                                            nodeBetween = testNodeBetween
                                        end
                                    end
                                end
                            end
                        end
                        if not(edgeId2BeSplit) then
                            logger.warn('cannot decide on an edge id for the second split')
                            return
                        end
                        if not(nodeBetween) then
                            logger.warn('cannot find out nodeBetween')
                            return
                        end

                        logger.print('final nodeBetween =') logger.debugPrint(nodeBetween)
                        _actions.splitEdge(edgeId2BeSplit, nodeBetween, _eventProperties.removeEdgeBetween.eventName, args)
                    elseif name == _eventProperties.removeEdgeBetween.eventName then
                        if not(edgeUtils.isValidAndExistingId(args.node0Id)) or not(edgeUtils.isValidAndExistingId(args.node1Id)) then
                            logger.warn('node0Id or node1Id is invalid')
                            return
                        end

                        local _map = api.engine.system.streetSystem.getNode2SegmentMap()
                        local connectedEdgeIdsUserdata0 = _map[args.node0Id] -- userdata
                        local connectedEdgeIdsUserdata1 = _map[args.node1Id] -- userdata
                        if connectedEdgeIdsUserdata0 == nil or connectedEdgeIdsUserdata1 == nil then
                            logger.warn('the edges between node0Id and node1Id are not connected to their nodes, this should never happen')
                            return
                        end
                        local edgeIdsBetweenNodes = {}
                        for _, edge0Id in pairs(connectedEdgeIdsUserdata0) do
                            for _, edge1Id in pairs(connectedEdgeIdsUserdata1) do
                                if edge0Id == edge1Id then
                                    arrayUtils.addUnique(edgeIdsBetweenNodes, edge0Id)
                                end
                            end
                        end
                        if #edgeIdsBetweenNodes ~= 1 then
                            logger.warn('no edges or too many edges found between node0Id and node1Id')
                            return
                        end

                        _actions.removeEdge(edgeIdsBetweenNodes[1], _eventProperties.buildConRequested.eventName, args)
                    elseif name == _eventProperties.buildConRequested.eventName then
                        -- LOLLO TODO build the construction between args.transf0 and args.transf1
                        -- the first thing to test is how to pass the parameters. First even, try to plop it as it is

                        _actions.buildConstruction(args.node0Id, args.node1Id, args.transf0, args.transf1, args.transfMid, args.streetType)
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
