-- Settings Menu UI for ccShop
local menuManager = require("ui.menuManager")
local utils = require("ui.utils")
local logging = require("logging")
local basalt = require("basalt")

local settingsMenu = {}

function settingsMenu.create(parent, context)
    logging.debug("[settingsMenu] Creating settings menu UI...")
    local w = parent:getWidth()
    local h = parent:getHeight()
    local frameHeight = h - 4

    local frame = parent:addFrame()
        :setPosition(1, 4)
        :setSize(w, frameHeight)
        :setBackground(colors.white)
        :setVisible(false)

    local elements = {}

    -- Change shop name button
    elements.changeNameButton = frame:addButton()
        :setText("Change shop name")
        :setForeground(colors.black)
        :setBackground(colors.pink)
        :setPosition(2, 2)
        :setSize(20, 3)

    -- Refresh items button
    elements.refreshButton = frame:addButton()
        :setText("Refresh items")
        :setForeground(colors.black)
        :setBackground(colors.pink)
        :setPosition(2, 6)
        :setSize(20, 3)

    -- Monitor setup button
    elements.monitorSetupButton = frame:addButton()
        :setText("Monitor setup")
        :setForeground(colors.black)
        :setBackground(colors.pink)
        :setPosition(w - 21, 2)
        :setSize(20, 3)

    -- Change name sub-menu
    elements.changeNameMenu = frame:addFrame()
        :setPosition(1, 1)
        :setSize(w, frameHeight)
        :setBackground(colors.white)
        :setVisible(false)

    elements.changeNameMenu:addLabel()
        :setText("New shop name")
        :setForeground(colors.black)
        :setBackground(colors.white)
        :setPosition(math.floor(w / 2) - 6, 3)

    elements.nameInput = elements.changeNameMenu:addInput()
        :setPosition(math.floor(w / 2) - 15, 4)
        :setSize(30, 1)
        :setText(context.shopSettings.shopName)

    elements.statusLabel = elements.changeNameMenu:addLabel()
        :setText("")
        :setForeground(colors.green)
        :setBackground(colors.white)
        :setPosition(math.floor(w / 2) - 10, 6)

    elements.saveNameButton = elements.changeNameMenu:addButton()
        :setText("Save")
        :setForeground(colors.black)
        :setBackground(colors.pink)
        :setPosition(math.floor(w / 2) - 10, frameHeight - 7)
        :setSize(20, 3)

    elements.backFromNameButton = elements.changeNameMenu:addButton()
        :setText("Back")
        :setForeground(colors.black)
        :setBackground(colors.pink)
        :setPosition(math.floor(w / 2) - 10, frameHeight - 3)
        :setSize(20, 3)

    elements.frame = frame
    elements.context = context

    -- Setup events
    settingsMenu.setupEvents(elements, context)

    logging.debug("[settingsMenu] Settings menu created successfully")
    return elements
end

function settingsMenu.setupEvents(elements, context)
    logging.debug("[settingsMenu] Setting up event handlers...")

    -- Change name button - opens submenu
    elements.changeNameButton:onClick(function()
        logging.debug("[settingsMenu] Opening change name submenu")
        local currentSettings = context.config.loadShopSettings()
        elements.nameInput:setText(currentSettings.shopName)
        elements.statusLabel:setText("")
        elements.changeNameMenu:setVisible(true)
    end)

    -- Back from name submenu
    elements.backFromNameButton:onClick(function()
        logging.debug("[settingsMenu] Closing change name submenu")
        elements.changeNameMenu:setVisible(false)
    end)

    -- Save name button
    elements.saveNameButton:onClick(function()
        local newName = elements.nameInput:getText()
        logging.info("[settingsMenu] Saving new shop name: " .. newName)

        local settings = context.config.loadShopSettings()
        settings.shopName = newName
        context.config.saveShopSettings(settings)

        elements.statusLabel:setForeground(colors.green)
        elements.statusLabel:setText("Shop name saved!")
        logging.info("[settingsMenu] Shop name saved successfully")

        if context.callbacks.onNameChange then
            context.callbacks.onNameChange(newName)
        end
    end)

    -- Refresh items button
    elements.refreshButton:onClick(function()
        logging.info("[settingsMenu] Refreshing items list...")
        if context.callbacks.onRefresh then
            context.callbacks.onRefresh()
        end
        elements.statusLabel:setForeground(colors.green)
        elements.statusLabel:setText("Items refreshed!")
        logging.info("[settingsMenu] Items list refreshed")
    end)

    -- Monitor setup button (placeholder)
    elements.monitorSetupButton:onClick(function()
        logging.debug("[settingsMenu] Monitor setup clicked (not implemented)")
        elements.statusLabel:setForeground(colors.yellow)
        elements.statusLabel:setText("Monitor setup coming soon")
    end)

    logging.debug("[settingsMenu] Event handlers setup complete")
end

function settingsMenu.show(elements)
    logging.debug("[settingsMenu] Showing settings menu")
    elements.changeNameMenu:setVisible(false) -- Reset submenu
    elements.frame:setVisible(true)
    elements.frame:setEnabled(true)
end

function settingsMenu.hide(elements)
    logging.debug("[settingsMenu] Hiding settings menu")
    elements.frame:setVisible(false)
    elements.frame:setEnabled(false)
end

return settingsMenu
