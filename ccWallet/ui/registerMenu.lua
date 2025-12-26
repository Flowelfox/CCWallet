-- Register Menu UI for ccWallet
local menuManager = require("ui.menuManager")
local utils = require("ui.utils")
local logging = require("logging")
local basalt = require("basalt")

local registerMenu = {}

function registerMenu.create(parent, context)
    logging.debug("[registerMenu] Creating register menu UI...")
    local frame = parent:addFrame()
        :setPosition(1, 1)
        :fillParent()
        :setBackground(colors.white)
        :setVisible(false)

    local elements = {}
    local inputWidth = 24

    -- Title (centered horizontally)
    local titleWidth = 18
    local titleX = math.floor((parent:getWidth() - titleWidth) / 2) -1
    elements.titleLabel = frame:addBigFont()
        :setText("Wallet")
        :setSize(titleWidth, 3)
        :setForeground(colors.magenta)
        :setBackground(colors.white)
        :setPosition(titleX, 2)

    -- Login input
    elements.loginLabel = frame:addLabel()
        :setText("New login")
        :setForeground(colors.gray)
        :setPosition(2, 6)
        :setSize(inputWidth, 1)

    elements.loginInput = frame:addInput()
        :setPosition(2, 7)
        :setSize(inputWidth, 1)

    -- Password input
    elements.passwordLabel = frame:addLabel()
        :setText("New password")
        :setForeground(colors.gray)
        :setPosition(2, 9)
        :setSize(inputWidth, 1)

    elements.passwordInput = frame:addInput()
        :setPosition(2, 10)
        :setSize(inputWidth, 1)
        :setReplaceChar("*")

    -- Repeat password input
    elements.repeatLabel = frame:addLabel()
        :setText("Repeat password")
        :setForeground(colors.gray)
        :setPosition(2, 12)
        :setSize(inputWidth, 1)

    elements.repeatInput = frame:addInput()
        :setPosition(2, 13)
        :setSize(inputWidth, 1)
        :setReplaceChar("*")

    -- Error labels
    elements.errorLabel1 = frame:addLabel()
        :setText("")
        :setPosition(2, 15)
        :setSize(inputWidth, 1)
        :setForeground(colors.red)

    elements.errorLabel2 = frame:addLabel()
        :setText("")
        :setPosition(2, 16)
        :setSize(inputWidth, 1)
        :setForeground(colors.red)

    -- Buttons (side by side, aligned to bottom)
    elements.confirmButton = frame:addButton()
        :setPosition(2, 1)
        :setSize(11, 3)
        :setBackground(colors.magenta)
        :setText("Register")
        :alignBottom("parent", -1)
        :registerState("loading", nil, 300)
        :setBackgroundState("loading", colors.lightBlue)

    elements.backButton = frame:addButton()
        :setSize(11, 3)
        :setBackground(colors.magenta)
        :setText("Back")
        :alignBottom("parent", -1)
        :alignRight("parent", -1)

    -- Animation timer
    elements.connectingTimer = frame:addTimer()
        :setInterval(0.4)
        :stop()

    elements.frame = frame
    elements.context = context

    -- Define callbacks
    local function handleConfirm()
        if elements.confirmButton:hasState("loading") then
            logging.debug("[registerMenu] Registration attempt blocked - already in progress")
            return
        end

        local login = elements.loginInput:getText()
        local password = elements.passwordInput:getText()
        local repeatPassword = elements.repeatInput:getText()
        logging.info("[registerMenu] Registration attempt for user: " .. login)

        if login == "" then
            logging.debug("[registerMenu] Registration validation failed - empty login")
            utils.setError(elements.errorLabel1, "Please enter login", false)
            return
        end

        if password == "" then
            logging.debug("[registerMenu] Registration validation failed - empty password")
            utils.setError(elements.errorLabel1, "Please enter password", false)
            return
        end

        if repeatPassword == "" then
            logging.debug("[registerMenu] Registration validation failed - empty repeat password")
            utils.setError(elements.errorLabel1, "Please repeat password", false)
            return
        end

        if password ~= repeatPassword then
            logging.debug("[registerMenu] Registration validation failed - passwords do not match")
            utils.setError(elements.errorLabel1, "Passwords do not match", false)
            return
        end

        -- Clear any previous errors
        elements.errorLabel1:setText("")
        elements.errorLabel2:setText("")

        -- Show loading state
        logging.debug("[registerMenu] Starting registration request...")
        registerMenu.setLoading(elements, true)

        -- Schedule registration to run async
        basalt.schedule(function()
            local success, result
            local timedOut = false

            parallel.waitForAny(
                function()
                    success, result = context.bankAPI.register(login, password)
                end,
                function()
                    sleep(5)
                    timedOut = true
                end
            )

            if timedOut and not success then
                logging.warning("[registerMenu] Registration timed out for user: " .. login)
                result = "Connection timed out"
            end

            registerMenu.setLoading(elements, false)

            if success then
                logging.info("[registerMenu] Registration successful for user: " .. login)
                registerMenu.clear(elements)
                context.navigate.toLogin()
                context.showLoginMessage("User registered!", colors.green)
            else
                logging.warning("[registerMenu] Registration failed for user: " .. login .. " - " .. (result or "unknown error"))
                utils.wrapText(
                    elements.errorLabel1,
                    elements.errorLabel2,
                    result or "Registration failed",
                    24
                )
            end
        end)
    end

    local function handleBack()
        if elements.confirmButton:hasState("loading") then return end
        logging.debug("[registerMenu] User clicked Back button")
        registerMenu.clear(elements)
        context.navigate.toLogin()
    end

    -- Setup events with internal callbacks
    registerMenu.setupEvents(elements, {
        onConfirm = handleConfirm,
        onBack = handleBack
    })

    return elements
