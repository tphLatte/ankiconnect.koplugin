local http = require("socket.http")
local json = require("rapidjson")
local ssl = require("ssl") -- LuaSec

io.stdout:setvbuf("line")
-- Enforce a reliable locale for numerical representations
os.setlocale("C", "numeric")

local AnkiConnect = {}

function AnkiConnect:get_decks()
    local body, code, headers, status =
        http.request("http://localhost:8765", '{"action": "deckNamesAndIds", "version": 6}')
    return json.decode(body).result
end

function AnkiConnect:get_stats(decks)
    local deck_names = ""
    for i = 1, #decks do
        deck_names = deck_names .. decks[i]
    end
    local body, code, headers, status = http.request(
        "http://localhost:8765",
        '{ "action": "getDeckStats", "version": 6, "params":{ "decks"=[' .. "]} }"
    )
    io.write("WARN DECK", body)
    return json.decode(body).result
end

function AnkiConnect:get_deck_id(deck_name)
    local action = '{ "action": "deckNamesAndIds", "version": 6 }'
    local body, code, headers, status = http.request("http://localhost:8765", action)
    return json.decode(body).result[deck_name]
end

function AnkiConnect:get_stats_from(deck)
    local deck_names = '"' .. deck .. '"'
    local action = '{ "action": "getDeckStats", "version": 6, "params":{ "decks":[' .. deck_names .. "]} }"
    local body, code, headers, status = http.request("http://localhost:8765", action)

    io.write("WARN DECK", body)
    return json.decode(body).result
end
return AnkiConnect
