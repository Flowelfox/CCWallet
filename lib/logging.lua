local function setup(monitor_name, level, file, writeToTerminal, maxFileSize, maxFiles)
    level = level or "INFO"
    file = file or nil
    if writeToTerminal == nil then
        writeToTerminal = true
    end
    maxFileSize = maxFileSize or 10240
    maxFiles = maxFiles or 5

    settings.load()
    local settingsData = settings.get("logging")
    settingsData = {
        logLevel = level,
        logMonitor = monitor_name,
        logFile = file,
        writeToTerminal = writeToTerminal,
        maxFileSize = maxFileSize,
        maxFiles = maxFiles
    }
    settings.set("logging", settingsData)
    settings.save()
    return settingsData
end

local function loadLoggingSettings()
    settings.load()
    local settingsData = settings.get("logging")
    if settingsData == nil then
        settingsData = setup("", "INFO", nil, true)
    end
    return settingsData
end

local function getLoggingMonitor()
    local settingsData = loadLoggingSettings()
    if settingsData.logMonitor == nil or settingsData.logMonitor == "" then
        return nil
    end
    local loggingMonitor = peripheral.find(settingsData.logMonitor)
    if loggingMonitor == nil then
        return nil
    else
        loggingMonitor.setTextScale(0.5)
        return loggingMonitor
    end
end

local function getLogFile()
    local settingsData = loadLoggingSettings()
    return settingsData.logFile
end

local function getWriteToTerminal()
    local settingsData = loadLoggingSettings()
    return settingsData.writeToTerminal
end


local function setLoggingMonitor(monitor)
    local settingsData = loadLoggingSettings()
    settingsData.logMonitor = monitor
    settings.set("logging", settingsData)
    settings.save()
end

local function setLoggingLevel(level)
    local settingsData = loadLoggingSettings()
    settingsData.logLevel = level
    settings.set("logging", settingsData)
    settings.save()
end

local function setLogFile(file)
    local settingsData = loadLoggingSettings()
    settingsData.logFile = file
    settings.set("logging", settingsData)
    settings.save()
end

local function setWriteToTerminal(writeToTerminal)
    local settingsData = loadLoggingSettings()
    settingsData.writeToTerminal = writeToTerminal
    settings.set("logging", settingsData)
    settings.save()
end

local function getMaxFileSize()
    local settingsData = loadLoggingSettings()
    return settingsData.maxFileSize or 10240
end

local function setMaxFileSize(maxFileSize)
    local settingsData = loadLoggingSettings()
    settingsData.maxFileSize = maxFileSize
    settings.set("logging", settingsData)
    settings.save()
end

local function getMaxFiles()
    local settingsData = loadLoggingSettings()
    return settingsData.maxFiles or 5
end

local function setMaxFiles(maxFiles)
    local settingsData = loadLoggingSettings()
    settingsData.maxFiles = maxFiles
    settings.set("logging", settingsData)
    settings.save()
end

local function rotateLogFile(logFile)
    local maxFiles = getMaxFiles()

    local oldestFile = logFile .. "." .. maxFiles
    if fs.exists(oldestFile) then
        fs.delete(oldestFile)
    end

    for i = maxFiles - 1, 1, -1 do
        local oldPath = logFile .. "." .. i
        local newPath = logFile .. "." .. (i + 1)
        if fs.exists(oldPath) then
            fs.move(oldPath, newPath)
        end
    end

    if fs.exists(logFile) then
        fs.move(logFile, logFile .. ".1")
    end
end

local function shouldRotate(logFile)
    if not fs.exists(logFile) then
        return false
    end
    local maxFileSize = getMaxFileSize()
    if maxFileSize <= 0 then
        return false
    end
    local fileSize = fs.getSize(logFile)
    return fileSize >= maxFileSize
end

local function logingLevelIndex(level)
    if level == "DEBUG" then
        return 1
    elseif level == "INFO" then
        return 2
    elseif level == "WARNING" then
        return 3
    elseif level == "ERROR" then
        return 4
    elseif level == "CRITICAL" then
        return 5
    end
end

