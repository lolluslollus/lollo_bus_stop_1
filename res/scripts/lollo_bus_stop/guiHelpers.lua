-- local _constants = require('lollo_bus_stop.constants')
local edgeUtils = require('lollo_bus_stop.edgeUtils')
local logger = require('lollo_bus_stop.logger')
-- local stringUtils = require('lollo_bus_stop.stringUtils')

local _conConfigWindowId = 'lollo_bus_stop_con_config_window'
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

guiHelpers.showConstructionConfig = function(paramPropsTable, onParamValueChanged)
    local layout = api.gui.layout.BoxLayout.new('VERTICAL')
    local window = api.gui.util.getById(_conConfigWindowId)
    if window == nil then
        window = api.gui.comp.Window.new(_texts.conConfigWindowTitle, layout)
        window:setId(_conConfigWindowId)
    else
        window:setContent(layout)
        window:setVisible(true, false)
    end

    local function addParam(paramPropsRecord)
        if not(paramPropsRecord) then return end

        local paramNameTextBox = api.gui.comp.TextView.new(paramPropsRecord.name)
        if type(paramPropsRecord.tooltip) == 'string' and paramPropsRecord.tooltip:len() > 0 then
            paramNameTextBox:setTooltip(paramPropsRecord.tooltip)
        end
        layout:addItem(paramNameTextBox)
        local _defaultValueIndexBase0 = (paramPropsRecord.defaultValue or 0)
        if paramPropsRecord.uiType == 'ICON_BUTTON' then
            local buttonRowLayout = api.gui.comp.ToggleButtonGroup.new(api.gui.util.Alignment.HORIZONTAL, 0, false)
            buttonRowLayout:setOneButtonMustAlwaysBeSelected(true)
            buttonRowLayout:setEmitSignal(false)
            buttonRowLayout:onCurrentIndexChanged(
                function(newIndexBase0)
                    onParamValueChanged(paramPropsTable, paramPropsRecord.key, newIndexBase0)
                end
            )
            for indexBase1, value in pairs(paramPropsRecord.values) do
                local button = api.gui.comp.ToggleButton.new(api.gui.comp.ImageView.new(value))
                buttonRowLayout:add(button)
                if indexBase1 -1 == _defaultValueIndexBase0 then
                    button:setSelected(true, false)
                end
            end
            layout:addItem(buttonRowLayout)
        elseif paramPropsRecord.uiType == 'COMBOBOX' then
            local comboBox = api.gui.comp.ComboBox.new()
            for _, value in pairs(paramPropsRecord.values) do
                comboBox:addItem(value)
            end
            if comboBox:getNumItems() > _defaultValueIndexBase0 then
                comboBox:setSelected(_defaultValueIndexBase0, false)
            end
            comboBox:onIndexChanged(
                function(indexBase0)
                    logger.print('comboBox:onIndexChanged firing, one =') logger.debugPrint(indexBase0)
                    onParamValueChanged(paramPropsTable, paramPropsRecord.key, indexBase0)
                end
            )
            layout:addItem(comboBox)
        else -- BUTTON or anything else
            local buttonRowLayout = api.gui.comp.ToggleButtonGroup.new(api.gui.util.Alignment.HORIZONTAL, 0, false)
            buttonRowLayout:setOneButtonMustAlwaysBeSelected(true)
            buttonRowLayout:setEmitSignal(false)
            buttonRowLayout:onCurrentIndexChanged(
                function(newIndexBase0)
                    onParamValueChanged(paramPropsTable, paramPropsRecord.key, newIndexBase0)
                end
            )
            for indexBase1, value in pairs(paramPropsRecord.values) do
                local button = api.gui.comp.ToggleButton.new(api.gui.comp.TextView.new(value))
                buttonRowLayout:add(button)
                if indexBase1 -1 == _defaultValueIndexBase0 then
                    button:setSelected(true, false)
                end
            end
            layout:addItem(buttonRowLayout)
        end
    end
    for _, paramPropsRecord in pairs(paramPropsTable) do
        addParam(paramPropsRecord)
    end

    -- window:setHighlighted(true)
    local position = api.gui.util.getMouseScreenPos()
    window:setPosition(position.x + _windowXShift, position.y + _windowYShift)
    window:addHideOnCloseHandler()
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
