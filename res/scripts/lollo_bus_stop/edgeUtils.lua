local arrayUtils = require('lollo_bus_stop.arrayUtils')
local comparisonUtils = require('lollo_bus_stop.comparisonUtils')
local quadrangleUtils = require('lollo_bus_stop.quadrangleUtils')
local transfUtils = require('lollo_bus_stop.transfUtils')
local transfUtilsUG = require('transf')


local helper = {}

helper.isValidId = function(id)
    return type(id) == 'number' and id >= 0
end

helper.isValidAndExistingId = function(id)
    return helper.isValidId(id) and api.engine.entityExists(id)
end

-- do not use this, it calls the old game.interface, which can freeze the game
-- helper.getNearbyEntitiesOLD = function(transf)
--     if type(transf) ~= 'table' then return {} end

--     -- debugger()
--     local edgeSearchRadius = 0.0
--     local squareCentrePosition = transfUtils.getVec123Transformed({0, 0, 0}, transf)
--     local results = game.interface.getEntities(
--         {pos = squareCentrePosition, radius = edgeSearchRadius},
--         {includeData = true}
--         -- {includeData = true}
--     )

--     return results
-- end

-- useless coz the refs to any1 and any2 are passed by val
-- and lua has a smarter way to do that
-- helper.swap = function(any1, any2)
--     -- local swapTemp = any1
--     -- any1 = any2
--     -- any2 = swapTemp
--     any2, any1 = any1, any2
-- end

helper.getPositionTableFromUserdata = function(pos)
    return {x = pos.x, y = pos.y, z = pos.z}
end

