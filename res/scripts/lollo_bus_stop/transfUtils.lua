local matrixUtils = require('lollo_lorry_station.matrix')

local utils = {}

local _getMatrix = function(transf)
    return {
        {
            transf[1],
            transf[5],
            transf[9],
            transf[13]
        },
        {
            transf[2],
            transf[6],
            transf[10],
            transf[14]
        },
        {
            transf[3],
            transf[7],
            transf[11],
            transf[15]
        },
        {
            transf[4],
            transf[8],
            transf[12],
            transf[16]
        }
    }
end

local _getTransf = function(mtx)
    return {
        mtx[1][1],
        mtx[2][1],
        mtx[3][1],
        mtx[4][1],
        mtx[1][2],
        mtx[2][2],
        mtx[3][2],
        mtx[4][2],
        mtx[1][3],
        mtx[2][3],
        mtx[3][3],
        mtx[4][3],
        mtx[1][4],
        mtx[2][4],
        mtx[3][4],
        mtx[4][4]
    }
end

utils.flipXYZ = function(m)
    return {
        -m[1],
        -m[2],
        -m[3],
        m[4],
        -m[5],
        -m[6],
        -m[7],
        m[8],
        -m[9],
        -m[10],
        -m[11],
        m[12],
        -m[13],
        -m[14],
        -m[15],
        m[16]
    }
end

-- utils.mul = function(m1, m2)
--     -- returns the product of two 1x16 vectors
--     local m = function(line, col)
--         local l = (line - 1) * 4
--         return m1[l + 1] * m2[col + 0] + m1[l + 2] * m2[col + 4] + m1[l + 3] * m2[col + 8] + m1[l + 4] * m2[col + 12]
--     end
--     return {
--         m(1, 1),
--         m(1, 2),
--         m(1, 3),
--         m(1, 4),
--         m(2, 1),
--         m(2, 2),
--         m(2, 3),
--         m(2, 4),
--         m(3, 1),
--         m(3, 2),
--         m(3, 3),
--         m(3, 4),
--         m(4, 1),
--         m(4, 2),
--         m(4, 3),
--         m(4, 4)
--     }
-- end

utils.getInverseTransf = function(transf)
    local matrix = _getMatrix(transf)
    local invertedMatrix = matrixUtils.invert(matrix)
    return _getTransf(invertedMatrix)
end

-- -- what I imagined first
-- results.getVecTransformed = function(vec, transf)
--     return {
--         x = vec.x * transf[1] + vec.y * transf[2] + vec.z * transf[3] + transf[13],
--         y = vec.x * transf[5] + vec.y * transf[6] + vec.z * transf[7] + transf[14],
--         z = vec.x * transf[9] + vec.y * transf[10] + vec.z * transf[11] + transf[15],
--     }
-- end

-- what coor does, and it makes more sense
utils.getVecTransformed = function(vecXYZ, transf)
    return {
        x = vecXYZ.x * transf[1] + vecXYZ.y * transf[5] + vecXYZ.z * transf[9] + transf[13],
        y = vecXYZ.x * transf[2] + vecXYZ.y * transf[6] + vecXYZ.z * transf[10] + transf[14],
        z = vecXYZ.x * transf[3] + vecXYZ.y * transf[7] + vecXYZ.z * transf[11] + transf[15]
    }
end

