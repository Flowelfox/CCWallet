-- ccShop Inventory Management
local inventory = {}

-- Mock items for testing when no real inventory is available
local mockItems = {
    {name = "minecraft:diamond", displayName = "Diamond", count = 64},
    {name = "minecraft:iron_ingot", displayName = "Iron Ingot", count = 128},
    {name = "minecraft:gold_ingot", displayName = "Gold Ingot", count = 64},
    {name = "minecraft:emerald", displayName = "Emerald", count = 32},
    {name = "minecraft:netherite_ingot", displayName = "Netherite Ingot", count = 8},
    {name = "minecraft:oak_log", displayName = "Oak Log", count = 256},
    {name = "minecraft:cobblestone", displayName = "Cobblestone", count = 512},
    {name = "minecraft:redstone", displayName = "Redstone Dust", count = 128},
    {name = "minecraft:lapis_lazuli", displayName = "Lapis Lazuli", count = 64},
    {name = "minecraft:coal", displayName = "Coal", count = 256},
    {name = "minecraft:copper_ingot", displayName = "Copper Ingot", count = 128},
    {name = "minecraft:amethyst_shard", displayName = "Amethyst Shard", count = 32},
    {name = "minecraft:quartz", displayName = "Nether Quartz", count = 64},
    {name = "minecraft:glowstone_dust", displayName = "Glowstone Dust", count = 64},
    {name = "minecraft:ender_pearl", displayName = "Ender Pearl", count = 16},
    {name = "minecraft:blaze_rod", displayName = "Blaze Rod", count = 24},
    {name = "minecraft:slime_ball", displayName = "Slime Ball", count = 48},
    {name = "minecraft:leather", displayName = "Leather", count = 64},
    {name = "minecraft:string", displayName = "String", count = 128},
    {name = "minecraft:feather", displayName = "Feather", count = 64},
}

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

    -- Return mock items if no real inventory found
    if #itemsList == 0 then
        return mockItems
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
