-- Login Menu UI for ccWallet
local menuManager = require("ui.menuManager")
local utils = require("ui.utils")
local logging = require("logging")
local basalt = require("basalt")

local loginMenu = {}

function loginMenu.create(parent, context)
    logging.debug("[loginMenu] Creating main menu UI...")
    local frame = parent:addFrame()
        :setPosition(1, 1)
        :fillParent()
        :setBackground(colors.white)

    local elements = {}
    local inputWidth = 24

    -- Title (manually centered - BigFont needs adjustment)
    local titleWidth = 18
    local titleX = math.floor((parent:getWidth() - titleWidth) / 2) -1
    elements.titleLabel = frame:addBigFont()
        :setText("Wallet")
        :setSize(titleWidth, 3)
        :setForeground(colors.magenta)
        :setBackground(colors.white)
        :setPosition(titleX, 2)

    -- Login section (centered horizontally)
    elements.loginLabel = frame:addLabel()
        :setText("Login")
        :setForeground(colors.gray)
        :setY(6)
        :setSize(inputWidth, 1)
        :centerHorizontal("parent")

    elements.loginInput = frame:addInput()
        :setY(7)
        :setSize(inputWidth, 1)
        :centerHorizontal("parent")

    elements.loginErrorLabel = frame:addLabel()
        :setText("")
        :setY(8)
        :setSize(inputWidth, 1)
        :setForeground(colors.red)
        :centerHorizontal("parent")

    -- Password section (centered horizontally)
    elements.passwordLabel = frame:addLabel()
        :setText("Password")
        :setForeground(colors.gray)
        :setY(9)
        :setSize(inputWidth, 1)
        :centerHorizontal("parent")

    elements.passwordInput = frame:addInput()
        :setY(10)
        :setSize(inputWidth, 1)
        :setReplaceChar("*")
        :centerHorizontal("parent")

    elements.passwordErrorLabel = frame:addLabel()
        :setText("")
        :setY(11)
        :setSize(inputWidth, 1)
        :setForeground(colors.red)
        :centerHorizontal("parent")

    elements.passwordErrorLabel2 = frame:addLabel()
        :setText("")
        :setY(12)
        :setSize(inputWidth, 1)
        :setForeground(colors.red)
        :centerHorizontal("parent")

    -- Buttons (centered, positioned from bottom)
    elements.loginButton = frame:addButton()
        :setSize(15, 3)
        :setBackground(colors.magenta)
        :setText("Login")
        :centerHorizontal("parent")
        :alignBottom("parent", -5)
        :registerState("loading", nil, 300)
        :setBackgroundState("loading", colors.lightBlue)

    elements.registerButton = frame:addButton()
        :setSize(15, 3)
        :setBackground(colors.magenta)
        :setText("Register")
        :centerHorizontal("parent")
        :below(elements.loginButton, 2)

    -- Animation timer
    elements.connectingTimer = frame:addTimer()
        :setInterval(0.4)
        :stop()

    elements.frame = frame
    elements.context = context

    -- Define callbacks
    local function handleLogin()
        if elements.loginButton:hasState("loading") then
            logging.debug("[loginMenu] Login attempt blocked - already in progress")
            return
        end

        local login = elements.loginInput:getText()
        local password = elements.passwordInput:getText()
        logging.info("[loginMenu] Login attempt for user: " .. login)

        if login == "" then
            logging.debug("[loginMenu] Login validation failed - empty login")
            utils.setError(elements.loginErrorLabel, "Please enter login", false)
            return
        end

        if password == "" then
            logging.debug("[loginMenu] Login validation failed - empty password")
            utils.setError(elements.passwordErrorLabel, "Please enter password", false)
            return
        end

        -- Clear any previous errors
        elements.loginErrorLabel:setText("")
        elements.passwordErrorLabel:setText("")
        elements.passwordErrorLabel2:setText("")

        -- Show connecting state
        logging.debug("[loginMenu] Starting login request...")
        loginMenu.setLoading(elements, true)

        -- Schedule login to run async
        basalt.schedule(function()
            local success, result
            local timedOut = false

            parallel.waitForAny(
                function()
                    success, result = context.bankAPI.login(login, password)
                end,
                function()
                    sleep(5)
                    timedOut = true
                end
            )

            if timedOut and not success then
                logging.warning("[loginMenu] Login timed out for user: " .. login)
                result = "Connection timed out"
            end

            loginMenu.setLoading(elements, false)

            if success then
                logging.info("[loginMenu] Login successful for user: " .. login)
                context.refreshUserData()
                context.updateRegisteredUsers()
                loginMenu.clear(elements)
                context.navigate.toAccount()
            else
                logging.warning("[loginMenu] Login failed for user: " .. login .. " - " .. (result or "unknown error"))
                utils.wrapText(
                    elements.passwordErrorLabel,
                    elements.passwordErrorLabel2,
                    result or "Login failed",
                    24
                )
            end
        end)
    end

    local function handleRegister()
        logging.debug("[loginMenu] User clicked Register button")
        context.navigate.toRegister()
    end

    -- Setup events with internal callbacks
    loginMenu.setupEvents(elements, {
        onLogin = handleLogin,
        onRegister = handleRegister
    })

    return elements
