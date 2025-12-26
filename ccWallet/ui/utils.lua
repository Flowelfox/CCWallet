-- UI Utilities for ccWallet
local utils = {}

-- Wrap text across two labels
function utils.wrapText(label1, label2, text, limit)
    if #text > limit then
        local splitPos = limit
        while splitPos > 0 and text:sub(splitPos, splitPos) ~= " " do
            splitPos = splitPos - 1
        end
        if splitPos == 0 then
            splitPos = limit
        end
        label1:setText(text:sub(1, splitPos))
        label2:setText(text:sub(splitPos + 1))
    else
        label1:setText(text)
        label2:setText("")
    end
end

-- Setup button with state-based focus styling
function utils.setupButton(button, normalText, focusedText, onFocusCallback)
    -- Register focused state with styling (priority 100, below loading at 300)
    button:registerState("focused", nil, 100)
        :setBackgroundState("focused", colors.lightBlue)
        :setTextState("focused", ">" .. (focusedText or normalText) .. "<")

    -- Activate/deactivate focused state on focus/blur
    button:onFocus(function(self)
        self:setState("focused")
        if onFocusCallback then
            onFocusCallback(self)
        end
    end)

    button:onBlur(function(self)
        self:unsetState("focused")
    end)
end

-- Execute button action with proper guards and focus
-- Returns true if action was executed, false if blocked
function utils.executeAction(button, callback, loadingCheck)
    if not button:getEnabled() then return false end
    if not button:getVisible() then return false end
    if loadingCheck and loadingCheck() then return false end
    -- Set focused state directly for immediate visual feedback
    button:setState("focused")
    button:setFocused(true)
    callback()
    return true
end

-- Bind click handler to button with standard behavior
-- onClick: focus + execute action
function utils.bindClick(button, callback, loadingCheck)
    button:onClick(function(self)
        utils.executeAction(self, callback, loadingCheck)
    end)
end

-- Handle Enter key in onKey handler with standard behavior
-- Returns false to stop propagation if Enter was handled, nil otherwise
function utils.handleEnterKey(button, key, callback, loadingCheck)
    if key == keys.enter then
        utils.executeAction(button, callback, loadingCheck)
        return false
    end
end

-- Clear error labels
function utils.clearErrors(...)
    local labels = {...}
    for _, label in ipairs(labels) do
        label:setText("")
    end
end

-- Set error with color
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
    -- textPattern example: "Sending" creates {"Sending.  ", "Sending.. ", "Sending..."}
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

return utils
