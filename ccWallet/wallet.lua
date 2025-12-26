-- ccWallet - Main Entry Point
-- Updated for Basalt 2 API
local basalt = require("basalt")

-- Validate that required Basalt elements are available
basalt.requireElements({
    "Frame", "Label", "Input", "Button",
    "Timer", "BigFont", "List"
})

local bankAPI = require("bankAPI")
local ecnet2 = require("ecnet2")
local logging = require("logging")

local config = require("config")
local loginMenuUI = require("ui.loginMenu")
local registerMenuUI = require("ui.registerMenu")
local accountMenuUI = require("ui.accountMenu")
local utils = require("ui.utils")

-- Initialize logging (file only, no terminal output, with rotation for pocket computer)
logging.setup(nil, config.logLevel, config.logFile, false, config.maxLogFileSize, config.maxLogFiles)
logging.info("=== ccWallet Starting ===")

-- State
local state = {
    token = nil,
    currentUser = nil,
    registeredUsers = {}
}

-- Modem utilities
local function getModemSide()
    logging.debug("Searching for modem...")
    local sides = peripheral.getNames()
    for _, side in ipairs(sides) do
        if peripheral.getType(side) == "modem" then
            logging.debug("Found modem on side: " .. side)
            return side
        end
    end
    logging.warning("No modem found on any side")
    return nil
end

-- Main application
local function main()
    logging.info("Initializing main application")
    local currentVersion = config.getVersion()
    logging.info("Wallet version: " .. currentVersion)
    os.setComputerLabel("Wallet v" .. currentVersion)

    -- Find modem
    local modemSide = getModemSide()
    if modemSide == nil then
        logging.critical("No modem found - cannot start")
        printError("No modem found")
        return
    end

    -- Initialize API
    local server = config.getWalletServer()
    if not server then
        logging.critical("No server configured")
        printError("No server configured. Run installer first.")
        return
    end
    logging.info("Using server: " .. server)

    logging.debug("Initializing bankAPI...")
    local isInitiated = bankAPI.init(server, modemSide)
    if not isInitiated then
        logging.critical("Failed to initialize bankAPI")
        printError("Failed to connect to server")
        return
    end
    logging.info("BankAPI initialized successfully")

    -- Create main frame using Basalt 2 API
    logging.debug("Creating Basalt UI framework")
    local mainFrame = basalt.getMainFrame()
        :setBackground(colors.white)

    -- Forward declarations
    local showMainMenu, showRegisterMenu, showAccountMenu
    local refreshUserData, updateRegisteredUsers
    local loginElements, registerElements, accountElements

    -- Create app context for dependency injection
    local appContext = {
        bankAPI = bankAPI,
        state = state,
        navigate = {},  -- Will be populated after navigation functions are defined
        -- Functions will be added after definition
    }

    -- Navigation functions
    local function showMainMenu(focusButton)
        logging.debug("Navigating to main menu")
        loginMenuUI.show(loginElements, focusButton)
        registerMenuUI.hide(registerElements)
        accountMenuUI.hide(accountElements)
    end

    local function showRegisterMenu()
        logging.debug("Navigating to register menu")
        local login, password = loginMenuUI.getCredentials(loginElements)
        registerMenuUI.setInitialValues(registerElements, login, password)
        loginMenuUI.hide(loginElements)
        registerMenuUI.show(registerElements)
    end

    local function showAccountMenu()
        logging.debug("Navigating to account menu")
        loginMenuUI.hide(loginElements)
        registerMenuUI.hide(registerElements)
        accountMenuUI.show(accountElements)
    end

    -- User data functions
    local function refreshUserData()
        logging.debug("Refreshing user data...")
        local user = bankAPI.getUser()
        if user then
            logging.debug("User data received: " .. user.login .. ", balance: " .. tostring(user.balance))
            state.currentUser = user
            accountMenuUI.updateUserData(accountElements, user)
        else
            logging.warning("Failed to get user data")
        end
        return user
    end

    local function updateRegisteredUsers()
        logging.debug("Fetching registered users list...")
        local users = bankAPI.getRegisteredUsers()
        if users then
            logging.debug("Received " .. #users .. " registered users")
            state.registeredUsers = users
        else
            logging.warning("Failed to get registered users")
        end
    end

    -- Populate appContext with navigation and utility functions
    appContext.navigate.toLogin = showMainMenu
    appContext.navigate.toRegister = showRegisterMenu
    appContext.navigate.toAccount = showAccountMenu
    appContext.refreshUserData = refreshUserData
    appContext.updateRegisteredUsers = updateRegisteredUsers
    appContext.showLoginMessage = function(message, color)
        loginElements.passwordErrorLabel:setForeground(color or colors.green)
        loginElements.passwordErrorLabel:setText(message)
    end

    -- Create UI components with context
    logging.debug("Creating UI components...")
    loginElements = loginMenuUI.create(mainFrame, appContext)
    registerElements = registerMenuUI.create(mainFrame, appContext)
    accountElements = accountMenuUI.create(mainFrame, appContext)
    logging.debug("UI components created")

    -- Show main menu initially
    logging.debug("Setup complete, showing main menu")
    showMainMenu()

    -- Set basalt global focus and trigger initial render
    basalt.setFocus(mainFrame)
    basalt.update()

    -- Run custom event loop that handles both basalt and ecnet2
    logging.info("Starting main event loop")
    local ecnetDaemon = coroutine.create(ecnet2.daemon)
    coroutine.resume(ecnetDaemon) -- Start daemon

    while true do
        local event = {os.pullEventRaw()}

        -- Feed event to basalt
        basalt.update(table.unpack(event))

        -- Feed modem_message events to ecnet2 daemon
        if event[1] == "modem_message" then
            coroutine.resume(ecnetDaemon, table.unpack(event))
        end

        if event[1] == "terminate" then
            logging.info("Received terminate event, shutting down")
            break
        end
    end
end

-- Protected startup
local function protectedStart()
    main()
end

-- Main loop with restart on error
while true do
    term.clear()
    term.setCursorPos(1, 1)

    local ok, err = pcall(protectedStart)

    if not ok then
        logging.critical("Application crashed: " .. tostring(err))
        printError(err)
        print("Restarting in 3 seconds...")
        sleep(3)
        logging.info("Restarting application after crash...")
    else
        if err == "Terminated" then
            logging.info("Application terminated by user")
            sleep(2)
        else
            logging.info("Application exited normally, restarting...")
            print("Restarting...")
            sleep(1)
        end
    end
end
