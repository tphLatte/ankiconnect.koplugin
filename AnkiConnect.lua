local http = require("socket.http")
local json = require("rapidjson")
local ssl = require("ssl") -- LuaSec

io.stdout:setvbuf("line")
-- Enforce a reliable locale for numerical representations
os.setlocale("C", "numeric")

local AnkiConnect = {}

local endpoint = "http://localhost:8765"
--"http://148.201.238:8765"
-- "http://192.168.100.109:8765"
function AnkiConnect:init()
    self.endpoint = endpoint
end

function AnkiConnect:get_decks()
    local body, code, headers, status = http.request(endpoint, '{"action": "deckNamesAndIds", "version": 6}')
    return json.decode(body).result
end

function AnkiConnect:get_stats(decks)
    local deck_names = ""
    for i = 1, #decks do
        deck_names = deck_names .. decks[i]
    end
    local body, code, headers, status =
        http.request(endpoint, '{ "action": "getDeckStats", "version": 6, "params":{ "decks"=[' .. "]} }")
    -- io.write("WARN DECK", body)
    return json.decode(body).result
end

function AnkiConnect:get_deck_id(deck_name)
    local action = '{ "action": "deckNamesAndIds", "version": 6 }'
    local body, code, headers, status = http.request(endpoint, action)
    return json.decode(body).result[deck_name]
end

function AnkiConnect:get_stats_from(deck)
    local deck_names = '"' .. deck .. '"'
    local action = '{ "action": "getDeckStats", "version": 6, "params":{ "decks":[' .. deck_names .. "]} }"
    local body, code, headers, status = http.request(endpoint, action)

    -- io.write("WARN stats ", body)
    return json.decode(body).result
end

function AnkiConnect:query_from_deck(deck)
    local query = '"deck:\\"' .. deck .. '\\""'
    local action = [[
    {"action": "findCards",
    "version": 6,
    "params": {
        "query": ]] .. query .. [[
        }
    }
    ]]
    io.write("WARN stats : curl localhost:8765 -X POST -d ' ", action, "' \n")

    local body, code, headers, status = http.request(endpoint, action)
    return json.decode(body).result
end

function AnkiConnect:review_card(card_id, ease)
    local action = [[
    {
        "action": "answerCards",
        "version": 6,
        "params": {
            "answers": [
                {
                    "cardId": ]] .. card_id .. ' ,"ease": ' .. ease .. [[
                }
            ]
        }
    }

    ]]
    io.write("WARN review, ", action, "\n")

    local body, code, headers, status = http.request(endpoint, action)
    io.write("WARN card_response, ", body, "\n")

    return json.decode(body).result
end

function AnkiConnect:read_card_from_id(card_id)
    local cards = card_id
    local action = [[{
        "action": "cardsInfo",
        "version": 6,
        "params": {
            "cards": []] .. cards .. [[ ]
        }
    }]]

    local body, code, headers, status = http.request(endpoint, action)
    return json.decode(body).result
end

return AnkiConnect
