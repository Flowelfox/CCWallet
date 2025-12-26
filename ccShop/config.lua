-- ccShop Configuration
local config = {}

-- Logging configuration
config.logFile = "ccShop/shop.log"
config.logLevel = "DEBUG"
config.maxLogFileSize = 4096
config.maxLogFiles = 3

function config.getModemSide()
    local sides = peripheral.getNames()
    for _, side in ipairs(sides) do
        if peripheral.getType(side) == "modem" then
            return side
        end
    end
    return nil
end

function config.getMonitors()
    local monitors = {}
    for _, side in pairs(peripheral.getNames()) do
        if peripheral.getType(side) == "monitor" then
            monitors[side] = peripheral.wrap(side)
        end
    end
    return monitors
end

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

function config.saveShopSettings(settings)
    local file = fs.open(".shopSettings", "w")
    file.write(textutils.serialize(settings))
    file.close()
end

function config.loadShopSettings()
    local settings = nil
    local file = fs.open(".shopSettings", "r")
    if file then
        settings = textutils.unserialize(file.readAll())
        file.close()
    end

    if not settings then
        settings = {
            shopName = "Shop name",
            mainMonitor = nil,
            navBarMonitor = nil,
            keyboardMonitor = nil,
            mainMonitorScale = 1,
            navBarMonitorScale = 1,
            keyboardMonitorScale = 1
        }
        config.saveShopSettings(settings)
    end
    return settings
end

return config
