-- Menu Manager: Unified state and navigation management for ccWallet UI
local basalt = require("basalt")
local utils = require("ui.utils")
local logging = require("logging")

local menuManager = {}

--------------------------------------------------------------------------------
-- MenuContext: Configuration and state for a single menu
--------------------------------------------------------------------------------

-- Create a new menu context
-- config = {
--   frame: Basalt frame element
--   elements: {name = element} table of named elements
--   navigation: {elementName = {up=target, down=target, enter=callback, ...}}
--   defaultFocus: string name of element to focus by default
--   loadingCheck: function() returning true if menu is in loading state
--   parent: parent frame for focus chain (for submenus)
-- }
function menuManager.createContext(config)
    local ctx = {
        frame = config.frame,
        elements = config.elements or {},
        navigation = config.navigation or {},
        defaultFocus = config.defaultFocus,
        loadingCheck = config.loadingCheck,
        parent = config.parent,
        lastFocus = nil,
        focusableElements = {}
    }

    -- Build focusable elements list from navigation config
    for name, _ in pairs(ctx.navigation) do
        local element = ctx.elements[name]
        if element then
            table.insert(ctx.focusableElements, {name = name, element = element})
        end
    end

    -- Set initial lastFocus
    if ctx.defaultFocus and ctx.elements[ctx.defaultFocus] then
        ctx.lastFocus = ctx.elements[ctx.defaultFocus]
    end

    return ctx
end

--------------------------------------------------------------------------------
-- Setup: Wire up all event handlers for a menu context
--------------------------------------------------------------------------------

function menuManager.setup(ctx)
    logging.debug("[menuManager] Setting up menu")

    -- Setup focus tracking for all navigable elements
    menuManager.setupFocusTracking(ctx)

    -- Setup frame focus handler
    menuManager.setupFrameFocus(ctx)

    -- Setup smart frame click handler
    menuManager.setupFrameClick(ctx)

    -- Setup keyboard navigation
    menuManager.setupNavigation(ctx)

    -- Setup button styles for all buttons in navigation
    menuManager.setupButtonStyles(ctx)

    return ctx
end

--------------------------------------------------------------------------------
-- Focus Tracking: All navigable elements update lastFocus on focus
--------------------------------------------------------------------------------

function menuManager.setupFocusTracking(ctx)
    for name, navConfig in pairs(ctx.navigation) do
        local element = ctx.elements[name]
        if element then
            -- Store existing onFocus if any
            local existingOnFocus = element._onFocusHandler

            element:onFocus(function(self)
                ctx.lastFocus = self
                logging.debug("[menuManager] Focus: " .. name)

                -- For buttons, set the focused state
                if self.setState then
                    self:setState("focused")
                end

                -- Call existing handler if any
                if existingOnFocus then
                    existingOnFocus(self)
                end
            end)

            -- For buttons, clear focused state on blur
            if element.onBlur then
                element:onBlur(function(self)
                    if self.unsetState then
                        self:unsetState("focused")
                    end
                end)
            end
        end
    end
end

--------------------------------------------------------------------------------
-- Frame Focus: Restore lastFocus when frame receives focus
--------------------------------------------------------------------------------

function menuManager.setupFrameFocus(ctx)
    ctx.frame:onFocus(function(self)
        if not self:getEnabled() then return end
        if ctx.lastFocus and ctx.lastFocus:getVisible() and ctx.lastFocus:getEnabled() then
            ctx.lastFocus:setFocused(true)
        end
    end)
end

--------------------------------------------------------------------------------
-- Smart Frame Click: Only restore focus when clicking empty space
--------------------------------------------------------------------------------

