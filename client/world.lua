-- Applies the server's weather, time and blackout (GlobalState, see server/world.lua).

local W = AdminConfig.World
if not W.Enabled then return end

local current

local function applyWeather(name, instant)
    if not name or name == current then return end
    current = name
    ClearOverrideWeather()
    ClearWeatherTypePersist()
    if instant then
        SetWeatherTypeNow(name)
    else
        SetWeatherTypeOvertimePersist(name, W.Transition)
        Wait(math.floor(W.Transition * 1000))
    end
    SetWeatherTypePersist(name)
    SetWeatherTypeNowPersist(name)
    SetOverrideWeather(name)

    local snow = name == 'XMAS' or name == 'SNOW' or name == 'BLIZZARD' or name == 'SNOWLIGHT'
    SetForceVehicleTrails(snow)
    SetForcePedFootstepsTracks(snow)
end

local function applyTime()
    local t = GlobalState.arcaTime
    if t then NetworkOverrideClockTime(t.h, t.m, 0) end
end

local function applyBlackout()
    SetArtificialLightsState(GlobalState.arcaBlackout == true)
    SetArtificialLightsStateAffectsVehicles(false)
end

AddStateBagChangeHandler('arcaWeather', 'global', function(_, _, value)
    CreateThread(function() applyWeather(value, false) end)
end)
AddStateBagChangeHandler('arcaBlackout', 'global', function()
    applyBlackout()
end)

CreateThread(function()
    applyWeather(GlobalState.arcaWeather, true)
    applyBlackout()
    -- the clock: GTA's own clock drifts, so keep it pinned to the server's
    while true do
        applyTime()
        Wait(1000)
    end
end)
