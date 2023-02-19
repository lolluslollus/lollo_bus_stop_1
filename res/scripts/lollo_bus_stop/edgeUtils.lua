local arrayUtils = require('lollo_bus_stop.arrayUtils')
local matrixUtils = require('lollo_bus_stop.matrix')
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

helper.getVectorLength = function(xyz)
    return transfUtils.getVectorLength(xyz)
end

helper.getVectorNormalised = function(xyz, targetLength)
    return transfUtils.getVectorNormalised(xyz, targetLength)
end

helper.getPositionsDistance = function(pos0, pos1)
    return transfUtils.getPositionsDistance(pos0, pos1)
end

helper.getPositionsMiddle = function(pos0, pos1)
    return transfUtils.getPositionsMiddle(pos0, pos1)
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
        -- print('boundingVolume =')
        -- debugPrint(boundingVolume)
        if not(entity) then return end

        if not(api.engine.getComponent(entity, componentType)) then return end
        -- print('the entity has the right component type')

        results[#results+1] = entity
    end
    -- LOLLO NOTE nodes may have a bounding box: for them, we check the position only
    local callback4Nodes = function(entity, boundingVolume)
        -- print('callback0 found entity', entity)
        -- print('boundingVolume =')
        -- debugPrint(boundingVolume)
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
        -- print('boundingVolume =')
        -- debugPrint(boundingVolume)
        if not(entityId) then return end

        local props = api.engine.getComponent(entityId, componentType)
        -- print('the entity has the right component type')
        results[entityId] = props
    end
    -- LOLLO NOTE nodes may have a bounding box: for them, we check the position only
    local callback4Nodes = function(entityId, boundingVolume)
        -- print('callback0 found entity', entity)
        -- print('boundingVolume =')
        -- debugPrint(boundingVolume)
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

helper.getEdgeLength = function(edgeId)
    if not(helper.isValidAndExistingId(edgeId)) then return nil end

    local baseEdge = api.engine.getComponent(edgeId, api.type.ComponentType.BASE_EDGE)
    if baseEdge == nil then return nil end

    -- these should be identical, but they are not really so, so we average them
    -- return (helper.getVectorLength(baseEdge.tangent0) + helper.getVectorLength(baseEdge.tangent1)) * 0.5
    local lengthA = (helper.getVectorLength(baseEdge.tangent0) + helper.getVectorLength(baseEdge.tangent1)) * 0.5
    -- this returns funny results but it is correct with humps, so we test both for a while LOLLO TODO
    -- local tn = api.engine.getComponent(edgeId, api.type.ComponentType.TRANSPORT_NETWORK)
    -- if tn == nil or tn.edges == nil or tn.edges[1] == nil or tn.edges[1].geometry == nil then return nil end
    -- return tn.edges[1].geometry.length

    local lengthB
    local tn = api.engine.getComponent(edgeId, api.type.ComponentType.TRANSPORT_NETWORK)
    if (tn ~= nil and tn.edges ~= nil) then
        local edgeCount = #tn.edges

        if edgeCount == 1 then -- faster when dealing with tracks
            lengthB = tn.edges[1].geometry.length
        elseif edgeCount > 1 then
            local totalLength = 0
            for i = 1, edgeCount, 1 do
                totalLength = totalLength + tn.edges[i].geometry.length
            end
            lengthB = totalLength / edgeCount
        end
    end
    if not(transfUtils.isNumVeryClose(lengthA, lengthB, 3)) then
        print('edgeUtils.getEdgeLength WARNING: edgeId', edgeId, 'has two different lengths:', lengthA, lengthB)
    end

    return lengthB or lengthA
end

local _getNodeBetween = function(position0, position1, tangent0, tangent1, shift0To1, edgeLength, isExtendedLog) --, length)
    local length = edgeLength
    if type(length) ~= 'number' or length <= 0 then
        print('edgeUtils._getNodeBetween WARNING: edge length is not a positive number, returning')
        return nil
    end

    if isExtendedLog then
        print('getNodeBetween starting, shift0To1 =', shift0To1, 'length =', length)
        print('position0, position1 =') debugPrint(position0) debugPrint(position1)
        print('tangent0, tangent1 =') debugPrint(tangent0) debugPrint(tangent1)
        print('getNodeBetween: ', 'length =', length or 'NIL')
    end

    -- print('baseEdge =') debugPrint(baseEdge)
    -- print('baseNode0 =') debugPrint(baseNode0)
    -- print('baseNode1 =') debugPrint(baseNode1)
    -- Now I solve the system for x:
    -- a + b l0 + c l0^2 + d l0^3 = posX0
    -- a + b l1 + c l1^2 + d l1^3 = posX1
    -- b + 2 c l0 + 3 d l0^2 = tanX0 / length
    -- b + 2 c l1 + 3 d l1^2 = tanX1 / length
    local aX = position0.x
    local bX = tangent0.x / length
    -- I am left with:
    -- a + b l1 + c l1^2 + d l1^3 = posX1
    -- b + 2 c l1 + 3 d l1^2 = tanX1 / length
    -- =>
    -- c l1^2 + d l1^3 = posX1 - a - b l1
    -- 2 c l1 + 3 d l1^2 = tanX1 / length - b
    -- =>
    -- c length^2 + d length^3 = posX1 - a - b length
    -- 2 c length + 3 d length^2 = tanX1 / length - b
    -- =>
    -- 2 c length^2 + 2 d length^3 = 2 posX1 - 2 a - 2 b length
    -- 2 c length^2 + 3 d length^3 = tanX1 - b length
    -- =>
    -- d length^3 = tanX1 - b length - 2 posX1 + 2 a + 2 b length
    -- =>
    -- d length^3 = tanX1 - 2 posX1 + 2 a + b length
    -- =>
    -- d = (tanX1 - 2 posX1 + 2 a + b length) / length^3
    local dX = (tangent1.x - 2 * position1.x + 2 * aX + bX * length) / length / length / length
    -- =>
    -- c length^2 + d length^3 = posX1 - a - b length
    -- =>
    -- c length^2 = posX1 - a - b length - d length^3
    -- =>
    -- c = posX1 / length^2 - a / length^2 - b / length - d length
    local cX = (position1.x - aX) / length / length - bX / length - dX * length

    local testX = aX + bX * length + cX * length * length + dX * length * length * length
    -- print(testX, 'should be', position1.x)
    if not(helper.isNumVeryClose(testX, position1.x, 3)) then
        if isExtendedLog then
            print('getNodeBetween WARNING: Xs are not close enough:', testX, position1.x)
        end
        return nil
    end

    local aY = position0.y
    local bY = tangent0.y / length
    local dY = (tangent1.y - 2 * position1.y + 2 * aY + bY * length) / length / length / length
    local cY = (position1.y - aY) / length / length - bY / length - dY * length

    local testY = aY + bY * length + cY * length * length + dY * length * length * length
    -- print(testY, 'should be', position1.y)
    if not(helper.isNumVeryClose(testY, position1.y, 3)) then
        if isExtendedLog then
            print('getNodeBetween WARNING: Ys are not close enough:', testY, position1.y)
        end
        return nil
    end

    local aZ = position0.z
    local bZ = tangent0.z / length
    local dZ = (tangent1.z - 2 * position1.z + 2 * aZ + bZ * length) / length / length / length
    local cZ = (position1.z - aZ) / length / length - bZ / length - dZ * length

    local testZ = aZ + bZ * length + cZ * length * length + dZ * length * length * length
    -- print(testZ, 'should be', position1.z)
    if not(helper.isNumVeryClose(testZ, position1.z, 3)) then
        if isExtendedLog then
            print('getNodeBetween WARNING: Zs are not close enough:', testZ, position1.z)
        end
        return nil
    end

    local lMid = shift0To1 * length
    local result = {
        refDistance0 = length * shift0To1,
        refPosition0 = {
            x = position0.x,
            y = position0.y,
            z = position0.z,
        },
        refTangent0 = {
            x = tangent0.x,
            y = tangent0.y,
            z = tangent0.z,
        },
        refDistance1 = length * (1 - shift0To1),
        refPosition1 = {
            x = position1.x,
            y = position1.y,
            z = position1.z,
        },
        refTangent1 = {
            x = tangent1.x,
            y = tangent1.y,
            z = tangent1.z,
        },
        refLength = length,
        -- length0 = length * shift0To1,
        -- length1 = length * (1 - shift0To1),
        position = {
            x = aX + bX * lMid + cX * lMid * lMid + dX * lMid * lMid * lMid,
            y = aY + bY * lMid + cY * lMid * lMid + dY * lMid * lMid * lMid,
            z = aZ + bZ * lMid + cZ * lMid * lMid + dZ * lMid * lMid * lMid
        },
        -- LOLLO NOTE these are real derivatives, they make no sense for a single point, so we normalise them
        tangent = helper.getVectorNormalised({
            x = bX + 2 * cX * lMid + 3 * dX * lMid * lMid,
            y = bY + 2 * cY * lMid + 3 * dY * lMid * lMid,
            z = bZ + 2 * cZ * lMid + 3 * dZ * lMid * lMid,
        })
    }
    -- print('getNodeBetween result =') debugPrint(result)
    return result
