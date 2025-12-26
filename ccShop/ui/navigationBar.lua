-- Navigation Bar UI for ccShop
local menuManager = require("menuManager")
local logging = require("logging")

local navigationBar = {}

function navigationBar.create(parent, context)
    logging.debug("[navigationBar] Creating navigation bar UI...")
    local w = parent:getWidth()
    local navBarHeight = math.min(3, parent:getHeight())

    local frame = parent:addFrame()
        :setPosition(1, 1)
        :setSize(w, navBarHeight)
        :setBackground(colors.lightGray)

    local elements = {}

    elements.titleLabel = frame:addLabel()
        :setText(context.shopSettings.shopName)
        :setForeground(colors.black)
        :setBackground(colors.lightGray)
        :setPosition(2, 2)

    elements.settingsButton = frame:addButton()
        :setText("Settings")
        :setForeground(colors.black)
        :setBackground(colors.pink)
        :setPosition(w - 27, 1)
        :setSize(10, navBarHeight)

    elements.homeButton = frame:addButton()
        :setText("Home")
        :setForeground(colors.black)
        :setBackground(colors.pink)
        :setPosition(w - 16, 1)
        :setSize(8, navBarHeight)

    elements.cartButton = frame:addButton()
        :setText("Cart")
        :setForeground(colors.black)
        :setBackground(colors.pink)
        :setPosition(w - 7, 1)
        :setSize(8, navBarHeight)

    elements.frame = frame
    elements.context = context

    -- Setup navigation
    navigationBar.setupEvents(elements, context)

    return elements
end

function navigationBar.setupEvents(elements, context)
    logging.debug("[navigationBar] Setting up event handlers...")

    elements.homeButton:onClick(function()
        context.navigate.toHome()
    end)

    elements.settingsButton:onClick(function()
        context.navigate.toSettings()
    end)

    elements.cartButton:onClick(function()
        context.navigate.toCart()
    end)
end

function navigationBar.updateTitle(elements, title)
    elements.titleLabel:setText(title)
end

function navigationBar.setActiveMenu(elements, menuName)
    elements.homeButton:setBackground(menuName == "home" and colors.white or colors.pink)
    elements.settingsButton:setBackground(menuName == "settings" and colors.white or colors.pink)
    elements.cartButton:setBackground(menuName == "cart" and colors.white or colors.pink)
end

return navigationBar