utils.getSkewTransf = function(oldPosNW, oldPosNE, oldPosSE, oldPosSW, newPosNW, newPosNE, newPosSE, newPosSW)
    -- oldPosNW.x * transf[1] + oldPosNW.y * transf[5] + oldPosNW.z * transf[9] + transf[13] = newPosNW.x
    -- oldPosNW.x * transf[2] + oldPosNW.y * transf[6] + oldPosNW.z * transf[10] + transf[14] = newPosNW.y
    -- oldPosNW.x * transf[3] + oldPosNW.y * transf[7] + oldPosNW.z * transf[11] + transf[15] = newPosNW.z

    -- oldPosNE.x * transf[1] + oldPosNE.y * transf[5] + oldPosNE.z * transf[9] + transf[13] = newPosNE.x
    -- oldPosNE.x * transf[2] + oldPosNE.y * transf[6] + oldPosNE.z * transf[10] + transf[14] = newPosNE.y
    -- oldPosNE.x * transf[3] + oldPosNE.y * transf[7] + oldPosNE.z * transf[11] + transf[15] = newPosNE.z

    -- oldPosSE.x * transf[1] + oldPosSE.y * transf[5] + oldPosSE.z * transf[9] + transf[13] = newPosSE.x
    -- oldPosSE.x * transf[2] + oldPosSE.y * transf[6] + oldPosSE.z * transf[10] + transf[14] = newPosSE.y
    -- oldPosSE.x * transf[3] + oldPosSE.y * transf[7] + oldPosSE.z * transf[11] + transf[15] = newPosSE.z

    -- oldPosSW.x * transf[1] + oldPosSW.y * transf[5] + oldPosSW.z * transf[9] + transf[13] = newPosSW.x
    -- oldPosSW.x * transf[2] + oldPosSW.y * transf[6] + oldPosSW.z * transf[10] + transf[14] = newPosSW.y
    -- oldPosSW.x * transf[3] + oldPosSW.y * transf[7] + oldPosSW.z * transf[11] + transf[15] = newPosSW.z

    -- 12 equations, 12 unknowns, it could work

    local matrix = {
        { oldPosNW.x, 0, 0,  oldPosNW.y, 0, 0,  oldPosNW.z, 0, 0,  1, 0, 0 },
        { oldPosNE.x, 0, 0,  oldPosNE.y, 0, 0,  oldPosNE.z, 0, 0,  1, 0, 0 },
        { oldPosSE.x, 0, 0,  oldPosSE.y, 0, 0,  oldPosSE.z, 0, 0,  1, 0, 0 },
        { oldPosSW.x, 0, 0,  oldPosSW.y, 0, 0,  oldPosSW.z, 0, 0,  1, 0, 0 },

        { 0, oldPosNW.x, 0,  0, oldPosNW.y, 0,  0, oldPosNW.z, 0,  0, 1, 0 },
        { 0, oldPosNE.x, 0,  0, oldPosNE.y, 0,  0, oldPosNE.z, 0,  0, 1, 0 },
        { 0, oldPosSE.x, 0,  0, oldPosSE.y, 0,  0, oldPosSE.z, 0,  0, 1, 0 },
        { 0, oldPosSW.x, 0,  0, oldPosSW.y, 0,  0, oldPosSW.z, 0,  0, 1, 0 },

        { 0, 0, oldPosNW.x,  0, 0, oldPosNW.y,  0, 0, oldPosNW.z,  0, 0, 1 },
        { 0, 0, oldPosNE.x,  0, 0, oldPosNE.y,  0, 0, oldPosNE.z,  0, 0, 1 },
        { 0, 0, oldPosSE.x,  0, 0, oldPosSE.y,  0, 0, oldPosSE.z,  0, 0, 1 },
        { 0, 0, oldPosSW.x,  0, 0, oldPosSW.y,  0, 0, oldPosSW.z,  0, 0, 1 },
    }

    -- M * transf = newPos => Minv * M * transf = Minv * newPos => transf = Minv * newPos
    -- sadly, it does not work: the matrix has rank 6
    local invertedMatrix = matrixUtils.invert(matrix)
    if invertedMatrix == nil then return nil end

    local bitsOfTransf = matrixUtils.mul(
        invertedMatrix,
        {
            {newPosNW.x},
            {newPosNE.x},
            {newPosSE.x},
            {newPosSW.x},

            {newPosNW.y},
            {newPosNE.y},
            {newPosSE.y},
            {newPosSW.y},

            {newPosNW.z},
            {newPosNE.z},
            {newPosSE.z},
            {newPosSW.z},
        }
    )

    local result = {
        bitsOfTransf[1], bitsOfTransf[2], bitsOfTransf[3], 0,
        bitsOfTransf[4], bitsOfTransf[5], bitsOfTransf[6], 0,
        bitsOfTransf[7], bitsOfTransf[8], bitsOfTransf[9], 0,
        bitsOfTransf[10], bitsOfTransf[11], bitsOfTransf[12], 1,
    }
    return result