end

helper.getNodeBetween = function(position0, position1, tangent0, tangent1, shift0To1, edgeLength, isExtendedLog)
    return _getNodeBetween(position0, position1, tangent0, tangent1, shift0To1, edgeLength, isExtendedLog)
end

helper.getNodeBetweenByPercentageShift = function(edgeId, shift0To1, isExtendedLog)
    if not(helper.isValidAndExistingId(edgeId)) then return nil end

    if type(shift0To1) ~= 'number' or shift0To1 < 0 or shift0To1 > 1 then shift0To1 = 0.5 end

    local baseEdge = api.engine.getComponent(edgeId, api.type.ComponentType.BASE_EDGE)
    if baseEdge == nil then return nil end

    local baseNode0 = api.engine.getComponent(baseEdge.node0, api.type.ComponentType.BASE_NODE)
    local baseNode1 = api.engine.getComponent(baseEdge.node1, api.type.ComponentType.BASE_NODE)
    if baseNode0 == nil or baseNode1 == nil then return nil end

    -- if helper.getEdgeLength(edgeId) <= 0 then return nil end

    local edgeLength = helper.getEdgeLength(edgeId)

    return helper.getNodeBetween(baseNode0.position, baseNode1.position, baseEdge.tangent0, baseEdge.tangent1, shift0To1, edgeLength, isExtendedLog)
