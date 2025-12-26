-- Send Sub-Menu UI for ccWallet
local menuManager = require("ui.menuManager")
local utils = require("ui.utils")
local logging = require("logging")

local sendMenu = {}

function sendMenu.create(parent, w, h)
    local menu = {}

    menu.frame = parent:addFrame()
        :setPosition(2, 4)
        :setSize(w - 2, h - 4)
        :setBackground(colors.white)
        :setVisible(false)
        :setEnabled(false)

    menu.titleLabel = menu.frame:addLabel()
        :setText("Send money")
        :setPosition(1, 1)
        :setSize(10, 1)
        :setForeground(colors.gray)

    menu.recipientLabel = menu.frame:addLabel()
        :setText("Recipient: ")
        :setPosition(1, 3)
        :setSize(10, 1)
        :setForeground(colors.gray)

    menu.recipientInput = menu.frame:addInput()
        :setPosition(1, 4)
        :setSize(20, 1)
        :setZ(1)

    menu.amountLabel = menu.frame:addLabel()
        :setText("Amount: ")
        :setPosition(2, 6)
        :setSize(10, 1)
        :setForeground(colors.gray)

    menu.amountInput = menu.frame:addInput()
        :setPosition(1, 7)
        :setSize(20, 1)
        :setText("0")
        :setZ(1)

    menu.errorLabel = menu.frame:addLabel()
        :setText("")
        :setPosition(1, 8)
        :setSize(w - 4, 1)
        :setForeground(colors.red)

    menu.errorLabel2 = menu.frame:addLabel()
        :setText("")
        :setPosition(1, 9)
        :setSize(w - 4, 1)
        :setForeground(colors.red)

    -- Buttons (centered horizontally)
    menu.confirmButton = menu.frame:addButton()
        :setText("Confirm")
        :setY(10)
        :setSize(14, 3)
        :setBackground(colors.magenta)
        :centerHorizontal("parent", -1)
        :registerState("loading", nil, 300)
        :setBackgroundState("loading", colors.lightBlue)

    menu.backButton = menu.frame:addButton()
        :setText("Back")
        :setSize(14, 3)
        :setBackground(colors.magenta)
        :centerHorizontal("parent", -1)
        :alignBottom("parent", -3)

    -- Animation timer
    menu.sendingTimer = menu.frame:addTimer()
        :setInterval(0.4)
        :stop()

    -- Suggestion UI
    menu.firstSuggestion = menu.frame:addLabel()
        :setText("")
        :setForeground(colors.green)
        :setPosition(20, 4)
        :setSize(20, 1)
        :setZ(5)

    menu.suggestionList = menu.frame:addList()
        :setPosition(1, 5)
        :setSize(20, 10)
        :setBackground(colors.gray)
        :setZ(4)
        :setVisible(false)

    return menu
end

function sendMenu.setupEvents(menu, elements, callbacks)
    -- Loading check helper
    local function isLoading()
        return menu.confirmButton:hasState("loading")
    end

    -- Helper for suggestion handling in recipient input
    local function handleSuggestion()
        local listVisible = menu.suggestionList:getVisible()
        local selectedItem = menu.suggestionList:getSelectedItem()
        if listVisible and selectedItem then
            menu.recipientInput:setText(selectedItem.text or selectedItem)
            if callbacks.onUpdateSuggestions then
                callbacks.onUpdateSuggestions()
            end
        else
            local suggestion = menu.firstSuggestion:getText()
            if suggestion ~= "" then
                menu.recipientInput:setText(menu.recipientInput:getText() .. suggestion)
                if callbacks.onUpdateSuggestions then
                    callbacks.onUpdateSuggestions()
                end
            end
        end
    end

    -- Navigation config with custom handlers for suggestion list
    local navigation = {
        recipientInput = {
            up = function()
                if not menu.suggestionList:getVisible() then
                    menu.backButton:setFocused(true)
                else
                    local selectedIdx = menu.suggestionList:getSelectedIndex()
                    if selectedIdx and selectedIdx > 1 then
                        menu.suggestionList:selectPrevious()
                    end
                end
            end,
            down = function()
                if menu.suggestionList:getVisible() then
                    menu.suggestionList:selectNext()
                else
                    menu.amountInput:setFocused(true)
                end
            end,
            tab = function()
                handleSuggestion()
                menu.amountInput:setFocused(true)
            end,
            enter = function()
                handleSuggestion()
                if menu.recipientInput:getText() ~= "" then
                    menu.amountInput:setFocused(true)
                end
            end
        },
        amountInput = {
            up = "recipientInput",
            down = "confirmButton",
            tab = "confirmButton",
            enter = function()
                if menu.amountInput:getText() ~= "" then
                    menu.confirmButton:setFocused(true)
                end
            end
        },
        confirmButton = {
            up = "amountInput",
            down = "backButton",
            tab = "backButton",
            enter = callbacks.onSend
        },
        backButton = {
            up = "confirmButton",
            down = "recipientInput",
            tab = "recipientInput",
            enter = callbacks.onCloseSend
        }
    }

    -- Create and setup menu context
    menu.ctx = menuManager.createContext({
        frame = menu.frame,
        elements = {
            recipientInput = menu.recipientInput,
            amountInput = menu.amountInput,
            confirmButton = menu.confirmButton,
            backButton = menu.backButton
        },
        navigation = navigation,
        defaultFocus = "recipientInput",
        loadingCheck = isLoading,
        parent = elements.parent
    })

    menuManager.setup(menu.ctx)

    -- Hide suggestions when recipient input loses focus
    menu.recipientInput:onBlur(function(self)
        menu.suggestionList:setVisible(false)
        menu.firstSuggestion:setText("")
    end)

    -- Amount input validation (numbers only)
    menu.amountInput:onChar(function(self, char)
        if char == "-" then
            return false
        end
        if tonumber(char) == nil and char ~= '.' then
            return false
        end
        if self:getText() == "0" then
            self:setText("")
        end
    end)

end

function sendMenu.clear(menu)
    logging.debug("[sendMenu] Clearing send form")
    menu.recipientInput:setText("")
    menu.amountInput:setText("0")
    utils.clearErrors(menu.errorLabel, menu.errorLabel2)
end

function sendMenu.setLoading(menu, loading)
    if loading then
        logging.debug("[sendMenu] Setting loading state: ON")
        if not menu.loadingAnim then
            menu.loadingAnim = utils.createLoadingAnimation(
                menu.confirmButton,
                menu.sendingTimer,
                "Sending"
            )
        end
        menu.loadingAnim.start()
        utils.setElementsVisible(false, menu.backButton)
        utils.setElementsEnabled(false, menu.recipientInput, menu.amountInput)
    else
        logging.debug("[sendMenu] Setting loading state: OFF")
        if menu.loadingAnim then
            menu.loadingAnim.stop("Confirm")
        end
        utils.setElementsVisible(true, menu.backButton)
        utils.setElementsEnabled(true, menu.recipientInput, menu.amountInput)
    end
end

function sendMenu.getData(menu)
    return menu.recipientInput:getText(),
           tonumber(menu.amountInput:getText())
end

return sendMenu
