-- Weather & time, synced to every client through GlobalState.

local W = AdminConfig.World
if not W.Enabled then return end

local function validWeather(name)
    for _, t in ipairs(W.Types) do
        if t == name then return true end
    end
end

GlobalState.arcaWeather = GlobalState.arcaWeather or W.Weather
GlobalState.arcaTime = GlobalState.arcaTime or { h = W.Hour, m = W.Minute }
GlobalState.arcaFreezeTime = GlobalState.arcaFreezeTime or false
GlobalState.arcaBlackout = GlobalState.arcaBlackout or false

function AdminWorldState()
    return {
        weather = GlobalState.arcaWeather, time = GlobalState.arcaTime,
        freeze = GlobalState.arcaFreezeTime, blackout = GlobalState.arcaBlackout,
    }
end

-- the server clock
CreateThread(function()
    while true do
        Wait(W.MinuteLength)
        if not GlobalState.arcaFreezeTime then
            local t = GlobalState.arcaTime
            local m, h = t.m + 1, t.h
            if m >= 60 then m, h = 0, (h + 1) % 24 end
            GlobalState.arcaTime = { h = h, m = m }
        end
    end
end)

AdminActions.weather = function(src, data)
    local name = tostring(data.weather or ''):upper()
    if not validWeather(name) then return AdminNotify(src, 'Unknown weather type', 'error') end
    GlobalState.arcaWeather = name
    AdminNotify(src, ('Weather set to %s'):format(name), 'success')
end

AdminActions.time = function(src, data)
    local h, m = math.floor(tonumber(data.hour) or -1), math.floor(tonumber(data.minute) or 0)
    if h < 0 or h > 23 or m < 0 or m > 59 then return AdminNotify(src, 'Invalid time', 'error') end
    GlobalState.arcaTime = { h = h, m = m }
    AdminNotify(src, ('Time set to %02d:%02d'):format(h, m), 'success')
end

AdminActions.freezetime = function(src)
    GlobalState.arcaFreezeTime = not GlobalState.arcaFreezeTime
    AdminNotify(src, GlobalState.arcaFreezeTime and 'Time frozen' or 'Time running', 'success')
end

AdminActions.blackout = function(src)
    GlobalState.arcaBlackout = not GlobalState.arcaBlackout
    AdminNotify(src, GlobalState.arcaBlackout and 'Blackout on' or 'Blackout off', 'success')
end

exports('SetWeather', function(name) if validWeather(name) then GlobalState.arcaWeather = name return true end end)
exports('SetTime', function(h, m) GlobalState.arcaTime = { h = h, m = m or 0 } end)
exports('GetWorld', AdminWorldState)