end

function registerMenu.setupEvents(elements, callbacks)
    logging.debug("[registerMenu] Setting up event handlers...")

    -- Loading check helper
    local function isLoading()
        return elements.confirmButton:hasState("loading")
    end

    -- Navigation config with left/right for buttons
    local navigation = {
        loginInput = {
            up = "repeatInput",
            down = "passwordInput",
            tab = "passwordInput",
            enter = function()
                if elements.loginInput:getText() ~= "" then
                    elements.passwordInput:setFocused(true)
                end
            end
        },
        passwordInput = {
            up = "loginInput",
            down = "repeatInput",
            tab = "repeatInput",
            enter = function()
                if elements.passwordInput:getText() ~= "" then
                    elements.repeatInput:setFocused(true)
                end
            end
        },
        repeatInput = {
            up = "passwordInput",
            down = "confirmButton",
            tab = "confirmButton",
            enter = function()
                if elements.repeatInput:getText() ~= "" then
                    elements.confirmButton:setFocused(true)
                end
            end
        },
        confirmButton = {
            up = "repeatInput",
            down = "loginInput",
            tab = "loginInput",
            left = "backButton",
            right = "backButton",
            enter = callbacks.onConfirm
        },
        backButton = {
            up = "repeatInput",
            down = "loginInput",
            tab = "loginInput",
            left = "confirmButton",
            right = "confirmButton",
            enter = callbacks.onBack
        }
    }

    -- Create and setup menu context
    elements.ctx = menuManager.createContext({
        frame = elements.frame,
        elements = {
            loginInput = elements.loginInput,
            passwordInput = elements.passwordInput,
            repeatInput = elements.repeatInput,
            confirmButton = elements.confirmButton,
            backButton = elements.backButton
        },
        navigation = navigation,
        defaultFocus = "loginInput",
        loadingCheck = isLoading
    })

    menuManager.setup(elements.ctx)
end

function registerMenu.show(elements)
    logging.debug("[registerMenu] Showing register menu")
    menuManager.show(elements.ctx, {
        focusElement = "loginInput"
    })
end

function registerMenu.hide(elements)
    logging.debug("[registerMenu] Hiding register menu")
    menuManager.hide(elements.ctx)
end

function registerMenu.clear(elements)
    logging.debug("[registerMenu] Clearing form inputs")
    elements.loginInput:setText("")
    elements.passwordInput:setText("")
    elements.repeatInput:setText("")
    utils.clearErrors(elements.errorLabel1, elements.errorLabel2)
end

function registerMenu.getCredentials(elements)
    return elements.loginInput:getText(),
           elements.passwordInput:getText(),
           elements.repeatInput:getText()
end

function registerMenu.setInitialValues(elements, login, password)
    logging.debug("[registerMenu] Setting initial form values")
    elements.loginInput:setText(login or "")
    elements.passwordInput:setText(password or "")
end

function registerMenu.setLoading(elements, loading)
    if loading then
        logging.debug("[registerMenu] Setting loading state: ON")
        -- Setup and start loading animation
        if not elements.loadingAnim then
            elements.loadingAnim = utils.createLoadingAnimation(
                elements.confirmButton,
                elements.connectingTimer,
                "Wait"
            )
        end
        elements.loadingAnim.start()
        utils.setElementsVisible(false, elements.backButton)
        utils.setElementsEnabled(false, elements.loginInput, elements.passwordInput, elements.repeatInput)
    else
        logging.debug("[registerMenu] Setting loading state: OFF")
        if elements.loadingAnim then
            elements.loadingAnim.stop("Register")
        end
        utils.setElementsVisible(true, elements.backButton)
        utils.setElementsEnabled(true, elements.loginInput, elements.passwordInput, elements.repeatInput)
    end
end

return registerMenu
