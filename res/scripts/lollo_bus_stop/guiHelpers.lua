local arrayUtils = require('lollo_bus_stop.arrayUtils')
-- local _constants = require('lollo_bus_stop.constants')
local edgeUtils = require('lollo_bus_stop.edgeUtils')
local logger = require('lollo_bus_stop.logger')
local stringUtils = require('lollo_bus_stop.stringUtils')

local _extraHeight4Title = 100
local _extraHeight4Param = 40
local _conConfigLayoutIdPrefix = 'lollo_bus_stop_con_config_layout_'
-- local _conConfigWindowId = 'lollo_bus_stop_con_config_window'
local _warningWindowWithGotoId = 'lollo_bus_stop_warning_window_with_goto'
-- local _warningWindowWithStateId = 'lollo_bus_stop_warning_window_with_state'

local _texts = {
    conConfigWindowTitle = _('conConfigWindowTitle'),
    goBack = _('GoBack'),
    goThere = _('GoThere'), -- cannot put this directly inside the loop for some reason
    warningWindowTitle = _('WarningWindowTitle'),
}

local _windowXShift = 40
local _windowYShift = 40

local guiHelpers = {
    isShowingWarning = false,
    isShowingWaypointDistance = false,
    moveCamera = function(position)
        local cameraData = game.gui.getCamera()
        game.gui.setCamera({position[1], position[2], cameraData[3], cameraData[4], cameraData[5]})
    end
}

local _getConstructionConfigLayout = function(stationGroupId, paramsMetadataSorted, paramValues, onParamValueChanged, isAddTitle)
    local layout = api.gui.layout.BoxLayout.new('VERTICAL')
    layout:setId(_conConfigLayoutIdPrefix .. stationGroupId)

    if isAddTitle then
        local br = api.gui.comp.TextView.new('')
        br:setGravity(0.5, 0)
        layout:addItem(br)
        local title = api.gui.comp.TextView.new(_texts.conConfigWindowTitle)
        title:setGravity(0.5, 0)
        layout:addItem(title)
    end

    local function addParam(paramKey, paramMetadata, paramValue)
        logger.print('addParam starting')
        if not(paramMetadata) or not(paramValue) then return end

        local paramNameTextBox = api.gui.comp.TextView.new(paramMetadata.name)
        if type(paramMetadata.tooltip) == 'string' and paramMetadata.tooltip:len() > 0 then
            paramNameTextBox:setTooltip(paramMetadata.tooltip)
        end
        layout:addItem(paramNameTextBox)
        local _valueIndexBase0 = paramValue or (paramMetadata.defaultIndex or 0)
        logger.print('_valueIndexBase0 =', _valueIndexBase0)
        if paramMetadata.uiType == 'ICON_BUTTON' then
            local buttonRowLayout = api.gui.comp.ToggleButtonGroup.new(api.gui.util.Alignment.HORIZONTAL, 0, true)
            buttonRowLayout:setGravity(0.5, 0) -- center horizontally
            buttonRowLayout:setOneButtonMustAlwaysBeSelected(true)
            buttonRowLayout:setEmitSignal(false)
            buttonRowLayout:onCurrentIndexChanged(
                function(newIndexBase0)
                    onParamValueChanged(stationGroupId, paramsMetadataSorted, paramKey, newIndexBase0)
                end
            )
            for indexBase1, value in pairs(paramMetadata.values) do
                local button = api.gui.comp.ToggleButton.new(api.gui.comp.ImageView.new(value))
                buttonRowLayout:add(button)
                if indexBase1 -1 == _valueIndexBase0 then
                    button:setSelected(true, false)
                end
            end
            layout:addItem(buttonRowLayout)
        elseif paramMetadata.uiType == 'COMBOBOX' then
            local comboBox = api.gui.comp.ComboBox.new()
            comboBox:setGravity(0.5, 0) -- center horizontally
            for _, value in pairs(paramMetadata.values) do
                comboBox:addItem(value)
            end
            if comboBox:getNumItems() > _valueIndexBase0 then
                comboBox:setSelected(_valueIndexBase0, false)
            end
            comboBox:onIndexChanged(
                function(indexBase0)
                    logger.print('comboBox:onIndexChanged firing, one =') logger.debugPrint(indexBase0)
                    onParamValueChanged(stationGroupId, paramsMetadataSorted, paramKey, indexBase0)
                end
            )
            layout:addItem(comboBox)
        else -- BUTTON or anything else
            local buttonRowLayout = api.gui.comp.ToggleButtonGroup.new(api.gui.util.Alignment.HORIZONTAL, 0, true)
            buttonRowLayout:setGravity(0.5, 0) -- center horizontally
            buttonRowLayout:setOneButtonMustAlwaysBeSelected(true)
            buttonRowLayout:setEmitSignal(false)
            buttonRowLayout:onCurrentIndexChanged(
                function(newIndexBase0)
                    onParamValueChanged(stationGroupId, paramsMetadataSorted, paramKey, newIndexBase0)
                end
            )
            for indexBase1, value in pairs(paramMetadata.values) do
                local button = api.gui.comp.ToggleButton.new(api.gui.comp.TextView.new(value))
                buttonRowLayout:add(button)
                if indexBase1 -1 == _valueIndexBase0 then
                    button:setSelected(true, false)
                end
            end
            layout:addItem(buttonRowLayout)
        end
    end
    -- logger.print('paramsMetadata =') logger.debugPrint(paramsMetadata)
    -- logger.print('paramValues =') logger.debugPrint(paramValues)
    for _, paramMetadata in pairs(paramsMetadataSorted) do
        for valueKey, value in pairs(paramValues) do
            if valueKey == paramMetadata.key then
                addParam(valueKey, paramMetadata, value)
                break
            end
        end
    end

    return layout