end

utils.getVec123Transformed = function(vec123, transf)
    return {
        vec123[1] * transf[1] + vec123[2] * transf[5] + vec123[3] * transf[9] + transf[13],
        vec123[1] * transf[2] + vec123[2] * transf[6] + vec123[3] * transf[10] + transf[14],
        vec123[1] * transf[3] + vec123[2] * transf[7] + vec123[3] * transf[11] + transf[15]
    }
end

utils.getPosTanX2Transformed = function(posTanX2, transf)
    local pos1 = {posTanX2[1][1][1], posTanX2[1][1][2], posTanX2[1][1][3]}
    local pos2 = {posTanX2[2][1][1], posTanX2[2][1][2], posTanX2[2][1][3]}
    local tan1 = {posTanX2[1][2][1], posTanX2[1][2][2], posTanX2[1][2][3]}
    local tan2 = {posTanX2[2][2][1], posTanX2[2][2][2], posTanX2[2][2][3]}

    local rotateTransf = {
        transf[1], transf[2], transf[3], transf[4],
        transf[5], transf[6], transf[7], transf[8],
        transf[9], transf[10], transf[11], transf[12],
        0, 0, 0, 1
    }

    local result = {
        {
            utils.getVec123Transformed(pos1, transf),
            utils.getVec123Transformed(tan1, rotateTransf)
        },
        {
            utils.getVec123Transformed(pos2, transf),
            utils.getVec123Transformed(tan2, rotateTransf)
        }
    }
    return result
end

utils.position2Transf = function(position)
    return {
        1, 0, 0, 0,
        0, 1, 0, 0,
        0, 0, 1, 0,
        position[1] or position.x, position[2] or position.y, position[3] or position.z, 1
    }
end

utils.transf2Position = function(transf, xyzFormat)
    if xyzFormat then
        return {
            x = transf[13],
            y = transf[14],
            z = transf[15]
        }
    else
        return {
            transf[13],
            transf[14],
            transf[15]
        }
    end
end

utils.oneTwoThree2XYZ = function(arr)
    if type(arr) ~= 'table' and type(arr) ~= 'userdata' then return nil end

    return {
        x = arr[1] or arr.x,
        y = arr[2] or arr.y,
        z = arr[3] or arr.z,
    }
end

utils.xYZ2OneTwoThree = function(arr)
    if type(arr) ~= 'table' and type(arr) ~= 'userdata' then return nil end

    return {
        arr[1] or arr.x,
        arr[2] or arr.y,
        arr[3] or arr.z,
    }
end

utils.getPositionRaisedBy = function(position, raiseBy)
    -- faster than calling mul()
    if position == nil or type(raiseBy) ~= 'number' then return position end

    if position.x ~= nil and position.y ~= nil and position.z ~= nil then
        return {
            x = position.x, y = position.y, z = position.z + raiseBy
        }
    else
        return {
            position[1], position[2], position[3] + raiseBy
        }
    end
end

utils.getTransfXShiftedBy = function(transf, shift)
    -- faster than calling mul()
    if transf == nil or type(shift) ~= 'number' then return transf end

    return {
        transf[1], transf[2], transf[3], transf[4],
        transf[5], transf[6], transf[7], transf[8],
        transf[9], transf[10], transf[11], transf[12],
        transf[1] * shift + transf[13],
        transf[2] * shift + transf[14],
		transf[3] * shift + transf[15],
		transf[4] * shift + transf[16],
    }
end

utils.getTransfYShiftedBy = function(transf, shift)
    -- faster than calling mul()
    if transf == nil or type(shift) ~= 'number' then return transf end

    return {
        transf[1], transf[2], transf[3], transf[4],
        transf[5], transf[6], transf[7], transf[8],
        transf[9], transf[10], transf[11], transf[12],
        transf[5] * shift + transf[13],
        transf[6] * shift + transf[14],
		transf[7] * shift + transf[15],
		transf[8] * shift + transf[16],
    }
