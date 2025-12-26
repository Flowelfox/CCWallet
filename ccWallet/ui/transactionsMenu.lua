-- Transactions Sub-Menu UI for ccWallet
local menuManager = require("ui.menuManager")
local logging = require("logging")

local transactionsMenu = {}

function transactionsMenu.create(parent, w, h)
    local menu = {}

    menu.frame = parent:addFrame()
        :setPosition(2, 4)
        :setSize(w - 2, h - 4)
        :setBackground(colors.white)
        :setVisible(false)
        :setEnabled(false)

    menu.titleLabel = menu.frame:addLabel()
        :setText("Last transactions:")
        :setPosition(1, 1)
        :setSize(18, 1)
        :setForeground(colors.gray)

    menu.labels = {}
    for i = 1, 10 do
        menu.labels[i] = menu.frame:addLabel()
            :setText("")
            :setPosition(1, 2 + i)
            :setSize(30, 1)
            :setForeground(colors.gray)
    end

    -- Back button (centered horizontally, aligned to bottom)
    menu.backButton = menu.frame:addButton()
        :setText("Back")
        :setSize(14, 3)
        :setBackground(colors.magenta)
        :centerHorizontal("parent", -1)
        :alignBottom("parent", -3)

    return menu
end

function transactionsMenu.setupEvents(menu, elements, callbacks)
    -- Navigation config - single button
    local navigation = {
        backButton = {
            up = "backButton",
            down = "backButton",
            tab = "backButton",
            enter = callbacks.onCloseTransactions
        }
    }

    -- Create and setup menu context
    menu.ctx = menuManager.createContext({
        frame = menu.frame,
        elements = {
            backButton = menu.backButton
        },
        navigation = navigation,
        defaultFocus = "backButton",
        parent = elements.parent
    })

    menuManager.setup(menu.ctx)
end

function transactionsMenu.updateTransactions(menu, transactions)
    local txLabels = menu.labels
    if #transactions == 0 then
        logging.debug("[transactionsMenu] No transactions to display")
        txLabels[1]:setText("No transactions")
        for i = 2, 10 do
            txLabels[i]:setText("")
        end
    else
        logging.debug("[transactionsMenu] Displaying " .. #transactions .. " transaction(s)")
        local count = #transactions
        for i = 1, 10 do
            local idx = count - i + 1
            if idx > 0 then
                local tx = transactions[idx]
                local amountRounded = math.floor(tx.amount * 100) / 100
                txLabels[i]:setText(tx.from .. " -> " .. tx.to .. ": " .. amountRounded .. "$")
            else
                txLabels[i]:setText("")
            end
        end
    end
end

return transactionsMenu
