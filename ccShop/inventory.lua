-- ccShop Inventory Management
local inventory = {}

function inventory.getItemsList()
    local deviceNames = peripheral.getNames()
    local itemsList = {}
    for _, deviceName in pairs(deviceNames) do
        local device = peripheral.wrap(deviceName)
        if peripheral.hasType(device, "inventory") then
            local items = device.list()
            for slot, item in pairs(items) do
                local itemDetails = device.getItemDetail(slot)
                if itemDetails then
                    itemDetails['device'] = deviceName
                    itemDetails['slot'] = slot
                    table.insert(itemsList, itemDetails)
                end
            end
        end
    end
    return itemsList
end

function inventory.loadPriceList()
    local priceList = {}
    local file = fs.open("priceList.txt", "r")
    if file then
        local line = file.readLine()
        while line do
            local parts = string.gmatch(line, "%S+")
            local itemName = parts()
            local price = tonumber(parts()) or 0
            priceList[itemName] = price
            line = file.readLine()
        end
        file.close()
    end
    return priceList
end

function inventory.savePriceList(priceList)
    local file = fs.open("priceList.txt", "w")
    for itemName, price in pairs(priceList) do
        file.writeLine(itemName .. " " .. price)
    end
    file.close()
end

function inventory.updatePriceList()
    local itemsList = inventory.getItemsList()
    local priceList = inventory.loadPriceList()

    for _, item in pairs(itemsList) do
        if not priceList[item.name] then
            priceList[item.name] = 0
        end
    end

    inventory.savePriceList(priceList)
    return priceList
end

function inventory.getItemPrice(itemName, priceList)
    return priceList[itemName] or 0
end

return inventory