end

utils.getTransfZShiftedBy = function(transf, shift)
    -- faster than calling mul()
    if transf == nil or type(shift) ~= 'number' then return transf end

    return {
        transf[1], transf[2], transf[3], transf[4],
        transf[5], transf[6], transf[7], transf[8],
        transf[9], transf[10], transf[11], transf[12],
        transf[9] * shift + transf[13],
        transf[10] * shift + transf[14],
		transf[11] * shift + transf[15],
		transf[12] * shift + transf[16],
    }
end

utils.getVectorLength = function(xyz)
    if type(xyz) ~= 'table' and type(xyz) ~= 'userdata' then return nil end
    local x = xyz.x or xyz[1] or 0.0
    local y = xyz.y or xyz[2] or 0.0
    local z = xyz.z or xyz[3] or 0.0
    return math.sqrt(x * x + y * y + z * z)
end

utils.getVectorNormalised = function(xyz, targetLength)
    if type(xyz) ~= 'table' and type(xyz) ~= 'userdata' then return nil end
    if type(targetLength) == 'number' and targetLength == 0 then return { 0, 0, 0 } end

    local _oldLength = utils.getVectorLength(xyz)
    if _oldLength == 0 then return { 0, 0, 0 } end

    local _lengthFactor = (type(targetLength) == 'number' and targetLength or 1.0) / _oldLength
    if xyz.x ~= nil and xyz.y ~= nil and xyz.z ~= nil then
        return {
            x = xyz.x * _lengthFactor,
            y = xyz.y * _lengthFactor,
            z = xyz.z * _lengthFactor
        }
    else
        return {
            xyz[1] * _lengthFactor,
            xyz[2] * _lengthFactor,
            xyz[3] * _lengthFactor
        }
    end
end

utils.getPositionsDistance = function(pos0, pos1)
    local distance = utils.getVectorLength({
        (pos0.x or pos0[1]) - (pos1.x or pos1[1]),
        (pos0.y or pos0[2]) - (pos1.y or pos1[2]),
        (pos0.z or pos0[3]) - (pos1.z or pos1[3]),
    })
    return distance
end

utils.getPositionsMiddle = function(pos0, pos1)
    local midPos = {
        ((pos0.x or pos0[1]) + (pos1.x or pos1[1])) * 0.5,
        ((pos0.y or pos0[2]) + (pos1.y or pos1[2])) * 0.5,
        ((pos0.z or pos0[3]) + (pos1.z or pos1[3])) * 0.5,
    }

    if pos0.x ~= nil and pos0.y ~= nil and pos0.z ~= nil then
        return {
            x = midPos[1],
            y = midPos[2],
            z = midPos[3]
        }
    else
        return midPos
    end
end

-- the result will be identical to the original but shifted sideways
utils.getParallelSideways = function(posTanX2, sideShift)
    local result = {
        {
            {},
            posTanX2[1][2]
        },
        {
            {},
            posTanX2[2][2]
        },
    }

    local oldPos1 = posTanX2[1][1]
    local oldPos2 = posTanX2[2][1]

    local ro = math.atan2(oldPos2[2] - oldPos1[2], oldPos2[1] - oldPos1[1])

    result[1][1] = { oldPos1[1] + math.sin(ro) * sideShift, oldPos1[2] - math.cos(ro) * sideShift, oldPos1[3] }
    result[2][1] = { oldPos2[1] + math.sin(ro) * sideShift, oldPos2[2] - math.cos(ro) * sideShift, oldPos2[3] }

    return result
end

