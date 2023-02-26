function data()
    -- local arrayUtils = require('lollo_bus_stop.arrayUtils')
    local constants = require('lollo_bus_stop.constants')
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

            local globalBridgeData = streetUtils.getGlobalBridgeDataPlusNoBridge()
            logger.print('postRunFn got globalBridgeData =') logger.debugPrint(globalBridgeData)
            --[[
                LOLLO NOTE UG TODO
                In postRunFn, api.res.streetTypeRep.getAll() only returns street types,
                which are available in the present game.
                In other lua states, eg in game_script, it returns all street types, which have ever been present in the game,
                including those from inactive mods.
                This is inconsistent: the api should return the same in every state.
                This happens with build 35050.
            ]]
            local globalStreetData = streetUtils.getGlobalStreetData({
                -- streetUtils.getStreetDataFilters().PATHS,
                streetUtils.getStreetDataFilters().STOCK,
            })
            -- logger.print('postRunFn: the api found ' .. #api.res.streetTypeRep.getAll() .. ' street types')
            local globalTunnelData = streetUtils.getGlobalTunnelDataPlusNoTunnel()
            local geldedBusStopModels = moduleHelpers.getGeldedBusStopModels()

            local function addAutoPlacingCon(sourceFileName, targetFileName, scriptFileName, yearFrom, yearTo)
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
                newCon.availability.yearFrom = yearFrom
                newCon.availability.yearTo = yearTo
                newCon.buildMode = staticCon.buildMode
                newCon.categories = staticCon.categories
                newCon.order = staticCon.order
                newCon.skipCollision = staticCon.skipCollision
                newCon.autoRemovable = staticCon.autoRemovable
                -- no params, so it will never change my own params with its stupid automatic behaviour
                -- for _, par in pairs(moduleHelpers.getParamsMetadata()) do
                --     local newConParam = api.type.ScriptParam.new()
                --     newConParam.key = par.key
                --     newConParam.name = par.name
                --     newConParam.tooltip = par.tooltip or ''
                --     newConParam.values = par.values
                --     newConParam.defaultIndex = par.defaultIndex or 0
                --     newConParam.uiType = _getUiTypeNumber(par.uiType)
                --     if par.yearFrom ~= nil then newConParam.yearFrom = par.yearFrom end
                --     if par.yearTo ~= nil then newConParam.yearTo = par.yearTo end
                --     newCon.params[#newCon.params + 1] = newConParam -- the api wants it this way, all the table at once dumps
                -- end
                -- UG TODO it would be nice to alter the soundSet here, but there is no suitable type
                newCon.updateScript.fileName = scriptFileName .. '.updateFn'
                newCon.updateScript.params = {
                    globalBridgeData = globalBridgeData,
                    globalStreetData = globalStreetData,
                    globalTunnelData = globalTunnelData,
                    globalBusStopModelData = geldedBusStopModels,
                }
                -- these are useless but the game wants them
                newCon.preProcessScript.fileName = scriptFileName .. '.preProcessFn'
                newCon.upgradeScript.fileName = scriptFileName .. '.upgradeFn'
                newCon.createTemplateScript.fileName = scriptFileName .. '.createTemplateFn'

                -- moduleHelpers.updateParamValues_model(newCon.params, geldedBusStopModels)
                -- moduleHelpers.updateParamValues_streetType(newCon.params, globalStreetData)

                api.res.constructionRep.add(newCon.fileName, newCon, true) -- fileName, resource, visible
            end
            addAutoPlacingCon(
                'station/street/lollo_bus_stop/stop.con',
                constants.autoPlacingConFileName,
                'construction/station/street/lollo_bus_stop/autoPlacingStop',
                -1,
                -1
            )

            local function addManualCon(sourceFileName, targetFileName, scriptFileName, yearFrom, yearTo)
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
                newCon.availability.yearFrom = yearFrom
                newCon.availability.yearTo = yearTo
                newCon.buildMode = staticCon.buildMode
                newCon.categories = staticCon.categories
                newCon.order = staticCon.order
                newCon.skipCollision = staticCon.skipCollision
                newCon.autoRemovable = staticCon.autoRemovable
                for _, par in pairs(moduleHelpers.getManualPlacingParamsMetadata(globalBridgeData, globalStreetData, geldedBusStopModels)) do
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
                    globalBridgeData = globalBridgeData,
                    globalStreetData = globalStreetData,
                    globalTunnelData = globalTunnelData,
                    globalBusStopModelData = geldedBusStopModels,
                }
                -- these are useless but the game wants them
                newCon.preProcessScript.fileName = scriptFileName .. '.preProcessFn'
                newCon.upgradeScript.fileName = scriptFileName .. '.upgradeFn'
                newCon.createTemplateScript.fileName = scriptFileName .. '.createTemplateFn'

                -- moduleHelpers.updateParamValues_model(newCon.params, geldedBusStopModels)
                -- moduleHelpers.updateParamValues_streetType(newCon.params, globalStreetData)

                api.res.constructionRep.add(newCon.fileName, newCon, true) -- fileName, resource, visible
            end
            addManualCon(
                'station/street/lollo_bus_stop/stop.con',
                constants.manualPlacingConFileName,
                'construction/station/street/lollo_bus_stop/manualPlacingStop',
                1925,
                0
            )
        end,
    }
end
