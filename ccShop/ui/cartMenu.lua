-- Cart Menu UI for ccShop
local menuManager = require("menuManager")
local utils = require("ui.utils")
local logging = require("logging")
local basalt = require("basalt")

local cartMenu = {}

function cartMenu.create(parent, context)
    logging.debug("[cartMenu] Creating cart menu UI...")
    local w = parent:getWidth()
    local h = parent:getHeight()

    local frame = parent:addFrame()
        :setPosition(1, 4)
        :setSize(w, h - 4)
        :setBackground(colors.white)
        :setVisible(false)

    local elements = {}

    elements.titleLabel = frame:addLabel()
        :setText("Shopping Cart")
        :setForeground(colors.black)
        :setBackground(colors.white)
        :setPosition(math.floor(w / 2) - 6, 2)

    elements.cartItemsFrame = frame:addScrollFrame()
        :setPosition(2, 4)
        :setSize(w - 4, h - 10)
        :setBackground(colors.lightGray)

    elements.emptyCartLabel = elements.cartItemsFrame:addLabel()
        :setText("Your cart is empty")
        :setForeground(colors.gray)
        :setBackground(colors.lightGray)
        :setPosition(2, 2)

    elements.totalLabel = frame:addLabel()
        :setText("Total: 0$")
        :setForeground(colors.black)
        :setBackground(colors.white)
        :setPosition(2, h - 5)

    elements.checkoutButton = frame:addButton()
        :setText("Checkout")
        :setForeground(colors.black)
        :setBackground(colors.lime)
        :setPosition(math.floor(w / 2) - 5, h - 4)
        :setSize(12, 3)
        :registerState("loading", nil, 300)
        :setBackgroundState("loading", colors.lightBlue)

    elements.clearCartButton = frame:addButton()
        :setText("Clear")
        :setForeground(colors.black)
        :setBackground(colors.red)
        :setPosition(2, h - 4)
        :setSize(8, 3)

    -- Animation timer for checkout
    elements.checkoutTimer = frame:addTimer()
        :setInterval(0.4)
        :stop()

    -- Status label for feedback
    elements.statusLabel = frame:addLabel()
        :setText("")
        :setForeground(colors.green)
        :setBackground(colors.white)
        :setPosition(2, h - 6)

    elements.frame = frame
    elements.context = context
    elements.cartRows = {}

    -- Setup events
    cartMenu.setupEvents(elements, context)

    logging.debug("[cartMenu] Cart menu created successfully")
    return elements
end

function cartMenu.setupEvents(elements, context)
    logging.debug("[cartMenu] Setting up event handlers...")

    -- Clear cart button
    elements.clearCartButton:onClick(function()
        logging.info("[cartMenu] Clearing cart")
        context.state.cart = {}
        cartMenu.refreshCart(elements)
        elements.statusLabel:setForeground(colors.yellow)
        elements.statusLabel:setText("Cart cleared")
    end)

    -- Checkout button
    elements.checkoutButton:onClick(function()
        if elements.checkoutButton:hasState("loading") then
            logging.debug("[cartMenu] Checkout blocked - already in progress")
            return
        end

        local cartItems = context.state.cart
        local itemCount = 0
        for _ in pairs(cartItems) do
            itemCount = itemCount + 1
        end

        if itemCount == 0 then
            logging.debug("[cartMenu] Checkout blocked - cart is empty")
            elements.statusLabel:setForeground(colors.red)
            elements.statusLabel:setText("Cart is empty!")
            return
        end

        logging.info("[cartMenu] Starting checkout process...")
        cartMenu.setLoading(elements, true)

        -- Schedule checkout to run async
        basalt.schedule(function()
            local success, result = cartMenu.processCheckout(elements, context)

            cartMenu.setLoading(elements, false)

            if success then
                logging.info("[cartMenu] Checkout successful")
                elements.statusLabel:setForeground(colors.green)
                elements.statusLabel:setText("Checkout successful!")
                context.state.cart = {}
                cartMenu.refreshCart(elements)
            else
                logging.warning("[cartMenu] Checkout failed: " .. (result or "unknown error"))
                elements.statusLabel:setForeground(colors.red)
                elements.statusLabel:setText(result or "Checkout failed")
            end
        end)
    end)

    logging.debug("[cartMenu] Event handlers setup complete")
