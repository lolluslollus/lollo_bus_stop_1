local guiConfigWindow = require('lollo_bus_stop.guiConfigWindow')
local logger = require('lollo_bus_stop.logger')


local instance = guiConfigWindow.new(
    'lollo_bus_stop_con_config_layout_',
    'lollo_bus_stop_warning_window_with_goto',
    {
        bulldoze = _('Bulldoze'),
        conConfigWindowTitle = _('ConConfigWindowTitle'),
        goBack = _('GoBack'),
        goThere = _('GoThere'), -- cannot put this directly inside the loop for some reason
        warningWindowTitle = _('WarningWindowTitle'),
    },
    60,
    45, -- half the height of module icons, which we reuse here
    40,
    40
)

return instance