-- the result will be parallel to the original at its ends but stretched or compressed due to the shift.
utils.getParallelSidewaysWithRotZ = function(posTanX2, sideShiftOnXYPlane)
    local _rot90Transf = { 0, 1, 0, 0, -1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, }

    local oldPos1 = posTanX2[1][1]
    local oldPos2 = posTanX2[2][1]
    -- we reset Z coz we rotate around the Z axis and we want to obtain a distance on the XY plane
    local oldTan1 = {posTanX2[1][2][1], posTanX2[1][2][2], 0}
    local oldTan2 = {posTanX2[2][2][1], posTanX2[2][2][2], 0}

    local tan1RotatedAndNormalised = utils.getVectorNormalised(utils.getVec123Transformed(oldTan1, _rot90Transf), sideShiftOnXYPlane)
    local tan2RotatedAndNormalised = utils.getVectorNormalised(utils.getVec123Transformed(oldTan2, _rot90Transf), sideShiftOnXYPlane)

    local newPos1 = { oldPos1[1] + tan1RotatedAndNormalised[1], oldPos1[2] + tan1RotatedAndNormalised[2], oldPos1[3] }
    local newPos2 = { oldPos2[1] + tan2RotatedAndNormalised[1], oldPos2[2] + tan2RotatedAndNormalised[2], oldPos2[3] }
    local xRatio = (oldPos2[1] ~= oldPos1[1]) and math.abs((newPos2[1] - newPos1[1]) / (oldPos2[1] - oldPos1[1])) or nil
    local yRatio = (oldPos2[2] ~= oldPos1[2]) and math.abs((newPos2[2] - newPos1[2]) / (oldPos2[2] - oldPos1[2])) or nil
    if not(xRatio) or not(yRatio) then xRatio, yRatio = 1, 1 end
    local newTan1 = { posTanX2[1][2][1] * xRatio, posTanX2[1][2][2] * yRatio, posTanX2[1][2][3] }
    local newTan2 = { posTanX2[2][2][1] * xRatio, posTanX2[2][2][2] * yRatio, posTanX2[2][2][3] }
    local result = {
        {
            newPos1,
            newTan1,
        },
        {
            newPos2,
            newTan2,
        },
    }

    return result, xRatio, yRatio
end

utils.get1MLaneTransf = function(pos1, pos2)
    -- gets a transf to fit a 1 m long model (typically a lane) between two points
    -- using transfUtils.getVecTransformed(), solve this system:
    -- first point: 0, 0, 0 => pos1
    -- transf[13] = pos1[1]
    -- transf[14] = pos1[2]
    -- transf[15] = pos1[3]
    -- second point: 1, 0, 0 => pos2
    -- transf[1] + transf[13] = pos2[1]
    -- transf[2] + transf[14] = pos2[2]
    -- transf[3] + transf[15] = pos2[3]
    -- third point: 0, 1, 0 => pos1 + { 0, 1, 0 }
    -- transf[5] + transf[13] = pos1[1]
    -- transf[6] + transf[14] = pos1[2] + 1
    -- transf[7] + transf[15] = pos1[3]
    -- fourth point: 0, 0, 1 => pos1 + { 0, 0, 1 }
    -- transf[9] + transf[13] = pos1[1]
    -- transf[10] + transf[14] = pos1[2]
    -- transf[11] + transf[15] = pos1[3] + 1
    -- fifth point: 1, 1, 0 => pos2 + { 0, 1, 0 }
    -- transf[1] + transf[5] + transf[13] = pos2[1]
    -- transf[2] + transf[6] + transf[14] = pos2[2] + 1
    -- transf[3] + transf[7] + transf[15] = pos2[3]
    local result = {
        pos2[1] - pos1[1],
        pos2[2] - pos1[2],
        pos2[3] - pos1[3],
        0,
        0, 1, 0,
        0,
        0, 0, 1,
        0,
        pos1[1],
        pos1[2],
        pos1[3],
        1
    }
    -- print('unitaryLaneTransf =') debugPrint(result)
    return result
end

