local arrayUtils = require('lollo_bus_stop.arrayUtils')
-- local constants = require('lollo_bus_stop.constants')
local edgeUtils = require('lollo_bus_stop.edgeUtils')
local logger = require('lollo_bus_stop.logger')
local stringUtils = require('lollo_bus_stop.stringUtils')


local privateData = {
    -- constants
    extraHeight4Title = 60,
    extraHeight4Param = 45, -- half the height of module icons, which we reuse here
    conConfigLayoutIdPrefix = 'lollo_bus_stop_con_config_layout_',

    texts = {
        bulldoze = _('Bulldoze'),
        conConfigWindowTitle = _('conConfigWindowTitle'),
        goBack = _('GoBack'),
        goThere = _('GoThere'), -- cannot put this directly inside the loop for some reason
        warningWindowTitle = _('WarningWindowTitle'),
    },

    warningWindowWithGotoId = 'lollo_bus_stop_warning_window_with_goto',

    windowXShift = 40,
    windowYShift = 40,

    -- attributes
    isShowingWarning = false,
}

local privateFuncs = {
    getConstructionConfigLayout = function(entityId, paramsMetadataSorted, paramValues, onParamValueChanged, isAddTitle, onBulldozeClicked)
        local layout = api.gui.layout.BoxLayout.new('VERTICAL')
        layout:setId(privateData.conConfigLayoutIdPrefix .. entityId)

        if isAddTitle then
            local br = api.gui.comp.TextView.new('')
            br:setGravity(0.5, 0)
            layout:addItem(br)
            local title = api.gui.comp.TextView.new(privateData.texts.conConfigWindowTitle)
            title:setGravity(0.5, 0)
            layout:addItem(title)
        end

        local function addParam(paramKey, paramMetadata, paramValue)
            logger.print('addParam starting, paramKey =', paramKey or 'NIL')
            if not(paramKey) or not(paramMetadata) or not(paramValue) then return end

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
                        onParamValueChanged(entityId, paramsMetadataSorted, paramKey, newIndexBase0)
                    end
                )
                for indexBase1, value in pairs(paramMetadata.values) do
                    -- logger.print('### paramMetadata =') logger.debugPrint(paramMetadata)
                    local imageView = api.gui.comp.ImageView.new(value)
                    imageView:setMaximumSize(api.gui.util.Size.new(privateData.extraHeight4Param, privateData.extraHeight4Param))
                    local button = api.gui.comp.ToggleButton.new(imageView)
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
                if comboBox:getNumItems() > _valueIndexBase0 then -- a simple validation
                    comboBox:setSelected(_valueIndexBase0, false)
                end
                comboBox:onIndexChanged(
                    function(indexBase0)
                        logger.print('comboBox:onIndexChanged firing, one =') logger.debugPrint(indexBase0)
                        onParamValueChanged(entityId, paramsMetadataSorted, paramKey, indexBase0)
                    end
                )
                layout:addItem(comboBox)
            elseif paramMetadata.uiType == 'SLIDER' then
                logger.print('paramMetadata =') logger.debugPrint(paramMetadata)
                local sliderValueView = api.gui.comp.TextView.new(tostring(paramMetadata.values[_valueIndexBase0 + 1]))
                sliderValueView:setGravity(0.5, 0) -- center horizontally
                local slider = api.gui.comp.Slider.new(true) -- true means horizontal
                slider:setGravity(0.5, 0) -- center horizontally
                slider:setMaximum(math.max(#paramMetadata.values -1, 1))
                slider:setMinimum(0)
                slider:setStep(1)
                slider:setValue(_valueIndexBase0, false)
                slider:onValueChanged(
                    function(newValueIndexBase0)
                        logger.print('slider emitted newValue =', newValueIndexBase0)
                        sliderValueView:setText(tostring(paramMetadata.values[newValueIndexBase0 + 1]))
                        onParamValueChanged(entityId, paramsMetadataSorted, paramKey, newValueIndexBase0)
                    end
                )
                slider:setMinimumSize(api.gui.util.Size.new(360, 40))

                local sliderLayout = api.gui.layout.BoxLayout.new('VERTICAL')
                sliderLayout:addItem(slider)
                sliderLayout:addItem(sliderValueView)

                layout:addItem(sliderLayout)
            else -- BUTTON or anything else
                -- logger.print('button clicked')
                local buttonRowLayout = api.gui.comp.ToggleButtonGroup.new(api.gui.util.Alignment.HORIZONTAL, 0, true)
                buttonRowLayout:setGravity(0.5, 0) -- center horizontally
                buttonRowLayout:setOneButtonMustAlwaysBeSelected(true)
                buttonRowLayout:setEmitSignal(false)
                buttonRowLayout:onCurrentIndexChanged(
                    function(newIndexBase0)
                        -- logger.print('buttonRowLayout:onCurrentIndexChanged, newIndexBase0 =', newIndexBase0 or 'NIL')
                        onParamValueChanged(entityId, paramsMetadataSorted, paramKey, newIndexBase0)
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
            local isFound = false
            for valueKey, value in pairs(paramValues) do
                if valueKey == paramMetadata.key then
                    addParam(valueKey, paramMetadata, value)
                    isFound = true
                    break
                end
            end
            -- allow adding new params to old cons that did not have them
            -- if not(isFound) then
            --     addParam(paramMetadata.key, paramMetadata, paramMetadata.defaultIndex)
            -- end
        end
--[[
        if type(onBulldozeClicked) == 'function' then
            local bulldozeButtonLayout = api.gui.layout.BoxLayout.new('HORIZONTAL')
            bulldozeButtonLayout:addItem(api.gui.comp.ImageView.new('ui/cursors/bulldoze.tga'))
            bulldozeButtonLayout:addItem(api.gui.comp.TextView.new(_constants.texts.bulldoze))
            local bulldozeButton = api.gui.comp.Button.new(bulldozeButtonLayout, true)
            bulldozeButton:onClick(
                function()
                    if type(onBulldozeClicked) == 'function' then
                        onBulldozeClicked(entityId)
                        -- window:setVisible(false, false) NO!
                    end
                end
            )
            bulldozeButton:setGravity(0.5, 0)
            layout:addItem(bulldozeButton)
        end
]]
        return layout
    end,
    moveCamera = function(position)
        local cameraData = game.gui.getCamera()
        game.gui.setCamera({position[1], position[2], cameraData[3], cameraData[4], cameraData[5]})
    end,
}

local public = {
    addEntityConfigToWindow = function(entityId, handleParamValueChanged, conParamsMetadata, conParams, onBulldozeClicked)
        local conWindowId = 'temp.view.entity_' .. entityId
        logger.print('conWindowId = \'' .. tostring(conWindowId) .. '\'')
        local window = api.gui.util.getById(conWindowId) -- eg temp.view.entity_26372
        if window == nil then logger.err('cannot get config window by id') return end
        local windowContent = window:getContent()
        if windowContent == nil then logger.err('cannot get config window content') return end
--[[
        windowContent:getItem(1):setVisible(false, false) -- hide the "configure' button" without emitting a signal

        for i = 0, windowContent:getNumItems() - 1, 1 do
            local item = windowContent:getItem(i)
            if item ~= nil and type(item.getId) == 'function' and stringUtils.stringStartsWith(item:getId() or '', privateData.conConfigLayoutIdPrefix) then
                logger.print('one of my menus is already in the window, about to remove it')
                windowContent:removeItem(item)
                logger.print('about to reset its id')
                if type(item.setId) == 'function' then item:setId('') end
                logger.print('about to call destroy')
                -- api.gui.util.destroyLater(item) -- this errors out
                item:destroy()
                logger.print('called destroy')
            end
        end

        local newLayout = privateFuncs.getConstructionConfigLayout(entityId, conParamsMetadata, conParams, handleParamValueChanged, true)
        windowContent:addItem(newLayout)
        windowContent:setGravity(0, 0) -- center top left
]]
        -- depending on the entity type, I attach my child to the window content (station group) or to its layout (construction)
        local isParentWindowContentLayout = type(windowContent.getName) == 'function' and windowContent:getName() == 'ConstructionContent'
        logger.print('isParentWindowContentLayout =', isParentWindowContentLayout)
        local parentLayout = isParentWindowContentLayout and windowContent:getLayout() or windowContent
        local configureButtonIndex = isParentWindowContentLayout and 0 or 1
        parentLayout:getItem(configureButtonIndex):setVisible(false, false) -- hide the "configure' button" without emitting a signal

        for i = 0, parentLayout:getNumItems() - 1, 1 do
            local item = parentLayout:getItem(i)
            if item ~= nil and type(item.getId) == 'function' and stringUtils.stringStartsWith(item:getId() or '', privateData.conConfigLayoutIdPrefix) then
                logger.print('one of my menus is already in the window, about to remove it')
                parentLayout:removeItem(item)
                logger.print('about to reset its id')
                if type(item.setId) == 'function' then item:setId('') else logger.err('cannot set config window id') end
                logger.print('about to call destroy')
                -- api.gui.util.destroyLater(item) -- this errors out
                item:destroy()
                logger.print('called destroy')
            end
        end

        local newLayout = privateFuncs.getConstructionConfigLayout(entityId, conParamsMetadata, conParams, handleParamValueChanged, true, onBulldozeClicked)
        parentLayout:addItem(newLayout)
        parentLayout:setGravity(0, 0) -- center top left

        local rect = window:getContentRect() -- this is mostly 0, 0 at this point
        local minSize = window:calcMinimumSize()
        -- logger.print('rect =') logger.debugPrint(rect)
        -- logger.print('minSize =') logger.debugPrint(minSize)

        local extraHeight = privateData.extraHeight4Title + arrayUtils.getCount(conParamsMetadata) * privateData.extraHeight4Param
        local size = api.gui.util.Size.new(math.max(rect.w, minSize.w), math.max(rect.h, minSize.h) + extraHeight)
        window:setSize(size)
        window:setResizable(true)
    end,
    isShowingWarning = privateData.isShowingWarning,
    ---@param text string
    ---@param wrongObjectId? integer
    ---@param similarObjectsIds? table<integer>
    showWarningWithGoto = function(text, wrongObjectId, similarObjectsIds)
        logger.print('guiHelpers.showWarningWithGoto starting, text =', text or 'NIL')
        privateData.isShowingWarning = true

        local layout = api.gui.layout.BoxLayout.new('VERTICAL')
        local window = api.gui.util.getById(privateData.warningWindowWithGotoId)
        if window == nil then
            window = api.gui.comp.Window.new(privateData.texts.warningWindowTitle, layout)
            window:setId(privateData.warningWindowWithGotoId)
            logger.print('the window does not exist yet, _warningWindowWithGotoId =', privateData.warningWindowWithGotoId)
        else
            window:setContent(layout)
            window:setVisible(true, false)
            logger.print('the window exists already, _warningWindowWithGotoId =', privateData.warningWindowWithGotoId)
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
                        buttonLayout:addItem(api.gui.comp.TextView.new(privateData.texts.goThere))
                        local button = api.gui.comp.Button.new(buttonLayout, true)
                        button:onClick(
                            function()
                                -- UG TODO this dumps, ask UG to fix it
                                -- api.gui.util.CameraController:setCameraData(
                                --     api.type.Vec2f.new(otherObjectPosition[1], otherObjectPosition[2]),
                                --     100, 0, 0
                                -- )
                                -- x, y, distance, angleInRad, pitchInRad
                                privateFuncs.moveCamera(otherObjectPosition)
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
                buttonLayout:addItem(api.gui.comp.TextView.new(privateData.texts.goBack))
                local button = api.gui.comp.Button.new(buttonLayout, true)
                button:onClick(
                    function()
                        -- UG TODO this dumps, ask UG to fix it
                        -- api.gui.util.CameraController:setCameraData(
                        --     api.type.Vec2f.new(wrongObjectPosition[1], wrongObjectPosition[2]),
                        --     100, 0, 0
                        -- )
                        -- x, y, distance, angleInRad, pitchInRad
                        privateFuncs.moveCamera(wrongObjectPosition)
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
        logger.print('window position (without shifts) =') logger.debugPrint(position)
        window:setPosition(position.x + privateData.windowXShift, position.y + privateData.windowYShift)
        -- window:addHideOnCloseHandler()
        window:onClose(
            function()
                logger.print('guiHelpers.showWarningWithGoto closing')
                privateData.isShowingWarning = false
                window:setVisible(false, false)
            end
        )
    end,
}

return public