function menuManager.setupFrameClick(ctx)
    ctx.frame:onClick(function(self, button, x, y)
        if not self:getEnabled() then return end

        -- Get frame position to calculate relative coordinates
        local frameX, frameY = self:getAbsolutePosition()
        local relX = x - frameX + 1
        local relY = y - frameY + 1

        -- Check if click hit any focusable element
        for _, item in ipairs(ctx.focusableElements) do
            local element = item.element
            if element:getVisible() and element:getEnabled() then
                local ex, ey = element:getPosition()
                local ew, eh = element:getSize()

                -- Check if click is within element bounds
                if relX >= ex and relX < ex + ew and
                   relY >= ey and relY < ey + eh then
                    -- Click hit an element - don't override its focus handling
                    logging.debug("[menuManager] Click on element: " .. item.name)
                    return
                end
            end
        end

        -- Click on empty space - restore lastFocus
        logging.debug("[menuManager] Click on empty space, restoring lastFocus")
        if ctx.lastFocus and ctx.lastFocus:getVisible() and ctx.lastFocus:getEnabled() then
            ctx.lastFocus:setFocused(true)
        end
    end)
end

--------------------------------------------------------------------------------
-- Keyboard Navigation: Declarative config -> handlers
--------------------------------------------------------------------------------

function menuManager.setupNavigation(ctx)
    -- Frame-level key handler for navigation
    ctx.frame:onKey(function(self, key)
        if not self:getEnabled() then return end

        -- Check loading state
        if ctx.loadingCheck and ctx.loadingCheck() then
            return false
        end

        -- Find currently focused element name
        local currentName = menuManager.findFocusedElement(ctx)
        if not currentName then return end

        local navConfig = ctx.navigation[currentName]
        if not navConfig then return end

        -- Map key to direction
        local direction = menuManager.keyToDirection(key)
        if not direction then return end

        -- Get target from nav config
        local target = navConfig[direction]
        if not target then return end

        -- Handle target
        return menuManager.handleNavTarget(ctx, target)
    end)

    -- Per-element key and click handlers
    for name, navConfig in pairs(ctx.navigation) do
        local element = ctx.elements[name]
        if element then
            -- Key handler
            if element.onKey then
                element:onKey(function(self, key)
                    if not self:getEnabled() then return end

                    -- Check loading state
                    if ctx.loadingCheck and ctx.loadingCheck() then
                        return false
                    end

                    -- Map key to direction
                    local direction = menuManager.keyToDirection(key)
                    if not direction then return end

                    -- Get target from nav config
                    local target = navConfig[direction]
                    if not target then return end

                    -- Handle target
                    return menuManager.handleNavTarget(ctx, target)
                end)
            end

            -- Click handler - focus element then trigger enter action
            if element.onClick and navConfig.enter then
                element:onClick(function(self)
                    if not self:getEnabled() then return false end
                    if not self:getVisible() then return false end
                    if ctx.loadingCheck and ctx.loadingCheck() then return false end

                    -- Focus element first
                    self:setFocused(true)
                    if self.setState then
                        self:setState("focused")
                    end
                    ctx.lastFocus = self

                    -- Trigger enter action (same as keyboard enter)
                    return menuManager.handleNavTarget(ctx, navConfig.enter)
                end)
            end
        end
    end
end

function menuManager.findFocusedElement(ctx)
    for name, element in pairs(ctx.elements) do
        if element.isFocused and element:isFocused() then
            return name
        end
    end
    return nil
end

function menuManager.keyToDirection(key)
    if key == keys.up then return "up"
    elseif key == keys.down then return "down"
    elseif key == keys.tab then return "tab"
    elseif key == keys.left then return "left"
    elseif key == keys.right then return "right"
    elseif key == keys.enter then return "enter"
    end
    return nil
end

function menuManager.handleNavTarget(ctx, target)
    if type(target) == "string" then
        -- It's an element name - focus it
        local element = ctx.elements[target]
        if element and element:getVisible() and element:getEnabled() then
            element:setFocused(true)
            return false
        end
    elseif type(target) == "function" then
        -- It's a callback function
        target(ctx)
        return false
    end
    return nil
end

--------------------------------------------------------------------------------
-- Button Styles: Register focused state for buttons only (not inputs)
--------------------------------------------------------------------------------

