-- UI Utilities for ccShop
local utils = {}

-- Clear error labels
function utils.clearErrors(...)
    local labels = {...}
    for _, label in ipairs(labels) do
        label:setText("")
    end
end

-- Set error/success message with color
function utils.setError(label, message, isSuccess)
    label:setForeground(isSuccess and colors.green or colors.red)
    label:setText(message)
end

--------------------------------------------------------------------------------
-- Loading Animation Helper
--------------------------------------------------------------------------------

-- Create a loading animation manager for a button
-- Returns { start = function(), stop = function(originalText) }
function utils.createLoadingAnimation(button, timer, textPattern)
    local dots = {
        textPattern .. ".  ",
        textPattern .. ".. ",
        textPattern .. "..."
    }
    local dotIndex = 1

    timer:setAction(function()
        button:setText(dots[dotIndex])
        dotIndex = (dotIndex % 3) + 1
    end)

    return {
        start = function()
            dotIndex = 1
            button:setState("loading")
            button:setText(dots[1])
            button:setEnabled(false)
            timer:start()
        end,
        stop = function(originalText)
            timer:stop()
            button:unsetState("loading")
            button:setText(originalText)
            button:setEnabled(true)
        end
    }
end

--------------------------------------------------------------------------------
-- Element Batch Operations
--------------------------------------------------------------------------------

-- Enable/disable multiple elements at once
function utils.setElementsEnabled(enabled, ...)
    for _, element in ipairs({...}) do
        element:setEnabled(enabled)
    end
end

-- Show/hide multiple elements at once
function utils.setElementsVisible(visible, ...)
    for _, element in ipairs({...}) do
        element:setVisible(visible)
    end
end

-- Enable and show multiple elements
function utils.showElements(...)
    for _, element in ipairs({...}) do
        element:setEnabled(true)
        element:setVisible(true)
    end
end

-- Disable and hide multiple elements
function utils.hideElements(...)
    for _, element in ipairs({...}) do
        element:setEnabled(false)
        element:setVisible(false)
    end
end

--------------------------------------------------------------------------------
-- Item Display Helpers
--------------------------------------------------------------------------------

-- Format item name with dots for price alignment
function utils.formatItemName(displayName, totalWidth, priceWidth)
    local nameWidth = totalWidth - priceWidth - 6 -- 6 for quantity controls
    if #displayName >= nameWidth then
        return displayName:sub(1, nameWidth - 1)
    end
    local dots = string.rep(".", nameWidth - #displayName - 1)
    return displayName .. " " .. dots
end

-- Format price with currency symbol
function utils.formatPrice(price)
    return tostring(price) .. "$"
end

return utils
