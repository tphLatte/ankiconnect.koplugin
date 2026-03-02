local http = require("socket.http")
local socket = require("socket")
local socketutil = require("socketutil")
local json = require("rapidjson")
local ssl = require("ssl") -- LuaSec
local ltn12 = require("ltn12")
local forvo = require("forvo")
local logger = require("logger")

io.stdout:setvbuf("line")
-- Enforce a reliable locale for numerical representations
os.setlocale("C", "numeric")

local AnkiConnect = {}

local endpoint = "http://192.168.100.109:8765"
-- "http://192.168.100.109:8765"
function AnkiConnect:init()
    self.endpoint = endpoint
end

function AnkiConnect.with_timeout(timeout, func)
    socketutil:set_timeout(timeout)
    local res = { func() } -- store all values returned by function
    socketutil:reset_timeout()
    return unpack(res)
end

function AnkiConnect:POST(opts)
    local payload = assert(opts.payload, "Missing payload!")
    if type(payload) ~= "string" then
        if opts.api_key then
            payload.key = opts.api_key
        end
        payload = json.encode(payload)
    end
    local headers = {
        ["Content-Type"] = "application/json",
        ["Content-Length"] = #payload,
    }
    local url = assert(opts.url, "Missing URL!")
    local scheme, basic_auth, host = url:match("^(https?://)([^:]+:[^@]+)@(.+)")
    if basic_auth then
        headers["Authorization"] = "Basic " .. forvo.base64e(basic_auth)
        url = scheme .. host
    end
    local sink = {}
    local req = {
        url = url,
        method = "POST",
        headers = headers,
        sink = ltn12.sink.table(sink),
        source = ltn12.source.string(payload),
    }

    logger.dbg("AnkiConnect#POST request:", req)
    local status_code, response_headers, status = self.with_timeout(1, function()
        return socket.skip(1, http.request(req))
    end)
    logger.dbg("AnkiConnect#POST response:", status_code, response_headers, status)

    if type(status_code) == "string" then
        return nil, status_code
    end
    if status_code ~= 200 then
        return nil, string.format("Invalid return code: %s.", status_code)
    end
    local response = json.decode(table.concat(sink))
    local json_err = response.error
    -- this turns a json NULL in a userdata instance, actual error will be a string
    if type(json_err) == "string" then
        return nil, json_err
    end
    return response.result
end

function AnkiConnect:get_decks()
    local anki_connect_request = { action = "deckNamesAndIds", version = 6 }
    return self:POST({ payload = anki_connect_request, url = endpoint })
end

function AnkiConnect:sync()
    local anki_connect_request = { action = "sync", version = 6 }
    return self:POST({ payload = anki_connect_request, url = endpoint })
end

function AnkiConnect:get_stats(decks)
    local deck_names = ""
    for i = 1, #decks do
        deck_names = deck_names .. decks[i]
    end
    local body, code, headers, status =
        http.request(endpoint, '{ "action": "getDeckStats", "version": 6, "params":{ "decks"=[' .. "]} }")

    assert(body ~= nil, "Did not get deck info")
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
    if body == nil then
        error()
    end
    io.write("WARN ", code)
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
    -- io.write("WARN card_response, ", body, "\n")

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

function AnkiConnect:read_cards(cards)
    local anki_connect_request = { action = "cardsInfo", params = { cards = cards }, version = 6 }
    return self:POST({ payload = anki_connect_request, url = endpoint })
end

return AnkiConnect