function menuManager.setupButtonStyles(ctx)
    for name, element in pairs(ctx.elements) do
        -- Check if element is a button (has setBackground but NOT setReplaceChar which inputs have)
        -- Also check it's in navigation and not already styled
        local isButton = element.setBackground and not element.setReplaceChar and not element.getValue
        if isButton and ctx.navigation[name] and not element._menuStyled then
            local text = element:getText() or name

            -- Register focused state with styling
            element:registerState("focused", nil, 100)
                :setBackgroundState("focused", colors.lightBlue)
                :setTextState("focused", ">" .. text .. "<")

            element._menuStyled = true
        end
    end
end

--------------------------------------------------------------------------------
-- Show/Hide: Menu visibility with state management
--------------------------------------------------------------------------------

function menuManager.show(ctx, options)
    options = options or {}
    logging.debug("[menuManager] Showing menu")

    -- Clear all element states first
    menuManager.clearStates(ctx)

    -- Enable and show frame, set global focus
    ctx.frame:setEnabled(true)
    ctx.frame:setVisible(true)
    basalt.setFocus(ctx.frame)

    -- Determine focus target
    local focusTarget = nil
    if options.focusElement then
        focusTarget = ctx.elements[options.focusElement]
    end
    if not focusTarget and ctx.defaultFocus then
        focusTarget = ctx.elements[ctx.defaultFocus]
    end
    if not focusTarget and ctx.lastFocus then
        focusTarget = ctx.lastFocus
    end

    -- Set focus
    if focusTarget and focusTarget:getVisible() and focusTarget:getEnabled() then
        focusTarget:setFocused(true)
        if focusTarget.setState then
            focusTarget:setState("focused")
        end
        ctx.lastFocus = focusTarget
    end
end

function menuManager.hide(ctx)
    logging.debug("[menuManager] Hiding menu")

    -- Clear all element states
    menuManager.clearStates(ctx)

    -- Disable and hide frame
    ctx.frame:setVisible(false)
    ctx.frame:setEnabled(false)
end

function menuManager.clearStates(ctx)
    for name, element in pairs(ctx.elements) do
        if element.unsetState then
            element:unsetState("focused")
        end
    end
end

--------------------------------------------------------------------------------
-- Submenu Support: Show/hide with parent focus management
--------------------------------------------------------------------------------

function menuManager.showSubMenu(ctx, parentCtx, options)
    options = options or {}
    logging.debug("[menuManager] Showing submenu")

    -- Hide parent elements if any
    if parentCtx then
        menuManager.clearStates(parentCtx)
    end

    -- Show submenu frame and set global focus to it
    ctx.frame:setEnabled(true)
    ctx.frame:setVisible(true)
    basalt.setFocus(ctx.frame)

    -- Determine focus target (same priority as show())
    local focusTarget = nil
    if options.focusElement then
        focusTarget = ctx.elements[options.focusElement]
    end
    if not focusTarget and ctx.defaultFocus then
        focusTarget = ctx.elements[ctx.defaultFocus]
    end
    if not focusTarget and ctx.lastFocus then
        focusTarget = ctx.lastFocus
    end

    -- Set focus on element within submenu
    if focusTarget and focusTarget:getVisible() and focusTarget:getEnabled() then
        focusTarget:setFocused(true)
        if focusTarget.setState then
            focusTarget:setState("focused")
        end
        ctx.lastFocus = focusTarget
    end
end

function menuManager.hideSubMenu(ctx, parentCtx)
    logging.debug("[menuManager] Hiding submenu")

    -- Clear submenu states and hide
    menuManager.clearStates(ctx)
    ctx.frame:setVisible(false)
    ctx.frame:setEnabled(false)

    -- Restore focus to parent
    if parentCtx then
        basalt.setFocus(parentCtx.frame)

        -- Focus parent's lastFocus element
        if parentCtx.lastFocus then
            local focusTarget = parentCtx.lastFocus
            if focusTarget:getVisible() and focusTarget:getEnabled() then
                focusTarget:setFocused(true)
                if focusTarget.setState then
                    focusTarget:setState("focused")
                end
            end
        end
    end
end

return menuManager
