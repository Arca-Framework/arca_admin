-- The /admin NUI: opening, data refresh and passing button presses to the server.

local isOpen = false
AdminState = { noclip = false, godmode = false, invisible = false, names = false, blips = false }

local function close()
    if not isOpen then return end
    isOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end
AdminCloseMenu = close
RegisterNetEvent('arca_admin:client:closeMenu', close)

local function refresh(full)
    local data = Arca.Callback.Await('arca_admin:data', full)
    if not data or not isOpen then return end
    data.state = AdminState
    SendNUIMessage({ action = 'data', data = data })
end

RegisterNetEvent('arca_admin:client:open', function(info)
    if isOpen then return close() end
    isOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', data = info })
    refresh(true)
    -- live player list while the menu is open
    CreateThread(function()
        while isOpen do
            Wait(3000)
            if isOpen then refresh(false) end
        end
    end)
end)

if AdminConfig.Key then
    RegisterCommand('+arca_admin', function() TriggerServerEvent('arca_admin:open') end, false)
    RegisterCommand('-arca_admin', function() end, false)
    RegisterKeyMapping('+arca_admin', 'Open admin menu', 'keyboard', AdminConfig.Key)
end

---------------------------------------------------------------------
-- NUI callbacks
---------------------------------------------------------------------
RegisterNUICallback('close', function(_, cb)
    close()
    cb(1)
end)

RegisterNUICallback('refresh', function(_, cb)
    cb(1)
    refresh(false)
end)

-- actions that need the game view close the menu first
local closesMenu = {
    tpto = true, bring = false, spectate = true, noclip = true, tpm = true, coords = true,
    tpcoords = true, openinventory = true, spawnvehicle = true,
}

RegisterNUICallback('action', function(req, cb)
    cb(1)
    if type(req) ~= 'table' or type(req.action) ~= 'string' then return end
    if closesMenu[req.action] then close() end
    TriggerServerEvent('arca_admin:action', req.action, req.data or {})
    -- let the server apply it, then show the new state
    SetTimeout(400, function() if isOpen then refresh(false) end end)
end)

RegisterNUICallback('copy', function(req, cb)
    cb(1)
    TriggerEvent('arca_core:client:copyCoords', req.kind)
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() and isOpen then SetNuiFocus(false, false) end
end)
