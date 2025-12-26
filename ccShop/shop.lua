-- ccShop - Main Entry Point
-- Updated for Basalt 2 API with modular UI structure
local basalt = require("basalt")
local bankAPI = require("bankAPI")
local logging = require("logging")

local config = require("config")
local inventory = require("inventory")
local navigationBarUI = require("ui.navigationBar")
local homeMenuUI = require("ui.homeMenu")
local settingsMenuUI = require("ui.settingsMenu")
local cartMenuUI = require("ui.cartMenu")
local footerUI = require("ui.footer")

-- Initialize logging
logging.setup(nil, config.logLevel, config.logFile, false, config.maxLogFileSize, config.maxLogFiles)
logging.info("=== ccShop Starting ===")

-- Global state
local state = {
    cart = {},
    itemsList = {},
    priceList = {},
    loggedInUser = nil,
    currentMenu = "home"
}

-- Initialize monitor frames using Basalt 2 API
local function initMonitorFrames(shopSettings)
    logging.debug("Initializing monitor frames...")
    local monitors = config.getMonitors()
    local monitorFrames = {}

    -- Terminal frame
    monitorFrames["terminal"] = basalt.getMainFrame()
        :setBackground(colors.white)
    logging.debug("Terminal frame created")

    -- Main monitor
    if shopSettings.mainMonitor and monitors[shopSettings.mainMonitor] then
        logging.debug("Setting up main monitor: " .. shopSettings.mainMonitor)
        local monitor = monitors[shopSettings.mainMonitor]
        monitor.setTextScale(shopSettings.mainMonitorScale)
        monitorFrames["mainMonitor"] = basalt.createFrame()
            :setTerm(monitor)
            :setBackground(colors.white)
        logging.debug("Main monitor frame created")
    end

    -- Nav bar monitor
    if shopSettings.navBarMonitor and monitors[shopSettings.navBarMonitor] then
        logging.debug("Setting up nav bar monitor: " .. shopSettings.navBarMonitor)
        local monitor = monitors[shopSettings.navBarMonitor]
        monitor.setTextScale(shopSettings.navBarMonitorScale)
        monitorFrames["navBarMonitor"] = basalt.createFrame()
            :setTerm(monitor)
            :setBackground(colors.white)
        logging.debug("Nav bar monitor frame created")
    end

    -- Keyboard monitor
    if shopSettings.keyboardMonitor and monitors[shopSettings.keyboardMonitor] then
        logging.debug("Setting up keyboard monitor: " .. shopSettings.keyboardMonitor)
        local monitor = monitors[shopSettings.keyboardMonitor]
        monitor.setTextScale(shopSettings.keyboardMonitorScale)
        monitorFrames["keyboardMonitor"] = basalt.createFrame()
            :setTerm(monitor)
            :setBackground(colors.white)
        logging.debug("Keyboard monitor frame created")
    end

    logging.info("Monitor frames initialized")
    return monitorFrames
end

-- Build complete UI for a frame
local function buildFrameUI(frame, appContext)
    logging.debug("Building UI for frame...")
    local elements = {}

    -- Create UI components with context
    elements.navigationBar = navigationBarUI.create(frame, appContext)
    elements.homeMenu = homeMenuUI.create(frame, appContext)
    elements.settingsMenu = settingsMenuUI.create(frame, appContext)
    elements.cartMenu = cartMenuUI.create(frame, appContext)
    elements.footer = footerUI.create(frame, appContext)

    -- Update footer with initial item count
    footerUI.updateItemCount(elements.footer, homeMenuUI.getItemCount(elements.homeMenu))

    logging.debug("UI components created successfully")
    return elements
end

-- Main application
local function main()
    logging.info("Initializing main application")
    local currentVersion = config.getVersion()
    local shopSettings = config.loadShopSettings()
    logging.info("Shop version: " .. currentVersion)
    logging.info("Shop name: " .. shopSettings.shopName)
    os.setComputerLabel(shopSettings.shopName .. " v" .. currentVersion)

    -- Find modem
    local modemSide = config.getModemSide()
    if modemSide == nil then
        logging.critical("No modem found - cannot start")
        printError("No modem found")
        return
    end
    logging.debug("Found modem on side: " .. modemSide)

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

    -- Load inventory
    logging.debug("Loading inventory...")
    state.priceList = inventory.updatePriceList()
    state.itemsList = inventory.getItemsList()
    logging.info("Inventory loaded: " .. #state.itemsList .. " items")

    -- Initialize frames
    local monitorFrames = initMonitorFrames(shopSettings)

    -- Forward declarations
    local showHome, showSettings, showCart
    local elements = {}

    -- Create app context for dependency injection
    local appContext = {
        bankAPI = bankAPI,
        state = state,
        config = config,
        shopSettings = shopSettings,
        navigate = {},
        callbacks = {}
    }

    -- Navigation functions
    showHome = function()
        logging.debug("Navigating to home menu")
        state.currentMenu = "home"
        homeMenuUI.show(elements.homeMenu)
        settingsMenuUI.hide(elements.settingsMenu)
        cartMenuUI.hide(elements.cartMenu)
        navigationBarUI.setActiveMenu(elements.navigationBar, "home")
    end

    showSettings = function()
        logging.debug("Navigating to settings menu")
        state.currentMenu = "settings"
        homeMenuUI.hide(elements.homeMenu)
        settingsMenuUI.show(elements.settingsMenu)
        cartMenuUI.hide(elements.cartMenu)
        navigationBarUI.setActiveMenu(elements.navigationBar, "settings")
    end

    showCart = function()
        logging.debug("Navigating to cart menu")
        state.currentMenu = "cart"
        homeMenuUI.hide(elements.homeMenu)
        settingsMenuUI.hide(elements.settingsMenu)
        cartMenuUI.show(elements.cartMenu)
        navigationBarUI.setActiveMenu(elements.navigationBar, "cart")
    end

    -- Populate appContext with navigation functions
    appContext.navigate.toHome = showHome
    appContext.navigate.toSettings = showSettings
    appContext.navigate.toCart = showCart

    -- Callbacks for settings and other actions
    appContext.callbacks.onNameChange = function(newName)
        logging.info("Shop name changed to: " .. newName)
        navigationBarUI.updateTitle(elements.navigationBar, newName)
        shopSettings.shopName = newName
        os.setComputerLabel(newName .. " v" .. currentVersion)
    end

    appContext.callbacks.onRefresh = function()
        logging.info("Refreshing inventory...")
        state.priceList = inventory.updatePriceList()
        state.itemsList = inventory.getItemsList()
        homeMenuUI.refreshItems(elements.homeMenu, state.itemsList, state.priceList)
        footerUI.updateItemCount(elements.footer, #state.itemsList)
        footerUI.showSuccess(elements.footer, "Items refreshed!")
        logging.info("Inventory refreshed: " .. #state.itemsList .. " items")
    end

    -- Build UI for terminal
    logging.debug("Creating UI components...")
    elements = buildFrameUI(monitorFrames["terminal"], appContext)
    logging.debug("UI components created")

    -- Build UI for additional monitors if available
    if monitorFrames["mainMonitor"] then
        logging.debug("Building UI for main monitor...")
        buildFrameUI(monitorFrames["mainMonitor"], appContext)
    end

    -- Show home menu initially
    logging.debug("Setup complete, showing home menu")
    showHome()

    -- Set basalt global focus
    basalt.setFocus(monitorFrames["terminal"])
    basalt.update()

    -- Run Basalt event loop
    logging.info("Starting main event loop")
    basalt.run()
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
