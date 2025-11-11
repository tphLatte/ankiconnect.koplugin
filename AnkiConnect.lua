local http = require("socket.http")
local json = require("rapidjson")
local ssl = require("ssl") -- LuaSec

local AnkiConnect = {}

function AnkiConnect:get_decks()
    local body, code, headers, status = http.request("http://localhost:8765", '{"action": "deckNames", "version": 6}')
    return json.decode(body).result
end
print(AnkiConnect:get_decks())

return AnkiConnect
