local bankAPI = {}
local ecnet2 = require("ecnet2")
local random = require("ccryptolib.random")
local logging = require("logging")
local serversChannel = 58235

logging.debug("[bankAPI] Module loading...")
random.initWithTiming()
local id = ecnet2.Identity(".identity")
logging.debug("[bankAPI] ECNet2 identity loaded")

-- Define a protocol.
local api = id:Protocol {
    -- Programs will only see packets sent on the same protocol.
    -- Only one active listener can exist at any time for a given protocol name.
    name = "api",

    -- Objects must be serialized before they are sent over.
    serialize = textutils.serialize,
    deserialize = textutils.unserialize,
}
logging.debug("[bankAPI] Protocol 'api' defined")

local server = nil
local timeout = 5
local side = 'back'
local isPocket = false
if pocket then
    isPocket = true
    logging.debug("[bankAPI] Running on pocket computer")
end

function bankAPI.init(serverId, modemSide)
    logging.debug("[bankAPI] Initializing with server: " .. tostring(serverId) .. ", modem: " .. tostring(modemSide))
    if serverId == nil then
        logging.error("[bankAPI] Server is not set")
        printError("Server is not set")
        return false
    elseif modemSide == nil then
        logging.error("[bankAPI] Modem side is not set")
        printError("Modem side is not set")
        return false
    end

    local modemType = peripheral.getType(modemSide)
    if modemType == nil then
        logging.error("[bankAPI] Modem not found on side: " .. modemSide)
        printError("Modem not found")
        return false
    elseif modemType ~= "modem" then
        logging.error("[bankAPI] Invalid peripheral type on " .. modemSide .. ": " .. modemType)
        printError("It is not a modem on the \"" .. modemSide .. "\" side")
        return false
    end
    server = serverId
    side = modemSide
    ecnet2.open(side)
    logging.info("[bankAPI] Initialized successfully - server: " .. server .. ", modem: " .. side)
    return true
end

function bankAPI.start(main)
    logging.debug("[bankAPI] Starting with ecnet2 daemon")
    parallel.waitForAny(main, ecnet2.daemon)
end

local function waitResponse(connection, timeout)
    logging.debug("[bankAPI] Waiting for response (timeout: " .. tostring(timeout) .. "s)")
    local response = select(2, connection:receive(timeout))
    if response == nil then
        logging.warning("[bankAPI] Response timeout after " .. tostring(timeout) .. "s")
        return nil
    end
    logging.debug("[bankAPI] Response received")
    return response
end

local function readToken()
    logging.debug("[bankAPI] Reading authentication token...")
    if not fs.exists(".token") then
        logging.debug("[bankAPI] Token file not found")
        return nil
    end
    local tokenFile = fs.open(".token", "r")
    local token = tokenFile.readAll()
    tokenFile.close()
    if token == nil or token == "" then
        logging.warning("[bankAPI] Token file is empty")
        return nil
    end
    logging.debug("[bankAPI] Token loaded successfully")
    return token
end


local function createConnection()
    -- Create a connection to the server.
    logging.debug("[bankAPI] Creating connection to server: " .. server)
    local connection = api:connect(server, side)
    -- Wait for the greeting.
    local response = waitResponse(connection, timeout)
    if response == nil then
        logging.error("[bankAPI] Failed to connect to server - no greeting received")
        return nil
    end
    logging.debug("[bankAPI] Connection established, greeting received")
    return connection
end

