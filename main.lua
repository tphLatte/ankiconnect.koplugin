local Dispatcher = require("dispatcher") -- luacheck:ignore
local Size = require("ui/size")
local json = require("rapidjson")
local Device = require("device")
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

local function get_decks()
    local decks = {}
    xpcall(function()
        decks = AnkiConnect:get_decks()
    end, catch_write)
    local sub_item_table = {}

    for k, v in pairs(decks) do
        local to_insert = ""
        to_insert = k
        table.insert(sub_item_table, {
            to_insert,
            "",
            callback = function()
                -- io.write("WARN id is", v)
                -- io.write("WARN calling stats from", to_insert, "\n")
                local stats = AnkiConnect:get_stats_from(to_insert)
                -- io.write("WARN statsTYpe ", type(stats))
                local deck = stats[tostring(v)]
                UIManager:show(myAnki:deckView(deck, k))
                --UIManager:show(InfoMessage:new({
                --    text = _("Deck is" .. to_insert .. " and " .. v),
                --}))
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

        {
            text = _("Synchronize data"),
            keep_menu_open = true,
            sub_item_table_func = function()
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