utils.get1MModelTransf = function(pos1, pos2)
    -- gets a transf to fit a 1 m long model (with a non-zero width) between two points
    -- using transfUtils.getVecTransformed(), solve this system:
    -- first point: 0, 0, 0 => pos1
    -- transf[13] = pos1[1]
    -- transf[14] = pos1[2]
    -- transf[15] = pos1[3]
    -- second point: 1, 0, 0 => pos2
    -- transf[1] + transf[13] = pos2[1]
    -- transf[2] + transf[14] = pos2[2]
    -- transf[3] + transf[15] = pos2[3]
    -- third point: 0, 1, 0 => pos1 + {(pos2[2] - pos1[2]) / xyLength, (pos1[1] - pos2[1]) / xyLength, 0}
    -- transf[5] + transf[13] = pos1[1] + (pos2[2] - pos1[2]) / xyLength
    -- transf[6] + transf[14] = pos1[2] + (pos1[1] - pos2[1]) / xyLength
    -- transf[7] + transf[15] = pos1[3]
    -- fourth point: 0, 0, 1 => pos1 + { 0, 0, 1 }
    -- transf[9] + transf[13] = pos1[1]
    -- transf[10] + transf[14] = pos1[2]
    -- transf[11] + transf[15] = pos1[3] + 1
    local xyLength = utils.getVectorLength({pos1[1] - pos2[1], pos1[2] - pos2[2], 0})
    if not(xyLength) or xyLength == 0 then return {1, 0, 0, 0,  0, 1, 0, 0,  0, 0, 1, 0,  0, 0, 0, 1} end

    local result = {
        pos2[1] - pos1[1],
        pos2[2] - pos1[2],
        pos2[3] - pos1[3],
        0,

        (pos2[2] - pos1[2]) / xyLength,
        (pos1[1] - pos2[1]) / xyLength,
        0,
        0,

        0,
        0,
        1,
        0,

        pos1[1],
        pos1[2],
        pos1[3],
        1
    }
    -- print('unitaryLaneTransf =') debugPrint(result)
    return result
end

utils.getPosTanX2Normalised = function(posTanX2, targetLength)
    local pos1 = {posTanX2[1][1][1], posTanX2[1][1][2], posTanX2[1][1][3]}
    local tan1 = utils.getVectorNormalised(posTanX2[1][2], targetLength)
    local tan2 = utils.getVectorNormalised(posTanX2[2][2], targetLength)
    local pos2 = {
        posTanX2[1][1][1] + tan1[1],
        posTanX2[1][1][2] + tan1[2],
        posTanX2[1][1][3] + tan1[3],
    }

    local result = {
        {
            pos1,
            tan1
        },
        {
            pos2,
            tan2
        }
    }
    return result
end

utils.getExtrapolatedPosTanX2Continuation = function(posTanX2, length)
    if length == 0 then
        return posTanX2
    -- elseif length > 0 then
    else
        local oldPos2 = {posTanX2[2][1][1], posTanX2[2][1][2], posTanX2[2][1][3]}
        local newTan = utils.getVectorNormalised(posTanX2[2][2], length)

        local result = {
            {
                oldPos2,
                newTan
            },
            {
                {
                    oldPos2[1] + newTan[1],
                    oldPos2[2] + newTan[2],
                    oldPos2[3] + newTan[3],
                },
                newTan
            }
        }
        return result
    end
end

utils.getExtrapolatedPosX2Continuation = function(pos1, pos2, length)
    if length == 0 then
        return pos2
    -- elseif length > 0 then
    else
        local pos3Delta = utils.getVectorNormalised(
            {
                pos2[1] - pos1[1],
                pos2[2] - pos1[2],
                pos2[3] - pos1[3],
            },
            length
        )
        return {
            pos2[1] + pos3Delta[1],
            pos2[2] + pos3Delta[2],
            pos2[3] + pos3Delta[3],
        }
    end
end

utils.getPosTanX2Reversed = function(posTanX2)
    if type(posTanX2) ~= 'table' then return posTanX2 end

    return {
        {
            {
                posTanX2[2][1][1], posTanX2[2][1][2], posTanX2[2][1][3],
            },
            {
                -posTanX2[2][2][1], -posTanX2[2][2][2], -posTanX2[2][2][3],
            },
        },
        {
            {
                posTanX2[1][1][1], posTanX2[1][1][2], posTanX2[1][1][3],
            },
            {
                -posTanX2[1][2][1], -posTanX2[1][2][2], -posTanX2[1][2][3],
            },
        },
    }
end

