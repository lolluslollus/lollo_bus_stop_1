function data()
    -- local arrayUtils = require('lollo_bus_stop.arrayUtils')
    local logger = require('lollo_bus_stop.logger')
    local moduleHelpers = require('lollo_bus_stop.moduleHelpers')
    local streetUtils = require('lollo_bus_stop.streetUtils')
    -- local stringUtils = require('lollo_bus_stop.stringUtils')
    -- local _extraCapacity = 160.0
    local function _getUiTypeNumber(uiTypeStr)
        if uiTypeStr == 'BUTTON' then return 0
        elseif uiTypeStr == 'SLIDER' then return 1
        elseif uiTypeStr == 'COMBOBOX' then return 2
        elseif uiTypeStr == 'ICON_BUTTON' then return 3 -- double-check this
        elseif uiTypeStr == 'CHECKBOX' then return 4 -- double-check this
        else return 0
        end
    end

    return {
        info = {
            minorVersion = 1,
            severityAdd = 'NONE',
            severityRemove = 'NONE',
            name = _('ModName'),
            description = _('ModDesc'),
            tags = {
                'Bus Station',
                'Station',
            },
            authors = {
                {
                    name = 'Lollus',
                    role = 'CREATOR'
                },
            }
        },

        -- runFn = function(settings) -- useless, unfortunately, otherwise the rest of the mod would be useless
        --     addModifier(
        --         'loadModel',
        --         function(fileName, data)
        --             if data and data.metadata and data.metadata.streetTerminal and not(data.metadata.signal) and not(data.metadata.streetTerminal.cargo) then
        --                 if not(data.metadata.pool) then data.metadata.pool = {} end
        --                 data.metadata.pool.moreCapacity = _extraCapacity
        --                 data.metadata.moreCapacity = _extraCapacity
        --                 data.metadata.streetTerminal.moreCapacity = _extraCapacity
        --                 data.metadata.streetTerminal.pool = {
        --                     moreCapacity = _extraCapacity,
        --                 }
        --                 logger.print('extra capacity added to station ' .. fileName)
        --             end
        --             return data
        --         end
        --     )
        -- end,

        -- Unlike runFn, postRunFn runs after all resources have been loaded.
        -- It is the only place where we can define a dynamic construction,
        -- which is the only way we can define dynamic parameters.
        -- Here, the dynamic parameters are the street types.
        postRunFn = function(settings, modParams)
            local allStreetData = streetUtils.getGlobalStreetData()

            -- UG TODO this causes random crashes without proper messages.
--[[
            local busStopModels = {}
            local allGameModels = api.res.modelRep.getAll()
            local allGameStationModels = {}
            for modelId, modelFileName in pairs(allGameModels) do
                if modelFileName ~= nil and modelFileName:find('station/bus/') then
                    allGameStationModels[modelId] = modelFileName
                end
            end

            for modelId, modelFileName in pairs(allGameStationModels) do
                if modelId ~= nil and modelFileName ~= nil then
                    local model = api.res.modelRep.get(modelId)
                    if not(model) then break end -- prevent a crash, the models table is dodgy

                    if model ~= nil
                    and model.metadata ~= nil
                    and model.metadata.streetTerminal ~= nil
                    and not(model.metadata.signal)
                    and not(model.metadata.streetTerminal.cargo)
                    and model.metadata.description ~= nil
                    and model.metadata.description.name ~= nil
                    then
                        busStopModels[#busStopModels+1] = {
                            fileName = modelFileName,
                            id = modelId,
                            name = model.metadata.description.name
                        }
                    end
                end
            end

            logger.print('#busStopModels =', #busStopModels) logger.debugPrint(busStopModels)
            -- now, make copies of the models with model.metadata = nil. This fails.
            local geldedBusStopModels = {}
            for _, value in pairs(busStopModels) do
                local staticModel = api.res.modelRep.get(value.id)
                local newModel = staticModel
                newModel.metadata = arrayUtils.cloneDeepOmittingFields(staticModel.metadata, {'streetTerminal'}, true)
                -- local newFileName = (stringUtils.stringSplit(value.fileName, '.mdl')[1])
                local newFileName = value.fileName:gsub('.mdl', '_2.mdl')
                print('newFileName =') debugPrint(newFileName)
                local newId = api.res.modelRep.add(newFileName, newModel, false)
                print('newId =') debugPrint(newId)
                geldedBusStopModels[#geldedBusStopModels+1] = {
                    fileName = newFileName,
                    id = newId,
                    name = value.name
                }
            end
]]
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
            local geldedBusStopModels = getGeldedBusStopModels()
            logger.print('geldedBusStopModels =') logger.debugPrint(geldedBusStopModels)

            local function addCon(sourceFileName, targetFileName, scriptFileName)
                local staticCon = api.res.constructionRep.get(
                    api.res.constructionRep.find(
                        sourceFileName
                    )
                )
                local newCon = api.type.ConstructionDesc.new()
                newCon.fileName = targetFileName
                newCon.type = staticCon.type
                newCon.snapping = staticCon.snapping
                newCon.description = staticCon.description
                -- newCon.availability = { yearFrom = 1925, yearTo = 0 } -- this dumps, the api wants it different
                newCon.availability.yearFrom = 1925 -- same year as modern streets
                newCon.availability.yearTo = 0
                newCon.buildMode = staticCon.buildMode
                newCon.categories = staticCon.categories
                newCon.order = staticCon.order
                newCon.skipCollision = staticCon.skipCollision
                newCon.autoRemovable = staticCon.autoRemovable
                for _, par in pairs(moduleHelpers.getParams()) do
                    local newConParam = api.type.ScriptParam.new()
                    newConParam.key = par.key
                    newConParam.name = par.name
                    newConParam.tooltip = par.tooltip or ''
                    newConParam.values = par.values
                    newConParam.defaultIndex = par.defaultIndex or 0
                    newConParam.uiType = _getUiTypeNumber(par.uiType)
                    if par.yearFrom ~= nil then newConParam.yearFrom = par.yearFrom end
                    if par.yearTo ~= nil then newConParam.yearTo = par.yearTo end
                    newCon.params[#newCon.params + 1] = newConParam -- the api wants it this way, all the table at once dumps
                end
                -- UG TODO it would be nice to alter the soundSet here, but there is no suitable type
                newCon.updateScript.fileName = scriptFileName .. '.updateFn'
                newCon.updateScript.params = {
                    globalStreetData = allStreetData,
                    globalBusStopModelData = geldedBusStopModels,
                }
                -- these are useless but the game wants them
                newCon.preProcessScript.fileName = scriptFileName .. '.preProcessFn'
                newCon.upgradeScript.fileName = scriptFileName .. '.upgradeFn'
                newCon.createTemplateScript.fileName = scriptFileName .. '.createTemplateFn'

                moduleHelpers.updateParamValues_model(newCon.params, geldedBusStopModels)
                moduleHelpers.updateParamValues_streetType_(newCon.params, allStreetData)

                api.res.constructionRep.add(newCon.fileName, newCon, true) -- fileName, resource, visible
            end
            addCon(
                'station/street/lollo_bus_stop/stop.con',
                'station/street/lollo_bus_stop/stop_2.con',
                'construction/station/street/lollo_bus_stop/stop'
            )
            addCon(
                'station/street/lollo_bus_stop/stop.con',
                'station/street/lollo_bus_stop/stop_3.con',
                'construction/station/street/lollo_bus_stop/stopParametric'
            )
        end,
    }
end
