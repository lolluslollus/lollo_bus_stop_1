local arrayUtils = require('lollo_bus_stop.arrayUtils')
local logger = require('lollo_bus_stop.logger')
-- local pitchHelpers = require('lollo_bus_stop.pitchHelper')
local streetUtils = require('lollo_bus_stop.streetUtils')
local stringUtils = require('lollo_bus_stop.stringUtils')


local getDefaultStreetTypeIndexBase0 = function(allStreetData)
    if type(allStreetData) ~= 'table' then return 0 end

    local result = arrayUtils.findIndex(allStreetData, 'fileName', 'lollo_medium_1_way_1_lane_street_narrow_sidewalk.lua') - 1
    if result < 0 then
        result = arrayUtils.findIndex(allStreetData, 'fileName', 'standard/country_small_one_way_new.lua') - 1
    end

    return result > 0 and result or 0
end

local getGeldedBusStopModels = function()
    local results = {}
    local add = function(fileName)
        local id = api.res.modelRep.find(fileName)
        local model = api.res.modelRep.get(id)
        results[#results+1] = {
            fileName = fileName,
            icon = model.metadata.description.icon,
            id = id,
            name = model.metadata.description.name
        }
    end
    add('lollo_bus_stop/geldedBusStops/pole_old.mdl')
    add('lollo_bus_stop/geldedBusStops/pole_mid.mdl')
    add('lollo_bus_stop/geldedBusStops/pole_new.mdl')
    add('lollo_bus_stop/geldedBusStops/small_old.mdl')
    add('lollo_bus_stop/geldedBusStops/small_mid.mdl')
    add('lollo_bus_stop/geldedBusStops/small_new.mdl')
    return results
end

local funcs = {}

