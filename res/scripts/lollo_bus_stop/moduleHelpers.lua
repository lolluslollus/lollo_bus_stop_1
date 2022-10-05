local arrayUtils = require('lollo_bus_stop.arrayUtils')
local logger = require('lollo_bus_stop.logger')
local pitchHelpers = require('lollo_bus_stop.pitchHelper')
local stringUtils = require('lollo_bus_stop.stringUtils')

local helpers = {}
helpers.getGroundFace = function(face, key)
    return {
        face = face, -- LOLLO NOTE Z is ignored here
        loop = true,
        modes = {
            {
                type = 'FILL',
                key = key
            }
        }
    }
end

helpers.getTerrainAlignmentList = function(face)
    local _raiseBy = 0.28 -- a lil bit less than 0.3 to avoid bits of construction being covered by earth
    local raisedFace = {}
    for i = 1, #face do
        raisedFace[i] = face[i]
        raisedFace[i][3] = raisedFace[i][3] + _raiseBy
    end
    -- print('LOLLO raisedFaces =')
    -- debugPrint(raisedFace)
    return {
        faces = {raisedFace},
        optional = true,
        -- slopeHigh = 9, -- this makes more harm than good
        -- slopeLow = 0.01, -- this makes more harm than good
        type = 'EQUAL',
    }
end

helpers.getParams = function()
    return {
        {
            key = 'lolloBusStop_streetType_',
            name = _('streetTypeName'),
            -- will be replaced at postRunFn
            values = {
                'dummy1',
                'dummy2'
            },
            -- will be replaced at postRunFn
            uiType = 'BUTTON',
            -- will be replaced at postRunFn
            defaultIndex = 0
        },
        {
            key = 'lolloBusStop_model',
            name = _('modelName'),
            -- will be replaced at postRunFn
            values = {
                'dummy1',
                'dummy2'
            },
            -- will be replaced at postRunFn
            uiType = 'BUTTON',
            -- will be replaced at postRunFn
            defaultIndex = 0
        },
        {
            key = 'lolloBusStop_bothSides',
            name = _('bothSidesName'),
            tooltip = _('bothSidesDesc'),
            values = {
                _('No'),
                _('Yes'),
            },
        },
        {
            key = 'lolloBusStop_direction',
            name = _('directionName'),
            values = {
                _('↑'),
                _('↓')
            },
        },
        {
            key = 'lolloBusStop_driveOnLeft',
            name = _('driveOnLeftName'),
            values = {
                _('No'),
                _('Yes'),
            },
        },
        {
            key = 'lolloBusStop_snapNodes',
            name = _('snapNodesName'),
            tooltip = _('snapNodesDesc'),
            values = {
                _('No'),
                _('Left'),
                _('Right'),
                _('Both')
            },
            defaultIndex = 3
        },
        {
            key = 'lolloBusStop_tramTrack',
            name = _('tramTrackName'),
            values = {
                -- must be in this sequence
                _('NO'),
                _('YES'),
                _('ELECTRIC')
            },
        },
        {
            key = 'lolloBusStop_pitch',
            name = _('pitchName'),
            values = pitchHelpers.getPitchParamValues(),
            defaultIndex = pitchHelpers.getDefaultPitchParamValue(),
            uiType = 'SLIDER'
        },
    }
end

helpers.getDefaultStreetTypeIndexBase0 = function(allStreetData)
    if type(allStreetData) ~= 'table' then return 0 end

    local result = arrayUtils.findIndex(allStreetData, 'fileName', 'lollo_medium_1_way_1_lane_street_narrow_sidewalk.lua') - 1
    if result < 0 then
        result = arrayUtils.findIndex(allStreetData, 'fileName', 'standard/country_small_one_way_new.lua') - 1
    end

    return result > 0 and result or 0
end

helpers.getStationPoolCapacities = function(params, result)
    local extraCargoCapacity = (params.isStoreCargoOnPavement == 1) and 12 or 0

    for _, slot in pairs(result.slots) do
        local module = params.modules[slot.id]
        if module and module.metadata and module.metadata.moreCapacity then
            if type(module.metadata.moreCapacity.cargo) == 'number' then
                extraCargoCapacity = extraCargoCapacity + module.metadata.moreCapacity.cargo
            end
        end
    end
    return extraCargoCapacity
end

helpers.updateParamValues_streetType_ = function(params, allStreetData)
    for _, param in pairs(params) do
        if param.key == 'lolloBusStop_streetType_' then
            param.values = arrayUtils.map(
                allStreetData,
                function(str)
                    return str.name
                end
            )
            param.defaultIndex = helpers.getDefaultStreetTypeIndexBase0(allStreetData)
            param.uiType = 2 -- 'COMBOBOX'
            -- print('lolloBusStop_streetType_ param =')
            -- debugPrint(param)
        end
    end
end

helpers.updateParamValues_model = function(params, modelData)
    for _, param in pairs(params) do
        if param.key == 'lolloBusStop_model' then
            param.values = arrayUtils.map(
                modelData,
                function(model)
                    -- return model.name
                    return model.icon
                end
            )
            logger.print('param.values =') logger.debugPrint(param.values)
            -- param.defaultIndex = helpers.getDefaultStreetTypeIndexBase0(allModelData)
            -- param.uiType = 2 -- 'COMBOBOX'
            param.uiType = 3 -- 'ICON_BUTTON'
            -- print('lolloBusStop_streetType_ param =')
            -- debugPrint(param)
        end
    end
end

local _decimalFiguresCount = 9 -- must be smaller than 2147483648
helpers.getFloatFromIntParams = function(params, name1, name2, paramNamePrefix)
    local _name1 = tostring(paramNamePrefix or '') .. name1
    local _name2 = tostring(paramNamePrefix or '') .. name2
    local _integerNum = (params[_name1] or 0)
    local _sgn = _integerNum < 1 and -1 or 1
    local _decimalNum = (params[_name2] or 0)
    local result = _integerNum + _decimalNum * (10 ^ -_decimalFiguresCount) * _sgn
    return result
end
helpers.setIntParamsFromFloat = function(params, name1, name2, float, paramNamePrefix)
    local _name1 = tostring(paramNamePrefix or '') .. name1
    local _name2 = tostring(paramNamePrefix or '') .. name2
    local _float = type(float) ~= 'number' and 0.0 or float
    local _format = '%.' .. tostring(_decimalFiguresCount) .. 'f' -- floating point number with (_decimalFiguresCount) decimal figures
    local _floatStr = _format:format(_float)
    logger.print('_floatStr =', _floatStr)
    local integerStr, decimalStr = table.unpack(stringUtils.stringSplit(_floatStr, '.'))
    logger.print('integerStr =', integerStr)
    logger.print('decimalStr =', decimalStr)
    if not(integerStr) then integerStr = '0' end
    if not(decimalStr) then decimalStr = '0' end

    params[_name1] = tonumber(integerStr)
    params[_name2] = tonumber(decimalStr)
end
return helpers
