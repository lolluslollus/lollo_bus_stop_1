local arrayUtils = require('lollo_bus_stop.arrayUtils')
local pitchHelpers = require('lollo_bus_stop.pitchHelper')

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

helpers.getParams = function(allStreetData, defaultStreetTypeIndex)
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
            tooltip = _('directionDesc'),
            values = {
                _('↑'),
                _('↓')
            },
        },
        {
            key = 'lolloBusStop_driveOnLeft',
            name = _('driveOnLeftName'),
            tooltip = _('driveOnLeftDesc'),
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
            name = _('Tram track'),
            values = {
                -- must be in this sequence
                _('NO'),
                _('YES'),
                _('ELECTRIC')
            },
        },
        {
            key = 'lolloBusStop_pitch',
            name = _('Pitch (adjust it with O and P while building)'),
            values = pitchHelpers.getPitchParamValues(),
            defaultIndex = pitchHelpers.getDefaultPitchParamValue(),
            uiType = 'SLIDER'
        }
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

return helpers
