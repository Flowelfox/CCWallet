-- Account Menu UI for ccWallet
local menuManager = require("ui.menuManager")
local utils = require("ui.utils")
local logging = require("logging")
local basalt = require("basalt")
local transactionsMenu = require("ui.transactionsMenu")
local sendMenuModule = require("ui.sendMenu")
local historyMenuModule = require("ui.historyMenu")

local accountMenu = {}

function accountMenu.create(parent, context)
    logging.debug("[accountMenu] Creating account menu UI...")
    local frame = parent:addFrame()
        :setPosition(1, 1)
        :setSize(parent:getWidth(), parent:getHeight())
        :setBackground(colors.white)
        :setVisible(false)

    local elements = {}
    elements.parent = parent
    local w = parent:getWidth()
    local h = parent:getHeight()

    -- Account info
    elements.accountNameLabel = frame:addLabel()
        :setText("Account: ")
        :setPosition(2, 2)
        :setSize(8, 1)
        :setForeground(colors.gray)

    elements.accountNameValue = frame:addLabel()
        :setText("")
        :setPosition(10, 2)
        :setForeground(colors.green)

    elements.balanceLabel = frame:addLabel()
        :setText("Balance:")
        :setPosition(2, 3)
        :setSize(8, 1)
        :setForeground(colors.gray)

    elements.balanceValue = frame:addLabel()
        :setText("0$")
        :setPosition(10, 3)
        :setForeground(colors.green)

    -- Main buttons (using stretchWidth for full width minus padding)
    elements.transactionsButton = frame:addButton()
        :setText("Transactions")
        :setPosition(2, 5)
        :stretchWidth("parent", 1)
        :setHeight(3)
        :setBackground(colors.magenta)

    elements.sendButton = frame:addButton()
        :setText("Send")
        :setPosition(2, 9)
        :stretchWidth("parent", 1)
        :setHeight(3)
        :setBackground(colors.magenta)

    elements.historyButton = frame:addButton()
        :setText("History")
        :setPosition(2, 13)
        :stretchWidth("parent", 1)
        :setHeight(3)
        :setBackground(colors.magenta)

    elements.logoutButton = frame:addButton()
        :setText("Logout")
        :setPosition(2, 17)
        :stretchWidth("parent", 1)
        :setHeight(3)
        :setBackground(colors.magenta)

    -- Create sub-menus
    elements.transactionsMenu = transactionsMenu.create(frame, w, h)
    elements.sendMenu = sendMenuModule.create(frame, w, h)
    elements.historyMenu = historyMenuModule.create(frame, w, h)

    elements.frame = frame
    elements.context = context

    -- Helper for updating suggestions
    local function updateSuggestions()
        local input = elements.sendMenu.recipientInput:getText()
        local suggestionList = elements.sendMenu.suggestionList
        local firstSuggestion = elements.sendMenu.firstSuggestion

        if not input or input == "" then
            suggestionList:setVisible(false)
            firstSuggestion:setText("")
            return
        end

        local matches = {}
        for _, user in ipairs(context.state.registeredUsers) do
            if user:sub(1, #input):lower() == input:lower() and user:lower() ~= input:lower() then
                table.insert(matches, user)
                if #matches >= 5 then break end
            end
        end

        if #matches > 0 then
            suggestionList:clear()
            for _, match in ipairs(matches) do
                suggestionList:addItem(match)
            end
            suggestionList:setVisible(true)
            suggestionList:selectNext()
            firstSuggestion:setText(matches[1]:sub(#input + 1))
        else
            suggestionList:setVisible(false)
            firstSuggestion:setText("")
        end
    end

    -- Define all callbacks
    local callbacks = {
        onOpenTransactions = function()
            logging.debug("[accountMenu] Opening transactions menu")
            accountMenu.showSubMenu(elements, "transactions")
            basalt.schedule(function()
                context.refreshUserData()
            end)
        end,

        onCloseTransactions = function()
            logging.debug("[accountMenu] Closing transactions menu")
            accountMenu.hideSubMenu(elements, "transactions")
        end,

        onOpenSend = function()
            logging.debug("[accountMenu] Opening send money menu")
            accountMenu.clearSendForm(elements)
            accountMenu.showSubMenu(elements, "send")
            basalt.schedule(function()
                context.updateRegisteredUsers()
            end)
        end,

        onCloseSend = function()
            logging.debug("[accountMenu] Closing send money menu")
            accountMenu.clearSendForm(elements)
            accountMenu.hideSubMenu(elements, "send")
        end,

        onSend = function()
            if elements.sendMenu.confirmButton:hasState("loading") then
                logging.debug("[accountMenu] Send attempt blocked - already in progress")
                return
            end

            local recipient, amount = accountMenu.getSendData(elements)
            local sendMenu = elements.sendMenu
            logging.info("[accountMenu] Send money attempt: " .. tostring(amount) .. " to " .. tostring(recipient))

            if not recipient or recipient == "" then
                logging.debug("[accountMenu] Send validation failed - empty recipient")
                utils.setError(sendMenu.errorLabel, "Enter recipient", false)
                return
            end

            if not amount or amount <= 0 then
                logging.debug("[accountMenu] Send validation failed - invalid amount: " .. tostring(amount))
                utils.setError(sendMenu.errorLabel, "Enter valid amount", false)
                return
            end

            sendMenu.errorLabel:setText("")
            sendMenu.errorLabel2:setText("")

            logging.debug("[accountMenu] Starting send request...")
            accountMenu.setSendLoading(elements, true)

            basalt.schedule(function()
                local success, result
                local timedOut = false

                parallel.waitForAny(
                    function()
                        success, result = context.bankAPI.sendMoney(recipient, amount)
                    end,
                    function()
                        sleep(5)
                        timedOut = true
                    end
                )

                if timedOut and not success then
                    logging.warning("[accountMenu] Send money timed out: " .. tostring(amount) .. " to " .. tostring(recipient))
                    result = "Connection timed out"
                end

                accountMenu.setSendLoading(elements, false)

                if success then
                    logging.info("[accountMenu] Money sent successfully: " .. tostring(amount) .. " to " .. recipient)
                    context.refreshUserData()
                    sendMenu.errorLabel:setForeground(colors.green)
                    sendMenu.errorLabel:setText("Money sent!")
                    accountMenu.clearSendForm(elements)
                else
                    logging.warning("[accountMenu] Send money failed: " .. (result or "unknown error"))
                    utils.wrapText(
                        sendMenu.errorLabel,
                        sendMenu.errorLabel2,
                        result or "Transfer failed",
                        20
                    )
                end
            end)
        end,

        onUpdateSuggestions = function()
            updateSuggestions()
        end,

        onOpenHistory = function()
            logging.debug("[accountMenu] Opening history menu")
            accountMenu.showSubMenu(elements, "history")
            basalt.schedule(function()
                context.refreshUserData()
            end)
        end,

        onCloseHistory = function()
            logging.debug("[accountMenu] Closing history menu")
            accountMenu.hideSubMenu(elements, "history")
        end,

        onLogout = function()
            logging.info("[accountMenu] User logging out: " .. (context.state.currentUser and context.state.currentUser.login or "unknown"))
            context.state.token = nil
            context.state.currentUser = nil
            accountMenu.hide(elements)
            context.navigate.toLogin(true)
            basalt.schedule(function()
                context.bankAPI.logout()
            end)
        end
    }

    -- Setup recipient input change handler for suggestions
    elements.sendMenu.recipientInput:onChange("text", function(self, value)
        updateSuggestions()
    end)

    -- Setup events with internal callbacks
    accountMenu.setupEvents(elements, callbacks)

    return elements
end

function accountMenu.setupEvents(elements, callbacks)
    logging.debug("[accountMenu] Setting up event handlers...")

    -- Check if any submenu is enabled
    local function isSubMenuEnabled()
        return elements.transactionsMenu.frame:getEnabled()
            or elements.sendMenu.frame:getEnabled()
            or elements.historyMenu.frame:getEnabled()
    end

    -- Navigation config for main buttons
    local navigation = {
        transactionsButton = {
            up = "logoutButton",
            down = "sendButton",
            tab = "sendButton",
            enter = callbacks.onOpenTransactions
        },
        sendButton = {
            up = "transactionsButton",
            down = "historyButton",
            tab = "historyButton",
            enter = callbacks.onOpenSend
        },
        historyButton = {
            up = "sendButton",
            down = "logoutButton",
            tab = "logoutButton",
            enter = callbacks.onOpenHistory
        },
        logoutButton = {
            up = "historyButton",
            down = "transactionsButton",
            tab = "transactionsButton",
            enter = callbacks.onLogout
        }
    }

    -- Create menu context
    elements.ctx = menuManager.createContext({
        frame = elements.frame,
        elements = {
            transactionsButton = elements.transactionsButton,
            sendButton = elements.sendButton,
            historyButton = elements.historyButton,
            logoutButton = elements.logoutButton
        },
        navigation = navigation,
        defaultFocus = "transactionsButton"
    })

    menuManager.setup(elements.ctx)

    -- Override frame focus to check submenus
    elements.frame:onFocus(function(self)
        if not self:getEnabled() then return end
        if not isSubMenuEnabled() and elements.ctx.lastFocus then
            elements.ctx.lastFocus:setFocused(true)
        end
    end)

    -- Override frame key handler to check submenus
    local originalOnKey = elements.frame._onKey
    elements.frame:onKey(function(self, key)
        if not self:getEnabled() then return end
        if isSubMenuEnabled() then return end  -- Let submenu handle keys

        -- Use the navigation
        local currentName = menuManager.findFocusedElement(elements.ctx)
        if currentName then
            local navConfig = navigation[currentName]
            local direction = menuManager.keyToDirection(key)
            if direction and navConfig and navConfig[direction] then
                return menuManager.handleNavTarget(elements.ctx, navConfig[direction])
            end
        end
    end)

    -- Setup sub-menu events
    transactionsMenu.setupEvents(elements.transactionsMenu, elements, callbacks)
    sendMenuModule.setupEvents(elements.sendMenu, elements, callbacks)
    historyMenuModule.setupEvents(elements.historyMenu, elements, callbacks)
end

function accountMenu.show(elements)
    logging.debug("[accountMenu] Showing account menu")
    menuManager.show(elements.ctx, {
        focusElement = "transactionsButton"
    })
    -- Resolve constraints on buttons using stretchWidth
    elements.transactionsButton:resolveAllConstraints()
    elements.sendButton:resolveAllConstraints()
    elements.historyButton:resolveAllConstraints()
    elements.logoutButton:resolveAllConstraints()
end

function accountMenu.hide(elements)
    logging.debug("[accountMenu] Hiding account menu")
    menuManager.hide(elements.ctx)
end

function accountMenu.showSubMenu(elements, menuName)
    logging.debug("[accountMenu] Showing sub-menu: " .. menuName)

    -- Hide and disable main buttons
    utils.hideElements(
        elements.transactionsButton,
        elements.sendButton,
        elements.historyButton,
        elements.logoutButton
    )

    -- Show selected sub-menu
    if menuName == "transactions" then
        menuManager.showSubMenu(elements.transactionsMenu.ctx, elements.ctx)
    elseif menuName == "send" then
        menuManager.showSubMenu(elements.sendMenu.ctx, elements.ctx)
    elseif menuName == "history" then
        menuManager.showSubMenu(elements.historyMenu.ctx, elements.ctx)
    end
end

function accountMenu.hideSubMenu(elements, menuName)
    logging.debug("[accountMenu] Hiding sub-menu: " .. menuName)

    -- Show and enable main buttons first (so lastFocus element is visible)
    utils.showElements(
        elements.transactionsButton,
        elements.sendButton,
        elements.historyButton,
        elements.logoutButton
    )

    -- Hide selected sub-menu and restore focus to parent's lastFocus
    if menuName == "transactions" then
        menuManager.hideSubMenu(elements.transactionsMenu.ctx, elements.ctx)
    elseif menuName == "send" then
        menuManager.hideSubMenu(elements.sendMenu.ctx, elements.ctx)
    elseif menuName == "history" then
        menuManager.hideSubMenu(elements.historyMenu.ctx, elements.ctx)
    end
end

function accountMenu.updateUserData(elements, user)
    logging.debug("[accountMenu] Updating user data display for: " .. user.login)
    elements.accountNameValue:setText(user.login)
    local balanceRounded = math.floor(user.balance * 100) / 100
    elements.balanceValue:setText(balanceRounded .. "$")

    transactionsMenu.updateTransactions(elements.transactionsMenu, user.transactions)
    historyMenuModule.updateHistory(elements.historyMenu, user.history)
end

function accountMenu.clearSendForm(elements)
    sendMenuModule.clear(elements.sendMenu)
end

function accountMenu.setSendLoading(elements, loading)
    sendMenuModule.setLoading(elements.sendMenu, loading)
end

function accountMenu.getSendData(elements)
    return sendMenuModule.getData(elements.sendMenu)
end

return accountMenu
