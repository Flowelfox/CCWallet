-- Footer UI for ccShop
local logging = require("logging")
local basalt = require("basalt")

local footer = {}

function footer.create(parent, context)
    logging.debug("[footer] Creating footer UI...")
    local w = parent:getWidth()
    local h = parent:getHeight()

    local frame = parent:addFrame()
        :setPosition(1, h)
        :setSize(w, 1)
        :setBackground(colors.lightGray)

    local elements = {}

    elements.itemsLabel = frame:addLabel()
        :setText("Items: 0")
        :setForeground(colors.black)
        :setBackground(colors.lightGray)
        :setPosition(1, 1)

    elements.separatorLabel = frame:addLabel()
        :setText("|")
        :setForeground(colors.black)
        :setBackground(colors.lightGray)
        :setPosition(14, 1)

    elements.userLabel = frame:addLabel()
        :setText("User: None")
        :setForeground(colors.black)
        :setBackground(colors.lightGray)
        :setPosition(16, 1)

    -- Notification bar (overlays the footer)
    elements.notificationBar = frame:addFrame()
        :setPosition(1, 1)
        :setSize(w, 1)
        :setBackground(colors.lightGray)
        :setVisible(false)

    elements.notificationIcon = elements.notificationBar:addLabel()
        :setText(string.char(7)) -- Bell character
        :setForeground(colors.black)
        :setBackground(colors.lightGray)
        :setPosition(1, 1)
        :setSize(2, 1)

    elements.notificationText = elements.notificationBar:addLabel()
        :setText("")
        :setForeground(colors.black)
        :setBackground(colors.lightGray)
        :setPosition(3, 1)

    -- Timer for auto-hiding notifications
    elements.notificationTimer = frame:addTimer()
        :setInterval(3)
        :stop()

    elements.notificationTimer:setAction(function()
        footer.hideNotification(elements)
    end)

    elements.frame = frame
    elements.context = context

    logging.debug("[footer] Footer created successfully")
    return elements
end

function footer.updateItemCount(elements, count)
    logging.debug("[footer] Updating item count: " .. count)
    elements.itemsLabel:setText("Items: " .. count)
end

function footer.updateUser(elements, username)
    logging.debug("[footer] Updating user: " .. (username or "None"))
    elements.userLabel:setText("User: " .. (username or "None"))
end

function footer.showNotification(elements, message, color, autoHide)
    logging.debug("[footer] Showing notification: " .. message)
    elements.notificationText:setText(message)
    elements.notificationText:setForeground(color or colors.black)
    elements.notificationIcon:setForeground(color or colors.black)
    elements.notificationBar:setVisible(true)

    if autoHide ~= false then
        elements.notificationTimer:start()
    end
end

function footer.hideNotification(elements)
    logging.debug("[footer] Hiding notification")
    elements.notificationTimer:stop()
    elements.notificationBar:setVisible(false)
end

function footer.showSuccess(elements, message)
    footer.showNotification(elements, message, colors.green, true)
end

function footer.showError(elements, message)
    footer.showNotification(elements, message, colors.red, true)
end

function footer.showWarning(elements, message)
    footer.showNotification(elements, message, colors.yellow, true)
end

return footer
