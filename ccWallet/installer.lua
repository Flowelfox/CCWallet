local NAME = "Wallet Installer"
local BASE_URL = "https://raw.githubusercontent.com/Flowelfox/CCWallet/main/"

-- Basalt configuration
local BASALT_DEV_PATH = "https://raw.githubusercontent.com/Pyroxenium/Basalt2/refs/heads/main/src/"
local BASALT_CONFIG_PATH = "https://raw.githubusercontent.com/Pyroxenium/Basalt2/refs/heads/main/config.lua"
local BASALT_MINIFY_PATH = "https://raw.githubusercontent.com/Pyroxenium/Basalt2/refs/heads/main/tools/minify.lua"

-- Required Basalt elements (with dependencies resolved)
local BASALT_ELEMENTS = {
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

local DOWNLOADS = {}

-- Core files
DOWNLOADS[#DOWNLOADS + 1] = BASE_URL .. "ccWallet/version.txt"
DOWNLOADS[#DOWNLOADS + 1] = BASE_URL .. "ccWallet/installer.lua"
DOWNLOADS[#DOWNLOADS + 1] = BASE_URL .. "ccWallet/wallet.lua"
DOWNLOADS[#DOWNLOADS + 1] = BASE_URL .. "ccWallet/config.lua"
DOWNLOADS[#DOWNLOADS + 1] = BASE_URL .. "ccWallet/setupWalletServer.lua"

-- Libraries (basalt.lua will be installed separately)
DOWNLOADS[#DOWNLOADS + 1] = BASE_URL .. "lib/bankAPI.lua"
DOWNLOADS[#DOWNLOADS + 1] = BASE_URL .. "lib/ecnet2.lua"

-- UI module files (stored with special prefix to handle folder structure)
local UI_DOWNLOADS = {
    ["ui/utils.lua"] = BASE_URL .. "ccWallet/ui/utils.lua",
    ["ui/menuManager.lua"] = BASE_URL .. "lib/menuManager.lua",
    ["ui/loginMenu.lua"] = BASE_URL .. "ccWallet/ui/loginMenu.lua",
    ["ui/registerMenu.lua"] = BASE_URL .. "ccWallet/ui/registerMenu.lua",
    ["ui/accountMenu.lua"] = BASE_URL .. "ccWallet/ui/accountMenu.lua",
    ["ui/sendMenu.lua"] = BASE_URL .. "ccWallet/ui/sendMenu.lua",
    ["ui/transactionsMenu.lua"] = BASE_URL .. "ccWallet/ui/transactionsMenu.lua",
    ["ui/historyMenu.lua"] = BASE_URL .. "ccWallet/ui/historyMenu.lua",
}

local args = {...}
local forceInstall = false

local function showHelp()
    print("CCWallet Installer")
    print("")
    print("Usage: installer.lua [options]")
    print("")
    print("Options:")
    print("  -f, --force    Force reinstall and allow non-pocket computers")
    print("  -h, --help     Show this help message")
    print("")
    print("By default, the installer only runs on Pocket Computers")
    print("with a wireless modem, and skips if already up to date.")
end

-- Parse arguments
for _, arg in ipairs(args) do
    if arg == "--help" or arg == "-h" then
        showHelp()
        return
    elseif arg == "--force" or arg == "-f" then
        forceInstall = true
    end
end
local width = term.getSize()
local totalDownloaded = 0
local totalFiles = #DOWNLOADS
for _ in pairs(UI_DOWNLOADS) do totalFiles = totalFiles + 1 end

local barLine = 6
local line = 8
local installFolder = "ccWallet"
local isPocket = false
if pocket then
    isPocket = true
end

local function update(text)
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
    term.setCursorPos(1, line)
    write(text)
    line = line + 1
end

local function bar(ratio)
    term.setBackgroundColor(colors.gray)
    term.setTextColor(colors.lime)
    term.setCursorPos(1, barLine)
    for i = 1, width do
        if (i / width < ratio) then write("|") else write(" ") end
    end
end

local function checkRemoteVersion(attempt)
    local rawData = http.get(DOWNLOADS[1])
    if not rawData then
        if attempt == 3 then error("Failed to check version after 3 attempts!") end
        return checkRemoteVersion(attempt + 1)
    end
    return rawData.readAll()
end

local function download(path, attempt, targetPath)
    local rawData = http.get(path)
    local fileName = targetPath or path:match("^.+/(.+)$")
    update("Downloaded " .. fileName .. "!")
    if not rawData then
        if attempt == 3 then error("Failed to download " .. path .. " after 3 attempts!") end
        update("Failed to download " .. path .. ". Trying again (attempt " .. (attempt + 1) .. "/3)")
        return download(path, attempt + 1, targetPath)
    end
    local data = rawData.readAll()

    local fullPath = installFolder .. '/' .. fileName

    -- Create parent directories if needed
    local dir = fullPath:match("(.+)/[^/]+$")
    if dir and not fs.exists(dir) then
        fs.makeDir(dir)
    end

    local file = fs.open(fullPath, "w")
    file.write(data)
    file.close()
end

local function downloadAll(downloads, total)
    local nextFile = table.remove(downloads, 1)
    if nextFile then
        sleep(0.3)
        parallel.waitForAll(function() downloadAll(downloads, total) end, function()
            download(nextFile, 1)
            totalDownloaded = totalDownloaded + 1
            bar(totalDownloaded / total)
        end)
    end
end

local function downloadUIModules()
    for targetPath, url in pairs(UI_DOWNLOADS) do
        download(url, 1, targetPath)
        totalDownloaded = totalDownloaded + 1
        bar(totalDownloaded / totalFiles)
        sleep(0.1)
    end
end

-- Install Basalt with only required elements (minified single file)
local function installBasalt()
    update("Installing Basalt UI framework...")

    -- Fetch Basalt config
    local configRequest = http.get(BASALT_CONFIG_PATH)
    if not configRequest then
        error("Failed to download Basalt config")
    end
    local basaltConfig = load(configRequest.readAll())()
    configRequest.close()

    -- Fetch minifier
    update("Downloading minifier...")
    local minifyRequest = http.get(BASALT_MINIFY_PATH)
    if not minifyRequest then
        error("Failed to download Basalt minifier")
    end
    local minify = load(minifyRequest.readAll())()
    minifyRequest.close()

    local project = {}

    -- Helper to download a file
    local function downloadBasaltFile(url, name)
        local request = http.get(url)
        if request then
            local content = request.readAll()
            request.close()
            return content
        else
            error("Failed to download Basalt file: " .. name)
        end
    end

    -- Download core files
    update("Downloading Basalt core...")
    for fileName, fileInfo in pairs(basaltConfig.categories.core.files) do
        project[fileInfo.path] = downloadBasaltFile(BASALT_DEV_PATH .. fileInfo.path, fileName)
    end

    -- Download libraries
    update("Downloading Basalt libraries...")
    for fileName, fileInfo in pairs(basaltConfig.categories.libraries.files) do
        project[fileInfo.path] = downloadBasaltFile(BASALT_DEV_PATH .. fileInfo.path, fileName)
    end

    -- Download required elements
    update("Downloading Basalt elements...")
    for _, elementName in ipairs(BASALT_ELEMENTS) do
        local fileInfo = basaltConfig.categories.elements.files[elementName]
        if fileInfo then
            project[fileInfo.path] = downloadBasaltFile(BASALT_DEV_PATH .. fileInfo.path, elementName)
        else
            update("Warning: Element not found: " .. elementName)
        end
    end

    -- Minify all files
    update("Minifying Basalt...")
    for path, content in pairs(project) do
        local success, minifiedContent = minify(content)
        if success then
            project[path] = minifiedContent
        else
            update("Warning: Failed to minify " .. path)
        end
    end

    -- Build single file output
    update("Building basalt.lua...")
    local output = {
        'local minified = true\n',
        'local minified_elementDirectory = {}\n',
        'local minified_pluginDirectory = {}\n',
        'local project = {}\n',
        'local loadedProject = {}\n',
        'local baseRequire = require\n',
        'require = function(path) if(project[path..".lua"])then if(loadedProject[path]==nil)then loadedProject[path] = project[path..".lua"]() end return loadedProject[path] end return baseRequire(path) end\n'
    }

    -- Add element directory entries
    for filePath, _ in pairs(project) do
        local elementName = filePath:match("^elements/(.+)%.lua$")
        if elementName then
            table.insert(output, string.format('minified_elementDirectory["%s"] = {}\n', elementName))
        end
    end

    -- Add project files
    for filePath, content in pairs(project) do
        table.insert(output, string.format('project["%s"] = function(...) %s end\n', filePath, content))
    end

    table.insert(output, 'return project["main.lua"]()')

    -- Write basalt.lua
    local basaltPath = installFolder .. "/basalt.lua"
    local file = fs.open(basaltPath, "w")
    if file then
        file.write(table.concat(output))
        file.close()
        update("Basalt installed successfully!")
    else
        error("Failed to write basalt.lua")
    end
end

local function rewriteStartup()
    local file = fs.open("startup", "w")

    file.writeLine("shell.run(\"".. installFolder .. "/installer.lua\")")
    file.writeLine("shell.run(\"".. installFolder .. "/setupWalletServer.lua\")")
    file.writeLine("while (true) do")
    file.writeLine("	shell.run(\"" .. installFolder .. "/wallet.lua\")")
    file.writeLine("	sleep(1)")
    file.writeLine("end")
    file.close()
end

local function checkCurrentVersion()
    if fs.exists(installFolder .. "/version.txt") then
        local file = fs.open(installFolder .. "/version.txt", "r")
        local version = file.readAll()
        file.close()
        return version
    end
    return nil
end

local function createInstallationFolder()
    if not fs.exists(installFolder) then
        fs.makeDir(installFolder)
    end
    -- Create ui subfolder
    if not fs.exists(installFolder .. "/ui") then
        fs.makeDir(installFolder .. "/ui")
    end
end

local function removeOldVersion()
    if fs.exists(installFolder) then
        fs.delete(installFolder)
    end
end

local function getModemSide()
    local sides = peripheral.getNames()
    for _, side in ipairs(sides) do
        if peripheral.getType(side) == "modem" then
            return side
        end
    end
    return nil
end

local function validateComputer()
    if forceInstall then
        return true
    end

    if not isPocket then
        printError("This installer is only for Pocket Computers!")
        return false
    end
    local modemSide = getModemSide()
    if not modemSide then
        printError("No modem found, this can be installed on a Pocket Computer with a wireless modem!")
        return false
    end
    local modem = peripheral.wrap(modemSide)
    if not modem.isWireless() then
        printError("This installer is only for Pocket Computers with a wireless modem!")
        return false
    end
    return true
end

local function install()
    local canInstall = validateComputer()
    if not canInstall then
        return
    end

    -- Check version first without writing to file
    local newVersion = checkRemoteVersion(1)
    local currentVersion = checkCurrentVersion()

    if currentVersion == newVersion and not forceInstall then
        return
    end

    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.yellow)
    term.clear()

    term.setCursorPos(math.floor(width / 2 - #NAME / 2 + 0.5), 2)
    write(NAME)

    term.setTextColor(colors.white)
    term.setCursorPos(1, barLine - 2)
    if currentVersion then
        term.write("Updating from " .. currentVersion .. " to " .. newVersion .. "...")
    else
        term.write("Installing version " .. newVersion .. "...")
    end

    bar(0)
    totalDownloaded = 0

    removeOldVersion()
    createInstallationFolder()

    -- Download core files
    downloadAll(DOWNLOADS, totalFiles)

    -- Download UI module files
    downloadUIModules()

    -- Install Basalt UI framework with required elements only
    installBasalt()

    term.setTextColor(colors.green)
    term.setBackgroundColor(colors.black)
    if currentVersion then
        update("Updated to version " .. newVersion .. "!")
    else
        update("Installed version " .. newVersion .. "!")
    end

    rewriteStartup()

    for i = 1, 3 do
        term.setCursorPos(1, line)
        term.clearLine()
        term.write("Rebooting in " .. (4 - i) .. " seconds...")
        sleep(1)
    end

    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
    term.clear()
    os.reboot()
end

install()