end

-- guiHelpers.showConstructionConfig = function(paramsMetadata, onParamValueChanged)
--     local layout = _getConstructionConfigLayout(paramsMetadata, onParamValueChanged)
--     local window = api.gui.util.getById(_conConfigWindowId)
--     if window == nil then
--         window = api.gui.comp.Window.new(_texts.conConfigWindowTitle, layout)
--         window:setId(_conConfigWindowId)
--     else
--         window:setContent(layout)
--         window:setVisible(true, false)
--     end

--     -- window:setHighlighted(true)
--     local position = api.gui.util.getMouseScreenPos()
--     window:setPosition(position.x + _windowXShift, position.y + _windowYShift)
--     window:addHideOnCloseHandler()
-- end

guiHelpers.addConConfigToWindow = function(stationGroupId, handleParamValueChanged, conParamsMetadata, conParams)
    local conWindowId = 'temp.view.entity_' .. stationGroupId
    print('conWindowId = \'' .. tostring(conWindowId) .. '\'')
    local window = api.gui.util.getById(conWindowId) -- eg temp.view.entity_26372
    local windowLayout = window:getContent()
    -- local contentView = windowLayout:getItem(windowLayout:getNumItems() - 1)
    -- local layout = contentView:getLayout() -- :getItem(0)
    -- contentView:getLayout():getItem(0):setVisible(false, false)
    -- print('oldLayoutId =', oldLayout:getId() or 'NIL')

    -- layout:addItem(newLayout, api.gui.util.Alignment.HORIZONTAL, api.gui.util.Alignment.VERTICAL)
    -- layout:addItem(newLayout, 1, 1)

    -- windowLayout:getItem(1):setEnabled(false) -- disables too much
    windowLayout:getItem(1):setVisible(false, false) -- hide the "configure' button" without emitting a signal

    for i = 0, windowLayout:getNumItems() - 1, 1 do
        local item = windowLayout:getItem(i)
        if item ~= nil and type(item.getId) == 'function' and stringUtils.stringStartsWith(item:getId() or '', _conConfigLayoutIdPrefix) then
            logger.print('one of my menus is already in the window, about to remove it')
            windowLayout:removeItem(item)
            logger.print('about to reset its id')
            if type(item.setId) == 'function' then item:setId('') end
            logger.print('about to call destroy')
            -- api.gui.util.destroyLater(item) -- this errors out
            item:destroy()
            logger.print('called destroy')
        end
    end

    local newLayout = _getConstructionConfigLayout(stationGroupId, conParamsMetadata, conParams, handleParamValueChanged, true)
    windowLayout:addItem(newLayout)
    windowLayout:setGravity(0, 0) -- center top left

    local rect = window:getContentRect() -- this is mostly 0, 0 at this point
    local minSize = window:calcMinimumSize()
    -- logger.print('rect =') logger.debugPrint(rect)
    logger.print('minSize =') logger.debugPrint(minSize)

    local extraHeight = _extraHeight4Title + arrayUtils.getCount(conParamsMetadata) * _extraHeight4Param
    local size = api.gui.util.Size.new(math.max(rect.w, minSize.w), math.max(rect.h, minSize.h) + extraHeight)
    window:setSize(size)
    window:setResizable(true)