function bankAPI.sendMoney(recipient, amount)
    logging.info("[bankAPI] Sending money: " .. tostring(amount) .. " to " .. tostring(recipient))
    local connection = createConnection()
    if connection == nil then
        logging.error("[bankAPI] sendMoney failed - no connection")
        return false, "Connection failed"
    end
    -- Send a message.
    local token = readToken()
    logging.debug("[bankAPI] Sending sendMoney command...")
    connection:send({command = "sendMoney", token = token, recipient = recipient, amount = amount})
    local response = waitResponse(connection, timeout)
    if response == nil then
        logging.warning("[bankAPI] sendMoney - no response from server")
        connection:send({command = "close"})
        return false
    end

    local type = response['type']
    local message = response['message']

    if type == nil or message == nil then
        logging.error("[bankAPI] sendMoney - invalid response format")
        connection:send({command = "close"})
        return false
    end

    if type == "success" then
        logging.info("[bankAPI] sendMoney successful: " .. message)
    else
        logging.warning("[bankAPI] sendMoney failed: " .. message)
    end
    connection:send({command = "close"})
    return type == "success", message
end

function bankAPI.getUser()
    logging.debug("[bankAPI] Fetching user information...")
    local connection = createConnection()
    if connection == nil then
        logging.error("[bankAPI] getUser failed - no connection")
        return false
    end
    -- Send a message.
    local token = readToken()
    logging.debug("[bankAPI] Sending getUser command...")
    connection:send({command = "getUser", token = token})
    local response = waitResponse(connection, timeout)
    if response == nil then
        logging.warning("[bankAPI] getUser - no response from server")
        connection:send({command = "close"})
        return false
    end

    local type = response['type']
    local user = response['user']
    local message = response['message']

    if type == "error" then
        logging.warning("[bankAPI] getUser error: " .. tostring(message))
        connection:send({command = "close"})
        return false
    elseif type == "success" then
        logging.debug("[bankAPI] getUser successful - user: " .. tostring(user and user.login))
        connection:send({command = "close"})
        return user
    elseif type == nil or user == nil then
        logging.error("[bankAPI] getUser - invalid response format")
        connection:send({command = "close"})
        return false
    end

end