--#region very close
-- "%." .. math.floor(significantFigures) .. "g"
-- we make the array for performance reasons
local _isVeryCloseFormatStrings = {
    "%.1g",
    "%.2g",
    "%.3g",
    "%.4g",
    "%.5g",
    "%.6g",
    "%.7g",
    "%.8g",
    "%.9g",
    "%.10g",
}
-- 1 + 10^(-significantFigures +1) -- 1.01 with 3 significant figures, 1.001 with 4, etc
-- we make the array for performance reasons
local _isVeryCloseTesters = {
    1.1,
    1.01,
    1.001,
    1.0001,
    1.00001,
    1.000001,
    1.0000001,
    1.00000001,
    1.000000001,
    1.0000000001,
}
local _getVeryCloseResult1 = function(num1, num2, significantFigures)
    local _formatString = _isVeryCloseFormatStrings[significantFigures]
    local result = (_formatString):format(num1) == (_formatString):format(num2)
    return result
end
-- in the debugger this is 40 % faster than the one above and it seems more accurate
local _getVeryCloseResult2 = function(num1, num2, significantFigures)
    local result
    local exp1 = math.floor(math.log(math.abs(num1), 10))
    local exp2 = math.floor(math.log(math.abs(num2), 10))
    if exp1 ~= exp2 then
        result = false
    else
        local mant1 = math.floor(num1 * 10^(significantFigures -exp1 -1))
        local mant2 = math.floor(num2 * 10^(significantFigures -exp2 -1))
        result = mant1 == mant2
    end
    return result
end
local _isSameSgnNumVeryClose = function (num1, num2, significantFigures)
    -- local roundingFactor = _roundingFactors[significantFigures]
    -- wrong (less accurate):
    -- local roundedNum1 = math.ceil(num1 * roundingFactor)
    -- local roundedNum2 = math.ceil(num2 * roundingFactor)
    -- better:
    -- local roundedNum1 = math.floor(num1 * roundingFactor + 0.5)
    -- local roundedNum2 = math.floor(num2 * roundingFactor + 0.5)
    -- return math.floor(roundedNum1 / roundingFactor) == math.floor(roundedNum2 / roundingFactor)
    -- but what I really want are the first significant figures, never mind how big the number is

    -- LOLLO TODO decide for one when done testing
    -- local result1 = _getVeryCloseResult1(num1, num2, significantFigures)
    -- or _getVeryCloseResult1(num1 * _isVeryCloseTesters[significantFigures], num2 * _isVeryCloseTesters[significantFigures], significantFigures)

    local result2 = _getVeryCloseResult2(num1, num2, significantFigures)
    or _getVeryCloseResult2(num1 * _isVeryCloseTesters[significantFigures], num2 * _isVeryCloseTesters[significantFigures], significantFigures)

    -- if result1 ~= result2 then
    --     print('############ WARNING : _isSameSgnNumVeryClose cannot decide between num1 =', num1, 'num2 =', num2, 'significantFigures =', significantFigures)
    --     print('result1 =', result1 or 'NIL', 'result2 =', result2 or 'NIL')
    -- end

    return result2
end
utils.isNumVeryClose = function(num1, num2, significantFigures)
    if type(num1) ~= 'number' or type(num2) ~= 'number' then return false end

    if not(significantFigures) then significantFigures = 5
    elseif type(significantFigures) ~= 'number' then return false
    elseif significantFigures < 1 then return false
    elseif significantFigures > 10 then significantFigures = 10
    end

    if (num1 > 0) == (num2 > 0) then
        return _isSameSgnNumVeryClose(num1, num2, significantFigures)
    else
        local addFactor = 0
        if math.abs(num1) < math.abs(num2) then
            addFactor = num1 > 0 and -num1 or num1
        else
            addFactor = num2 > 0 and -num2 or num2
        end
        addFactor = addFactor + addFactor -- safely away from 0

        return _isSameSgnNumVeryClose(num1 + addFactor, num2 + addFactor, significantFigures)
    end
end

utils.isNumsCloserThan = function(num1, num2, comp)
    if type(num1) ~= 'number' or type(num2) ~= 'number' or type(comp) ~= 'number' then return false end

    return math.abs(num1-num2) < math.abs(comp)