helper.getNearbyObjectIds = function(transf, searchRadius, componentType, minZ, maxZ)
    if type(transf) ~= 'table' then return {} end

    if not(componentType) then componentType = api.type.ComponentType.BASE_EDGE end

    local _position = transfUtils.getVec123Transformed({0, 0, 0}, transf)
    local _searchRadius = searchRadius or 0.5
    local _box0 = api.type.Box3.new(
        api.type.Vec3f.new(_position[1] - _searchRadius, _position[2] - _searchRadius, minZ or -9999),
        api.type.Vec3f.new(_position[1] + _searchRadius, _position[2] + _searchRadius, maxZ or 9999)
    )
    local results = {}
    local callbackDefault = function(entity, boundingVolume)
        -- print('callback0 found entity', entity)
        -- print('boundingVolume =') debugPrint(boundingVolume)
        if not(entity) then return end

        if not(api.engine.getComponent(entity, componentType)) then return end
        -- print('the entity has the right component type')

        results[#results+1] = entity
    end
    -- LOLLO NOTE nodes may have a bounding box: for them, we check the position only
    local callback4Nodes = function(entity, boundingVolume)
        -- print('callback0 found entity', entity)
        -- print('boundingVolume =') debugPrint(boundingVolume)
        if not(entity) then return {} end

        local node = api.engine.getComponent(entity, api.type.ComponentType.BASE_NODE)
        if node == nil then return {} end
        -- print('the entity has the right component type')

        if math.abs(node.position.x - _position[1]) > _searchRadius then return end
        if math.abs(node.position.y - _position[2]) > _searchRadius then return end
        if math.abs(node.position.z - _position[3]) > _searchRadius then return end

        results[#results+1] = entity
    end
    local callbackInUse = componentType == api.type.ComponentType.BASE_NODE and callback4Nodes or callbackDefault
    api.engine.system.octreeSystem.findIntersectingEntities(_box0, callbackInUse)

    return results
end

helper.getNearbyObjects = function(transf, searchRadius, componentType, minZ, maxZ)
    if type(transf) ~= 'table' then return {} end

    if not(componentType) then componentType = api.type.ComponentType.BASE_EDGE end

    local _position = transfUtils.getVec123Transformed({0, 0, 0}, transf)
    local _searchRadius = searchRadius or 0.5
    local _box0 = api.type.Box3.new(
        api.type.Vec3f.new(_position[1] - _searchRadius, _position[2] - _searchRadius, minZ or -9999),
        api.type.Vec3f.new(_position[1] + _searchRadius, _position[2] + _searchRadius, maxZ or 9999)
    )
    local results = {}
    local callbackDefault = function(entityId, boundingVolume)
        -- print('callback0 found entity', entity)
        -- print('boundingVolume =') debugPrint(boundingVolume)
        if not(entityId) then return end

        local props = api.engine.getComponent(entityId, componentType)
        -- print('the entity has the right component type')
        results[entityId] = props
    end
    -- LOLLO NOTE nodes may have a bounding box: for them, we check the position only
    local callback4Nodes = function(entityId, boundingVolume)
        -- print('callback0 found entity', entity)
        -- print('boundingVolume =') debugPrint(boundingVolume)
        if not(entityId) then return end

        local props = api.engine.getComponent(entityId, api.type.ComponentType.BASE_NODE)
        if not(props) then
            results[entityId] = props
            return
        end
        -- print('the entity has the right component type')

        if math.abs(props.position.x - _position[1]) > _searchRadius then return end
        if math.abs(props.position.y - _position[2]) > _searchRadius then return end
        if math.abs(props.position.z - _position[3]) > _searchRadius then return end

        results[entityId] = props
    end
    local callbackInUse = (componentType == api.type.ComponentType.BASE_NODE) and callback4Nodes or callbackDefault
    api.engine.system.octreeSystem.findIntersectingEntities(_box0, callbackInUse)
    -- print('getNearbyObjects about to return') debugPrint(results)
    return results
end

helper.sign = function(num1)
    if type(num1) ~= 'number' then return nil end

    if num1 == 0 then return 0 end
    if num1 > 0 then return 1 end
    return -1
end

--#region getEdgeLength
--[[
helper.getEdgeLengthUG = function(edgeId, isExtendedLog)
    -- copied from UG mods/urbangames_campaign_mission_11_1/res/scripts/part1.lua
    -- this is slow and produces the same results as TRANSPORT_NETWORK,
    -- which are no good coz they are often too short.
    if not(helper.isValidAndExistingId(edgeId)) then
        print('ERROR: edgeUtils.getEdgeLength got an invalid edgeId =', edgeId or 'NIL')
        return nil
    end

    local baseEdge = api.engine.getComponent(edgeId, api.type.ComponentType.BASE_EDGE)
    if baseEdge == nil or baseEdge.node0 == nil or baseEdge.node1 == nil then
        print('ERROR: edgeUtils.getEdgeLength found no proper baseEdge, edgeId =', edgeId)
        return nil
    end

    local pos0 = api.engine.getComponent(baseEdge.node0, api.type.ComponentType.BASE_NODE).position
    local pos1 = api.engine.getComponent(baseEdge.node1, api.type.ComponentType.BASE_NODE).position
    local tan0 = baseEdge.tangent0
    local tan1 = baseEdge.tangent1

    local dot = transfUtils.getVectorsDot(tan0, tan1)
    local cosAlpha = dot / transfUtils.getVectorLength(tan0) / transfUtils.getVectorLength(tan1)
    cosAlpha = math.min(math.max(cosAlpha, -1), 1) --avoids numeric issues close to -1 and 1
    local alpha = math.acos(cosAlpha)
    local distance = transfUtils.getPositionsDistance(pos0, pos1)
    local len = streetutil.calcScale(distance, alpha)
    return len
end
]]
--[[
    LOLLO NOTE
    Dealing with a street, there is an edge each lane; tracks only have one lane.
    There can also be multiple edges if the street has a waypoint, a bus stop, or the likes.
    Street segments can only have one waypoint, or streetside stop, in each direction.
    Tracks can have many traffic lights in one segment instead.

    The player can snap together two road or rail segments ("edges") at awkward angles,
    or place a 2-lane road after a 4.lane one.
    The bit between the segment ends looks OK but it is no proper edge:
    it cannot be bulldozed and it has no edgeId;
    if it is a road, the stitches at its ends cannot be crossed by pedestrians.
    If you try to split one of those bits, you get a catchable error.
    The edges involved are coerced into a different geometry,
    which can twist the tangents at both ends and the positions at the snapped ends.
    In these cases, TRANSPORT_NETWORK returns a shorter length.

    In general TRANSPORT_NETWORK returns a better length with humps and certain other dirty setups,
    better than the baseEdge.tangent calc.
    However, it is worse with bends, which are more common.
    We test both for a while LOLLO TODO
    If there are no forceful snaps, the positions and tangents from TRANSPORT_NETWORK
    are consistent with baseEdge and we can simply take the bigger one.

    To be precise, this looks like a good estimator but I wouldn't bet the farm on it.
    The crux is, these tans are not always perfect (eg humps with tracks).
    The game algo to get the length, which delivers the same as the TRANSPORT_NETWORK, is not absolutely reliable. either.
    I'd still look for a better algo, based on the normalised tans;
    but we'd need to know more if we don't know the tans accurately,
    for example a third point. So for the moment there is no better way to solve this.
]]
local _getSplitId = function(entityA, entityB)
    return entityA .. '-' .. entityB
end

---@param edgeId integer
---@param baseEdge table
---@param tn table
---@param isExtendedLog? boolean
---@return number|nil "edge length"
---@return boolean "can use the result"
---@return boolean "the result is accurate"
local _getEdgeLength_Street = function(edgeId, baseEdge, tn, isExtendedLog)
    local node0Id, node1Id = baseEdge.node0, baseEdge.node1
    local tan0 = baseEdge.tangent0
    local tan1 = baseEdge.tangent1
    local resultWithBaseEdge = (transfUtils.getVectorLength_FAST(tan0) + transfUtils.getVectorLength_FAST(tan1)) * 0.5 -- they should be equal but they are not, so we average them

    local pos0 = helper.getPositionTableFromUserdata(api.engine.getComponent(node0Id, api.type.ComponentType.BASE_NODE).position)
    local pos1 = helper.getPositionTableFromUserdata(api.engine.getComponent(node1Id, api.type.ComponentType.BASE_NODE).position)
    -- group data by splits, sorted in the direction node0Id -> node1Id
    local dataBySplit = {}
    for i = 1, #tn.edges, 1 do
        local entity0 = tn.edges[i].conns[1].entity
        local entity1 = tn.edges[i].conns[2].entity
        local isReverse = entity0 ~= node0Id and entity1 ~= node1Id
        local currentSplitId = isReverse and _getSplitId(entity1, entity0) or _getSplitId(entity0, entity1)
        if not(dataBySplit[currentSplitId]) then
            dataBySplit[currentSplitId] = {count = 0, length = 0}
        end

        dataBySplit[currentSplitId].count = dataBySplit[currentSplitId].count + 1
        dataBySplit[currentSplitId].length = dataBySplit[currentSplitId].length + tn.edges[i].geometry.length
        if isReverse then
            dataBySplit[currentSplitId].entity0 = entity1
            dataBySplit[currentSplitId].entity1 = entity0
            dataBySplit[currentSplitId].pos0= tn.edges[i].geometry.params.pos[2]
            dataBySplit[currentSplitId].pos1 = tn.edges[i].geometry.params.pos[1]
        else
            dataBySplit[currentSplitId].entity0 = entity0
            dataBySplit[currentSplitId].entity1 = entity1
            dataBySplit[currentSplitId].pos0 = tn.edges[i].geometry.params.pos[1]
            dataBySplit[currentSplitId].pos1 = tn.edges[i].geometry.params.pos[2]
        end
    end
    -- if isExtendedLog then
    --     print('dataBySplit before join') debugPrint(dataBySplit)
    -- end
    -- join the splits
    -- print('node0Id, edgeId, node1Id, getSplit1, getSplit2', node0Id, edgeId, node1Id, _getSplitId(node0Id, edgeId), _getSplitId(edgeId, node1Id))
    if dataBySplit[_getSplitId(node0Id, edgeId)] ~= nil and dataBySplit[_getSplitId(edgeId, node1Id)] ~= nil then
        if dataBySplit[_getSplitId(node0Id, edgeId)].count ~= dataBySplit[_getSplitId(edgeId, node1Id)].count then
            print('ERROR: _getEdgeLength_Street found edge splits with different amounts of lanes, this should never happen')
            return nil, false, false
        end
        local newRecord = {
            count = dataBySplit[_getSplitId(node0Id, edgeId)].count,
            length = dataBySplit[_getSplitId(node0Id, edgeId)].length + dataBySplit[_getSplitId(edgeId, node1Id)].length,
            entity0 = node0Id,
            entity1 = node1Id,
            pos0 = dataBySplit[_getSplitId(node0Id, edgeId)].pos0,
            pos1 = dataBySplit[_getSplitId(edgeId, node1Id)].pos1,
        }

        if dataBySplit[_getSplitId(node0Id, node1Id)] == nil then
            dataBySplit[_getSplitId(node0Id, node1Id)] = newRecord
        else
            dataBySplit[_getSplitId(node0Id, node1Id)].length =
                (dataBySplit[_getSplitId(node0Id, node1Id)].length / dataBySplit[_getSplitId(node0Id, node1Id)].count
                + newRecord.length / newRecord.count) * 0.5
            dataBySplit[_getSplitId(node0Id, node1Id)].count = 1
        end
        dataBySplit[_getSplitId(node0Id, edgeId)] = nil
        dataBySplit[_getSplitId(edgeId, node1Id)] = nil
    end
    -- if isExtendedLog then
    --     print('dataBySplit after join') debugPrint(dataBySplit)
    -- end
    -- put it all together
    local dataTogether = {length = 0}
    for _, splitData in pairs(dataBySplit) do
        if splitData.count ~= 0 then
            dataTogether.length = dataTogether.length + splitData.length / splitData.count
        end
        if splitData.entity0 == node0Id then
            dataTogether.pos0 = splitData.pos0
        end
        if splitData.entity1 == node1Id then
            dataTogether.pos1 = splitData.pos1
        end
    end
    -- if isExtendedLog then
    --     print('dataTogether') debugPrint(dataTogether)
    -- end

    local resultWithTN = dataTogether.length

    if (not(comparisonUtils.isXYZsSame_onlyXY(pos0, dataTogether.pos0)) or not(comparisonUtils.isXYZsSame_onlyXY(pos1, dataTogether.pos1)))
    then
        if (not(comparisonUtils.isXYsVeryClose_FAST(pos0, dataTogether.pos0, 4)) or not(comparisonUtils.isXYsVeryClose_FAST(pos1, dataTogether.pos1, 4)))
        then
            if isExtendedLog then
                print('WARNING: edgeUtils.getEdgeLength found that tn and baseEdge mismatch, edgeId =', edgeId)
                print('pos0, pos1 =') debugPrint(pos0) debugPrint(pos1)
                print('data from TN after join') debugPrint(dataBySplit)
                print('data from TN, final =') debugPrint(dataTogether)
                print('resultWithBaseEdge =', resultWithBaseEdge, ', resultWithTN =', dataTogether.length)
            end
            return math.max(resultWithBaseEdge, resultWithTN), true, false
        else
            if isExtendedLog then
                print('edgeUtils.getEdgeLength found that tn and baseEdge slightly mismatch, edgeId =', edgeId)
            end
        end
    end

    if isExtendedLog and resultWithTN > resultWithBaseEdge then
        print('resultWithTN > resultWithBaseEdge, =', resultWithTN, resultWithBaseEdge, '; pos0, pos1, tan0, tan1 =')
        debugPrint(pos0) debugPrint(pos1) debugPrint(tan0) debugPrint(tan1)
    end

    return math.max(resultWithBaseEdge, resultWithTN), true, true
end

---@param edgeId integer
---@param baseEdge table
---@param tn table
---@param isExtendedLog? boolean
---@return number "edge length"
---@return boolean "can use the result"
---@return boolean "the result is accurate"
local _getEdgeLength_Track = function(edgeId, baseEdge, tn, isExtendedLog)
    local tan0 = baseEdge.tangent0
    local tan1 = baseEdge.tangent1
    local resultWithBaseEdge = (transfUtils.getVectorLength_FAST(tan0) + transfUtils.getVectorLength_FAST(tan1)) * 0.5 -- they should be equal but they are not, so we average them

    local pos0 = helper.getPositionTableFromUserdata(api.engine.getComponent(baseEdge.node0, api.type.ComponentType.BASE_NODE).position)
    local pos1 = helper.getPositionTableFromUserdata(api.engine.getComponent(baseEdge.node1, api.type.ComponentType.BASE_NODE).position)
    local geometry0 = tn.edges[1].geometry
    local geometry1 = tn.edges[#tn.edges].geometry

    local resultWithTN = 0
    local edgeCount = #tn.edges
    if edgeCount == 1 then
        resultWithTN = tn.edges[1].geometry.length
    else
        if isExtendedLog then
            print('edgeUtils.getEdgeLength found ' .. edgeCount .. ' edges in the TN, edgeId =', edgeId)
            if edgeCount > 3 then -- this happens if I put several traffic light on the same edge
                print('edgeUtils.getEdgeLength found a geometry with ' .. edgeCount .. ' consecutive edge groups, edgeId =', edgeId)
            end
        end
        local totalLengthsByEntity = {}
        for i = 1, edgeCount, 1 do
            local currentEntity12 = tn.edges[i].conns[1].entity .. '-' .. tn.edges[i].conns[1].index .. '-' .. tn.edges[i].conns[2].entity .. '-' .. tn.edges[i].conns[2].index

            if not(totalLengthsByEntity[currentEntity12]) then
                totalLengthsByEntity[currentEntity12] = {count = 0, length = 0}
            end
            totalLengthsByEntity[currentEntity12].count = totalLengthsByEntity[currentEntity12].count + 1
            totalLengthsByEntity[currentEntity12].length = totalLengthsByEntity[currentEntity12].length + tn.edges[i].geometry.length
        end
        for _, countAndLength in pairs(totalLengthsByEntity) do
            resultWithTN = resultWithTN + countAndLength.length / countAndLength.count
        end
    end

    if not(comparisonUtils.isXYZsSame_onlyXY(pos0, geometry0.params.pos[1])) or not(comparisonUtils.isXYZsSame_onlyXY(pos1, geometry1.params.pos[2]))
    then
        if not(comparisonUtils.isXYsVeryClose_FAST(pos0, geometry0.params.pos[1], 4)) or not(comparisonUtils.isXYsVeryClose_FAST(pos1, geometry1.params.pos[2], 4))
        then
            if isExtendedLog then
                print('WARNING: edgeUtils.getEdgeLength found that tn and baseEdge mismatch, edgeId =', edgeId)
                print('pos0, pos1 =') debugPrint(pos0) debugPrint(pos1)
                print('geometry0.params =') debugPrint(geometry0.params)
                print('geometry1.params =') debugPrint(geometry1.params)
                print('resultWithBaseEdge =', resultWithBaseEdge, ', resultWithTN =', resultWithTN, 'I chose the largest')
            end
            return math.max(resultWithBaseEdge, resultWithTN), true, false
        else
            if isExtendedLog then
                print('edgeUtils.getEdgeLength found that tn and baseEdge slightly mismatch, edgeId =', edgeId)
            end
        end
    end

    if isExtendedLog and resultWithTN > resultWithBaseEdge then
        print('resultWithTN > resultWithBaseEdge, =', resultWithTN, resultWithBaseEdge, '; pos0, pos1, tan0, tan1 =')
        debugPrint(pos0) debugPrint(pos1) debugPrint(tan0) debugPrint(tan1)
    end

    return math.max(resultWithBaseEdge, resultWithTN), true, true
end

---@param edgeId integer
---@param isExtendedLog? boolean
---@return number|nil "edge length"
---@return boolean "can use the result"
---@return boolean "the result is accurate"
helper.getEdgeLength = function(edgeId, isExtendedLog)
    if not(helper.isValidAndExistingId(edgeId)) then
        print('ERROR: edgeUtils.getEdgeLength got an invalid edgeId =', edgeId or 'NIL')
        return nil, false, false
    end

    local baseEdge = api.engine.getComponent(edgeId, api.type.ComponentType.BASE_EDGE)
    if baseEdge == nil or baseEdge.node0 == nil or baseEdge.node1 == nil then
        print('ERROR: edgeUtils.getEdgeLength found no proper baseEdge, edgeId =', edgeId)
        return nil, false, false
    end

    local tn = api.engine.getComponent(edgeId, api.type.ComponentType.TRANSPORT_NETWORK)
    if tn == nil or tn.edges == nil or tn.edges[1] == nil then
        print('ERROR: edgeUtils.getEdgeLength found no tn, edgeId =', edgeId)
        return nil, false, false
    end

    local baseEdgeStreet = api.engine.getComponent(edgeId, api.type.ComponentType.BASE_EDGE_STREET)
    if not(baseEdgeStreet) then return _getEdgeLength_Track(edgeId, baseEdge, tn, isExtendedLog) end
    return _getEdgeLength_Street(edgeId, baseEdge, tn, isExtendedLog)
end
--#endregion getEdgeLength

--#region getNodeBetween
local _getNodeBetween = function(pos0, pos1, tan0, tan1, shift0To1, length, isExtendedLog)
    if isExtendedLog then
        print('_getNodeBetween starting, shift0To1 =', shift0To1, 'length =', length)
        print('pos0, pos1 =') debugPrint(pos0) debugPrint(pos1)
        print('tan0, tan1 =') debugPrint(tan0) debugPrint(tan1)
    end

    tan0 = transfUtils.getVectorNormalised_FAST(tan0, length)
    if tan0 == nil then
        print('WARNING: edgeUtils._getNodeBetween failed to normalise tan0, returning')
        return nil
    end
    tan1 = transfUtils.getVectorNormalised_FAST(tan1, length)
    if tan1 == nil then
        print('WARNING: edgeUtils._getNodeBetween failed to normalise tan1, returning')
        return nil
    end
--[[
    -- Now I solve the system for x:
    -- a + b l0 + c l0^2 + d l0^3 = posX0
    -- a + b l1 + c l1^2 + d l1^3 = posX1
    -- b + 2 c l0 + 3 d l0^2 = tanX0 / length
    -- b + 2 c l1 + 3 d l1^2 = tanX1 / length
    local aX = pos0.x
    local bX = tan0.x / length
    -- I am left with:
    -- a + b l1 + c l1^2 + d l1^3 = posX1
    -- b + 2 c l1 + 3 d l1^2 = tanX1 / length
    -- =>
    -- c l1^2 + d l1^3 = posX1 - a - b l1
    -- 2 c l1 + 3 d l1^2 = tanX1 / length - b
    -- =>
    -- c length^2 + d length^3 = posX1 - posX0 - tanX0
    -- 2 c length + 3 d length^2 = (tanX1 - tanX0) / length
    -- =>
    -- 2 c length^2 + 2 d length^3 = 2 posX1 - 2 posX0 - 2 tanX0
    -- 2 c length^2 + 3 d length^3 = tanX1 - tanX0
    -- =>
    -- d length^3 = tanX1 - tanX0 - 2 posX1 + 2 posX0 + 2 tanX0
    -- =>
    -- d length^3 = tanX1 - 2 posX1 + 2 posX0 + tanX0
    -- =>
    -- d = (tanX1 - 2 posX1 + 2 posX0 + tanX0) / length^3
    local dX = (2 * pos0.x - 2 * pos1.x + tan0.x + tan1.x) / length / length / length
    -- I can still use
    -- c length^2 + d length^3 = posX1 - posX0 - tanX0
    -- =>
    -- c length^2 = posX1 - posX0 - tanX0 - d length^3
    -- =>
    -- c = posX1 / length^2 - posX0 / length^2 - tanX0 / length^2 - d length
    -- =>
    -- c = (posX1 - posX0 - tanX0 - tanX1 +2 * posX1 -2 * posX0 -tanX0) / length^2
    -->
    -- c = (-3*posX0 +3*posX1 -2*tanX0 -tanX1) / length^2
    local cX = (-3 * pos0.x + 3 * pos1.x -2 * tan0.x -tan1.x) / length / length

    local testX = aX + bX * length + cX * length * length + dX * length * length * length
    local testXAt0 = pos0.x -- immediately verified
    local testXAtLength = pos1.x -- immediately verified
]]

    local shift0To1_Pwr2 = shift0To1 *shift0To1
    local shift0To1_Pwr3 = shift0To1 *shift0To1 *shift0To1
    ---comment
    ---@param axis string
    ---@return number
    local getPosOnAxisAtShift = function(axis)
        return
        pos0[axis]
        +tan0[axis] *shift0To1
        +(-3*pos0[axis] +3*pos1[axis] -2*tan0[axis] -tan1[axis]) *shift0To1_Pwr2
        +(2*pos0[axis] -2*pos1[axis] +tan0[axis] +tan1[axis]) *shift0To1_Pwr3
    end

    ---comment
    ---@param axis string
    ---@return number
    local getTanOnAxisAtShift = function(axis)
        return
        tan0[axis] /length
        +2*(-3*pos0[axis] +3*pos1[axis] -2*tan0[axis] -tan1[axis]) /length *shift0To1
        +3*(2*pos0[axis] -2*pos1[axis] +tan0[axis] +tan1[axis]) /length *shift0To1_Pwr2
    end
--[[
    if shift0To1 == 0 then
        tanOnXAxis = tan0.x / length
    elseif shift0To1 == 1 then
        tanOnXAxis = tan0[axis] /length
        +2*(-3*pos0[axis] +3*pos1[axis] -2*tan0[axis] -tan1[axis]) /length
        +3*(2*pos0[axis] -2*pos1[axis] +tan0[axis] +tan1[axis]) /length
        => tanOnXAxis = (
            + pos0[axis] (-6 + 6)
            + pos1[axis] (6 - 6)
            + tan0[axis] (1 - 4 + 3)
            + tan1[axis] (-2 +3 )
        ) / length
        => tanOnAxis = tan1[axis] / length
    end
]]
--[[
    if not(comparisonUtils.isNumsVeryClose(testX, pos1.x, 3)) then
        if isExtendedLog then
            print('getNodeBetween WARNING: Xs are not close enough:', testX, pos1.x)
        end
        return nil
    end

    local aY = pos0.y
    local bY = tan0.y / length
    local dY = (2 * pos0.y - 2 * pos1.y + tan0.y + tan1.y) / length / length / length
    -- local dY = (tan1.y - 2 * pos1.y + 2 * aY + bY * length) / length / length / length
    local cY = (-3 * pos0.y + 3 * pos1.y -2 * tan0.y -tan1.y) / length / length
    -- local cY = (pos1.y - aY) / length / length - bY / length - dY * length

    local testY = aY + bY * length + cY * length * length + dY * length * length * length
    if not(comparisonUtils.isNumsVeryClose(testY, pos1.y, 3)) then
        if isExtendedLog then
            print('getNodeBetween WARNING: Ys are not close enough:', testY, pos1.y)
        end
        return nil
    end

    local aZ = pos0.z
    local bZ = tan0.z / length
    local dZ = (2 * pos0.z - 2 * pos1.z + tan0.z + tan1.z) / length / length / length
    -- local dZ = (tan1.z - 2 * pos1.z + 2 * aZ + bZ * length) / length / length / length
    local cZ = (-3 * pos0.z + 3 * pos1.z -2 * tan0.z -tan1.z) / length / length
    -- local cZ = (pos1.z - aZ) / length / length - bZ / length - dZ * length

    local testZ = aZ + bZ * length + cZ * length * length + dZ * length * length * length
    if not(comparisonUtils.isNumsVeryClose(testZ, pos1.z, 3)) then
        if isExtendedLog then
            print('getNodeBetween WARNING: Zs are not close enough:', testZ, pos1.z)
        end
        return nil
    end
]]
    -- I have obtained Hermite's coefficients in the end

    local result = {
        refDistance0 = length * shift0To1,
        refPosition0 = {
            x = pos0.x,
            y = pos0.y,
            z = pos0.z,
        },
        refTangent0 = {
            x = tan0.x,
            y = tan0.y,
            z = tan0.z,
        },
        refDistance1 = length * (1 - shift0To1),
        refPosition1 = {
            x = pos1.x,
            y = pos1.y,
            z = pos1.z,
        },
        refTangent1 = {
            x = tan1.x,
            y = tan1.y,
            z = tan1.z,
        },
        refLength = length,
        position = {
            x = getPosOnAxisAtShift('x'),
            y = getPosOnAxisAtShift('y'),
            z = getPosOnAxisAtShift('z')
        },
        -- LOLLO NOTE these are real derivatives, they make no sense for a single point, so we normalise them
        tangent = transfUtils.getVectorNormalised_FAST({
            x = getTanOnAxisAtShift('x'),
            y = getTanOnAxisAtShift('y'),
            z = getTanOnAxisAtShift('z'),
        })
    }
    -- print('getNodeBetween result =') debugPrint(result)
    return result
end

helper.getNodeBetween = function(position0, position1, tangent0, tangent1, shift0To1, edgeLength, isExtendedLog)
    if type(edgeLength) ~= 'number' or edgeLength <= 0 then
        print('ERROR: edgeUtils.getNodeBetween got an edge length that is not a positive number, returning')
        return nil
    end
    if type(shift0To1) ~= 'number' or shift0To1 < 0 or shift0To1 > 1 then
        print('WARNING: edgeUtils.getNodeBetween got a shift0To1 that is not a positive number, adjusting to 0.5')
        shift0To1 = 0.5
    end

    return _getNodeBetween(position0, position1, tangent0, tangent1, shift0To1, edgeLength, isExtendedLog)
end

helper.getNodeBetweenByPercentageShift = function(edgeId, shift0To1, isExtendedLog)
    if not(helper.isValidAndExistingId(edgeId)) then return nil end

    if type(shift0To1) ~= 'number' or shift0To1 < 0 or shift0To1 > 1 then
        print('WARNING: edgeUtils.getNodeBetweenByPercentageShift got a shift0To1 that is not a positive number, adjusting to 0.5')
        shift0To1 = 0.5
    end

    local baseEdge = api.engine.getComponent(edgeId, api.type.ComponentType.BASE_EDGE)
    if baseEdge == nil then return nil end

    local baseNode0 = api.engine.getComponent(baseEdge.node0, api.type.ComponentType.BASE_NODE)
    local baseNode1 = api.engine.getComponent(baseEdge.node1, api.type.ComponentType.BASE_NODE)
    if baseNode0 == nil or baseNode1 == nil then return nil end

    local edgeLength, isEdgeLengthUsable, isEdgeLengthAccurate = helper.getEdgeLength(edgeId, isExtendedLog)
    if isExtendedLog then
        print('getNodeBetweenByPercentageShift firing, edgeId =', edgeId or 'NIL', 'shift0To1 =', shift0To1 or 'NIL')
        print('baseNode0.position =') debugPrint(baseNode0.position)
        print('baseNode1.position =') debugPrint(baseNode1.position)
        print('baseEdge.tangent0 =') debugPrint(baseEdge.tangent0)
        print('baseEdge.tangent1 =') debugPrint(baseEdge.tangent1)
        print('edgeLength =', edgeLength or 'NIL', 'isEdgeLengthUsable =', isEdgeLengthUsable, 'isEdgeLengthAccurate =', isEdgeLengthAccurate)
        print('getNodeBetween about to fire')
    end
    if not(edgeLength) then return nil end

    return helper.getNodeBetween(
        baseNode0.position,
        baseNode1.position,
        baseEdge.tangent0,
        baseEdge.tangent1,
        shift0To1,
        edgeLength,
        isExtendedLog
    )
end

helper.getNodeBetweenByPosition = function(edgeId, position, isIgnoreZ, isExtendedLog)
    if not(helper.isValidAndExistingId(edgeId)) then return nil end

    if position == nil or (position[1] == nil and position.x == nil) or (position[2] == nil and position.y == nil) or (position[3] == nil and position.z == nil)
    then return nil end

    local baseEdge = api.engine.getComponent(edgeId, api.type.ComponentType.BASE_EDGE)
    if baseEdge == nil then return nil end

    local baseNode0 = api.engine.getComponent(baseEdge.node0, api.type.ComponentType.BASE_NODE)
    local baseNode1 = api.engine.getComponent(baseEdge.node1, api.type.ComponentType.BASE_NODE)
    if baseNode0 == nil or baseNode1 == nil then return nil end

    local distance_0_to_split = transfUtils.getVectorLength_FAST({
        x = (position[1] or position.x) - baseNode0.position.x,
        y = (position[2] or position.y) - baseNode0.position.y,
        z = isIgnoreZ and 0 or ((position[3] or position.z) - baseNode0.position.z),
    })
    local distance_split_to_1 = transfUtils.getVectorLength_FAST({
        x = (position[1] or position.x) - baseNode1.position.x,
        y = (position[2] or position.y) - baseNode1.position.y,
        z = isIgnoreZ and 0 or ((position[3] or position.z) - baseNode1.position.z),
    })
    local edgeLength, isEdgeLengthUsable, isEdgeLengthAccurate = helper.getEdgeLength(edgeId, isExtendedLog)

    if isExtendedLog then
        print('getNodeBetweenByPosition firing, isIgnoreZ =', isIgnoreZ or 'false', 'position =') debugPrint(position)
        print('baseNode0.position =') debugPrint(baseNode0.position)
        print('baseNode1.position =') debugPrint(baseNode1.position)
        print('baseEdge.tangent0 =') debugPrint(baseEdge.tangent0)
        print('baseEdge.tangent1 =') debugPrint(baseEdge.tangent1)
        print('distance_0_to_split =', distance_0_to_split or 'NIL')
        print('distance_split_to_1 =', distance_split_to_1 or 'NIL')
        print('distance_0_to_split / (distance_0_to_split + distance_split_to_1) =', distance_0_to_split / (distance_0_to_split + distance_split_to_1))
        print('edgeLength =', edgeLength or 'NIL', 'isEdgeLengthUsable =', isEdgeLengthUsable, 'isEdgeLengthAccurate =', isEdgeLengthAccurate)
        print('getNodeBetween about to fire')
    end
    if edgeLength == nil or distance_0_to_split == nil or distance_split_to_1 == nil then return nil end

    return helper.getNodeBetween(
        baseNode0.position,
        baseNode1.position,
        baseEdge.tangent0,
        baseEdge.tangent1,
        distance_0_to_split / (distance_0_to_split + distance_split_to_1),
        edgeLength,
        isExtendedLog
    )
end
--#endregion getNodeBetween

helper.isEdgeFrozen = function(edgeId)
    if not(helper.isValidAndExistingId(edgeId)) then return false end

    local conId = api.engine.system.streetConnectorSystem.getConstructionEntityForEdge(edgeId)
    if not(helper.isValidAndExistingId(conId)) then return false end

    local conData = api.engine.getComponent(conId, api.type.ComponentType.CONSTRUCTION)
    if not(conData) or not(conData.frozenEdges) then return false end

    for _, value in pairs(conData.frozenEdges) do
        if value == edgeId then return true end
    end

    return false
end

helper.isEdgeInACon = function(edgeId)
    if not(helper.isValidAndExistingId(edgeId)) then return false end

    local conId = api.engine.system.streetConnectorSystem.getConstructionEntityForEdge(edgeId)
    return helper.isValidAndExistingId(conId)
end

helper.getEdgeObjectModelId = function(edgeObjectId)
    if helper.isValidAndExistingId(edgeObjectId) then
        local modelInstanceList = api.engine.getComponent(edgeObjectId, api.type.ComponentType.MODEL_INSTANCE_LIST)
        if modelInstanceList ~= nil
        and modelInstanceList.fatInstances
        and modelInstanceList.fatInstances[1]
        and modelInstanceList.fatInstances[1].modelId then
            return modelInstanceList.fatInstances[1].modelId
        end
    end
    return nil
end

helper.getEdgeObjectsIdsWithModelId = function(edgeObjects, refModelId)
    local results = {}
    if type(edgeObjects) ~= 'table' or not(helper.isValidId(refModelId)) then return results end

    for i = 1, #edgeObjects do
        if helper.isValidAndExistingId(edgeObjects[i][1]) then
            local modelInstanceList = api.engine.getComponent(edgeObjects[i][1], api.type.ComponentType.MODEL_INSTANCE_LIST)
            if modelInstanceList ~= nil
            and modelInstanceList.fatInstances
            and modelInstanceList.fatInstances[1]
            and modelInstanceList.fatInstances[1].modelId == refModelId then
                results[#results+1] = edgeObjects[i][1]
            end
        end
    end
    return results
end

helper.getEdgeObjectsIdsWithModelId2 = function(edgeObjectIds, refModelId)
    local results = {}
    if type(edgeObjectIds) ~= 'table' or not(helper.isValidId(refModelId)) then return results end

    for i = 1, #edgeObjectIds do
        if helper.isValidAndExistingId(edgeObjectIds[i]) then
            local modelInstanceList = api.engine.getComponent(edgeObjectIds[i], api.type.ComponentType.MODEL_INSTANCE_LIST)
            if modelInstanceList ~= nil
            and modelInstanceList.fatInstances
            and modelInstanceList.fatInstances[1]
            and modelInstanceList.fatInstances[1].modelId == refModelId then
                results[#results+1] = edgeObjectIds[i]
            end
        end
    end
    return results
end

helper.isNodeStreet = function(nodeId)
    if not(helper.isValidAndExistingId(nodeId)) then return false end

    return (#api.engine.system.streetSystem.getNode2StreetEdgeMap()[nodeId] > 0)
end

helper.isNodeTrack = function(nodeId)
    if not(helper.isValidAndExistingId(nodeId)) then return false end

    return (#api.engine.system.streetSystem.getNode2TrackEdgeMap()[nodeId] > 0)
end

helper.getObjectPosition = function(objectId)
    if not(helper.isValidAndExistingId(objectId)) then return nil end

    local modelInstanceList = api.engine.getComponent(objectId, api.type.ComponentType.MODEL_INSTANCE_LIST)
    if not(modelInstanceList) then return nil end

    local fatInstances = modelInstanceList.fatInstances
    if not(fatInstances) or not(fatInstances[1]) or not(fatInstances[1].transf) or not(fatInstances[1].transf.cols) then return nil end

    local xyzw = fatInstances[1].transf:cols(3)
    if not(xyzw) or not(xyzw.x) or not(xyzw.y) or not(xyzw.z) then return nil end

    return {
        xyzw.x,
        xyzw.y,
        xyzw.z,
    }
end

helper.getObjectTransf = function(objectId)
    -- print('getObjectTransf starting')
    if not(helper.isValidAndExistingId(objectId)) then return nil end

    local modelInstanceList = api.engine.getComponent(objectId, api.type.ComponentType.MODEL_INSTANCE_LIST)
    if not(modelInstanceList) then return nil end

    local fatInstances = modelInstanceList.fatInstances
    if not(fatInstances) or not(fatInstances[1]) or not(fatInstances[1].transf) or not(fatInstances[1].transf.cols) then return nil end

    local objectTransf = transfUtilsUG.new(
        fatInstances[1].transf:cols(0),
        fatInstances[1].transf:cols(1),
        fatInstances[1].transf:cols(2),
        fatInstances[1].transf:cols(3)
    )
    local result = {}
    for _, value in pairs(objectTransf) do
        result[#result+1] = value
    end

    return result
end

---this func has specialised siblings for street and track
---@param nodeIds table<integer>
---@return table<integer>
helper.getConnectedEdgeIds = function(nodeIds)
    -- print('getConnectedEdgeIds starting')
    if type(nodeIds) ~= 'table' or #nodeIds < 1 then return {} end

    local _map = api.engine.system.streetSystem.getNode2SegmentMap()
    local results = {}

    for _, nodeId in pairs(nodeIds) do
        if helper.isValidAndExistingId(nodeId) then
            local connectedEdgeIdsUserdata = _map[nodeId] -- userdata
            if connectedEdgeIdsUserdata ~= nil then
                for _, edgeId in pairs(connectedEdgeIdsUserdata) do -- cannot use connectedEdgeIdsUserdata[index] here
                    if helper.isValidAndExistingId(edgeId) then
                        arrayUtils.addUnique(results, edgeId)
                    end
                end
            end
        end
    end

    -- print('getConnectedEdgeIds is about to return') debugPrint(results)
    return results
end

helper.getEdgeIdsConnectedToEdgeId = function(edgeId)
    -- print('getEdgeIdsConnectedToEdgeId starting')
    if not(helper.isValidAndExistingId(edgeId)) then return {} end
    local baseEdge = api.engine.getComponent(edgeId, api.type.ComponentType.BASE_EDGE)
    if baseEdge == nil then return {} end

    local _map = api.engine.system.streetSystem.getNode2SegmentMap()
    local results = {}

    for _, nodeId in pairs({ baseEdge.node0, baseEdge.node1 }) do
        if helper.isValidAndExistingId(nodeId) then
            local connectedEdgeIdsUserdata = _map[nodeId] -- userdata
            if connectedEdgeIdsUserdata ~= nil then
                for _, connectedEdgeId in pairs(connectedEdgeIdsUserdata) do -- cannot use connectedEdgeIdsUserdata[index] here
                    if connectedEdgeId ~= edgeId and helper.isValidAndExistingId(connectedEdgeId) then
                        arrayUtils.addUnique(results, connectedEdgeId)
                    end
                end
            end
        end
    end

    -- print('getEdgeIdsConnectedToEdgeId is about to return') debugPrint(results)
    return results
end

helper.street = {
    ---this func has specialised siblings for generic and track
    ---@param nodeIds table<integer>
    ---@return table<integer>
    getConnectedEdgeIds = function(nodeIds)
        -- print('getConnectedEdgeIds starting')
        if type(nodeIds) ~= 'table' or #nodeIds < 1 then return {} end

        local _map = api.engine.system.streetSystem.getNode2StreetEdgeMap()
        local results = {}

        for _, nodeId in pairs(nodeIds) do
            if helper.isValidAndExistingId(nodeId) then
                local connectedEdgeIdsUserdata = _map[nodeId] -- userdata
                if connectedEdgeIdsUserdata ~= nil then
                    for _, edgeId in pairs(connectedEdgeIdsUserdata) do -- cannot use connectedEdgeIdsUserdata[index] here
                        -- getNode2TrackEdgeMap returns the same as getNode2SegmentMap, so we check it ourselves
                        if helper.isValidAndExistingId(edgeId) and api.engine.getComponent(edgeId, api.type.ComponentType.BASE_EDGE_STREET) ~= nil then
                            arrayUtils.addUnique(results, edgeId)
                        end
                    end
                end
            end
        end

        -- print('getConnectedEdgeIds is about to return') debugPrint(results)
        return results
    end,
    getNearestEdgeId = function(transf, minZ, maxZ)
        if type(transf) ~= 'table' then return nil end

        local _position = transfUtils.getVec123Transformed({0, 0, 0}, transf)
        local _searchRadius = 0.5
        local _box0 = api.type.Box3.new(
            api.type.Vec3f.new(_position[1] - _searchRadius, _position[2] - _searchRadius, minZ or -9999),
            api.type.Vec3f.new(_position[1] + _searchRadius, _position[2] + _searchRadius, maxZ or 9999)
        )
        local baseEdgeIds = {}
        local callback0 = function(entity, boundingVolume)
            -- print('callback0 found entity', entity)
            -- print('boundingVolume =') debugPrint(boundingVolume)
            if not(entity) then return end

            if not(api.engine.getComponent(entity, api.type.ComponentType.BASE_EDGE)) then return end
            -- print('the entity is a BASE_EDGE')

            baseEdgeIds[#baseEdgeIds+1] = entity
        end
        api.engine.system.octreeSystem.findIntersectingEntities(_box0, callback0)

        if #baseEdgeIds == 0 then
            return nil
        elseif #baseEdgeIds == 1 then
            return baseEdgeIds[1]
        else
            -- print('multiple base edges found')
            -- choose one edge and return its id
            for i = 1, #baseEdgeIds do
                local baseEdge = api.engine.getComponent(baseEdgeIds[i], api.type.ComponentType.BASE_EDGE)
                local baseEdgeStreet = api.engine.getComponent(baseEdgeIds[i], api.type.ComponentType.BASE_EDGE_STREET)
                if baseEdge ~= nil and baseEdgeStreet ~= nil then -- false when there is a modded road that underwent a breaking change
                    local node0 = api.engine.getComponent(baseEdge.node0, api.type.ComponentType.BASE_NODE)
                    local node1 = api.engine.getComponent(baseEdge.node1, api.type.ComponentType.BASE_NODE)
                    local streetTypeProperties = api.res.streetTypeRep.get(baseEdgeStreet.streetType)
                    local halfStreetWidth = (streetTypeProperties.streetWidth or 0) * 0.5 + (streetTypeProperties.sidewalkWidth or 0)
                    local alpha = math.atan2(node1.position.y - node0.position.y, node1.position.x - node0.position.x)
                    local xPlus = - math.sin(alpha) * halfStreetWidth
                    local yPlus = math.cos(alpha) * halfStreetWidth
                    local vertices = {
                        [1] = {
                            x = node0.position.x - xPlus,
                            y = node0.position.y - yPlus
                        },
                        [2] = {
                            x = node0.position.x + xPlus,
                            y = node0.position.y + yPlus
                        },
                        [3] = {
                            x = node1.position.x + xPlus,
                            y = node1.position.y + yPlus
                        },
                        [4] = {
                            x = node1.position.x - xPlus,
                            y = node1.position.y - yPlus
                        },
                    }
                    -- check if the _position falls within the quadrangle approximating the edge
                    -- LOLLO NOTE I could get a more accurate polygon (not necessarily a quadrangle!) getIsPointWithin
                    -- api.engine.getComponent(entity, api.type.ComponentType.LOT_LIST)
                    -- but it returns nothing with bridges and tunnels
                    if quadrangleUtils.getIsPointWithin(quadrangleUtils.getVerticesSortedClockwise(vertices), _position) then
                        return baseEdgeIds[i]
                    end
                end
            end
            -- print('falling back')
            return baseEdgeIds[1] -- fallback
        end
    end,
}

local _getTrackEdgeIdsBetweenEdgeAndNode = function(edgeId, nodeId, maxDistance)
    local edge1IdTyped = api.type.EdgeId.new(edgeId, 0)
    local edgeIdDir1False = api.type.EdgeIdDirAndLength.new(edge1IdTyped, false, 0)
    local edgeIdDir1True = api.type.EdgeIdDirAndLength.new(edge1IdTyped, true, 0)
    local node2Typed = api.type.NodeId.new(nodeId, 0)
    local myPath = api.engine.util.pathfinding.findPath(
        { edgeIdDir1False, edgeIdDir1True },
        { node2Typed },
        {
            api.type.enum.TransportMode.TRAIN,
            -- api.type.enum.TransportMode.ELECTRIC_TRAIN
        },
        maxDistance
    )
    local results = {}
    for _, value in pairs(myPath) do
        -- remove non-edge funds, this api can add some nodes to its output.
        local baseEdge = api.engine.getComponent(value.entity, api.type.ComponentType.BASE_EDGE)
        if baseEdge ~= nil then
            -- remove duplicates arising from traffic light or waypoints on edges, which have the same entity but a higher index.
            if #results == 0 or results[#results] ~= value.entity then
                results[#results+1] = value.entity
            end
        end
    end
    return results
end

local _getTrackEdgeIdsBetweenEdgeIds = function(edge1Id, edge2Id, maxDistance, isExtendedLog)
    local baseEdge2 = api.engine.getComponent(edge2Id, api.type.ComponentType.BASE_EDGE)
    local results = _getTrackEdgeIdsBetweenEdgeAndNode(edge1Id, baseEdge2.node0, maxDistance)
    if #results > 0 and arrayUtils.arrayHasValue(results, edge2Id) then
        if isExtendedLog then
            print('_getTrackEdgeIdsBetweenEdgeIds got path =')
            debugPrint(results)
        end
        return results
    end

    -- the path did not include edge2Id coz we picked the wrong node: retry with the other node
    results = _getTrackEdgeIdsBetweenEdgeAndNode(edge1Id, baseEdge2.node1, maxDistance)
    if #results > 0 and arrayUtils.arrayHasValue(results, edge2Id) then
        if isExtendedLog then
            print('_getTrackEdgeIdsBetweenEdgeIds now got path =')
            debugPrint(results)
        end
        return results
    end

    if isExtendedLog then
        print('_getTrackEdgeIdsBetweenEdgeIds could not get a proper path, it only got =')
        debugPrint(results)
    end
    return {}
end
helper.track = {
    ---this func has specialised siblings for street and generic
    ---@param nodeIds table<integer>
    ---@return table<integer>
    getConnectedEdgeIds = function(nodeIds)
        -- print('getConnectedEdgeIds starting')
        if type(nodeIds) ~= 'table' or #nodeIds < 1 then return {} end

        local _map = api.engine.system.streetSystem.getNode2TrackEdgeMap()
        local results = {}

        for _, nodeId in pairs(nodeIds) do
            if helper.isValidAndExistingId(nodeId) then
                local connectedEdgeIdsUserdata = _map[nodeId] -- userdata
                if connectedEdgeIdsUserdata ~= nil then
                    for _, edgeId in pairs(connectedEdgeIdsUserdata) do -- cannot use connectedEdgeIdsUserdata[index] here
                        -- getNode2TrackEdgeMap returns the same as getNode2SegmentMap, so we check it ourselves
                        if helper.isValidAndExistingId(edgeId) and api.engine.getComponent(edgeId, api.type.ComponentType.BASE_EDGE_TRACK) ~= nil then
                            arrayUtils.addUnique(results, edgeId)
                        end
                    end
                end
            end
        end

        -- print('getConnectedEdgeIds is about to return') debugPrint(results)
        return results
    end,
    getContiguousEdges_UNUSED_BUT_KEEP_IT_FOR_NOW = function(edgeId, acceptedTrackTypes)
        local _calcContiguousEdges = function(firstEdgeId, firstNodeId, map, isInsertFirst, results)
            local refEdgeId = firstEdgeId
            local refNodeId = firstNodeId
            local edgeIds = map[firstNodeId] -- userdata
            local isExit = false
            while not(isExit) do
                if not(edgeIds) or #edgeIds ~= 2 then
                    isExit = true
                else
                    for _, _edgeId in pairs(edgeIds) do -- cannot use edgeIds[index] here
                        -- print('edgeId =') debugPrint(_edgeId)
                        if _edgeId ~= refEdgeId then
                            local baseEdgeTrack = api.engine.getComponent(_edgeId, api.type.ComponentType.BASE_EDGE_TRACK)
                            -- print('baseEdgeTrack =') debugPrint(baseEdgeTrack)
                            if not(baseEdgeTrack) or not(arrayUtils.arrayHasValue(acceptedTrackTypes, baseEdgeTrack.trackType)) then
                                isExit = true
                                break
                            else
                                if isInsertFirst then
                                    table.insert(results, 1, _edgeId)
                                else
                                    table.insert(results, _edgeId)
                                end
                                local edgeData = api.engine.getComponent(_edgeId, api.type.ComponentType.BASE_EDGE)
                                if edgeData.node0 ~= refNodeId then
                                    refNodeId = edgeData.node0
                                else
                                    refNodeId = edgeData.node1
                                end
                                refEdgeId = _edgeId
                                break
                            end
                        end
                    end
                    edgeIds = map[refNodeId]
                end
            end
        end

        -- print('getContiguousEdges starting, edgeId =') debugPrint(edgeId)
        -- print('track type =') debugPrint(trackType)

        if not(edgeId) or acceptedTrackTypes == nil or #acceptedTrackTypes == 0 then return {} end

        local _baseEdgeTrack = api.engine.getComponent(edgeId, api.type.ComponentType.BASE_EDGE_TRACK)
        if not(_baseEdgeTrack) or not(arrayUtils.arrayHasValue(acceptedTrackTypes, _baseEdgeTrack.trackType)) then return {} end

        local _baseEdge = api.engine.getComponent(edgeId, api.type.ComponentType.BASE_EDGE)
        local _edgeId = edgeId
        local _map = api.engine.system.streetSystem.getNode2TrackEdgeMap()
        local results = { edgeId }

        _calcContiguousEdges(_edgeId, _baseEdge.node0, _map, true, results)
        _calcContiguousEdges(_edgeId, _baseEdge.node1, _map, false, results)

        return results
    end,
    getNearestEdgeIdStrict = function(transf, minZ, maxZ, myLogger)
        if myLogger == nil then myLogger = {print = function(q) end, debugPrint = function (q) end} end
        if type(transf) ~= 'table' then return nil end

        local _position = transfUtils.getVec123Transformed({0, 0, 0}, transf)
         -- local testPosition = transfUtils.transf2Position(transf, true)
        -- print('position =') debugPrint(_position)
        local _searchRadius = 0.5
        local _box0 = api.type.Box3.new(
            api.type.Vec3f.new(_position[1] - _searchRadius, _position[2] - _searchRadius, minZ or -9999),
            api.type.Vec3f.new(_position[1] + _searchRadius, _position[2] + _searchRadius, maxZ or 9999)
        )
        local baseEdgeIds = {}
        local callback0 = function(entity, boundingVolume)
            -- print('callback0 found entity', entity)
            -- print('boundingVolume =') debugPrint(boundingVolume)
            if not(entity) then return end

            if not(api.engine.getComponent(entity, api.type.ComponentType.BASE_EDGE))
            or not(api.engine.getComponent(entity, api.type.ComponentType.BASE_EDGE_TRACK))
            or not(helper.isValidAndExistingId(entity))
            then return end
            -- print('the entity is a BASE_EDGE')

            baseEdgeIds[#baseEdgeIds+1] = entity
        end
        api.engine.system.octreeSystem.findIntersectingEntities(_box0, callback0)

        if #baseEdgeIds == 0 then
            myLogger.print('#baseEdgeIds == 0')
            return nil
            -- LOLLO NOTE comment this out to make it less strict
        -- elseif #baseEdgeIds == 1 then
            -- print('#baseEdgeIds == 1')
            -- return baseEdgeIds[1]
        else
            myLogger.print('#baseEdgeIds == ' .. tostring(#baseEdgeIds) .. ', position = ') myLogger.debugPrint(_position)
            -- print('multiple base edges found')
            -- choose one edge and return its id

            -- this is better than nothing
            -- for i = 1, #baseEdgeIds do
            --     local baseEdge = api.engine.getComponent(baseEdgeIds[i], api.type.ComponentType.BASE_EDGE)
            --     local baseEdgeTrack = api.engine.getComponent(baseEdgeIds[i], api.type.ComponentType.BASE_EDGE_TRACK)
            --     if baseEdge ~= nil and baseEdgeTrack ~= nil then -- false when there is a modded road that underwent a breaking change
            --         local node0 = api.engine.getComponent(baseEdge.node0, api.type.ComponentType.BASE_NODE)
            --         local node1 = api.engine.getComponent(baseEdge.node1, api.type.ComponentType.BASE_NODE)
            --         local trackTypeProperties = api.res.trackTypeRep.get(baseEdgeTrack.trackType)
            --         local halfTrackWidth = (trackTypeProperties.shapeWidth or 0) * 0.5
            --         print('halfTrackWidth = ' .. tostring(halfTrackWidth))
            --         local alpha = math.atan2(node1.position.y - node0.position.y, node1.position.x - node0.position.x)
            --         local xPlus = - math.sin(alpha) * halfTrackWidth
            --         local yPlus = math.cos(alpha) * halfTrackWidth
            --         local vertices = {
            --             [1] = {
            --                 x = node0.position.x - xPlus,
            --                 y = node0.position.y - yPlus
            --             },
            --             [2] = {
            --                 x = node0.position.x + xPlus,
            --                 y = node0.position.y + yPlus
            --             },
            --             [3] = {
            --                 x = node1.position.x + xPlus,
            --                 y = node1.position.y + yPlus
            --             },
            --             [4] = {
            --                 x = node1.position.x - xPlus,
            --                 y = node1.position.y - yPlus
            --             },
            --         }
            --         -- check if the _position falls within the quadrangle approximating the edge
            --         -- LOLLO NOTE I could get a more accurate polygon (not necessarily a quadrangle!) getIsPointWithin
            --         -- api.engine.getComponent(entity, api.type.ComponentType.LOT_LIST)
            --         -- but it returns nothing with bridges and tunnels
            --         if quadrangleUtils.getIsPointWithin(quadrangleUtils.getVerticesSortedClockwise(vertices), _position) then
            --             return baseEdgeIds[i]
            --         end
            --     end
            -- end

            -- another way to do the same, but wrong
            -- for i = 1, #baseEdgeIds do
            --     local baseEdge = api.engine.getComponent(baseEdgeIds[i], api.type.ComponentType.BASE_EDGE)
            --     local baseEdgeTrack = api.engine.getComponent(baseEdgeIds[i], api.type.ComponentType.BASE_EDGE_TRACK)
            --     if baseEdge ~= nil and baseEdgeTrack ~= nil then -- false when there is a modded road that underwent a breaking change
            --         -- local node0 = api.engine.getComponent(baseEdge.node0, api.type.ComponentType.BASE_NODE)
            --         -- local node1 = api.engine.getComponent(baseEdge.node1, api.type.ComponentType.BASE_NODE)
            --         local trackTypeProperties = api.res.trackTypeRep.get(baseEdgeTrack.trackType)
            --         local halfTrackWidth = (trackTypeProperties.shapeWidth or 0) * 0.5
            --         lmyLoggerogger.print('halfTrackWidth = ' .. tostring(halfTrackWidth))
            --         local testPosition = transfUtils.transf2Position(transf, true)
            --         local nodeBetween = helper.getNodeBetweenByPosition(baseEdgeIds[i], testPosition)
            --         if nodeBetween ~= nil and nodeBetween.length0 ~= 0 and nodeBetween.length1 ~= 0 and nodeBetween.position ~= nil then
            --             local distance = transfUtils.getVectorLength({
            --                 nodeBetween.position.x - testPosition.x,
            --                 nodeBetween.position.y - testPosition.y,
            --                 nodeBetween.position.z - testPosition.z,
            --             })
            --             if distance <= halfTrackWidth then return baseEdgeIds[i] end
            --         end
            --     end
            -- end

            -- a new idea: split every edge into shorter segments, which are straight enough, then check the point to segment distances
            local minDistance_edgeId = {distance = 9999, edgeId = nil}
            for i = 1, #baseEdgeIds do
                local edgeId = baseEdgeIds[i]
                local baseEdge = api.engine.getComponent(edgeId, api.type.ComponentType.BASE_EDGE)
                local baseEdgeTrack = api.engine.getComponent(edgeId, api.type.ComponentType.BASE_EDGE_TRACK)
                if baseEdge ~= nil and baseEdgeTrack ~= nil then -- false when there is a modded road that underwent a breaking change
                    -- local node0 = api.engine.getComponent(baseEdge.node0, api.type.ComponentType.BASE_NODE)
                    -- local node1 = api.engine.getComponent(baseEdge.node1, api.type.ComponentType.BASE_NODE)
                    local trackTypeProperties = api.res.trackTypeRep.get(baseEdgeTrack.trackType)
                    local halfTrackWidth = (trackTypeProperties.shapeWidth or 0) * 0.5
                    myLogger.print('halfTrackWidth = ' .. tostring(halfTrackWidth))
                    -- local testPosition = transfUtils.transf2Position(transf, true)
                    local shifts = {}
                    local howManySplitsM1 = 32.0 -- the higher, he better. Over 100 would be nonsense. 18 is not enough.
                    for k = 0, howManySplitsM1, 1 do
                        shifts[#shifts+1] = k / howManySplitsM1
                    end
                    -- print('shifts =') debugPrint(shifts)
                    local nodesBetween = {}
                    for _, shift in pairs(shifts) do
                        local nodeBetween = helper.getNodeBetweenByPercentageShift(edgeId, shift)
                        --[[
local nodeBetween = {
        refDistance0 = length * shift0To1,
        refPosition0 = {
            x = pos0.x,
            y = pos0.y,
            z = pos0.z,
        },
        refTangent0 = {
            x = tan0.x,
            y = tan0.y,
            z = tan0.z,
        },
        refDistance1 = length * (1 - shift0To1),
        refPosition1 = {
            x = pos1.x,
            y = pos1.y,
            z = pos1.z,
        },
        refTangent1 = {
            x = tan1.x,
            y = tan1.y,
            z = tan1.z,
        },
        refLength = length,
        position = {
            x = getPosOnAxisAtShift('x'),
            y = getPosOnAxisAtShift('y'),
            z = getPosOnAxisAtShift('z')
        },
        -- LOLLO NOTE these are real derivatives, they make no sense for a single point, so we normalise them
        tangent = transfUtils.getVectorNormalised_FAST({
            x = getTanOnAxisAtShift('x'),
            y = getTanOnAxisAtShift('y'),
            z = getTanOnAxisAtShift('z'),
        })
    }
]]
                        if nodeBetween ~= nil and nodeBetween.position ~= nil then
                            nodesBetween[#nodesBetween+1] = nodeBetween
                        end
                    end
                    -- myLogger.print('nodesBetween for edgeId ' .. tostring(edgeId) .. ' =') myLogger.debugPrint(nodesBetween)
                    if #nodesBetween > 1 then
                        for k = 1, #nodesBetween - 1, 1 do
                            -- local distance = transfUtils.getDistanceBetweenPointAndStraight(segmentPosition[1], segmentPosition[2], testPosition)
                            local distance = transfUtils.getDistanceBetweenPointAndStraight(nodesBetween[k].position, nodesBetween[k+1].position, _position)
                            if type(distance) == 'number' and distance < minDistance_edgeId.distance and distance < halfTrackWidth then
                                myLogger.print('new lower distance found for edge ' .. tostring(edgeId) .. ', it is ' .. tostring(distance))
                                minDistance_edgeId.distance = distance
                                minDistance_edgeId.edgeId = edgeId
                            else
                                myLogger.print('no lower distance found for edge ' .. tostring(edgeId) .. ', it would be ' .. tostring(distance))
                            end
                        end
                    end
                end
            end -- loop over edges
            myLogger.print('track.getNearestEdgeIdStrict is about to return; minDistance_edgeId = ') myLogger.debugPrint(minDistance_edgeId)
            return minDistance_edgeId.edgeId
        end
    end,
    ---Receives an unsorted list of edge ids and returns an unsorted list of node ids.
    ---It can include the outer nodes that are dead ends.
    ---It requires at least two edgeIds.
    ---@param edgeIds table<integer>
    ---@param isIncludeOuterEndNodes? boolean
    ---@return table<integer>
    getNodeIdsBetweenEdgeIds_optionalDeadEnds = function(edgeIds, isIncludeOuterEndNodes)
        if type(edgeIds) ~= 'table' then return {} end

        local _map = api.engine.system.streetSystem.getNode2TrackEdgeMap()
        local allNodeIds_indexed = {}
        local sharedNodeIds_indexed = {}
        for _, edgeId in pairs(edgeIds) do
            local baseEdge = api.engine.getComponent(edgeId, api.type.ComponentType.BASE_EDGE)
            if baseEdge ~= nil and api.engine.getComponent(edgeId, api.type.ComponentType.BASE_EDGE_TRACK) ~= nil then
                local nEdgesAttached2Node0 = #(_map[baseEdge.node0] or {})
                if nEdgesAttached2Node0 == 0 then -- should never happen
                    logger.warn('should never happen: 0 edges are attached to node ' .. baseEdge.node0)
                    sharedNodeIds_indexed[baseEdge.node0] = true
                elseif nEdgesAttached2Node0 == 1 then
                    if isIncludeOuterEndNodes then
                        sharedNodeIds_indexed[baseEdge.node0] = true
                    end
                elseif allNodeIds_indexed[baseEdge.node0] == nEdgesAttached2Node0 - 1 then
                    sharedNodeIds_indexed[baseEdge.node0] = true
                end
                local nEdgesAttached2Node1 = #(_map[baseEdge.node1] or {})
                if nEdgesAttached2Node1 == 0 then -- should never happen
                    logger.warn('should never happen: 0 edges are attached to node ' .. baseEdge.node1)
                    sharedNodeIds_indexed[baseEdge.node1] = true
                elseif nEdgesAttached2Node1 == 1 then
                    if isIncludeOuterEndNodes then
                        sharedNodeIds_indexed[baseEdge.node1] = true
                    end
                elseif allNodeIds_indexed[baseEdge.node1] == nEdgesAttached2Node1 - 1 then
                    sharedNodeIds_indexed[baseEdge.node1] = true
                end
                allNodeIds_indexed[baseEdge.node0] = (allNodeIds_indexed[baseEdge.node0] or 0) + 1
                allNodeIds_indexed[baseEdge.node1] = (allNodeIds_indexed[baseEdge.node1] or 0) + 1
            end
        end

        local results = {}
        for nodeId, _ in pairs(sharedNodeIds_indexed) do
            results[#results+1] = nodeId
        end
        return results
    end,
    ---Receives an unsorted list of edge ids and returns an unsorted list of node ids.
    ---It can include the outer nodes.
    ---@param edgeIds table<integer>
    ---@param isIncludeOuterNodes? boolean
    ---@return table<integer>
    getNodeIdsBetweenEdgeIds_optionalEnds = function(edgeIds, isIncludeOuterNodes)
        if type(edgeIds) ~= 'table' then return {} end

        local nodesBetweenEdges_indexed = {} -- nodeId, counter
        for _, edgeId in pairs(edgeIds) do -- don't use _ here, we call it below to translate the message!
            local baseEdge = api.engine.getComponent(edgeId, api.type.ComponentType.BASE_EDGE)
            if baseEdge and api.engine.getComponent(edgeId, api.type.ComponentType.BASE_EDGE_TRACK) ~= nil then
                if nodesBetweenEdges_indexed[baseEdge.node0] then
                    nodesBetweenEdges_indexed[baseEdge.node0] = nodesBetweenEdges_indexed[baseEdge.node0] + 1
                else
                    nodesBetweenEdges_indexed[baseEdge.node0] = 1
                end
                if nodesBetweenEdges_indexed[baseEdge.node1] then
                    nodesBetweenEdges_indexed[baseEdge.node1] = nodesBetweenEdges_indexed[baseEdge.node1] + 1
                else
                    nodesBetweenEdges_indexed[baseEdge.node1] = 1
                end
            end
        end

        local results = {}
        for nodeId, count in pairs(nodesBetweenEdges_indexed) do
            if count > 1 or isIncludeOuterNodes then
                results[#results+1] = nodeId
            end
        end
        return results
    end,
    getTrackEdgeIdsBetweenNodeIds = function(_node1Id, _node2Id, maxDistance, isExtendedLog)
        if isExtendedLog then
            print('getTrackEdgeIdsBetweenNodeIds starting')
            print('node1Id =', _node1Id) print('node2Id =', _node2Id)
            print('ONE')
        end
        if not(helper.isValidAndExistingId(_node1Id)) then return {} end
        if isExtendedLog then print('ONE AND A HALF') end
        if not(helper.isValidAndExistingId(_node2Id)) then return {} end
        if isExtendedLog then print('TWO') end
        if _node1Id == _node2Id then return {} end
        if isExtendedLog then print('THREE') end

        local _map = api.engine.system.streetSystem.getNode2TrackEdgeMap()
        local adjacentEdge1Ids = {}
        local adjacentEdge2Ids = {}
        local _fetchAdjacentEdges = function()
            local adjacentEdge1IdsUserdata = _map[_node1Id] -- userdata
            local adjacentEdge2IdsUserdata = _map[_node2Id] -- userdata
            if adjacentEdge1IdsUserdata == nil then
                if isExtendedLog then print('Warning: FOUR') end
                return false
            else
                for _, edgeId in pairs(adjacentEdge1IdsUserdata) do -- cannot use adjacentEdgeIds[index] here
                    -- arrayUtils.addUnique(adjacentEdge1Ids, edgeId)
                    adjacentEdge1Ids[#adjacentEdge1Ids+1] = edgeId
                end
                if isExtendedLog then print('FIVE') end
            end
            if adjacentEdge2IdsUserdata == nil then
                if isExtendedLog then print('Warning: SIX') end
                return false
            else
                for _, edgeId in pairs(adjacentEdge2IdsUserdata) do -- cannot use adjacentEdgeIds[index] here
                    -- arrayUtils.addUnique(adjacentEdge2Ids, edgeId)
                    adjacentEdge2Ids[#adjacentEdge2Ids+1] = edgeId
                end
                if isExtendedLog then print('SEVEN') end
            end

            return true
        end

        if not(_fetchAdjacentEdges()) then
            if isExtendedLog then print('FOUR OR SIX') end
            return {}
        end
        if #adjacentEdge1Ids < 1 or #adjacentEdge2Ids < 1 then
            if isExtendedLog then print('Warning: EIGHT') end
            return {}
        end

        if #adjacentEdge1Ids == 1 and #adjacentEdge2Ids == 1 then
            if adjacentEdge1Ids[1] == adjacentEdge2Ids[1] then
                if isExtendedLog then print('NINE') end
                return { adjacentEdge1Ids[1] }
            else
                if isExtendedLog then print('TEN') end
            end
        end
        -- if isExtendedLog then
        --     print('adjacentEdge1Ids =') debugPrint(adjacentEdge1Ids)
        --     print('adjacentEdge2Ids =') debugPrint(adjacentEdge2Ids)
        -- end

        local trackEdgeIdsBetweenEdgeIds = _getTrackEdgeIdsBetweenEdgeAndNode(adjacentEdge1Ids[1], _node2Id, maxDistance)
        if isExtendedLog then
            print('trackEdgeIdsBetweenEdgeIds before pruning =') debugPrint(trackEdgeIdsBetweenEdgeIds)
        end
        -- remove edges adjacent to but outside node1 and node2

        -- for _, edgeId in pairs(trackEdgeIdsBetweenEdgeIds) do
        --     local baseEdge = api.engine.getComponent(edgeId, api.type.ComponentType.BASE_EDGE)
        --     if isExtendedLog then
        --         print('base edge = ', edgeId) debugPrint(baseEdge)
        --     end
        -- end

        local isExit = false
        while not(isExit) do
            if #trackEdgeIdsBetweenEdgeIds > 1
            and arrayUtils.arrayHasValue(adjacentEdge1Ids, trackEdgeIdsBetweenEdgeIds[1])
            and arrayUtils.arrayHasValue(adjacentEdge1Ids, trackEdgeIdsBetweenEdgeIds[2]) then
                if isExtendedLog then print('ELEVEN') end
                table.remove(trackEdgeIdsBetweenEdgeIds, 1)
                if isExtendedLog then
                    print('trackEdgeIdsBetweenEdgeIds during pruning =')
                    debugPrint(trackEdgeIdsBetweenEdgeIds)
                end
            else
                if isExtendedLog then print('TWELVE') end
                isExit = true
            end
        end
        -- isExit = false
        -- while not(isExit) do
        --     if #trackEdgeIdsBetweenEdgeIds > 1
        --     and arrayUtils.arrayHasValue(adjacentEdge2Ids, trackEdgeIdsBetweenEdgeIds[#trackEdgeIdsBetweenEdgeIds])
        --     and arrayUtils.arrayHasValue(adjacentEdge2Ids, trackEdgeIdsBetweenEdgeIds[#trackEdgeIdsBetweenEdgeIds-1]) then
        --         if isExtendedLog then
        --             print('THIRTEEN HALF')
        --             warn('I reinstated this, check it')
        --         end
        --         table.remove(trackEdgeIdsBetweenEdgeIds, #trackEdgeIdsBetweenEdgeIds)
        --         if isExtendedLog then
        --             print('trackEdgeIdsBetweenEdgeIds during pruning =')
        --             debugPrint(trackEdgeIdsBetweenEdgeIds)
        --         end
        --     else
        --         if isExtendedLog then print('FOURTEEN') end
        --         isExit = true
        --     end
        -- end

        -- for _, edgeId in pairs(trackEdgeIdsBetweenEdgeIds) do
        --     local baseEdge = api.engine.getComponent(edgeId, api.type.ComponentType.BASE_EDGE)
        --     if isExtendedLog then print('base edge = ', edgeId) debugPrint(baseEdge) end
        -- end
        if isExtendedLog then
            print('trackEdgeIdsBetweenEdgeIds after pruning =')
            debugPrint(trackEdgeIdsBetweenEdgeIds)
        end
        if arrayUtils.arrayHasValue(adjacentEdge2Ids, trackEdgeIdsBetweenEdgeIds[#trackEdgeIdsBetweenEdgeIds]) then return trackEdgeIdsBetweenEdgeIds end
        print('WARNING: the last edge does not connect, this should never happen')
        return {}
    end,
    -- returns the edge ids in the right sequence from edge1 to edge2, but their node0 and node1 may be scrambled,
    -- depending how the user laid the tracks
    getTrackEdgeIdsBetweenEdgeIds = function(edge1Id, edge2Id, maxDistance, isEitherDirection, isExtendedLog)
        if isExtendedLog then
            print('getTrackEdgeIdsBetweenEdgeIds starting, edge1Id = ' .. edge1Id .. ', edge2Id = ' .. edge2Id)
        end
        if not(helper.isValidAndExistingId(edge1Id)) or not(helper.isValidAndExistingId(edge2Id)) or type(maxDistance) ~= 'number' or maxDistance <= 0 then
            print('WARNING: getTrackEdgeIdsBetweenEdgeIds received wrong arguments')
            return {}
        end

        local results = _getTrackEdgeIdsBetweenEdgeIds(edge1Id, edge2Id, maxDistance, isExtendedLog)
        if #results > 0 then return results end

        if isEitherDirection then
            if isExtendedLog then print('getTrackEdgeIdsBetweenEdgeIds about to return reversed results') end
            return arrayUtils.getReversed(
                _getTrackEdgeIdsBetweenEdgeIds(edge2Id, edge1Id, maxDistance, isExtendedLog)
            )
        end

        return {}
    end,
}

return helper
