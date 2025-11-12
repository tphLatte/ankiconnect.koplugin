local http = require("socket.http")
local json = require("rapidjson")
local ssl = require("ssl") -- LuaSec

local AnkiConnect = {}

function AnkiConnect:get_decks()
    local body, code, headers, status = http.request("http://localhost:8765", '{"action": "deckNames", "version": 6}')
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
    return json.decode(body).result
end

function AnkiConnect:get_stats_from(deck)
    local deck_names = '"' .. deck .. '"'
    local action = '{ "action": "getDeckStats", "version": 6, "params":{ "decks":[' .. deck_names .. "]} }"
    local body, code, headers, status = http.request("http://localhost:8765", action)
    return json.decode(body).result
end

print(AnkiConnect:get_decks())
print(AnkiConnect:get_stats_from("Vocabulary"))

return AnkiConnect
