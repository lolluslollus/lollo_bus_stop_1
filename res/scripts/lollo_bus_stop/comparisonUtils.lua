local utils = { }

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

utils.isNumsVeryClose = function(num1, num2, significantFigures)
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
utils.isXYsVeryClose_FAST = function(xy1, xy2, significantFigures)
    -- if (type(xy1) ~= 'table' and type(xy1) ~= 'userdata')
    -- or (type(xy2) ~= 'table' and type(xy2) ~= 'userdata')
    -- then return false end

    -- local X1 = xy1.x or xy1[1]
    -- local Y1 = xy1.y or xy1[2]
    -- local X2 = xy2.x or xy2[1]
    -- local Y2 = xy2.y or xy2[2]

    -- if type(X1) ~= 'number' or type(Y1) ~= 'number' then return false end
    -- if type(X2) ~= 'number' or type(Y2) ~= 'number' then return false end

    return utils.isNumsVeryClose(xy1.x, xy2.x, significantFigures)
    and utils.isNumsVeryClose(xy1.y, xy2.y, significantFigures)
end

utils.isVec3sVeryClose = function(xyz1, xyz2, significantFigures)
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

    return utils.isNumsVeryClose(X1, X2, significantFigures)
    and utils.isNumsVeryClose(Y1, Y2, significantFigures)
    and utils.isNumsVeryClose(Z1, Z2, significantFigures)
end
--#endregion very close

--#region closer than
local _isNumsCloserThan = function(num1, num2, comp)
    return math.abs(num1-num2) < math.abs(comp)
end

utils.isNumsCloserThan = function(num1, num2, comp)
    if type(num1) ~= 'number' or type(num2) ~= 'number' or type(comp) ~= 'number' then return false end

    return _isNumsCloserThan(num1, num2, comp)
end

utils.isVec3sCloserThan = function(xyz1, xyz2, comp)
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

    return _isNumsCloserThan(X1, X2, comp)
    and _isNumsCloserThan(Y1, Y2, comp)
    and _isNumsCloserThan(Z1, Z2, comp)
end
--#endregion closer than

--#region is same
utils.is123sSame = function(xyz1, xyz2)
    if (type(xyz1) ~= 'table' and type(xyz1) ~= 'userdata')
    or (type(xyz2) ~= 'table' and type(xyz2) ~= 'userdata')
    then return false end

    return xyz1[1] == xyz2[1] and xyz1[2] == xyz2[2] and xyz1[3] == xyz2[3]
end

utils.isXYZsSame = function(xyz1, xyz2)
    if (type(xyz1) ~= 'table' and type(xyz1) ~= 'userdata')
    or (type(xyz2) ~= 'table' and type(xyz2) ~= 'userdata')
    then return false end

    return xyz1.x == xyz2.x and xyz1.y == xyz2.y and xyz1.z == xyz2.z
end

utils.isXYZsSame_onlyXY = function(xy1, xy2)
    if (type(xy1) ~= 'table' and type(xy1) ~= 'userdata')
    or (type(xy2) ~= 'table' and type(xy2) ~= 'userdata')
    then return false end

    return xy1.x == xy2.x and xy1.y == xy2.y
end

utils.isVec3sSame = function(xyz1, xyz2)
    if (type(xyz1) ~= 'table' and type(xyz1) ~= 'userdata')
    or (type(xyz2) ~= 'table' and type(xyz2) ~= 'userdata')
    then return false end

    return (xyz1.x or xyz1[1]) == (xyz2.x or xyz2[1])
    and (xyz1.y or xyz1[2]) == (xyz2.y or xyz2[2])
    and (xyz1.z or xyz1[3]) == (xyz2.z or xyz2[3])
end
--#endregion is same

utils.sgn = function(num)
    if tonumber(num) == nil then return nil end
    if num > 0 then return 1
    elseif num < 0 then return -1
    else return 0
    end
end

return utils
