function data()
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
                    if data and data.metadata and data.metadata.streetTerminal and not(data.metadata.streetTerminal.cargo) then
                        data.metadata.pool = {
                            moreCapacity = 50
                        }
                    end
                    return data
                end
            )
        end,
    }
end
