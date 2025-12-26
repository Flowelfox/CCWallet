-- Home Menu UI for ccShop
local menuManager = require("ui.menuManager")
local utils = require("ui.utils")
local logging = require("logging")

local homeMenu = {}

-- Create item row in list
local function createItemRow(parent, item, priceList, y, onQuantityChange)
    local w = parent:getWidth()
    local price = priceList[item.name] or 0
    local priceText = utils.formatPrice(price)

    local row = {
        item = item,
        quantity = 0
    }

    -- Item name with dots
    local nameWidth = w - 10 - #priceText
    local displayName = item.displayName or item.name
    local dots = ""
    if #displayName < nameWidth then
        dots = string.rep(".", nameWidth - #displayName - 1)
    end

    row.nameLabel = parent:addLabel()
        :setText(displayName .. " " .. dots)
        :setForeground(colors.black)
        :setBackground(colors.white)
        :setPosition(1, y)
        :setSize(nameWidth, 1)

    row.priceLabel = parent:addLabel()
        :setText(priceText)
        :setForeground(colors.black)
        :setBackground(colors.white)
        :setPosition(nameWidth + 1, y)
        :setSize(#priceText, 1)

    row.minusButton = parent:addButton()
        :setText("-")
        :setForeground(colors.black)
        :setBackground(colors.pink)
        :setPosition(w - 5, y)
        :setSize(1, 1)

    row.quantityLabel = parent:addLabel()
        :setText("0")
        :setForeground(colors.black)
        :setBackground(colors.white)
        :setPosition(w - 4, y)
        :setSize(2, 1)

    row.plusButton = parent:addButton()
        :setText("+")
        :setForeground(colors.black)
        :setBackground(colors.pink)
        :setPosition(w - 2, y)
        :setSize(1, 1)

    -- Event handlers
    row.plusButton:onClick(function()
        row.quantity = row.quantity + 1
        row.quantityLabel:setText(tostring(row.quantity))
        if onQuantityChange then
            onQuantityChange(item, row.quantity)
        end
    end)

    row.minusButton:onClick(function()
        if row.quantity > 0 then
            row.quantity = row.quantity - 1
            row.quantityLabel:setText(tostring(row.quantity))
            if onQuantityChange then
                onQuantityChange(item, row.quantity)
            end
        end
    end)

    return row
end

function homeMenu.create(parent, context)
    logging.debug("[homeMenu] Creating home menu UI...")
    local w = parent:getWidth()
    local h = parent:getHeight()
    local frameHeight = h - 4
    local scrollAreaHeight = frameHeight - 4

    local frame = parent:addFrame()
        :setPosition(1, 4)
        :setSize(w, frameHeight)
        :setBackground(colors.white)

    local elements = {}

    -- Search bar
    elements.searchBar = frame:addFrame()
        :setPosition(1, 1)
        :setSize(w, 3)
        :setBackground(colors.white)

    elements.searchBar:addLabel()
        :setText("Search:")
        :setForeground(colors.black)
        :setBackground(colors.white)
        :setPosition(2, 2)

    elements.searchInput = elements.searchBar:addInput()
        :setPosition(10, 2)
        :setSize(w - 15, 1)

    -- Items scroll frame with built-in scrollbar
    -- Scrollbar appears automatically when content exceeds visible height
    elements.itemsFrame = frame:addScrollFrame()
        :setPosition(1, 4)
        :setSize(w - 1, scrollAreaHeight)
        :setBackground(colors.white)

    -- Add items to frame
    elements.itemRows = {}
    for i, item in ipairs(context.state.itemsList) do
        local row = createItemRow(elements.itemsFrame, item, context.state.priceList, i, function(item, qty)
            context.state.cart[item.name] = qty > 0 and {item = item, quantity = qty} or nil
        end)
        table.insert(elements.itemRows, row)
    end

    elements.frame = frame
    elements.context = context

    -- Setup events
    homeMenu.setupEvents(elements)

    return elements
end

function homeMenu.setupEvents(elements)
    logging.debug("[homeMenu] Setting up event handlers...")

    -- Search functionality - observe "text" property changes
    elements.searchInput:onChange("text", function(self, newText)
        local searchText = (newText or ""):lower()
        homeMenu.filterItems(elements, searchText)
    end)
end

function homeMenu.filterItems(elements, searchText)
    logging.debug("[homeMenu] Filtering items with: " .. searchText)
    local visibleY = 1

    for i, row in ipairs(elements.itemRows) do
        local displayName = (row.item.displayName or row.item.name):lower()
        local itemName = row.item.name:lower()
        local visible = searchText == "" or displayName:find(searchText, 1, true) or itemName:find(searchText, 1, true)

        if visible then
            -- Reposition visible items to fill gaps
            local w = elements.itemsFrame:getWidth()
            local price = elements.context.state.priceList[row.item.name] or 0
            local priceText = utils.formatPrice(price)
            local nameWidth = w - 10 - #priceText

            row.nameLabel:setPosition(1, visibleY)
            row.priceLabel:setPosition(nameWidth + 1, visibleY)
            row.minusButton:setPosition(w - 5, visibleY)
            row.quantityLabel:setPosition(w - 4, visibleY)
            row.plusButton:setPosition(w - 2, visibleY)

            row.nameLabel:setVisible(true)
            row.priceLabel:setVisible(true)
            row.minusButton:setVisible(true)
            row.quantityLabel:setVisible(true)
            row.plusButton:setVisible(true)

            visibleY = visibleY + 1
        else
            row.nameLabel:setVisible(false)
            row.priceLabel:setVisible(false)
            row.minusButton:setVisible(false)
            row.quantityLabel:setVisible(false)
            row.plusButton:setVisible(false)
        end
    end

    -- Reset scroll position to top when filtering
    elements.itemsFrame:setOffset(0, 0)
end

function homeMenu.refreshItems(elements, itemsList, priceList)
    logging.debug("[homeMenu] Refreshing items list...")
    -- Clear existing items
    for _, row in ipairs(elements.itemRows) do
        row.nameLabel:destroy()
        row.priceLabel:destroy()
        row.minusButton:destroy()
        row.quantityLabel:destroy()
        row.plusButton:destroy()
    end
    elements.itemRows = {}

    -- Add new items
    for i, item in ipairs(itemsList) do
        local row = createItemRow(elements.itemsFrame, item, priceList, i, function(item, qty)
            elements.context.state.cart[item.name] = qty > 0 and {item = item, quantity = qty} or nil
        end)
        table.insert(elements.itemRows, row)
    end
end

function homeMenu.show(elements)
    logging.debug("[homeMenu] Showing home menu")
    elements.frame:setVisible(true)
    elements.frame:setEnabled(true)
end

function homeMenu.hide(elements)
    logging.debug("[homeMenu] Hiding home menu")
    elements.frame:setVisible(false)
    elements.frame:setEnabled(false)
end

function homeMenu.getItemCount(elements)
    return #elements.itemRows
end

return homeMenu
