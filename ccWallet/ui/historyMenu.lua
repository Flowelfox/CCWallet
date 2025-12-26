-- History Sub-Menu UI for ccWallet
local menuManager = require("ui.menuManager")
local logging = require("logging")

local historyMenu = {}

function historyMenu.create(parent, w, h)
    local menu = {}

    menu.frame = parent:addFrame()
        :setPosition(2, 4)
        :setSize(w - 2, h - 4)
        :setBackground(colors.white)
        :setVisible(false)
        :setEnabled(false)

    menu.titleLabel = menu.frame:addLabel()
        :setText("History:")
        :setPosition(1, 1)
        :setSize(8, 1)
        :setForeground(colors.gray)

    -- Scrollable list for history entries
    menu.historyList = menu.frame:addList()
        :setPosition(1, 2)
        :setSize(w - 2, h - 9)
        :setBackground(colors.white)
        :setForeground(colors.gray)
        :setSelectable(false)
        :setScrollBarColor(colors.magenta)
        :setScrollBarBackgroundColor(colors.lightGray)
        :listenEvent("mouse_scroll", true)

    -- Back button (centered horizontally, aligned to bottom)
    menu.backButton = menu.frame:addButton()
        :setText("Back")
        :setSize(14, 3)
        :setBackground(colors.magenta)
        :centerHorizontal("parent", -1)
        :alignBottom("parent", -3)

    return menu
end

function historyMenu.setupEvents(menu, elements, callbacks)
    -- Helper to scroll list
    local function scrollList(delta)
        local currentOffset = menu.historyList.get("offset") or 0
        local newOffset = math.max(0, currentOffset + delta)
        logging.info("[historyMenu] scrollList: offset " .. tostring(currentOffset) .. " -> " .. tostring(newOffset))
        menu.historyList.set("offset", newOffset)
        menu.historyList:updateRender()
    end

    -- Navigation config with scroll functions
    local navigation = {
        backButton = {
            up = function() scrollList(-1) end,
            down = function() scrollList(1) end,
            tab = "backButton",  -- Only one focusable element
            enter = callbacks.onCloseHistory
        }
    }

    -- Create and setup menu context
    menu.ctx = menuManager.createContext({
        frame = menu.frame,
        elements = {
            backButton = menu.backButton,
            historyList = menu.historyList
        },
        navigation = navigation,
        defaultFocus = "backButton",
        parent = elements.parent
    })

    menuManager.setup(menu.ctx)

    -- Mouse scroll on list (menu-specific behavior)
    menu.historyList:onScroll(function(self, direction)
        scrollList(direction)
        return true
    end)

end

function historyMenu.updateHistory(menu, history)
    menu.historyList:clear()
    if #history == 0 then
        logging.debug("[historyMenu] No history to display")
        menu.historyList:addItem("No history")
    else
        logging.debug("[historyMenu] Displaying " .. #history .. " history entry(ies)")
        -- Add items in reverse order (newest first)
        for i = #history, 1, -1 do
            local hist = history[i]
            menu.historyList:addItem(os.date("%R", hist.time) .. ": " .. hist.message)
        end
    end
end

return historyMenu