end

helper.getNodeBetweenByPosition = function(edgeId, position, isExtendedLog)
    if not(helper.isValidAndExistingId(edgeId)) then return nil end

    if position == nil or (position[1] == nil and position.x == nil) or (position[2] == nil and position.y == nil) or (position[3] == nil and position.z == nil)
    then return nil end

    local baseEdge = api.engine.getComponent(edgeId, api.type.ComponentType.BASE_EDGE)
    if baseEdge == nil then return nil end

    local baseNode0 = api.engine.getComponent(baseEdge.node0, api.type.ComponentType.BASE_NODE)
    local baseNode1 = api.engine.getComponent(baseEdge.node1, api.type.ComponentType.BASE_NODE)
    if baseNode0 == nil or baseNode1 == nil then return nil end

    local length0 = helper.getVectorLength({
        x = (position[1] or position.x) - baseNode0.position.x,
        y = (position[2] or position.y) - baseNode0.position.y,
        z = (position[3] or position.z) - baseNode0.position.z,
    })
    local length1 = helper.getVectorLength({
        x = (position[1] or position.x) - baseNode1.position.x,
        y = (position[2] or position.y) - baseNode1.position.y,
        z = (position[3] or position.z) - baseNode1.position.z,
    })
    local edgeLength = helper.getEdgeLength(edgeId)

    if isExtendedLog then
        print('getNodeBetweenByPosition firing')
        print('baseNode0.position =') debugPrint(baseNode0.position)
        print('baseNode1.position =') debugPrint(baseNode1.position)
        print('baseEdge.tangent0 =') debugPrint(baseEdge.tangent0)
        print('baseEdge.tangent1 =') debugPrint(baseEdge.tangent1)
        print('length0 =', length0 or 'NIL')
        print('length1 =', length1 or 'NIL')
        print('length0 / (length0 + length1) =', length0 / (length0 + length1))
        print('edgeLength =', edgeLength or 'NIL')
        print('getNodeBetween about to fire')
    end

    if edgeLength == nil or length0 == nil or length1 == nil then return nil end

    local lengthAdjustment = edgeLength / (length0 + length1)
    length0, length1 = length0 * lengthAdjustment, length1 * lengthAdjustment

    return helper.getNodeBetween(baseNode0.position, baseNode1.position, baseEdge.tangent0, baseEdge.tangent1, length0 / (length0 + length1), edgeLength, isExtendedLog)
end

