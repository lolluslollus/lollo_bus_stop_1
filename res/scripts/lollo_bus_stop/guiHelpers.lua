-- local _constants = require('lollo_bus_stop.constants')
local edgeUtils = require('lollo_bus_stop.edgeUtils')
-- local stringUtils = require('lollo_bus_stop.stringUtils')

local _warningWindowWithGotoId = 'lollo_bus_stop_warning_window_with_goto'
-- local _warningWindowWithStateId = 'lollo_bus_stop_warning_window_with_state'

local _texts = {
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
