local Dispatcher = require("dispatcher") -- luacheck:ignore
local AnkiConnect = require("AnkiConnect")
local KeyValuePage = require("ui/widget/keyvaluepage")
local InfoMessage = require("ui/widget/infomessage")
local HtmlBoxWidget = require("ui/widget/htmlboxwidget")
local ViewHtml = require("ui.viewhtml")
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local _ = require("gettext")

-- Enforce line-buffering for stdout (this is the default if it points to a tty, but we redirect to a file on most platforms).
io.stdout:setvbuf("line")
-- Enforce a reliable locale for numerical representations
os.setlocale("C", "numeric")

io.write([[ WARN myAnki[*] Current time: ]], os.date("%x-%X"), "\n")

local myAnki = WidgetContainer:extend({
    name = "anki_rev",
})

function myAnki:KeyValuePage(title, messageTable)
    local kv = KeyValuePage:new({
        title = title,
        kv_pairs = messageTable,
        callback_return = function()
            UIManager:close(self.kv)
        end,
    })
    UIManager:show(kv)
end

local function get_decks()
    local decks = AnkiConnect.get_decks()
    local sub_item_table = {}
    for i = 1, #decks do
        local to_insert = ""
        to_insert = decks[i]
        table.insert(sub_item_table, {
            to_insert,
            "",
            callback = function()
                UIManager:show(InfoMessage:new({
                    text = _("Deck is" .. to_insert),
                }))
            end,
        })
    end

    return myAnki:KeyValuePage("Decks", sub_item_table)
end

function myAnki:init()
    self.ui.menu:registerToMainMenu(self)
    UIManager:show(InfoMessage:new({
        text = _("Hello, anki"),
    }))
end

function myAnki:get_sub_menu_items()
    local sub_item_table = {

        {
            text = _("Select Decks"),
            keep_menu_open = true,
            sub_item_table_func = function()
                return get_decks()
            end,
        },
    }
    return sub_item_table
end

function myAnki:addToMainMenu(menu_items)
    menu_items.anki_rev = {
        text = _("Anki Plugin"),
        sorting_hint = "search_settings",
        sub_item_table_func = function()
            return self:get_sub_menu_items()
        end,
    }
end

io.write([[ WARN myAnki[*] still exists Current time: ]], os.date("%x-%X"), "\n")
return myAnki
