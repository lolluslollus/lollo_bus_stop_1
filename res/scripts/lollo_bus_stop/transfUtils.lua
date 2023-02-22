if math.atan2 == nil then
    math.atan2 = function(dy, dx)
        local result = 0
        if dx == 0 then
            result = math.pi * 0.5
        else
            result = math.atan(dy / dx)
        end

        if dx > 0 then
            return result
        elseif dx < 0 and dy >= 0 then
            return result + math.pi
        elseif dx < 0 and dy < 0 then
            return result - math.pi
        elseif dy > 0 then
            return result
        elseif dy < 0 then
            return - result
        else return false
        end
    end
end

local matrixUtils = require('lollo_bus_stop.matrix')

local utils = {
    --#region faster than mul()
    getTransf_XShifted = function(transf, shift)
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
    end,

    getTransf_YShifted = function(transf, shift)
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
    end,

    getTransf_ZShifted = function(transf, shift)
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
    end,
    ---@param transf table<number>
    ---@param shifts123 table<number>
    ---@return table<number>
    getTransf_Shifted = function(transf, shifts123)
        if type(transf) ~= 'table' or type(shifts123) ~= 'table' then return transf end
        local x, y, z = table.unpack(shifts123)
        -- if type(x) ~= 'number' or type[y] ~= 'number' or type(z) ~= 'number' then return transf end

        return {
            transf[1], transf[2], transf[3], transf[4],
            transf[5], transf[6], transf[7], transf[8],
            transf[9], transf[10], transf[11], transf[12],
            transf[1] * x + transf[5] * y + transf[9]  * z + transf[13],
            transf[2] * x + transf[6] * y + transf[10] * z + transf[14],
            transf[3] * x + transf[7] * y + transf[11] * z + transf[15],
            transf[4] * x + transf[8] * y + transf[12] * z + transf[16],
        }
    end,
    ---@param transf table<number>
    ---@param rotYRad number
    ---@return table<number>
    getTransf_YRotated = function(transf, rotYRad)
        if type(transf) ~= 'table' or type(rotYRad) ~= 'number' then return transf end

        local cosY, sinY = math.cos(rotYRad), math.sin(rotYRad)

        return {
            transf[1] * cosY - transf[9]  * sinY,
            transf[2] * cosY - transf[10] * sinY,
            transf[3] * cosY - transf[11] * sinY,
            transf[4] * cosY - transf[12] * sinY,
            transf[5],
            transf[6],
            transf[7],
            transf[8],
            transf[1] * sinY + transf[9]  * cosY,
            transf[2] * sinY + transf[10] * cosY,
            transf[3] * sinY + transf[11] * cosY,
            transf[4] * sinY + transf[12] * cosY,
            transf[13],
            transf[14],
            transf[15],
            transf[16],
        }
    end,
    ---@param transf table<number>
    ---@param rotZRad number
    ---@return table<number>
    getTransf_ZRotated = function(transf, rotZRad)
        if type(transf) ~= 'table' or type(rotZRad) ~= 'number' then return transf end

        local cosZ, sinZ = math.cos(rotZRad), math.sin(rotZRad)

        return {
            transf[1] * cosZ  + transf[5] * sinZ,
            transf[2] * cosZ  + transf[6] * sinZ,
            transf[3] * cosZ  + transf[7] * sinZ,
            transf[4] * cosZ  + transf[8] * sinZ,
            -transf[1] * sinZ  + transf[5] * cosZ,
            -transf[2] * sinZ  + transf[6] * cosZ,
            -transf[3] * sinZ  + transf[7] * cosZ,
            -transf[4] * sinZ  + transf[8] * cosZ,
            transf[9],
            transf[10],
            transf[11],
            transf[12],
            transf[13],
            transf[14],
            transf[15],
            transf[16],
        }
    end,
    --- faster than calling mul(transf, {0, 1, 0, 0,  -1, 0, 0, 0...})
    ---@param transf table<number>
    ---@return table<number>
    getTransf_ZRotatedP90 = function(transf)
        if type(transf) ~= 'table' then return transf end

        return {
            transf[5], transf[6], transf[7], transf[8],
            -transf[1], -transf[2], -transf[3], -transf[4],
            transf[9], transf[10], transf[11], transf[12],
            transf[13], transf[14], transf[15], transf[16],
        }
    end,
    --- faster than calling mul(transf, {0, -1, 0, 0,  1, 0, 0, 0...})
    ---@param transf table<number>
    ---@return table<number>
    getTransf_ZRotatedM90 = function(transf)
        if type(transf) ~= 'table' then return transf end

        local cosZ, sinZ = 0, -1

        return {
            -transf[5], -transf[6], -transf[7], -transf[8],
            transf[1], transf[2], transf[3], transf[4],
            transf[9], transf[10], transf[11], transf[12],
            transf[13], transf[14], transf[15], transf[16],
        }
    end,
    --- faster than calling mul(transf, {-1, 0, 0, 0,  0, -1, 0, 0...})
    ---@param transf table<number>
    ---@return table<number>
    getTransf_ZRotated180 = function(transf)
        if type(transf) ~= 'table' then return transf end

        return {
            -transf[1], -transf[2], -transf[3], -transf[4],
            -transf[5], -transf[6], -transf[7], -transf[8],
            transf[9], transf[10], transf[11], transf[12],
            transf[13], transf[14], transf[15], transf[16],
        }
    end,
    ---@param transf table<number>
    ---@param rotZRad number
    ---@param shifts123? table<number>
    ---@return table<number>
    getTransf_ZRotated_Shifted = function(transf, rotZRad, shifts123)
        if type(transf) ~= 'table' or type(rotZRad) ~= 'number' then return transf end
        local x, y, z = 0, 0, 0
        if type(shifts123) == 'table' then x, y, z = table.unpack(shifts123) end
        -- if type(x) ~= 'number' or type[y] ~= 'number' or type(z) ~= 'number' then return transf end

        local cosZ, sinZ = math.cos(rotZRad), math.sin(rotZRad)

        return {
            transf[1] * cosZ  + transf[5] * sinZ,
            transf[2] * cosZ  + transf[6] * sinZ,
            transf[3] * cosZ  + transf[7] * sinZ,
            transf[4] * cosZ  + transf[8] * sinZ,
            -transf[1] * sinZ  + transf[5] * cosZ,
            -transf[2] * sinZ  + transf[6] * cosZ,
            -transf[3] * sinZ  + transf[7] * cosZ,
            -transf[4] * sinZ  + transf[8] * cosZ,
            transf[9],
            transf[10],
            transf[11],
            transf[12],
            transf[1] * x + transf[5] * y + transf[9]  * z + transf[13],
            transf[2] * x + transf[6] * y + transf[10] * z + transf[14],
            transf[3] * x + transf[7] * y + transf[11] * z + transf[15],
            transf[4] * x + transf[8] * y + transf[12] * z + transf[16],
        }
    end,
    --- faster than calling mul(transf, {0, 1, 0, 0,  -1, 0, 0, 0...})
    ---@param transf table<number>
    ---@param shifts123? table<number>
    ---@return table<number>
    getTransf_ZRotatedP90_Shifted = function(transf, shifts123)
        if type(transf) ~= 'table' then return transf end
        local x, y, z = 0, 0, 0
        if type(shifts123) == 'table' then x, y, z = table.unpack(shifts123) end
        -- if type(x) ~= 'number' or type[y] ~= 'number' or type(z) ~= 'number' then return transf end

        return {
            transf[5], transf[6], transf[7], transf[8],
            -transf[1], -transf[2], -transf[3], -transf[4],
            transf[9], transf[10], transf[11], transf[12],
            transf[1] * x + transf[5] * y + transf[9]  * z + transf[13],
            transf[2] * x + transf[6] * y + transf[10] * z + transf[14],
            transf[3] * x + transf[7] * y + transf[11] * z + transf[15],
            transf[4] * x + transf[8] * y + transf[12] * z + transf[16],
        }
    end,
    --- faster than calling mul(transf, {0, -1, 0, 0,  1, 0, 0, 0...})
    ---@param transf table<number>
    ---@param shifts123? table<number>
    ---@return table<number>
    getTransf_ZRotatedM90_Shifted = function(transf, shifts123)
        if type(transf) ~= 'table' then return transf end
        local x, y, z = 0, 0, 0
        if type(shifts123) == 'table' then x, y, z = table.unpack(shifts123) end
        -- if type(x) ~= 'number' or type[y] ~= 'number' or type(z) ~= 'number' then return transf end

        local cosZ, sinZ = 0, -1

        return {
            -transf[5], -transf[6], -transf[7], -transf[8],
            transf[1], transf[2], transf[3], transf[4],
            transf[9], transf[10], transf[11], transf[12],
            transf[1] * x + transf[5] * y + transf[9]  * z + transf[13],
            transf[2] * x + transf[6] * y + transf[10] * z + transf[14],
            transf[3] * x + transf[7] * y + transf[11] * z + transf[15],
            transf[4] * x + transf[8] * y + transf[12] * z + transf[16],
        }
    end,
    --- faster than calling mul(transf, {-1, 0, 0, 0,  0, -1, 0, 0...})
    ---@param transf table<number>
    ---@param shifts123? table<number>
    ---@return table<number>
    getTransf_ZRotated180_Shifted = function(transf, shifts123)
        if type(transf) ~= 'table' then return transf end
        local x, y, z = 0, 0, 0
        if type(shifts123) == 'table' then x, y, z = table.unpack(shifts123) end
        -- if type(x) ~= 'number' or type[y] ~= 'number' or type(z) ~= 'number' then return transf end

        return {
            -transf[1], -transf[2], -transf[3], -transf[4],
            -transf[5], -transf[6], -transf[7], -transf[8],
            transf[9], transf[10], transf[11], transf[12],
            transf[1] * x + transf[5] * y + transf[9]  * z + transf[13],
            transf[2] * x + transf[6] * y + transf[10] * z + transf[14],
            transf[3] * x + transf[7] * y + transf[11] * z + transf[15],
            transf[4] * x + transf[8] * y + transf[12] * z + transf[16],
        }
    end,
    getTransf_XScaled = function(transf, scale)
        return {
            transf[1] * scale, transf[2] * scale, transf[3] * scale, transf[4] * scale,
            transf[5], transf[6], transf[7], transf[8],
            transf[9], transf[10], transf[11], transf[12],
            transf[13], transf[14], transf[15], transf[16]
        }
    end,
    getTransf_YScaled = function(transf, scale)
        return {
            transf[1], transf[2], transf[3], transf[4],
            transf[5] * scale, transf[6] * scale, transf[7] * scale, transf[8] * scale,
            transf[9], transf[10], transf[11], transf[12],
            transf[13], transf[14], transf[15], transf[16]
        }
    end,
    getTransf_ZScaled = function(transf, scale)
        return {
            transf[1], transf[2], transf[3], transf[4],
            transf[5], transf[6], transf[7], transf[8],
            transf[9] * scale, transf[10] * scale, transf[11] * scale, transf[12] * scale,
            transf[13], transf[14], transf[15], transf[16]
        }
    end,
    getTransf_Scaled = function(transf, scales123)
        if type(transf) ~= 'table' then return transf end
        local x, y, z = 1, 1, 1
        if type(scales123) == 'table' then x, y, z = table.unpack(scales123) end

        return {
            transf[1] * x, transf[2] * x, transf[3] * x, transf[4] * x,
            transf[5] * y, transf[6] * y, transf[7] * y, transf[8] * y,
            transf[9] * z, transf[10] * z, transf[11] * z, transf[12] * z,
            transf[13], transf[14], transf[15], transf[16]
        }
    end,
    getTransf_XSkewedOnZ = function(transf, skew)
        local m2 = {
            1, 0, skew, 0,
            0, 1, 0, 0,
            0, 0, 1, 0,
            0, 0, 0, 1,
        }

        return {
            transf[1]  + transf[9]  * skew,
            transf[2]  + transf[10] * skew,
            transf[3]  + transf[11] * skew,
            transf[4]  + transf[12] * skew,
            transf[5],
            transf[6],
            transf[7],
            transf[8],
            transf[9],
            transf[10],
            transf[11],
            transf[12],
            transf[13],
            transf[14],
            transf[15],
            transf[16],
        }
    end,
--#endregion faster than mul()
}

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

