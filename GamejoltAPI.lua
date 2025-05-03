-- Documentation: https://gamejolt.com/game-api/doc

local gamejolt = {}

local md5 = require("Scripts.Libraries.Utils.MD5")
local json = require("Scripts.Libraries.Utils.dkjson")
local http = require("socket.http")
local ltn12 = require("ltn12")

-- Generates a signature for the GameJolt API request by hashing the input with MD5.
local function generate_signature(request_path)
    local input = gamejolt.base_url .. request_path .. gamejolt.private_key
    return md5.sumhexa(input)
end

-- Sends an HTTP request to the GameJolt API and returns the response or error message.
local function api_request(url)
    local response_body = {}
    local res, code, headers = http.request{
        url = url,
        sink = ltn12.sink.table(response_body)
    }

    if (code ~= 200) then
        return false, "HTTP error: "..tostring(code)
    end

    local response = table.concat(response_body)
    local data, pos, err = json.decode(response)
    if (not data) then
        return false, "JSON decode error: "..tostring(err).."\nResponse: "..tostring(response)
    end

    if (data.response and data.response.success == "false") then
        return false, data.response.message or "API error"
    end

    return data.response
end

-- Initializes the GameJolt API with the provided app ID and private key.
function gamejolt.init(app_id, private_key)
    gamejolt.app_id = app_id
    gamejolt.private_key = private_key
    gamejolt.base_url = "https://api.gamejolt.com/api/game/v1_2"
    return (gamejolt.app_id ~= nil and gamejolt.private_key ~= nil)
end

-- Authenticates a user with their username and token against the GameJolt API.
-- Syntax: /users/?game_id=xxxxx&username=test&user_token=test
function gamejolt.auth_user(username, user_token)
    gamejolt.username = username
    gamejolt.user_token = user_token
    local url = gamejolt.base_url .. "/users/auth/?game_id=" .. gamejolt.app_id ..
                "&username=" .. username .. "&user_token=" .. user_token ..
                "&signature=" .. generate_signature("/users/auth/?game_id=" .. gamejolt.app_id ..
                                                  "&username=" .. username .. "&user_token=" .. user_token)

    local success, err = api_request(url)
    return success ~= false, err
end

-- Fetches achievements (trophies) from the GameJolt API. If achieved_only is true, only achieved trophies are returned.
-- Syntax: /trophies/?game_id=xxxxx&username=test&user_token=test&achieved=true
function gamejolt.fetch_achievements(achieved_only)
    local url = gamejolt.base_url .. "/trophies/?game_id=" .. gamejolt.app_id ..
                "&username=" .. gamejolt.username .. "&user_token=" .. gamejolt.user_token ..
                (achieved_only and "&achieved=true" or "") ..
                "&signature=" .. generate_signature("/trophies/?game_id=" .. gamejolt.app_id ..
                                                  "&username=" .. gamejolt.username ..
                                                  "&user_token=" .. gamejolt.user_token ..
                                                  (achieved_only and "&achieved=true" or ""))

    return api_request(url)
end

-- Unlocks an achievement (trophy) in the GameJolt API using the trophy ID.
-- Syntax: /trophies/add-achieved/?game_id=xxxxx&username=myusername&user_token=mytoken&trophy_id=1047
function gamejolt.unlock_achievement(trophy_id)
    local endpoint = "/trophies/add-achieved/"
    local base_params = "?game_id=" .. gamejolt.app_id ..
                       "&username=" .. gamejolt.username ..
                       "&user_token=" .. gamejolt.user_token ..
                       "&trophy_id=" .. trophy_id

    local url = gamejolt.base_url .. endpoint .. base_params ..
                "&signature=" .. generate_signature(endpoint .. base_params)

    local result, err = api_request(url)
    if result then
        return true
    end
end

-- Opens a session for the authenticated user in the GameJolt API.
-- Syntax: /sessions/open/?game_id=xxxxx&username=myusername&user_token=mytoken
function gamejolt.session_open()
    local url = gamejolt.base_url .. "/sessions/open/?game_id=" .. gamejolt.app_id ..
                "&username=" .. gamejolt.username .. "&user_token=" .. gamejolt.user_token ..
                "&signature=" .. generate_signature("/sessions/open/?game_id=" .. gamejolt.app_id ..
                                                  "&username=" .. gamejolt.username ..
                                                  "&user_token=" .. gamejolt.user_token)
    return api_request(url)
end

-- Pings the current session to keep it active or update its status.
-- Syntax: /sessions/ping/?game_id=xxxxx&username=myusername&user_token=mytoken&status=active
function gamejolt.session_ping(status)
    local url = gamejolt.base_url .. "/sessions/ping/?game_id=" .. gamejolt.app_id ..
                "&username=" .. gamejolt.username .. "&user_token=" .. gamejolt.user_token ..
                "&status=" .. (status or "active") ..
                "&signature=" .. generate_signature("/sessions/ping/?game_id=" .. gamejolt.app_id ..
                                                  "&username=" .. gamejolt.username ..
                                                  "&user_token=" .. gamejolt.user_token ..
                                                  "&status=" .. (status or "active"))
    return api_request(url)
end

-- Closes the current session for the authenticated user in the GameJolt API.
-- Syntax: /sessions/close/?game_id=xxxxx&username=myusername&user_token=mytoken
function gamejolt.session_close()
    local url = gamejolt.base_url .. "/sessions/close/?game_id=" .. gamejolt.app_id ..
                "&username=" .. gamejolt.username .. "&user_token=" .. gamejolt.user_token ..
                "&signature=" .. generate_signature("/sessions/close/?game_id=" .. gamejolt.app_id ..
                                                  "&username=" .. gamejolt.username ..
                                                  "&user_token=" .. gamejolt.user_token)
    return api_request(url)
end

-- Stores data in the GameJolt Data Store under the specified key.
-- Syntax: /data-store/set/?game_id=xxxxx&key=test&data=test&username=myusername&user_token=mytoken
function gamejolt.data_store(key, data, user_data)
    local url = gamejolt.base_url .. "/data-store/set/?game_id=" .. gamejolt.app_id ..
                "&key=" .. key .. "&data=" .. data ..
                (user_data and ("&username=" .. gamejolt.username .. "&user_token=" .. gamejolt.user_token) or "") ..
                "&signature=" .. generate_signature("/data-store/set/?game_id=" .. gamejolt.app_id ..
                                                  "&key=" .. key .. "&data=" .. data ..
                                                  (user_data and ("&username=" .. gamejolt.username ..
                                                   "&user_token=" .. gamejolt.user_token) or ""))
    return api_request(url)
end

-- Fetches data from the GameJolt Data Store using the specified key.
-- Syntax: /data-store/?game_id=xxxxx&key=test&username=myusername&user_token=mytoken
function gamejolt.data_fetch(key, user_data)
    local url = gamejolt.base_url .. "/data-store/?game_id=" .. gamejolt.app_id ..
                "&key=" .. key ..
                (user_data and ("&username=" .. gamejolt.username .. "&user_token=" .. gamejolt.user_token) or "") ..
                "&signature=" .. generate_signature("/data-store/?game_id=" .. gamejolt.app_id ..
                                                  "&key=" .. key ..
                                                  (user_data and ("&username=" .. gamejolt.username ..
                                                   "&user_token=" .. gamejolt.user_token) or ""))
    return api_request(url)
end

return gamejolt