end

guiHelpers.showWarningWindowWithGoto = function(text, wrongObjectId, similarObjectsIds)
    local layout = api.gui.layout.BoxLayout.new('VERTICAL')
    local window = api.gui.util.getById(_warningWindowWithGotoId)
    if window == nil then
        window = api.gui.comp.Window.new(_texts.warningWindowTitle, layout)
        window:setId(_warningWindowWithGotoId)
    else
        window:setContent(layout)
        window:setVisible(true, false)
    end

    layout:addItem(api.gui.comp.TextView.new(text))

    local function addGotoOtherObjectsButtons()
        if type(similarObjectsIds) ~= 'table' then return end

        local wrongObjectIdTolerant = wrongObjectId
        if not(edgeUtils.isValidAndExistingId(wrongObjectIdTolerant)) then wrongObjectIdTolerant = -1 end

        for _, otherObjectId in pairs(similarObjectsIds) do
            if otherObjectId ~= wrongObjectIdTolerant and edgeUtils.isValidAndExistingId(otherObjectId) then
                local otherObjectPosition = edgeUtils.getObjectPosition(otherObjectId)
                if otherObjectPosition ~= nil then
                    local buttonLayout = api.gui.layout.BoxLayout.new('HORIZONTAL')
                    buttonLayout:addItem(api.gui.comp.ImageView.new('ui/design/window-content/locate_small.tga'))
                    buttonLayout:addItem(api.gui.comp.TextView.new(_texts.goThere))
                    local button = api.gui.comp.Button.new(buttonLayout, true)
                    button:onClick(
                        function()
                            -- UG TODO this dumps, ask UG to fix it
                            -- api.gui.util.CameraController:setCameraData(
                            --     api.type.Vec2f.new(otherObjectPosition[1], otherObjectPosition[2]),
                            --     100, 0, 0
                            -- )
                            -- x, y, distance, angleInRad, pitchInRad
                            guiHelpers.moveCamera(otherObjectPosition)
                            -- game.gui.setCamera({otherObjectPosition[1], otherObjectPosition[2], 100, 0, 0})
                        end
                    )
                    layout:addItem(button)
                end
            end
        end
    end
    local function addGoBackToWrongObjectButton()
        if not(edgeUtils.isValidAndExistingId(wrongObjectId)) then return end

        local wrongObjectPosition = edgeUtils.getObjectPosition(wrongObjectId)
        if wrongObjectPosition ~= nil then
            local buttonLayout = api.gui.layout.BoxLayout.new('HORIZONTAL')
            buttonLayout:addItem(api.gui.comp.ImageView.new('ui/design/window-content/arrow_style1_left.tga'))
            buttonLayout:addItem(api.gui.comp.TextView.new(_texts.goBack))
            local button = api.gui.comp.Button.new(buttonLayout, true)
            button:onClick(
                function()
                    -- UG TODO this dumps, ask UG to fix it
                    -- api.gui.util.CameraController:setCameraData(
                    --     api.type.Vec2f.new(wrongObjectPosition[1], wrongObjectPosition[2]),
                    --     100, 0, 0
                    -- )
                    -- x, y, distance, angleInRad, pitchInRad
                    guiHelpers.moveCamera(wrongObjectPosition)
                    -- game.gui.setCamera({wrongObjectPosition[1], wrongObjectPosition[2], 100, 0, 0})
                end
            )
            layout:addItem(button)
        end
    end
    addGotoOtherObjectsButtons()
    addGoBackToWrongObjectButton()

    window:setHighlighted(true)
    local position = api.gui.util.getMouseScreenPos()
    window:setPosition(position.x + _windowXShift, position.y + _windowYShift)
    window:addHideOnCloseHandler()
end

guiHelpers.hideAllWarnings = function()
    local window = api.gui.util.getById(_warningWindowWithGotoId)
    if window ~= nil then
        window:setVisible(false, false)
    end
end

return guiHelpers
