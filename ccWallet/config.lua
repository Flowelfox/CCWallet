-- ccWallet Configuration
local config = {}

-- Basalt UI elements required by ccWallet
-- Used by installer.lua to create minimal basalt.lua
config.basaltElements = {
    "BaseElement",      -- Base class for all elements
    "VisualElement",    -- Base for visual elements
    "Container",        -- Required by Frame
    "Collection",       -- Required by List
    "BaseFrame",        -- Required for getMainFrame()
    "Frame",            -- UI container frames
    "Label",            -- Text labels
    "Input",            -- Text input fields
    "Button",           -- Clickable buttons
    "Timer",            -- Animation timers
    "BigFont",          -- Large title text
    "List",             -- Scrollable lists
}

config.logFile = "ccWallet/wallet.log"
config.logLevel = "DEBUG"
config.modemSide = "back"
config.maxLogFileSize = 4096
config.maxLogFiles = 3

function config.getWalletServer()
    local addressFile = fs.open(".walletServerAddress.txt", "r")
    if not addressFile then
        return nil
    end
    local server = addressFile.readAll()
    addressFile.close()
    return server
end

function config.getVersion()
    local currentDirectory = fs.getDir(shell.getRunningProgram())
    local versionFile = fs.open(currentDirectory .. "/version.txt", "r")
    if not versionFile then
        return "0.0.0"
    end
    local version = versionFile.readAll()
    versionFile.close()
    return version
end

return config