-- Returns a sorted table and an indexed table with the same values.
-- Inside constructions, you must pass all parameters coz the api is not available
funcs.getParamsMetadata = function(allBridgeData, allStreetData, modelData)
    if not(allBridgeData) then allBridgeData = streetUtils.getGlobalBridgeDataPlusNoBridge() end
    if not(allStreetData) then
        allStreetData = streetUtils.getGlobalStreetData({
            -- streetUtils.getStreetDataFilters().PATHS,
            streetUtils.getStreetDataFilters().STOCK,
        })
    end
    if not(modelData) then modelData = funcs.getGeldedBusStopModels() end

    local metadata_sorted = {
        {
            defaultIndex = getDefaultStreetTypeIndexBase0(allStreetData),
            key = 'lolloBusStop_streetType',
            name = _('streetTypeName'),
            values = arrayUtils.map(
                allStreetData,
                function(str)
                    return str.name
                end
            ),
            uiType = 'COMBOBOX',
        },
        {
            key = 'lolloBusStop_bridgeOrTunnelType',
            name = _('bridgeTypeName'),
            values = arrayUtils.map(
                allBridgeData,
                function(str)
                    return str.name
                end
            ),
            uiType = 'COMBOBOX',
        },
        {
            key = 'lolloBusStop_model',
            name = _('modelName'),
            values = arrayUtils.map(
                modelData,
                function(model)
                    -- return model.name
                    return model.icon
                end
            ),
            uiType = 'ICON_BUTTON',
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
        -- {
        --     key = 'lolloBusStop_snapNodes',
        --     name = _('snapNodesName'),
        --     tooltip = _('snapNodesDesc'),
        --     values = {
        --         _('No'),
        --         _('Left'),
        --         _('Right'),
        --         _('Both')
        --     },
        --     defaultIndex = 3
        -- },
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
        -- {
        --     key = 'lolloBusStop_pitch',
        --     name = _('pitchName'),
        --     values = pitchHelpers.getPitchParamValues(),
        --     defaultIndex = pitchHelpers.getDefaultPitchParamValue(),
        --     uiType = 'SLIDER'
        -- },
    }
    -- add defaultIndex wherever not present
    for _, record in pairs(metadata_sorted) do
        record.defaultIndex = record.defaultIndex or 0
    end
    local metadata_indexed = {}
    for _, record in pairs(metadata_sorted) do
        metadata_indexed[record.key] = record
    end
    -- logger.print('metadata_sorted =') logger.debugPrint(metadata_sorted)
    -- logger.print('metadata_indexed =') logger.debugPrint(metadata_indexed)
    return metadata_sorted, metadata_indexed
end

-- do not call this from inside the construction
funcs.getGeldedBusStopModels = function()
    return getGeldedBusStopModels()
end

funcs.getStationPoolCapacities = function(params, result)
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

--[[
helpers.updateParamValues_streetType = function(params, allStreetData)
    for _, param in pairs(params) do
        if param.key == 'lolloBusStop_streetType' then
            param.values = arrayUtils.map(
                allStreetData,
                function(str)
                    return str.name
                end
            )
            param.defaultIndex = getDefaultStreetTypeIndexBase0(allStreetData)
            param.uiType = 2 -- 'COMBOBOX'
            -- print('lolloBusStop_streetType param =')
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
            -- param.defaultIndex = getDefaultStreetTypeIndexBase0(allModelData)
            -- param.uiType = 2 -- 'COMBOBOX'
            param.uiType = 3 -- 'ICON_BUTTON'
            -- print('lolloBusStop_streetType param =')
            -- debugPrint(param)
        end
    end
end
]]

--[[
local _decimalFiguresCount = 9 -- must be smaller than 2147483648
local _getFloatParamNames = function(paramNamePrefix, name)
    local _nameSuffixInt = 'Int'
    local _nameSuffixDec1 = 'Dec1'
    local _nameSuffixDec2 = 'Dec2'
    local _nameSuffixDec3 = 'Dec3'

    local _nameInt = tostring(paramNamePrefix or '') .. name .. _nameSuffixInt
    local _nameDec1 = tostring(paramNamePrefix or '') .. name .. _nameSuffixDec1
    local _nameDec2 = tostring(paramNamePrefix or '') .. name .. _nameSuffixDec2
    local _nameDec3 = tostring(paramNamePrefix or '') .. name .. _nameSuffixDec3

    return _nameInt, _nameDec1, _nameDec2, _nameDec3
end
local _padRight = function(str)
    while str:len() < _decimalFiguresCount do
        str = str .. '0'
    end
    return str
end
helpers.getFloatFromIntParams = function(params, name, paramNamePrefix)
    local _nameInt, _nameDec1, _nameDec2, _nameDec3 = _getFloatParamNames(paramNamePrefix, name)
    local _integerNum = (params[_nameInt] or 0)
    local _decimalNum1 = (params[_nameDec1] or 0)
    local _decimalNum2 = (params[_nameDec2] or 0)
    local _decimalNum3 = (params[_nameDec3] or 0)
    local result =
        _integerNum
        + _decimalNum1 * (10 ^ -_decimalFiguresCount)
        + _decimalNum2 * (10 ^ (-2 * _decimalFiguresCount))
        + _decimalNum3 * (10 ^ (-3 * _decimalFiguresCount))
    return result
end
helpers.setIntParamsFromFloat = function(params, name, float, paramNamePrefix)
    local _nameInt, _nameDec1, _nameDec2, _nameDec3 = _getFloatParamNames(paramNamePrefix, name)
    local _float = type(float) ~= 'number' and 0.0 or float
    local _format = '%.' .. tostring(_decimalFiguresCount * 2) .. 'f' -- floating point number with (_decimalFiguresCount) decimal figures
    local _floatStr = _format:format(_float)
    -- logger.print('_floatStr =', _floatStr)
    local intStr, dec1Str = table.unpack(stringUtils.stringSplit(_floatStr, '.'))
    -- logger.print('intStr =', intStr)
    -- logger.print('dec1Str =', dec1Str)
    if not(intStr) then intStr = '0' end
    if not(dec1Str) then dec1Str = '0' end
    local dec3Str = _padRight(dec1Str:sub(2 * _decimalFiguresCount + 1, 3 * _decimalFiguresCount) or '0')
    local dec2Str = _padRight(dec1Str:sub(_decimalFiguresCount + 1, 2 * _decimalFiguresCount) or '0')
    -- logger.print('dec2Str =', dec2Str)
    -- logger.print('dec3Str =', dec3Str)
    dec1Str = _padRight(dec1Str:sub(1, _decimalFiguresCount) or '0')
    if stringUtils.stringStartsWith(intStr, '-') then
        dec1Str = '-' .. dec1Str
        dec2Str = '-' .. dec2Str
        dec3Str = '-' .. dec3Str
    end

    params[_nameInt] = tonumber(intStr)
    params[_nameDec1] = tonumber(dec1Str)
    params[_nameDec2] = tonumber(dec2Str)
    params[_nameDec3] = tonumber(dec3Str)
end
]]
return funcs
