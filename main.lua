local Dispatcher = require("dispatcher") -- luacheck:ignore
local Size = require("ui/size")
local json = require("rapidjson")
local Device = require("device")
local NetworkMgr = require("ui/network/manager")
local Screen = Device.screen
local AnkiConnect = require("AnkiConnect")
local CardWidget = require("CardWidget") -- luacheck:ignore
local KeyValuePage = require("ui/widget/keyvaluepage")
local InfoMessage = require("ui/widget/infomessage")
local HtmlBoxWidget = require("ui/widget/htmlboxwidget")
local ScrollHtmlWidget = require("ui/widget/scrollhtmlwidget")
local ViewHtml = require("ui.viewhtml")
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local ButtonDialog = require("ui/widget/buttondialog")
local MultiConfirmBox = require("ui/widget/multiconfirmbox")
local _ = require("gettext")

-- Enforce line-buffering for stdout (this is the default if it points to a tty, but we redirect to a file on most platforms).
io.stdout:setvbuf("line")
-- Enforce a reliable locale for numerical representations
os.setlocale("C", "numeric")

io.write([[ WARN myAnki[*] Current time: ]], os.date("%x-%X"), "\n")

local myAnki = WidgetContainer:extend({
    name = "anki_rev",
})

function myAnki:get_cards(deck)
    local card_ids = AnkiConnect:query_from_deck(deck)
    return card_ids
end

function myAnki:deck_cards_iterator(deck)
    local card_ids = myAnki:get_cards(deck)
    local i = 0
    local n = #card_ids
    return function()
        i = i + 1
        if i <= n then
            local card_id = card_ids[i]
            return AnkiConnect:read_card_from_id(card_id)
        end
    end
end

function myAnki:show_card(card_info, question_answer, on_done)
    local signal = question_answer
    local function review_card(card_id, ease)
        AnkiConnect:review_card(card_id, ease)
    end
    local function on_save_cb()
        local m = self.card_menu
        -- self.current_note:set_custom_context(m.prev_s_cnt, m.prev_c_cnt, m.next_s_cnt, m.next_c_cnt)
        -- AnkiConnect:add_note(self.current_note)
        self.card_menu:onClose()
    end

    local function on_show_next()
        self.card_menu:onClose()
        on_done("answer")
    end

    self.card_menu = CardWidget:new({
        note = card_info,
        mode = signal,
        on_save_cb = on_save_cb, -- called when saving note with updated context
        on_show_answer = on_show_next,
        review = review_card,
    })
    UIManager:show(self.card_menu)
end

function myAnki:deckView(deck, deck_name)
    local name = deck_name
    local new_v = deck.new_count
    local learn_v = deck.learn_count
    local review_v = deck.review_count
    return MultiConfirmBox:new({
        text = _(
            name
                .. " \n "
                .. "New Cards: "
                .. new_v
                .. "\n"
                .. "To Relearn: "
                .. learn_v
                .. "\n"
                .. "To Review: "
                .. review_v
                .. "\n"
        ),
        choice1_text = _("Study"),
        choice1_callback = function()
            local deck_iter = myAnki:deck_cards_iterator(name)
            local function show_next_card()
                local card = deck_iter()
                if not card then
                    UIManager:show(InfoMessage:new({
                        text = _("Deck finished"),
                    }))
                    return
                end

                -- Show QUESTION
                myAnki:show_card(card[1], "question", function(result)
                    -- Show ANSWER after user clicks
                    myAnki:show_card(card[1], result, function()
                        -- Move to NEXT card only after answer is done
                        show_next_card()
                    end)
                end)
            end

            -- Start the chain
            show_next_card()
        end,
        choice2_text = _("Options"),
        choice2_callback = function()
            -- set as fallback font
        end,

        choice3_text = _("Deck Statistics"),
        choice3_callback = function()
            -- set as fallback font
        end,
    })
end

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
local function catch_write(e)
    print("ERROR:", e)
end

local function deck_load_helper()
    local decks = AnkiConnect:get_decks()
    local result = {}

    xpcall(function()
        decks = AnkiConnect:get_decks()
    end, catch_write)

    for name, id in pairs(decks) do
        result[name] = {
            text = name,
            name,
            callback = function()
                local stats = AnkiConnect:get_stats_from(name)
                local deck = stats[tostring(id)]
                UIManager:show(myAnki:deckView(deck, name))
            end,
        }
    end

    return result
end

local function build_tree(tbl)
    local result = {}

    for key, value in pairs(tbl) do
        local node = result
        for part in (key .. "::"):gmatch("(.-)::") do
            node[part] = node[part] or {}
            node = node[part]
        end
        node.current = value
    end

    return result
end

function myAnki:open_group_page(title, node)
    local items = {}

    if type(node) ~= "table" then
        return
    end

    -- open deck entry
    if node.current and node.current.callback then
        table.insert(items, {
            _("Open deck"),
            "",
            callback = node.current.callback,
        })
    end

    for k, v in pairs(node) do
        if k ~= "current" and type(v) == "table" then
            table.insert(items, {
                k,
                "",
                callback = function()
                    self:open_group_page(k, v)
                end,
            })
        end
    end

    UIManager:show(KeyValuePage:new({
        title = title,
        kv_pairs = items,
    }))
end

local function get_grouped_decks()
    local decks = deck_load_helper()
    local tree = build_tree(decks)
    myAnki:open_group_page("Decks", tree)
end

local function get_decks()
    local decks = {}
    local sub_item_table = {}

    sub_item_table = {}
    decks = deck_load_helper()
    for k, v in pairs(decks) do
        table.insert(sub_item_table, v)
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
                return NetworkMgr:runWhenOnline(function()
                    return get_decks()
                end)
            end,
        },

        {
            text = _("Grouped Decks"),
            keep_menu_open = true,
            sub_item_table_func = function()
                return NetworkMgr:runWhenOnline(function()
                    return get_grouped_decks()
                end)
            end,
        },

        {
            text = _("Synchronize data"),
            keep_menu_open = true,
            callback = function()
                return NetworkMgr:runWhenOnline(function()
                    return AnkiConnect:sync()
                end)
            end,
        },

        {
            text = _("Set Anki Endpoint"),
            keep_menu_open = true,
            callback = function()
                return AnkiConnect:sync()
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
