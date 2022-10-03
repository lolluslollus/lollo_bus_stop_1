local utils = {}

utils.getVerticesSortedClockwise = function(unsorted)
    local indexes = {
        topLeft = 1,
        topRight = -1,
        bottomRight = -1,
        bottomLeft = -1
    }
    -- find the highest of the leftmost points
    for i = 2, 4 do
        if unsorted[i].x < unsorted[indexes.topLeft].x then
            indexes.topLeft = i
        elseif unsorted[i].x == unsorted[indexes.topLeft].x then
            if unsorted[i].y > unsorted[indexes.topLeft].y then
                indexes.topLeft = i
            end
        end
    end

    -- now find the second point clockwise
    local lastTan = -math.huge
    for i = 1, 4 do
        if i ~= indexes.topLeft and unsorted[i].x > unsorted[indexes.topLeft].x then
            local newTan = (unsorted[i].y - unsorted[indexes.topLeft].y) / (unsorted[i].x - unsorted[indexes.topLeft].x)
            if newTan > lastTan then
                lastTan = newTan
                indexes.topRight = i
            elseif newTan == lastTan
            and indexes.topRight > 0
            and unsorted[i].x < unsorted[indexes.topRight].x then
                indexes.topRight = i
            end
        end
    end
    if indexes.topRight == -1 then return nil end

    -- now find the third point clockwise
    local lastAtan = -2 * math.pi
    for i = 1, 4 do
        if i ~= indexes.topLeft and i ~= indexes.topRight then
            local newAtan = math.atan2(
                unsorted[i].y - unsorted[indexes.topRight].y,
                unsorted[i].x - unsorted[indexes.topRight].x
            )
            if newAtan == false then -- edge case: two points are equal
                indexes.bottomRight = i
                break
            else
                if newAtan > lastAtan then
                    lastAtan = newAtan
                    indexes.bottomRight = i
                elseif newAtan == lastAtan
                and indexes.bottomRight > 0
                and unsorted[i].x < unsorted[indexes.bottomRight].x then
                    indexes.bottomRight = i
                end
            end
        end
    end
    if indexes.bottomRight == -1 then return nil end

    for i = 1, 4 do
        if i ~= indexes.topLeft and i ~= indexes.topRight and i ~= indexes.bottomRight then
            indexes.bottomLeft = i
            break
        end
    end

    local result = {
        topLeft = unsorted[indexes.topLeft],
        topRight = unsorted[indexes.topRight],
        bottomRight = unsorted[indexes.bottomRight],
        bottomLeft = unsorted[indexes.bottomLeft],
    }
    return result
end

local function _getMidPoint(sortedVertices)
    local midPoint1 = {
        x = (sortedVertices.topLeft.x + sortedVertices.bottomRight.x) * 0.5,
        y = (sortedVertices.topLeft.y + sortedVertices.bottomRight.y) * 0.5,
    }
    local midPoint2 = {
        x = (sortedVertices.topRight.x + sortedVertices.bottomLeft.x) * 0.5,
        y = (sortedVertices.topRight.y + sortedVertices.bottomLeft.y) * 0.5,
    }
    local midPoint = {
        x = (midPoint1.x + midPoint2.x) * 0.5,
        y = (midPoint1.y + midPoint2.y) * 0.5,
    }
    return midPoint
end

utils.getIsPointWithin = function(sortedVertices, pointToCheck)
    if not(sortedVertices) or not(pointToCheck) then return false end

    local point2Check = {
        x = pointToCheck.x or pointToCheck[1],
        y = pointToCheck.y or pointToCheck[2]
    }
    -- print('thinking')
    -- local test = sortedVertices.topLeft.x
    -- print('KKKKKK')
    -- local test2 = sortedVertices.topLeft.x + sortedVertices.bottomRight.x
    -- print('HHHHHHHHHHHHHHHH')
    local midPoint = _getMidPoint(sortedVertices)
    -- print('still thinking')
    -- debugPrint(midPoint)
    -- y = a + bx
    -- y0 = a + b * x0
    -- y1 = a + b * x1
    -- y0 - y1 = b * (x0 - x1)  =>  b = (y0 - y1) / (x0 - x1)
    -- a = y0 - b * x0
    if sortedVertices.topLeft.x == sortedVertices.topRight.x then
        if sortedVertices.topLeft.y ~= sortedVertices.topRight.y then
            if (sortedVertices.topLeft.x > point2Check.x) ~= (sortedVertices.topLeft.x > midPoint.x)
            then return false end
        end
    else
        local b = (sortedVertices.topLeft.y - sortedVertices.topRight.y) / (sortedVertices.topLeft.x - sortedVertices.topRight.x)
        local a = sortedVertices.topLeft.y - b * sortedVertices.topLeft.x
        if (point2Check.y > (a + b * point2Check.x)) ~= (midPoint.y > (a + b * midPoint.x)) then return false end
    end

    if sortedVertices.topRight.x == sortedVertices.bottomRight.x then
        if sortedVertices.topRight.y ~= sortedVertices.bottomRight.y then
            if (sortedVertices.topRight.x > point2Check.x) ~= (sortedVertices.topRight.x > midPoint.x)
            then return false end
        end
    else
        local b = (sortedVertices.topRight.y - sortedVertices.bottomRight.y) / (sortedVertices.topRight.x - sortedVertices.bottomRight.x)
        local a = sortedVertices.topRight.y - b * sortedVertices.topRight.x
        if (point2Check.y > (a + b * point2Check.x)) ~= (midPoint.y > (a + b * midPoint.x)) then return false end
    end

    if sortedVertices.bottomRight.x == sortedVertices.bottomLeft.x then
        if sortedVertices.bottomRight.y ~= sortedVertices.bottomLeft.y then
            if (sortedVertices.bottomRight.x < point2Check.x) ~= (sortedVertices.bottomRight.x < midPoint.x)
            then return false end
        end
    else
        local b = (sortedVertices.bottomRight.y - sortedVertices.bottomLeft.y) / (sortedVertices.bottomRight.x - sortedVertices.bottomLeft.x)
        local a = sortedVertices.bottomRight.y - b * sortedVertices.bottomRight.x
        if (point2Check.y < (a + b * point2Check.x)) ~= (midPoint.y < (a + b * midPoint.x)) then return false end
    end

    if sortedVertices.bottomLeft.x == sortedVertices.topLeft.x then
        if sortedVertices.bottomLeft.y ~= sortedVertices.topLeft.y then
            if (sortedVertices.bottomLeft.x < point2Check.x) ~= (sortedVertices.bottomLeft.x < midPoint.x)
            then return false end
        end
    else
        local b = (sortedVertices.bottomLeft.y - sortedVertices.topLeft.y) / (sortedVertices.bottomLeft.x - sortedVertices.topLeft.x)
        local a = sortedVertices.bottomLeft.y - b * sortedVertices.bottomLeft.x
        if (point2Check.y < (a + b * point2Check.x)) ~= (midPoint.y < (a + b * midPoint.x)) then return false end
    end

    return true
end

return utils