utils.getVec123ZRotatedP90Deg = function(vec123)
    return {
        -vec123[2],
        vec123[1],
        vec123[3]
    }
end

utils.getVec123ZRotatedM90Deg = function(vec123)
    return {
        vec123[2],
        -vec123[1],
        vec123[3]
    }
end

utils.getVec123ZRotated180Deg = function(vec123)
    return {
        -vec123[1],
        -vec123[2],
        vec123[3]
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

utils.getVectorLength = function(xyz)
    if type(xyz) ~= 'table' and type(xyz) ~= 'userdata' then return nil end
    local x = xyz.x or xyz[1] or 0.0
    local y = xyz.y or xyz[2] or 0.0
    local z = xyz.z or xyz[3] or 0.0
    return math.sqrt(x * x + y * y + z * z)
end

---runs no checks, takes an xyz table
---@param xyz table
---@return number
utils.getVectorLength_FAST = function(xyz)
    -- if type(xyz) ~= 'table' and type(xyz) ~= 'userdata' then return nil end
    local x = xyz.x
    local y = xyz.y
    local z = xyz.z
    return math.sqrt(x * x + y * y + z * z)
end

utils.getVectorLength_onlyXY = function(xy)
    if type(xy) ~= 'table' and type(xy) ~= 'userdata' then return nil end
    local x = xy.x or xy[1] or 0.0
    local y = xy.y or xy[2] or 0.0
    return math.sqrt(x * x + y * y)
end

utils.getVectorNormalised = function(xyz, targetLength)
    if type(xyz) ~= 'table' and type(xyz) ~= 'userdata' then return nil end
    if targetLength == 0 then return { 0, 0, 0 } end

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

---runs no checks, takes and returns an xyz table
---@param xyz table
---@param targetLength? number
---@return table
utils.getVectorNormalised_FAST = function(xyz, targetLength)
    -- if type(xyz) ~= 'table' and type(xyz) ~= 'userdata' then return nil end
    if targetLength == 0 then return { 0, 0, 0 } end

    local _oldLength = utils.getVectorLength_FAST(xyz)
    if _oldLength == 0 then return { 0, 0, 0 } end

    local _lengthFactor = (type(targetLength) == 'number' and targetLength or 1.0) / _oldLength
    return {
        x = xyz.x * _lengthFactor,
        y = xyz.y * _lengthFactor,
        z = xyz.z * _lengthFactor
    }
end

utils.getVectorMultiplied = function(xyz, factor)
    if type(xyz) ~= 'table' and type(xyz) ~= 'userdata' then return nil end
    if type(factor) ~= 'number' then return nil end

    if xyz.x ~= nil and xyz.y ~= nil and xyz.z ~= nil then
        return {
            x = xyz.x * factor,
            y = xyz.y * factor,
            z = xyz.z * factor
        }
    else
        return {
            xyz[1] * factor,
            xyz[2] * factor,
            xyz[3] * factor
        }
    end
end

utils.getVectorsDot = function(xyz1, xyz2)
    -- returns |xyz1| * |xyz2| * cos(angle between xyz1 and xyz2)
    if type(xyz1) ~= 'table' and type(xyz1) ~= 'userdata' then return nil end
    if type(xyz2) ~= 'table' and type(xyz2) ~= 'userdata' then return nil end

    local x1 = xyz1.x or xyz1[1] or 0.0
    local y1 = xyz1.y or xyz1[2] or 0.0
    local z1 = xyz1.z or xyz1[3] or 0.0

    local x2 = xyz2.x or xyz2[1] or 0.0
    local y2 = xyz2.y or xyz2[2] or 0.0
    local z2 = xyz2.z or xyz2[3] or 0.0

    return x1 * x2 + y1 * y2 + z1 * z2
end

utils.getPositionsDistance = function(pos0, pos1)
    local distance = utils.getVectorLength({
        (pos0.x or pos0[1]) - (pos1.x or pos1[1]),
        (pos0.y or pos0[2]) - (pos1.y or pos1[2]),
        (pos0.z or pos0[3]) - (pos1.z or pos1[3]),
    })
    return distance
end

utils.getPositionsDistance_onlyXY = function(pos0, pos1)
    local distance = utils.getVectorLength_onlyXY({
        (pos0.x or pos0[1]) - (pos1.x or pos1[1]),
        (pos0.y or pos0[2]) - (pos1.y or pos1[2]),
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
utils.getParallelSidewaysOLD = function(posTanX2, sideShift)
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

---the result will be parallel to the original at its ends but stretched or compressed due to the shift; tan changes are ignored for speed.
---do not use this for edges
---@param posTanX2 table
---@param sideShift number
---@return table
utils.getParallelSidewaysCoarse = function(posTanX2, sideShift)
    local _oldPos1 = posTanX2[1][1]
    local _oldPos2 = posTanX2[2][1]
    if _oldPos1[1] == _oldPos2[1] and _oldPos1[2] == _oldPos2[2] then
        return posTanX2
    end

    -- we ignore Z coz we rotate around the Z axis and we want to obtain a distance on the XY plane
    -- here, we imagine segments perpendicular to the tangents
    local sinZ1 = -posTanX2[1][2][2]
    local cosZ1 = posTanX2[1][2][1]
    local sinZ2 = -posTanX2[2][2][2]
    local cosZ2 = posTanX2[2][2][1]
    local _lengthZ1 = math.sqrt(sinZ1 * sinZ1 + cosZ1 * cosZ1)
    sinZ1, cosZ1 = sinZ1 / _lengthZ1, cosZ1 / _lengthZ1
    local _lengthZ2 = math.sqrt(sinZ2 * sinZ2 + cosZ2 * cosZ2)
    sinZ2, cosZ2 = sinZ2 / _lengthZ2, cosZ2 / _lengthZ2
    local _newPos1 = { _oldPos1[1] + sinZ1 * sideShift, _oldPos1[2] + cosZ1 * sideShift, _oldPos1[3] }
    local _newPos2 = { _oldPos2[1] + sinZ2 * sideShift, _oldPos2[2] + cosZ2 * sideShift, _oldPos2[3] }

    return {
        {
            _newPos1,
            {
                posTanX2[1][2][1],
                posTanX2[1][2][2],
                posTanX2[1][2][3],
            }
        },
        {
            _newPos2,
            {
                posTanX2[2][2][1],
                posTanX2[2][2][2],
                posTanX2[2][2][3],
            }
        },
    }
end

---the result will be parallel to the original at its ends but stretched or compressed due to the shift.
---@param posTanX2 table
---@param sideShift number
---@return table
---@return number
---@return number
utils.getParallelSideways = function(posTanX2, sideShift)
    local _oldPos1 = posTanX2[1][1]
    local _oldPos2 = posTanX2[2][1]
    if _oldPos1[1] == _oldPos2[1] and _oldPos1[2] == _oldPos2[2] then
        return posTanX2, 1, 1
    end

    -- we ignore Z coz we rotate around the Z axis and we want to obtain a distance on the XY plane
    -- here, we imagine segments perpendicular to the tangents
    local sinZ1 = -posTanX2[1][2][2]
    local cosZ1 = posTanX2[1][2][1]
    local sinZ2 = -posTanX2[2][2][2]
    local cosZ2 = posTanX2[2][2][1]
    local _lengthZ1 = math.sqrt(sinZ1 * sinZ1 + cosZ1 * cosZ1)
    sinZ1, cosZ1 = sinZ1 / _lengthZ1, cosZ1 / _lengthZ1
    local _lengthZ2 = math.sqrt(sinZ2 * sinZ2 + cosZ2 * cosZ2)
    sinZ2, cosZ2 = sinZ2 / _lengthZ2, cosZ2 / _lengthZ2

    local _newPos1 = { _oldPos1[1] + sinZ1 * sideShift, _oldPos1[2] + cosZ1 * sideShift, _oldPos1[3] }
    local _newPos2 = { _oldPos2[1] + sinZ2 * sideShift, _oldPos2[2] + cosZ2 * sideShift, _oldPos2[3] }

    local xRatio = (_oldPos2[1] ~= _oldPos1[1]) and math.abs((_newPos2[1] - _newPos1[1]) / (_oldPos2[1] - _oldPos1[1])) or nil
    local yRatio = (_oldPos2[2] ~= _oldPos1[2]) and math.abs((_newPos2[2] - _newPos1[2]) / (_oldPos2[2] - _oldPos1[2])) or nil
    if not(xRatio) or not(yRatio) then xRatio, yRatio = 1, 1 end -- vertical or horizontal posTanX2

    local _newTan1 = { posTanX2[1][2][1] * xRatio, posTanX2[1][2][2] * yRatio, posTanX2[1][2][3] }
    local _newTan2 = { posTanX2[2][2][1] * xRatio, posTanX2[2][2][2] * yRatio, posTanX2[2][2][3] }

    return {
        {
            _newPos1,
            _newTan1,
        },
        {
            _newPos2,
            _newTan2,
        },
    },
    xRatio,
    yRatio
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

-- gets a transf to fit something with length xObjectLength between two positions. x size is scaled, y and z sizes are preserved
utils.getTransf2FitObjectBetweenPositions = function(pos0, pos1, xObjectLength, logger)
    local _absX0I = xObjectLength / 2
    local _logger = logger == nil and {print = function() end, debugPrint = function() end, getIsExtendedLog = function() return false end} or logger
    local x0 = pos0.x or pos0[1]
    local x1 = pos1.x or pos1[1]
    local y0 = pos0.y or pos0[2]
    local y1 = pos1.y or pos1[2]
    local z0 = pos0.z or pos0[3]
    local z1 = pos1.z or pos1[3]
    local xMid = (x0 + x1) / 2
    local yMid = (y0 + y1) / 2
    local zMid = (z0 + z1) / 2
    local vecX0 = {-_absX0I, 0, 0} -- transforms to {x0, y0, z0}
    local vecX1 = {_absX0I, 0, 0} -- transforms to {x1, y1, z1}
    local ipotenusaYX = math.sqrt((x1 - x0)^2 + (y1 - y0)^2)
    local sinYX = (y1-y0) / ipotenusaYX
    local cosYX = (x1-x0) / ipotenusaYX
    _logger.print('ipotenusaYX =', ipotenusaYX, 'sinYX =', sinYX, 'cosYX =', cosYX)
    local vecY0 = {0, 1, 0} -- transforms to {xMid - sinYX, yMid + cosYX, zMid}
    local vecZ0 = {0, 0, 1} -- transforms to {xMid, yMid, zMid + 1}
    local vecZTilted = {0, 0, 1} -- transforms to
    -- {
        -- xMid -math.sin(math.atan2((z1-z0), (ipotenusaYX))) * cosYX
        -- yMid -math.sin(math.atan2((z1-z0), (ipotenusaYX))) * sinYX
        -- zMid +math.cos(math.atan2((z1-z0), (ipotenusaYX)))
    -- }
    -- vecXYZ transformed with transf is:
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
    unknownTransf[1] = (x0 - xMid) / (-_absX0I)
    unknownTransf[2] = (y0 - yMid) / (-_absX0I)
    unknownTransf[3] = (z0 - zMid) / (-_absX0I)
    -- solving for vecX1 (same result)
    -- unknownTransf[1] = (x1 - xMid) / absX0I
    -- unknownTransf[2] = (y1 - yMid) / absX0I
    -- unknownTransf[3] = (z1 - zMid) / absX0I
    -- solving for vecY0
    unknownTransf[5] = -sinYX
    unknownTransf[6] = cosYX
    unknownTransf[7] = 0
    -- solving for vecZ0 vertical
    -- this makes buildings vertical, the points match
    unknownTransf[9] = 0
    unknownTransf[10] = 0
    unknownTransf[11] = 1
    _logger.print('unknownTransf straight =') _logger.debugPrint(unknownTransf)
    -- solving for vecZ0 tilted
    -- this makes buildings perpendicular to the road, the points match. Curves seem to get less angry.
    -- LOLLO TODO these three are fine for the edges but tilt the construction models, the con should compensate for it
    -- xMid -math.sin(math.atan2((z1-z0), (ipotenusaYX))) * cosYX = unknownTransf[9] + xMid
    unknownTransf[9] = -math.sin(math.atan2((z1-z0), (ipotenusaYX))) * cosYX
    -- yMid -math.sin(math.atan2((z1-z0), (ipotenusaYX))) * sinYX = unknownTransf[10] + yMid
    unknownTransf[10] = -math.sin(math.atan2((z1-z0), (ipotenusaYX))) * sinYX
    -- zMid +math.cos(math.atan2((z1-z0), (ipotenusaYX))) = unknownTransf[11] + zMid
    unknownTransf[11] = math.cos(math.atan2((z1-z0), (ipotenusaYX)))
    _logger.print('unknownTransf tilted =') _logger.debugPrint(unknownTransf)

    local result = unknownTransf
    _logger.print('result =') _logger.debugPrint(result)
    local vecX0Transformed = utils.getVecTransformed(utils.oneTwoThree2XYZ(vecX0), result)
    local vecX1Transformed = utils.getVecTransformed(utils.oneTwoThree2XYZ(vecX1), result)
    local vecYTransformed = utils.getVecTransformed(utils.oneTwoThree2XYZ(vecY0), result)
    local vecZ0Transformed = utils.getVecTransformed(utils.oneTwoThree2XYZ(vecZ0), result)
    if _logger.getIsExtendedLog() then
        print('vecX0 straight and transformed =') debugPrint(vecX0) debugPrint(vecX0Transformed)
        print('should be') debugPrint({x0, y0, z0})
        print('vecX1 straight and transformed =') debugPrint(vecX1) debugPrint(vecX1Transformed)
        print('should be') debugPrint({x1, y1, z1})
        print('vecY0 straight and transformed =') debugPrint(vecY0) debugPrint(vecYTransformed)
        print('should be') debugPrint({xMid - sinYX, yMid + cosYX, zMid})
        print('vecZ0 straight and transformed =') debugPrint(vecZ0) debugPrint(vecZ0Transformed)
        print('should be (vertical)') debugPrint({xMid, yMid, zMid + 1})
        print('or, it should be (perpendicular fixed)') debugPrint({
            xMid -math.sin(math.atan2((z1-z0), (ipotenusaYX))) * cosYX,
            yMid -math.sin(math.atan2((z1-z0), (ipotenusaYX))) * sinYX,
            zMid +math.cos(math.atan2((z1-z0), (ipotenusaYX)))
        })
        print('x0, x1 =', x0, x1)
        print('y0, y1 =', y0, y1)
        print('z0, z1 =', z0, z1)
        print('xMid, yMid, zMid =', xMid, yMid, zMid)
    end
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

    -- This is slower and less accurate
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

---takes two vectors with x and y
---@param xy1 table
---@param xy2 table
---@param significantFigures integer
---@return boolean
utils.isXYVeryClose_FAST = function(xy1, xy2, significantFigures)
    -- if (type(xy1) ~= 'table' and type(xy1) ~= 'userdata')
    -- or (type(xy2) ~= 'table' and type(xy2) ~= 'userdata')
    -- then return false end

    -- local X1 = xy1.x or xy1[1]
    -- local Y1 = xy1.y or xy1[2]
    -- local X2 = xy2.x or xy2[1]
    -- local Y2 = xy2.y or xy2[2]

    -- if type(X1) ~= 'number' or type(Y1) ~= 'number' then return false end
    -- if type(X2) ~= 'number' or type(Y2) ~= 'number' then return false end

    return utils.isNumVeryClose(xy1.x, xy2.x, significantFigures)
    and utils.isNumVeryClose(xy1.y, xy2.y, significantFigures)
end

utils.isXYZVeryClose = function(xyz1, xyz2, significantFigures)
    if (type(xyz1) ~= 'table' and type(xyz1) ~= 'userdata')
    or (type(xyz2) ~= 'table' and type(xyz2) ~= 'userdata')
    then return false end

    local X1 = xyz1.x or xyz1[1]
    local Y1 = xyz1.y or xyz1[2]
    local Z1 = xyz1.z or xyz1[3]
    local X2 = xyz2.x or xyz2[1]
    local Y2 = xyz2.y or xyz2[2]
    local Z2 = xyz2.z or xyz2[3]

    if type(X1) ~= 'number' or type(Y1) ~= 'number' or type(Z1) ~= 'number' then return false end
    if type(X2) ~= 'number' or type(Y2) ~= 'number' or type(Z2) ~= 'number' then return false end

    return utils.isNumVeryClose(X1, X2, significantFigures)
    and utils.isNumVeryClose(Y1, Y2, significantFigures)
    and utils.isNumVeryClose(Z1, Z2, significantFigures)
end

utils.isNumsCloserThan = function(num1, num2, comp)
    if type(num1) ~= 'number' or type(num2) ~= 'number' or type(comp) ~= 'number' then return false end

    return math.abs(num1-num2) < math.abs(comp)
end

utils.isXYZSame = function(xyz1, xyz2)
    if (type(xyz1) ~= 'table' and type(xyz1) ~= 'userdata')
    or (type(xyz2) ~= 'table' and type(xyz2) ~= 'userdata')
    then return false end

    return (xyz1.x or xyz1[1]) == (xyz2.x or xyz2[1])
    and (xyz1.y or xyz1[2]) == (xyz2.y or xyz2[2])
    and (xyz1.z or xyz1[3]) == (xyz2.z or xyz2[3])
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