helper.getNodeBetweenOLD = function(position0, tangent0, position1, tangent1, betweenPosition)
    if not(position0) or not(position1) or not(tangent0) or not(tangent1) then return nil end

    -- local node01Distance = helper.getVectorLength({
    --     position1.x - position0.x,
    --     position1.y - position0.y,
    --     position1.z - position0.z
    -- })
    -- if node01Distance == 0 then return nil end

    local node01DistanceXY = helper.getVectorLength({
        position1.x - position0.x,
        position1.y - position0.y,
        0.0
    })
    if node01DistanceXY == 0 then return nil end

    if type(betweenPosition) ~= 'table' then
        betweenPosition = {
            x = (position0.x + position1.x) * 0.5,
            y = (position0.y + position1.y) * 0.5,
            z = (position0.z + position1.z) * 0.5,
        }
    end

    local x20Shift = helper.getVectorLength(
        {
            betweenPosition.x - position0.x,
            betweenPosition.y - position0.y,
            -- betweenPosition.z - position0.z
            0.0
        }
    ) / node01DistanceXY
    -- print('x20Shift =', x20Shift or 'NIL')
    -- shift everything around betweenPosition to avoid large numbers being summed and subtracted
    local x0 = position0.x - betweenPosition.x
    local x1 = position1.x - betweenPosition.x
    local y0 = position0.y - betweenPosition.y
    local y1 = position1.y - betweenPosition.y
    local ypsilon0 = math.atan2(tangent0.y, tangent0.x)
    local ypsilon1 = math.atan2(tangent1.y, tangent1.x)
    local z0 = position0.z - betweenPosition.z
    local z1 = position1.z - betweenPosition.z
    -- rotate the edges around the Z axis so that y0 = y1
    local zRotation = -math.atan2(y1 - y0, x1 - x0)
    local x0I = x0
    local x1I = x0 + node01DistanceXY
    local y0I = y0
    local ypsilon0I = ypsilon0 + zRotation
    local ypsilon1I = ypsilon1 + zRotation
    local z0I = z0
    local z1I = z1

    local invertedXMatrix = matrixUtils.invert(
        {
            {1, x0I, x0I * x0I, x0I * x0I * x0I},
            {1, x1I, x1I * x1I, x1I * x1I * x1I},
            {0, 1, 2 * x0I, 3 * x0I * x0I},
            {0, 1, 2 * x1I, 3 * x1I * x1I}
        }
    )

    if not(invertedXMatrix) then return nil end -- if x0 == x1 the system cannot be solved, this is why I rotated it. If it still fails, reject.

    local _maxTangent = 3 -- node01DistanceXY * 0.3 -- 5 -- this is tricky. In edge cases, I will be approximating a U or a J with a polynom.
    -- That means, the bottom tip of the U or the bottom tip of the J will be infinitely far away from its top.
    -- This factor keeps the curve in shape, but it must have the right sign. Beyond that, I can reject or bodge.
    -- Also, tangents have a discontinuity at +/- PI/2: bodging could get tricky
    -- AN idea could be: replace the equation with the large tangent with one based on the position the user clicked.
    local tanY0I = math.tan(ypsilon0I)
    if math.abs(tanY0I) > _maxTangent then return nil end
    local tanY1I = math.tan(ypsilon1I)
    if math.abs(tanY1I) > _maxTangent then return nil end

    -- Now I solve the system for y:
    -- a + b x0' + c x0'^2 + d x0'^3 = y0'
    -- a + b x1' + c x1'^2 + d x1'^3 = y0' .. y0' == y1' by construction
    -- b + 2 c x0' + 3 d x0'^2 = sin0' / cos0'
    -- b + 2 c x1' + 3 d x1'^2 = sin1' / cos1'
    local abcdY = matrixUtils.mul(
        invertedXMatrix,
        {
            {y0I},
            {y0I},
            {tanY0I},
            {tanY1I}
        }
    )
    local aY = abcdY[1][1]
    local bY = abcdY[2][1]
    local cY = abcdY[3][1]
    local dY = abcdY[4][1]

    -- Now I solve the system for z:
    -- a + b x0' + c x0'^2 + d x0'^3 = z0'
    -- a + b x1' + c x1'^2 + d x1'^3 = z1'
    -- b + 2 c x0' + 3 d x0'^2 = sin0' / cos0'
    -- b + 2 c x1' + 3 d x1'^2 = sin1' / cos1'
    local abcdZ = matrixUtils.mul(
        invertedXMatrix,
        {
            {z0I},
            {z1I},
            {tangent0.z / helper.getVectorLength({tangent0.x, tangent0.y, 0.0})},
            {tangent1.z / helper.getVectorLength({tangent1.x, tangent1.y, 0.0})},
        }
    )
    local aZ = abcdZ[1][1]
    local bZ = abcdZ[2][1]
    local cZ = abcdZ[3][1]
    local dZ = abcdZ[4][1]

    -- Now I take x2' between x0' and x1',
    local x2I = x0I + (x1I - x0I) * x20Shift
    local y2I = aY + bY * x2I + cY * x2I * x2I + dY * x2I * x2I * x2I
    local z2I = aZ + bZ * x2I + cZ * x2I * x2I + dZ * x2I * x2I * x2I
    -- calculate its y derivative:
    local DYOnDX2I = bY + 2 * cY * x2I + 3 * dY * x2I * x2I
    local ypsilon2I = math.atan(DYOnDX2I)
    -- calculate its z derivative:
    local DZOnDX2I = bZ + 2 * cZ * x2I + 3 * dZ * x2I * x2I
    local zeta2I = math.atan(DZOnDX2I)

    -- Now I undo the rotation and the traslation I did at the beginning
    local ro2 = helper.getVectorLength({x2I - x0I, y2I - y0I, 0.0})
    local alpha2I = math.atan2(y2I - y0I, x2I - x0I)

    local nodeBetween = {
        position = {
            x0I + ro2 * math.cos(alpha2I - zRotation) + betweenPosition.x,
            y0I + ro2 * math.sin(alpha2I - zRotation) + betweenPosition.y,
            z2I + betweenPosition.z
        },
        tangent = {
            math.cos(ypsilon2I - zRotation),
            math.sin(ypsilon2I - zRotation),
            math.sin(zeta2I)
        }
    }

    -- normalise tangent
    local tangentLength = helper.getVectorLength(nodeBetween.tangent)
    if tangentLength ~= 0 and tangentLength ~= 1 then
        nodeBetween.tangent[1] = nodeBetween.tangent[1] / tangentLength
        nodeBetween.tangent[2] = nodeBetween.tangent[2] / tangentLength
        nodeBetween.tangent[3] = nodeBetween.tangent[3] / tangentLength
    end

    return nodeBetween