end
--#endregion very close

utils.sgn = function(num)
    if tonumber(num) == nil then return nil end
    if num > 0 then return 1
    elseif num < 0 then return -1
    else return 0
    end
end

utils.getDistanceBetweenPointAndStraight = function(segmentPosition1, segmentPosition2, testPointPosition)
    -- a + bx = y
    -- => a + b * x1 = y1
    -- => a + b * x2 = y2
    -- => b * (x1 - x2) = y1 - y2
    -- => b = (y1 - y2) / (x1 - x2)
    -- OR division by zero
    -- => a = y1 - b * x1
    -- => a = y1 - (y1 - y2) / (x1 - x2) * x1
    -- a + b * xM > yM <= this is what we want to know
    -- => y1 - (y1 - y2) / (x1 - x2) * x1 + (y1 - y2) / (x1 - x2) * xM > yM
    -- => y1 * (x1 - x2) - (y1 - y2) * x1 + (y1 - y2) * xM > yM * (x1 - x2)
    -- => (y1 - yM) * (x1 - x2) + (y1 - y2) * (xM - x1) > 0

    local x1 = segmentPosition1[1] or segmentPosition1.x
    local y1 = segmentPosition1[2] or segmentPosition1.y
    local x2 = segmentPosition2[1] or segmentPosition2.x
    local y2 = segmentPosition2[2] or segmentPosition2.y
    local xM = testPointPosition[1] or testPointPosition.x
    local yM = testPointPosition[2] or testPointPosition.y
    -- print('getDistanceBetweenPointAndStraight received coords =', x1, y1, x2, y2, xM, yM)
    -- local b = (y1 - y2) / (x1 - x2)
    -- local a = y1 - (y1 - y2) / (x1 - x2) * x1

    -- local yMDist = math.abs(yM - b * xM - a) / math.sqrt(1 + b * b)
    -- local yMDist = math.abs(yM - (y1 - y2) / (x1 - x2) * xM  - y1 + (y1 - y2) / (x1 - x2) * x1) / math.sqrt(1 + (y1 - y2) / (x1 - x2) * (y1 - y2) / (x1 - x2))
    -- local yMDist = math.abs(yM - y1 + (y1 - y2) / (x1 - x2) * (x1 - xM)) / math.sqrt(1 + (y1 - y2) / (x1 - x2) * (y1 - y2) / (x1 - x2))

    -- Ax + By + C = 0
    -- dist = math.abs(A * xM + B * yM + C) / math.sqrt(A * A + B * B)
    -- => -A/B x -C/B = y
    -- => b = -A/B, a = -C/B
    -- => dist = math.abs(A/B * xM + yM + C/B) / math.sqrt(A/B * A/B + 1)
    -- => dist = math.abs(-b * xM + yM -a) / math.sqrt(b * b + 1)
    -- => dist = math.abs(-(y1 - y2) / (x1 - x2) * xM + yM -(y1 - (y1 - y2) / (x1 - x2) * x1)) / math.sqrt((y1 - y2) / (x1 - x2) * (y1 - y2) / (x1 - x2) + 1)
    -- => dist = math.abs(-(y1 - y2) / (x1 - x2) * xM + yM -y1 + (y1 - y2) / (x1 - x2) * x1) / math.sqrt((y1 - y2) / (x1 - x2) * (y1 - y2) / (x1 - x2) + 1)
    -- => dist = math.abs((y1 - y2) / (x1 - x2) * (x1 -xM ) + yM -y1) / math.sqrt((y1 - y2) / (x1 - x2) * (y1 - y2) / (x1 - x2) + 1)
    local yMDist = 0
    if x1 == x2 then
        if y1 == y2 then return utils.getPositionsDistance(segmentPosition1, testPointPosition) end
        return math.abs(x1 - xM)
    else
        return math.abs(yM - y1 + (y1 - y2) / (x1 - x2) * (x1 - xM)) / math.sqrt(1 + (y1 - y2) / (x1 - x2) * (y1 - y2) / (x1 - x2))
    end

end

return utils