local function getLoggingLevel()
    local settingsData = loadLoggingSettings()
    local logLevelIndex = logingLevelIndex(settingsData.logLevel)
    if logLevelIndex == nil then
        printError("Logging level not set, setting to \"INFO\"")
        setLoggingLevel("INFO")
        return "INFO"
    else
        return settingsData.logLevel
    end
end

local function _log(text, level)
    local terminal = term.current()
    local loggingMonitor = getLoggingMonitor()
    local loggingLevel = getLoggingLevel()
    local logFile = getLogFile()
    local writeToTerminal = getWriteToTerminal()

    local currentLevelIndex = logingLevelIndex(level)
    if currentLevelIndex < logingLevelIndex(loggingLevel) then
        return
    end

    if level == "DEBUG" then
        if loggingMonitor ~= nil then
            loggingMonitor.setTextColor(colors.gray)
        end
        if writeToTerminal then
            terminal.setTextColor(colors.gray)
        end
    elseif level == "INFO" then
        if loggingMonitor ~= nil then
            loggingMonitor.setTextColor(colors.lightBlue)
        end
        if writeToTerminal then
            terminal.setTextColor(colors.lightBlue)
        end
    elseif level == "WARNING" then
        if loggingMonitor ~= nil then
            loggingMonitor.setTextColor(colors.yellow)
        end
        if writeToTerminal then
            terminal.setTextColor(colors.yellow)
        end
    elseif level == "ERROR" then
        if loggingMonitor ~= nil then
            loggingMonitor.setTextColor(colors.red)
        end
        if writeToTerminal then
            terminal.setTextColor(colors.red)
        end
    elseif level == "CRITICAL" then
        if loggingMonitor ~= nil then
            loggingMonitor.setTextColor(colors.red)
            loggingMonitor.write("!!!")
        end
        if writeToTerminal then
            terminal.setTextColor(colors.red)
            terminal.write("!!!")
        end
    end
    -- Prepare the log line
    local currentTime = os.date("%T")
    local line = currentTime .. " (".. level .."): " .. text

    -- Write to the monitor
    if loggingMonitor ~= nil then
        local width, height = loggingMonitor.getSize()
        local x, y = loggingMonitor.getCursorPos()
        if y >= height then
            loggingMonitor.scroll(1)
            loggingMonitor.setCursorPos(1, height)
        else
            loggingMonitor.setCursorPos(1, y + 1)
        end
        loggingMonitor.write(line)
    end

    -- Write to the terminal
    if writeToTerminal then
        local width, height = terminal.getSize()
        local x, y = terminal.getCursorPos()
        if y >= height then
            terminal.scroll(1)
            terminal.setCursorPos(1, height)
        else
            terminal.setCursorPos(1, y + 1)
        end
        terminal.write(line)
    end

    -- Write to the log File
    if logFile ~= nil then
        if shouldRotate(logFile) then
            rotateLogFile(logFile)
        end
        local loggingFile = fs.open(logFile, "a")
        loggingFile.writeLine(line)
        loggingFile.close()
    end
end


local function clear()
    local loggingMonitor = getLoggingMonitor()
    if loggingMonitor ~= nil then
        loggingMonitor.clear()
    end
    local terminal = term.current()
    terminal.clear()
end

local function logDebug(text)
    _log(text, "DEBUG")
end
local function logInfo(text)
    _log(text, "INFO")
end
local function logWarning(text)
    _log(text, "WARNING")
end
local function logError(text)
    _log(text, "ERROR")
end
local function logCritical(text)
    _log(text, "CRITICAL")
end

local export = {
    setup = setup,
    setLoggingMonitor = setLoggingMonitor,
    setLoggingLevel = setLoggingLevel,
    setLogFile = setLogFile,
    setWriteToTerminal = setWriteToTerminal,
    setMaxFileSize = setMaxFileSize,
    setMaxFiles = setMaxFiles,
    getMaxFileSize = getMaxFileSize,
    getMaxFiles = getMaxFiles,
    rotateLogFile = rotateLogFile,
    clear = clear,
    debug = logDebug,
    info = logInfo,
    warning = logWarning,
    error = logError,
    critical = logCritical,
    DEBUG = "DEBUG",
    INFO = "INFO",
    WARNING = "WARNING",
    ERROR = "ERROR",
    CRITICAL = "CRITICAL"
}

return export