end

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

helper.getNodeIdsBetweenEdgeIds = function(edgeIds, isIncludeExclusiveOuterNodes)
    if type(edgeIds) ~= 'table' then return {} end

    local _map = api.engine.system.streetSystem.getNode2SegmentMap()
    local allNodeIds = {}
    local sharedNodeIds = {}
    for _, edgeId in pairs(edgeIds) do
        local baseEdge = api.engine.getComponent(edgeId, api.type.ComponentType.BASE_EDGE)
        if baseEdge ~= nil then
            local nEdgesAttached2Node0 = _map[baseEdge.node0]
            if nEdgesAttached2Node0 == nil then nEdgesAttached2Node0 = 2 else nEdgesAttached2Node0 = #_map[baseEdge.node0] end
            if (nEdgesAttached2Node0 == 1 and isIncludeExclusiveOuterNodes) or arrayUtils.arrayHasValue(allNodeIds, baseEdge.node0) then
                arrayUtils.addUnique(sharedNodeIds, baseEdge.node0)
            end
            local nEdgesAttached2Node1 = _map[baseEdge.node1]
            if nEdgesAttached2Node1 == nil then nEdgesAttached2Node1 = 2 else nEdgesAttached2Node1 = #_map[baseEdge.node1] end
            if (nEdgesAttached2Node1 == 1 and isIncludeExclusiveOuterNodes) or arrayUtils.arrayHasValue(allNodeIds, baseEdge.node1) then
                arrayUtils.addUnique(sharedNodeIds, baseEdge.node1)
            end
            allNodeIds[#allNodeIds+1] = baseEdge.node0
            allNodeIds[#allNodeIds+1] = baseEdge.node1
        end
    end

    return sharedNodeIds
end

helper.getNodeIdsBetweenNeighbourEdgeIds = function(edgeIds, isIncludeExclusiveOuterNodes)
    if type(edgeIds) ~= 'table' then return {} end

    local nodesBetweenEdges = {} -- nodeId, counter
    for _, edgeId in pairs(edgeIds) do -- don't use _ here, we call it below to translate the message!
        local baseEdge = api.engine.getComponent(edgeId, api.type.ComponentType.BASE_EDGE)
        if baseEdge then
            if nodesBetweenEdges[baseEdge.node0] then
                nodesBetweenEdges[baseEdge.node0] = nodesBetweenEdges[baseEdge.node0] + 1
            else
                nodesBetweenEdges[baseEdge.node0] = 1
            end
            if nodesBetweenEdges[baseEdge.node1] then
                nodesBetweenEdges[baseEdge.node1] = nodesBetweenEdges[baseEdge.node1] + 1
            else
                nodesBetweenEdges[baseEdge.node1] = 1
            end
        end
    end

    local results = {}
    for nodeId, count in pairs(nodesBetweenEdges) do
        if count > 1 or isIncludeExclusiveOuterNodes then
            results[#results+1] = nodeId
        end
    end

    -- print('getNodeIdsBetweenEdgeIds about to return') debugPrint(results)
    return results
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

    local nodeIds = { baseEdge.node0, baseEdge.node1 }

    local _map = api.engine.system.streetSystem.getNode2SegmentMap()
    local results = {}

    for _, nodeId in pairs(nodeIds) do
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

helper.isNumVeryClose = function(num1, num2, significantFigures)
    return transfUtils.isNumVeryClose(num1, num2, significantFigures)
end

helper.isXYZVeryClose = function(xyz1, xyz2, significantFigures)
    return transfUtils.isXYZVeryClose(xyz1, xyz2, significantFigures)
end

helper.isXYZCloserThan = function(xyz1, xyz2, comp)
    if (type(xyz1) ~= 'table' and type(xyz1) ~= 'userdata')
    or (type(xyz2) ~= 'table' and type(xyz2) ~= 'userdata')
    or (type(comp) ~= 'number')
    then return false end

    local X1 = xyz1.x or xyz1[1]
    local Y1 = xyz1.y or xyz1[2]
    local Z1 = xyz1.z or xyz1[3]
    local X2 = xyz2.x or xyz2[1]
    local Y2 = xyz2.y or xyz2[2]
    local Z2 = xyz2.z or xyz2[3]

    if type(X1) ~= 'number' or type(Y1) ~= 'number' or type(Z1) ~= 'number' then return false end
    if type(X2) ~= 'number' or type(Y2) ~= 'number' or type(Z2) ~= 'number' then return false end

    return transfUtils.isNumsCloserThan(X1, X2, comp)
    and transfUtils.isNumsCloserThan(Y1, Y2, comp)
    and transfUtils.isNumsCloserThan(Z1, Z2, comp)
end

helper.isXYZSame = function(xyz1, xyz2)
    if (type(xyz1) ~= 'table' and type(xyz1) ~= 'userdata')
    or (type(xyz2) ~= 'table' and type(xyz2) ~= 'userdata')
    or type(xyz1.x) ~= 'number' or type(xyz1.y) ~= 'number' or type(xyz1.z) ~= 'number'
    or type(xyz2.x) ~= 'number' or type(xyz2.y) ~= 'number' or type(xyz2.z) ~= 'number'
    then return nil end

    return xyz1.x == xyz2.x and xyz1.y == xyz2.y and xyz1.z == xyz2.z
end

helper.street = {}
helper.street.getNearestEdgeId = function(transf, minZ, maxZ)
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
        -- print('boundingVolume =')
        -- debugPrint(boundingVolume)
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
end

helper.track = {}
helper.track.getConnectedEdgeIds = function(nodeIds)
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
                    if api.engine.getComponent(edgeId, api.type.ComponentType.BASE_EDGE_TRACK) ~= nil then
                        arrayUtils.addUnique(results, edgeId)
                    end
                end
            end
        end
    end

    -- print('getConnectedEdgeIds is about to return') debugPrint(results)
    return results
end
helper.track.getContiguousEdges = function(edgeId, acceptedTrackTypes)
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
                    -- print('edgeId =')
                    -- debugPrint(_edgeId)
                    if _edgeId ~= refEdgeId then
                        local baseEdgeTrack = api.engine.getComponent(_edgeId, api.type.ComponentType.BASE_EDGE_TRACK)
                        -- print('baseEdgeTrack =')
                        -- debugPrint(baseEdgeTrack)
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

    -- print('getContiguousEdges starting, edgeId =')
    -- debugPrint(edgeId)
    -- print('track type =')
    -- debugPrint(trackType)

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
end

helper.track.getNearestEdgeIdStrict = function(transf, minZ, maxZ)
    if type(transf) ~= 'table' then return nil end

    local _position = transfUtils.getVec123Transformed({0, 0, 0}, transf)
    -- print('position =') debugPrint(_position)
    local _searchRadius = 0.5
    local _box0 = api.type.Box3.new(
        api.type.Vec3f.new(_position[1] - _searchRadius, _position[2] - _searchRadius, minZ or -9999),
        api.type.Vec3f.new(_position[1] + _searchRadius, _position[2] + _searchRadius, maxZ or 9999)
    )
    local baseEdgeIds = {}
    local callback0 = function(entity, boundingVolume)
        -- print('callback0 found entity', entity)
        -- print('boundingVolume =')
        -- debugPrint(boundingVolume)
        if not(entity) then return end

        if not(api.engine.getComponent(entity, api.type.ComponentType.BASE_EDGE)) then return end
        -- print('the entity is a BASE_EDGE')

        baseEdgeIds[#baseEdgeIds+1] = entity
    end
    api.engine.system.octreeSystem.findIntersectingEntities(_box0, callback0)

    if #baseEdgeIds == 0 then
        return nil
        -- LOLLO NOTE comment this out to make it less strict
    -- elseif #baseEdgeIds == 1 then
    --     return baseEdgeIds[1]
    else
        -- print('multiple base edges found')
        -- choose one edge and return its id

        for i = 1, #baseEdgeIds do
            local baseEdge = api.engine.getComponent(baseEdgeIds[i], api.type.ComponentType.BASE_EDGE)
            local baseEdgeTrack = api.engine.getComponent(baseEdgeIds[i], api.type.ComponentType.BASE_EDGE_TRACK)
            if baseEdge ~= nil and baseEdgeTrack ~= nil then -- false when there is a modded road that underwent a breaking change
                local node0 = api.engine.getComponent(baseEdge.node0, api.type.ComponentType.BASE_NODE)
                local node1 = api.engine.getComponent(baseEdge.node1, api.type.ComponentType.BASE_NODE)
                local trackTypeProperties = api.res.trackTypeRep.get(baseEdgeTrack.trackType)
                local halfTrackWidth = (trackTypeProperties.shapeWidth or 0) * 0.5
                local alpha = math.atan2(node1.position.y - node0.position.y, node1.position.x - node0.position.x)
                local xPlus = - math.sin(alpha) * halfTrackWidth
                local yPlus = math.cos(alpha) * halfTrackWidth
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

        -- another way to do the same, but wrong
        -- for i = 1, #baseEdgeIds do
        --     local baseEdge = api.engine.getComponent(baseEdgeIds[i], api.type.ComponentType.BASE_EDGE)
        --     local baseEdgeTrack = api.engine.getComponent(baseEdgeIds[i], api.type.ComponentType.BASE_EDGE_TRACK)
        --     if baseEdge ~= nil and baseEdgeTrack ~= nil then -- false when there is a modded road that underwent a breaking change
        --         -- local node0 = api.engine.getComponent(baseEdge.node0, api.type.ComponentType.BASE_NODE)
        --         -- local node1 = api.engine.getComponent(baseEdge.node1, api.type.ComponentType.BASE_NODE)
        --         local trackTypeProperties = api.res.trackTypeRep.get(baseEdgeTrack.trackType)
        --         local halfTrackWidth = (trackTypeProperties.shapeWidth or 0) * 0.5

        --         local testPosition = transfUtils.transf2Position(transf, true)
        --         local nodeBetween = helper.getNodeBetweenByPosition(baseEdgeIds[i], testPosition)
        --         if nodeBetween ~= nil and nodeBetween.length0 ~= 0 and nodeBetween.length1 ~= 0 and nodeBetween.position ~= nil then
        --             local distance = helper.getVectorLength({
        --                 nodeBetween.position.x - testPosition.x,
        --                 nodeBetween.position.y - testPosition.y,
        --                 nodeBetween.position.z - testPosition.z,
        --             })
        --             if distance <= halfTrackWidth then return baseEdgeIds[i] end
        --         end
        --     end
        -- end
        print('track.getNearestEdgeIdStrict falling back, could not find an edge covering the position')
        return baseEdgeIds[1] -- fallback
    end
end

return helper