end

function cartMenu.processCheckout(elements, context)
    logging.debug("[cartMenu] Processing checkout...")

    -- Calculate total
    local total = 0
    for itemName, cartItem in pairs(context.state.cart) do
        local price = context.state.priceList[itemName] or 0
        total = total + (price * cartItem.quantity)
    end

    logging.debug("[cartMenu] Cart total: " .. total .. "$")

    -- Check if user is logged in
    if not context.state.loggedInUser then
        logging.warning("[cartMenu] No user logged in")
        return false, "Please login first"
    end

    -- Process payment via bankAPI
    local success, result
    local timedOut = false

    parallel.waitForAny(
        function()
            -- TODO: Implement actual payment processing
            -- success, result = context.bankAPI.transfer(context.state.loggedInUser, "shop", total)
            sleep(1) -- Simulate payment
            success = true
            result = "Payment successful"
        end,
        function()
            sleep(10)
            timedOut = true
        end
    )

    if timedOut and not success then
        return false, "Payment timed out"
    end

    return success, result
end

function cartMenu.refreshCart(elements)
    logging.debug("[cartMenu] Refreshing cart display...")
    local context = elements.context

    -- Clear existing cart rows
    for _, row in ipairs(elements.cartRows) do
        if row.nameLabel then row.nameLabel:remove() end
        if row.qtyLabel then row.qtyLabel:remove() end
        if row.priceLabel then row.priceLabel:remove() end
    end
    elements.cartRows = {}

    -- Calculate totals and rebuild display
    local total = 0
    local y = 1
    local hasItems = false

    for itemName, cartItem in pairs(context.state.cart) do
        hasItems = true
        local item = cartItem.item
        local quantity = cartItem.quantity
        local price = context.state.priceList[itemName] or 0
        local lineTotal = price * quantity

        total = total + lineTotal

        local row = {}
        local displayName = item.displayName or item.name
        if #displayName > 20 then
            displayName = displayName:sub(1, 17) .. "..."
        end

        row.nameLabel = elements.cartItemsFrame:addLabel()
            :setText(displayName)
            :setForeground(colors.black)
            :setBackground(colors.lightGray)
            :setPosition(2, y)

        row.qtyLabel = elements.cartItemsFrame:addLabel()
            :setText("x" .. quantity)
            :setForeground(colors.gray)
            :setBackground(colors.lightGray)
            :setPosition(25, y)

        row.priceLabel = elements.cartItemsFrame:addLabel()
            :setText(utils.formatPrice(lineTotal))
            :setForeground(colors.black)
            :setBackground(colors.lightGray)
            :setPosition(30, y)

        table.insert(elements.cartRows, row)
        y = y + 1
    end

    -- Show/hide empty cart message
    elements.emptyCartLabel:setVisible(not hasItems)

    -- Update total
    elements.totalLabel:setText("Total: " .. utils.formatPrice(total))
    logging.debug("[cartMenu] Cart refreshed, total: " .. total .. "$")
end

function cartMenu.setLoading(elements, loading)
    if loading then
        logging.debug("[cartMenu] Setting loading state: ON")
        if not elements.loadingAnim then
            elements.loadingAnim = utils.createLoadingAnimation(
                elements.checkoutButton,
                elements.checkoutTimer,
                "Processing"
            )
        end
        elements.loadingAnim.start()
        utils.setElementsEnabled(false, elements.clearCartButton)
    else
        logging.debug("[cartMenu] Setting loading state: OFF")
        if elements.loadingAnim then
            elements.loadingAnim.stop("Checkout")
        end
        utils.setElementsEnabled(true, elements.clearCartButton)
    end
end

function cartMenu.show(elements)
    logging.debug("[cartMenu] Showing cart menu")
    cartMenu.refreshCart(elements)
    elements.statusLabel:setText("")
    elements.frame:setVisible(true)
    elements.frame:setEnabled(true)
end

function cartMenu.hide(elements)
    logging.debug("[cartMenu] Hiding cart menu")
    elements.frame:setVisible(false)
    elements.frame:setEnabled(false)
end

return cartMenu
