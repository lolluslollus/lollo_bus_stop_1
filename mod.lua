function data()
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
                        print('extra capacity added to station ' .. fileName)
                    end
                    return data
                end
            )
        end,
    }
end