function bankAPI.getRegisteredUsers()
    logging.debug("[bankAPI] Fetching registered users list...")
    local connection = createConnection()
    if connection == nil then
        logging.error("[bankAPI] getRegisteredUsers failed - no connection")
        return {}
    end
    -- Send a message.
    local token = readToken()
    logging.debug("[bankAPI] Sending getRegisteredUsers command...")
    connection:send({command = "getRegisteredUsers", token = token})
    local response = waitResponse(connection, timeout)
    if response == nil then
        logging.warning("[bankAPI] getRegisteredUsers - no response from server")
        connection:send({command = "close"})
        return {}
    end

    local type = response['type']
    local users = response['users']
    local message = response['message']

    if type == "error" then
        logging.warning("[bankAPI] getRegisteredUsers error: " .. tostring(message))
        connection:send({command = "close"})
        return {}
    elseif type == "success" then
        logging.debug("[bankAPI] getRegisteredUsers successful - " .. #users .. " users")
        connection:send({command = "close"})
        return users
    elseif type == nil or users == nil then
        logging.error("[bankAPI] getRegisteredUsers - invalid response format")
        connection:send({command = "close"})
        return {}
    end
end

function bankAPI.register(login, password)
    logging.info("[bankAPI] Registering new user: " .. login)
    local connection = createConnection()
    if connection == nil then
        logging.error("[bankAPI] register failed - no connection")
        return false, "Can't connect to the server"
    end
    -- Send a message.
    logging.debug("[bankAPI] Sending register command...")
    connection:send({command = "register", login = login, password = password})
    local response = waitResponse(connection, timeout)
    if response == nil then
        logging.warning("[bankAPI] register - no response from server")
        connection:send({command = "close"})
        return false, "Request timeout"
    end

    local type = response['type']
    local message = response['message']

    if type == nil or message == nil then
        logging.error("[bankAPI] register - invalid response format")
        connection:send({command = "close"})
        return false, "Internal error"
    end

    if type == "success" then
        logging.info("[bankAPI] Registration successful for user: " .. login)
    else
        logging.warning("[bankAPI] Registration failed for user: " .. login .. " - " .. message)
    end
    connection:send({command = "close"})
    return type == "success", message
end

function bankAPI.login(login, password)
    logging.info("[bankAPI] Login attempt for user: " .. login)
    local connection = createConnection()
    if connection == nil then
        logging.error("[bankAPI] login failed - no connection")
        return false, "Can't connect to the server"
    end
    -- Send a message.
    logging.debug("[bankAPI] Sending login command...")
    connection:send({command = "login", login = login, password = password, isPocket = isPocket})
    local response = waitResponse(connection, timeout)
    if response == nil then
        logging.warning("[bankAPI] login - no response from server")
        connection:send({command = "close"})
        return false, "Request timeout"
    end

    local type = response['type']
    local token = response['token']
    local message = response['message']


    if type == "error" then
        logging.warning("[bankAPI] Login failed for user: " .. login .. " - " .. tostring(message))
        connection:send({command = "close"})
        return false, message
    elseif type == nil or token == nil then
        logging.error("[bankAPI] login - invalid response format")
        connection:send({command = "close"})
        return false, "Internal error"
    else
        logging.info("[bankAPI] Login successful for user: " .. login)
        logging.debug("[bankAPI] Saving authentication token...")
        local tokenFile = fs.open(".token", "w")
        tokenFile.write(token)
        tokenFile.close()
        logging.debug("[bankAPI] Token saved to file")
        connection:send({command = "close"})
        return true, user
    end

end

function bankAPI.logout()
    logging.info("[bankAPI] Logging out...")
    local connection = createConnection()
    if connection == nil then
        logging.error("[bankAPI] logout failed - no connection")
        return false
    end

    local token = readToken()

    logging.debug("[bankAPI] Sending logout command...")
    connection:send({command = "logout", token = token})
    local response = waitResponse(connection, timeout)
    if response == nil then
        logging.warning("[bankAPI] logout - no response from server")
        connection:send({command = "close"})
        return false
    end

    local type = response['type']
    local message = response['message']

    if type == nil or message == nil then
        logging.error("[bankAPI] logout - invalid response format")
        connection:send({command = "close"})
        return false
    end

    if type == "error" then
        logging.warning("[bankAPI] Logout error: " .. tostring(message))
        connection:send({command = "close"})
        return false
    else
        logging.info("[bankAPI] Logout successful")
        logging.debug("[bankAPI] Deleting token file...")
        fs.delete(".token")
        connection:send({command = "close"})
        return true
    end
end

function bankAPI.getRunningServers(modemSide)
    logging.debug("[bankAPI] Searching for running servers on modem: " .. modemSide)
    local modem = peripheral.wrap(modemSide)
    if modem == nil then
        logging.error("[bankAPI] getRunningServers - modem not found")
        return {}
    end
    local replyChannel = math.random(1, 65535)
    local stopSearch = false
    local servers = {}
    os.startTimer(2)

    logging.debug("[bankAPI] Broadcasting getServers on channel " .. serversChannel .. ", reply on " .. replyChannel)
    modem.open(replyChannel)
    modem.transmit(serversChannel, replyChannel, "getServers")
    while true do
        local event, side, channel, _, message, distance
        repeat
            event, side, channel, _, message, distance = os.pullEvent()
            if event == "timer" then
                stopSearch = true
                break
            end
        until event == "modem_message" and channel == replyChannel
        if stopSearch then
            logging.debug("[bankAPI] Server search completed - found " .. #servers .. " server(s)")
            modem.close(replyChannel)
            return servers
        end
        if message ~= nil then
            if message:sub(1, 15) == "serverAvailable" then
                local serverData = textutils.unserialize(message:sub(16))
                logging.debug("[bankAPI] Found server: " .. tostring(serverData and serverData.name))
                table.insert(servers, serverData)
            end
        end
    end
end

logging.debug("[bankAPI] Module loaded successfully")
return bankAPI