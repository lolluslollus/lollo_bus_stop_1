function data()
    local logger = require('lollo_bus_stop.logger')
    local moduleHelpers = require('lollo_bus_stop.moduleHelpers')
    local streetUtils = require('lollo_bus_stop.streetUtils')
    local _extraCapacity = 160.0
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

        runFn = function(settings)
            addModifier(
                'loadModel',
                function(fileName, data)
                    if data and data.metadata and data.metadata.streetTerminal and not(data.metadata.signal) and not(data.metadata.streetTerminal.cargo) then
                        if not(data.metadata.pool) then data.metadata.pool = {} end
                        data.metadata.pool.moreCapacity = _extraCapacity
                        data.metadata.moreCapacity = _extraCapacity
                        data.metadata.streetTerminal.moreCapacity = _extraCapacity
                        data.metadata.streetTerminal.pool = {
                            moreCapacity = _extraCapacity,
                        }
                        logger.print('extra capacity added to station ' .. fileName) -- this has no effect, otherwise the rest would be useless
                    end
                    return data
                end
            )
        end,

        -- Unlike runFn, postRunFn runs after all resources have been loaded.
        -- It is the only place where we can define a dynamic construction,
        -- which is the only way we can define dynamic parameters.
        -- Here, the dynamic parameters are the street types.
        postRunFn = function(settings, modParams)
            local allStreetData = streetUtils.getGlobalStreetData()

            local staticCon = api.res.constructionRep.get(
                api.res.constructionRep.find(
                    'station/street/lollo_bus_stop/stop.con'
                )
            )
            -- UG TODO it would be nice to alter the soundSet here, but there is no suitable type
            staticCon.updateScript.fileName = 'construction/station/street/lollo_bus_stop/stop.updateFn'
            staticCon.updateScript.params = {
                globalStreetData = allStreetData
            }
            -- this is useless
            -- staticCon.upgradeScript.fileName = 'construction/station/street/lollo_bus_stop/stop.upgradeFn'
            moduleHelpers.updateParamValues_streetType_(staticCon.params, allStreetData)
        end,
    }
end
