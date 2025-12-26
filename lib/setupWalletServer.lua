-- Shared Wallet Server Setup
-- Used by ccWallet and ccShop to configure server address
local bankAPI = require("bankAPI")
local basalt = require("basalt")
local logging = require("logging")

local args = {...}
local force = false
for _, arg in ipairs(args) do
    if arg == "-f" or arg == "--force" then
        force = true
        break
    end
end

local function main()
    logging.info("[Setup] Starting wallet server setup...")

    if not force and fs.exists(".walletServerAddress.txt") then
        logging.debug("[Setup] Server already configured, skipping setup")
        return true
    end

    local modem = peripheral.find("modem")
    if not modem then
        logging.error("[Setup] No modem found")
        print("No modem found")
        return false
    end
    logging.debug("[Setup] Found modem: " .. peripheral.getName(modem))

    term.clear()
    term.setCursorPos(1, 1)
    print("Searching for running servers...")
    logging.debug("[Setup] Searching for running servers...")
    local runningServers = bankAPI.getRunningServers(peripheral.getName(modem))
    if #runningServers == 0 then
        logging.warning("[Setup] No servers found")
        print("No servers running")
        return false
    end
    logging.info("[Setup] Found " .. #runningServers .. " server(s)")

    -- Get terminal size for calculations
    local termW, termH = term.getSize()
    local innerW = termW - 2
    local innerH = termH - 2
    local buttonW = innerW - 2

    -- Create main frame with border
    local mainFrame = basalt.createFrame()
        :setBackground(colors.lightGray)
        :setForeground(colors.white)

    -- Create inner frame with margin
    local innerFrame = mainFrame:addFrame()
        :setBackground(colors.gray)
        :setPosition(2, 2)
        :setSize(innerW, innerH)

    -- Create decorative header
    local headerFrame = innerFrame:addFrame()
        :setPosition(1, 1)
        :setSize(innerW, 3)
        :setBackground(colors.gray)

    -- Add decorative top border
    local topBorder = headerFrame:addLabel()
        :setText(string.rep("=", innerW))
        :setForeground(colors.magenta)
        :setBackground(colors.black)
        :setPosition(1, 1)

    -- Add title with better styling
    headerFrame:addLabel()
        :setText("Select Server")
        :setForeground(colors.magenta)
        :setBackground(colors.black)
        :setPosition(math.floor(innerW / 2 - 6), 2)

    -- Add decorative bottom border
    local bottomBorder = headerFrame:addLabel()
        :setText(string.rep("=", innerW))
        :setForeground(colors.magenta)
        :setBackground(colors.black)
        :setPosition(1, 3)

    local function saveData(address)
        logging.info("[Setup] Saving server address: " .. address)
        local file = fs.open(".walletServerAddress.txt", "w")
        file.write(address)
        file.close()
        logging.debug("[Setup] Server address saved to .walletServerAddress.txt")
    end

    -- Create server buttons with improved styling
    local buttons = {}
    local yPos = 5 -- Starting Y position after header
    for i, server in ipairs(runningServers) do
        local serverName = server.name:sub(1, 16) -- Strip server name to 16 symbols
        local button = innerFrame:addButton()
            :setText(serverName)
            :setPosition(2, yPos)
            :setSize(buttonW, 3)
            :setBackground(colors.magenta)
            :setForeground(colors.white)

        -- Store server data with the button
        button.serverData = server

        table.insert(buttons, button)
        yPos = yPos + 3 -- Increment Y position by button height

        -- Add hover effects
        button:onFocus(function(self)
            logging.debug("[Setup] Server button focused: " .. serverName)
            self:setBackground(colors.lightBlue)
            self:setText(">" .. serverName .. "<")
        end)

        button:onBlur(function(self)
            self:setBackground(colors.magenta)
            self:setText(serverName)
        end)

        -- Add click handler
        button:onClick(function()
            logging.info("[Setup] Server selected: " .. serverName .. " (" .. server.address .. ")")
            -- Save selected server address
            saveData(server.address)

            -- Close program
            logging.debug("[Setup] Stopping Basalt and exiting setup")
            basalt.stop()
        end)
    end

    -- Set focus to first button
    if #buttons > 0 then
        buttons[1]:setFocused(true)
    end

    -- Add keyboard navigation
    mainFrame:onKey(function(self, event, key)
        -- Guard against empty buttons table
        if #buttons == 0 then
            return
        end

        -- Find currently focused button
        local currentIndex = nil
        for i, button in ipairs(buttons) do
            if button:isFocused() then
                currentIndex = i
                break
            end
        end

        -- If no button is focused, focus the first one
        if not currentIndex then
            buttons[1]:setFocused(true)
            currentIndex = 1
        end

        if key == keys.up then
            local newIndex = currentIndex - 1
            if newIndex < 1 then
                newIndex = #buttons
            end
            buttons[newIndex]:setFocused(true)
        elseif key == keys.down or key == keys.tab then
            local newIndex = currentIndex + 1
            if newIndex > #buttons then
                newIndex = 1
            end
            buttons[newIndex]:setFocused(true)
        elseif key == keys.enter then
            local focusedButton = buttons[currentIndex]
            if focusedButton then
                logging.info("[Setup] Server selected via keyboard: " .. focusedButton.serverData.name .. " (" .. focusedButton.serverData.address .. ")")
                -- Save selected server address using the stored server data
                saveData(focusedButton.serverData.address)

                -- Close program
                logging.debug("[Setup] Stopping Basalt and exiting setup")
                basalt.stop()
            end
        end
    end)

    logging.debug("[Setup] UI initialized, running Basalt")
    basalt.run()
    logging.info("[Setup] Setup completed")
    return true
end

main()