end

function loginMenu.setupEvents(elements, callbacks)
    logging.debug("[loginMenu] Setting up event handlers...")

    local function isLoading()
        return elements.loginButton:hasState("loading")
    end

    local navigation = {
        loginInput = {
            up = "registerButton",
            down = "passwordInput",
            tab = "passwordInput",
            enter = function() elements.passwordInput:setFocused(true) end
        },
        passwordInput = {
            up = "loginInput",
            down = "loginButton",
            tab = "loginButton",
            enter = function() elements.loginButton:setFocused(true) end
        },
        loginButton = {
            up = "passwordInput",
            down = "registerButton",
            tab = "registerButton",
            enter = callbacks.onLogin
        },
        registerButton = {
            up = "loginButton",
            down = "loginInput",
            tab = "loginInput",
            enter = callbacks.onRegister
        }
    }

    elements.ctx = menuManager.createContext({
        frame = elements.frame,
        elements = {
            loginInput = elements.loginInput,
            passwordInput = elements.passwordInput,
            loginButton = elements.loginButton,
            registerButton = elements.registerButton
        },
        navigation = navigation,
        defaultFocus = "loginInput",
        loadingCheck = isLoading
    })

    menuManager.setup(elements.ctx)
end

function loginMenu.clear(elements)
    logging.debug("[loginMenu] Clearing form inputs")
    elements.loginInput:setText("")
    elements.passwordInput:setText("")
    utils.clearErrors(elements.loginErrorLabel, elements.passwordErrorLabel, elements.passwordErrorLabel2)
end

function loginMenu.getCredentials(elements)
    return elements.loginInput:getText(), elements.passwordInput:getText()
end

function loginMenu.show(elements, focusButton)
    logging.debug("[loginMenu] Showing main menu")
    menuManager.show(elements.ctx, {
        focusElement = focusButton and "loginButton" or "loginInput"
    })
end

function loginMenu.hide(elements)
    logging.debug("[loginMenu] Hiding main menu")
    menuManager.hide(elements.ctx)
end

function loginMenu.setLoading(elements, loading)
    if loading then
        logging.debug("[loginMenu] Setting loading state: ON")
        -- Setup and start loading animation
        if not elements.loadingAnim then
            elements.loadingAnim = utils.createLoadingAnimation(
                elements.loginButton,
                elements.connectingTimer,
                "Connecting"
            )
        end
        elements.loadingAnim.start()
        utils.setElementsVisible(false, elements.registerButton)
        utils.setElementsEnabled(false, elements.loginInput, elements.passwordInput)
    else
        logging.debug("[loginMenu] Setting loading state: OFF")
        if elements.loadingAnim then
            elements.loadingAnim.stop("Login")
        end
        utils.setElementsVisible(true, elements.registerButton)
        utils.setElementsEnabled(true, elements.loginInput, elements.passwordInput)
    end
end

return loginMenu
