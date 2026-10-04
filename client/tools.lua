-- Admin tools that run on the client: noclip, god mode, invisibility, names, blips,
-- spectating, vehicle helpers and what happens to players an admin targets.

local S = AdminState

local function notify(msg, kind) exports.arca_core:Notify(msg, kind or 'inform') end

local function toggleState(key, label)
    S[key] = not S[key]
    notify(('%s %s'):format(label, S[key] and 'on' or 'off'), S[key] and 'success' or 'inform')
    return S[key]
end

---------------------------------------------------------------------
-- Noclip: WASD to fly where the camera looks, Q/E down/up, Shift fast, Alt slow
---------------------------------------------------------------------
local function noclipLoop()
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    local entity = veh ~= 0 and veh or ped
    SetEntityCollision(entity, false, false)
    FreezeEntityPosition(entity, true)
    SetEntityInvincible(entity, true)
    if not S.invisible then SetEntityAlpha(entity, 150, false) end

    while S.noclip do
        local speed = 1.0
        if IsControlPressed(0, 21) then speed = 4.0 elseif IsControlPressed(0, 19) then speed = 0.25 end

        local rot = GetGameplayCamRot(2)
        local pitch, yaw = math.rad(rot.x), math.rad(rot.z)
        local forward = vec3(-math.sin(yaw) * math.cos(pitch), math.cos(yaw) * math.cos(pitch), math.sin(pitch))
        local right = vec3(math.cos(yaw), math.sin(yaw), 0.0)
        local move = vec3(0.0, 0.0, 0.0)

        if IsControlPressed(0, 32) then move = move + forward end          -- W
        if IsControlPressed(0, 33) then move = move - forward end          -- S
        if IsControlPressed(0, 34) then move = move - right end            -- A
        if IsControlPressed(0, 35) then move = move + right end            -- D
        if IsControlPressed(0, 44) then move = move - vec3(0, 0, 1.0) end  -- Q
        if IsControlPressed(0, 38) then move = move + vec3(0, 0, 1.0) end  -- E

        local pos = GetEntityCoords(entity) + move * speed
        SetEntityCoordsNoOffset(entity, pos.x, pos.y, pos.z, true, true, true)
        SetEntityHeading(entity, rot.z)
        DisableControlAction(0, 85, true) -- radio wheel on Q in vehicles
        Wait(0)
    end

    SetEntityCollision(entity, true, true)
    FreezeEntityPosition(entity, false)
    SetEntityInvincible(entity, S.godmode)
    if not S.invisible then ResetEntityAlpha(entity) end
end

---------------------------------------------------------------------
-- God mode / invisible (kept applied in case something resets them)
---------------------------------------------------------------------
CreateThread(function()
    while true do
        if S.godmode or S.invisible then
            local ped = PlayerPedId()
            if S.godmode then
                SetEntityInvincible(ped, true)
                SetPlayerInvincible(PlayerId(), true)
            end
            if S.invisible then SetEntityVisible(ped, false, false) end
        end
        Wait(500)
    end
end)

---------------------------------------------------------------------
-- Names above players' heads
---------------------------------------------------------------------
local function drawText3D(x, y, z, text)
    local onScreen, sx, sy = World3dToScreen2d(x, y, z)
    if not onScreen then return end
    SetTextScale(0.32, 0.32)
    SetTextFont(4)
    SetTextCentre(true)
    SetTextOutline()
    SetTextColour(255, 255, 255, 230)
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(sx, sy)
end

local function namesLoop()
    while S.names do
        local me = GetEntityCoords(PlayerPedId())
        for _, player in ipairs(GetActivePlayers()) do
            local ped = GetPlayerPed(player)
            local c = GetEntityCoords(ped)
            if #(me - c) < 60.0 then
                local talking = NetworkIsPlayerTalking(player) and ' ~g~[talking]' or ''
                drawText3D(c.x, c.y, c.z + 1.1, ('[%d] %s%s'):format(GetPlayerServerId(player), GetPlayerName(player), talking))
            end
        end
        Wait(0)
    end
end

---------------------------------------------------------------------
-- Player blips (positions come from the server so they work map-wide)
---------------------------------------------------------------------
local blips = {}

local function clearBlips()
    for _, blip in pairs(blips) do RemoveBlip(blip) end
    blips = {}
end

RegisterNetEvent('arca_admin:client:blips', function(on)
    S.blips = on
    if not on then clearBlips() end
    notify(('Player blips %s'):format(on and 'on' or 'off'), on and 'success' or 'inform')
end)

RegisterNetEvent('arca_admin:client:blipData', function(list)
    if not S.blips then return end
    local mine, seen = GetPlayerServerId(PlayerId()), {}
    for _, p in ipairs(list) do
        if p.id ~= mine then
            seen[p.id] = true
            local blip = blips[p.id]
            if not blip or not DoesBlipExist(blip) then
                blip = AddBlipForCoord(p.x, p.y, p.z)
                SetBlipScale(blip, 0.8)
                SetBlipColour(blip, 0)
                SetBlipCategory(blip, 7)
                ShowHeadingIndicatorOnBlip(blip, true)
                blips[p.id] = blip
            end
            SetBlipCoords(blip, p.x, p.y, p.z)
            SetBlipSprite(blip, p.veh and 225 or 1)
            SetBlipRotation(blip, math.floor(p.h))
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName(('[%d] %s'):format(p.id, p.name))
            EndTextCommandSetBlipName(blip)
        end
    end
    for id, blip in pairs(blips) do
        if not seen[id] then RemoveBlip(blip) blips[id] = nil end
    end
end)

---------------------------------------------------------------------
-- Spectate
---------------------------------------------------------------------
local spectating -- { id, returnTo }

local function stopSpectate()
    if not spectating then return end
    local ped = PlayerPedId()
    NetworkSetInSpectatorMode(false, ped)
    local r = spectating.returnTo
    spectating = nil
    SetEntityCoords(ped, r.x, r.y, r.z, false, false, false, false)
    FreezeEntityPosition(ped, false)
    SetEntityCollision(ped, true, true)
    if not S.invisible then SetEntityVisible(ped, true, false) end
    exports.arca_core:HideTextUI()
end

RegisterNetEvent('arca_admin:client:spectate', function(id, coords)
    if spectating then return stopSpectate() end
    local ped = PlayerPedId()
    spectating = { id = id, returnTo = GetEntityCoords(ped) }
    SetEntityVisible(ped, false, false)
    SetEntityCollision(ped, false, false)
    FreezeEntityPosition(ped, true)
    -- move close enough that the target streams in, below the ground so nobody sees us
    SetEntityCoords(ped, coords.x, coords.y, coords.z - 15.0, false, false, false, false)

    local timeout = GetGameTimer() + 5000
    local player = GetPlayerFromServerId(id)
    while (player == -1 or not DoesEntityExist(GetPlayerPed(player))) and GetGameTimer() < timeout do
        Wait(100)
        player = GetPlayerFromServerId(id)
    end
    if player == -1 then
        notify('Could not reach that player', 'error')
        return stopSpectate()
    end

    NetworkSetInSpectatorMode(true, GetPlayerPed(player))
    exports.arca_core:ShowTextUI(('Spectating [%d] %s · [Backspace] stop'):format(id, GetPlayerName(player)), { icon = 'fa-solid fa-eye' })
    CreateThread(function()
        while spectating do
            local target = GetPlayerPed(GetPlayerFromServerId(spectating.id))
            if target == 0 or not DoesEntityExist(target) or IsControlJustPressed(0, 177) then
                stopSpectate()
                break
            end
            -- follow under the target so they never stream out
            local c = GetEntityCoords(target)
            SetEntityCoordsNoOffset(PlayerPedId(), c.x, c.y, c.z - 15.0, false, false, false)
            Wait(0)
        end
    end)
end)

---------------------------------------------------------------------
-- Things that happen to the targeted player
---------------------------------------------------------------------
RegisterNetEvent('arca_admin:client:freeze', function(state)
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, state)
    local veh = GetVehiclePedIsIn(ped, false)
    if veh ~= 0 then FreezeEntityPosition(veh, state) end
    notify(state and 'You have been frozen by staff' or 'You have been unfrozen', state and 'warning' or 'inform')
end)

RegisterNetEvent('arca_admin:client:heal', function()
    local ped = PlayerPedId()
    SetEntityHealth(ped, GetEntityMaxHealth(ped))
    ClearPedBloodDamage(ped)
    notify('You have been healed', 'success')
end)

RegisterNetEvent('arca_admin:client:revive', function()
    local ped = PlayerPedId()
    if IsEntityDead(ped) then
        local c, h = GetEntityCoords(ped), GetEntityHeading(ped)
        NetworkResurrectLocalPlayer(c.x, c.y, c.z, h, true, false)
        ped = PlayerPedId()
    end
    SetEntityHealth(ped, GetEntityMaxHealth(ped))
    ClearPedBloodDamage(ped)
    ClearPedTasksImmediately(ped)
    -- death / ambulance scripts listening for the usual events
    TriggerEvent('hospital:client:Revive')
    TriggerEvent('arca_core:client:revived')
    notify('You have been revived', 'success')
end)

RegisterNetEvent('arca_admin:client:kill', function()
    SetEntityHealth(PlayerPedId(), 0)
end)

---------------------------------------------------------------------
-- Vehicle helpers (the admin's current or nearest vehicle)
---------------------------------------------------------------------
local function myVehicle()
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if veh ~= 0 then return veh end
    local pos, best, closest = GetEntityCoords(ped), 6.0, nil
    for _, v in ipairs(GetGamePool('CVehicle')) do
        local d = #(pos - GetEntityCoords(v))
        if d < best then closest, best = v, d end
    end
    if not closest then notify('No vehicle nearby', 'error') end
    return closest
end

local vehicleOps = {
    fixvehicle = function(veh)
        SetVehicleFixed(veh)
        SetVehicleDeformationFixed(veh)
        SetVehicleEngineHealth(veh, 1000.0)
        SetVehicleBodyHealth(veh, 1000.0)
        SetVehiclePetrolTankHealth(veh, 1000.0)
        SetVehicleUndriveable(veh, false)
        return 'Vehicle repaired'
    end,
    cleanvehicle = function(veh)
        SetVehicleDirtLevel(veh, 0.0)
        WashDecalsFromVehicle(veh, 1.0)
        return 'Vehicle cleaned'
    end,
    flipvehicle = function(veh)
        local c = GetEntityCoords(veh)
        SetEntityRotation(veh, 0.0, 0.0, GetEntityHeading(veh), 2, true)
        SetEntityCoords(veh, c.x, c.y, c.z + 1.0, false, false, false, false)
        SetVehicleOnGroundProperly(veh)
        return 'Vehicle flipped'
    end,
    tunevehicle = function(veh)
        SetVehicleModKit(veh, 0)
        for mod = 0, 16 do
            local count = GetNumVehicleMods(veh, mod)
            if count > 0 then SetVehicleMod(veh, mod, count - 1, false) end
        end
        ToggleVehicleMod(veh, 18, true) -- turbo
        ToggleVehicleMod(veh, 22, true) -- xenon
        SetVehicleWindowTint(veh, 1)
        return 'Vehicle fully upgraded'
    end,
    refuelvehicle = function(veh)
        SetVehicleFuelLevel(veh, 100.0)
        Entity(veh).state:set('fuel', 100.0, true)
        return 'Vehicle refuelled'
    end,
}

---------------------------------------------------------------------
-- Self actions (sent back by the server after its permission check)
---------------------------------------------------------------------
RegisterNetEvent('arca_admin:client:self', function(name, data)
    if vehicleOps[name] then
        local veh = myVehicle()
        if veh then
            NetworkRequestControlOfEntity(veh)
            notify(vehicleOps[name](veh), 'success')
        end
    elseif name == 'noclip' then
        if toggleState('noclip', 'Noclip') then CreateThread(noclipLoop) end
    elseif name == 'godmode' then
        if not toggleState('godmode', 'God mode') then
            SetEntityInvincible(PlayerPedId(), false)
            SetPlayerInvincible(PlayerId(), false)
        end
    elseif name == 'invisible' then
        if not toggleState('invisible', 'Invisible') then
            SetEntityVisible(PlayerPedId(), true, false)
        end
    elseif name == 'names' then
        if toggleState('names', 'Player names') then CreateThread(namesLoop) end
    elseif name == 'tpm' then
        TriggerEvent('arca_core:client:tpm')
    elseif name == 'coords' then
        TriggerEvent('arca_core:client:coordsEditor')
    elseif name == 'tpcoords' then
        local x, y, z = tonumber(data.x), tonumber(data.y), tonumber(data.z)
        if x and y and z then TriggerEvent('arca_core:client:teleport', vector3(x, y, z)) end
    end
end)

-- noclip without opening the menu (bind it in GTA settings > FiveM)
RegisterCommand('+arca_noclip', function() TriggerServerEvent('arca_admin:action', 'noclip') end, false)
RegisterCommand('-arca_noclip', function() end, false)
RegisterKeyMapping('+arca_noclip', 'Admin: toggle noclip', 'keyboard', '')

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    clearBlips()
    stopSpectate()
    local ped = PlayerPedId()
    if S.noclip then S.noclip = false SetEntityCollision(ped, true, true) FreezeEntityPosition(ped, false) ResetEntityAlpha(ped) end
    if S.godmode then SetEntityInvincible(ped, false) SetPlayerInvincible(PlayerId(), false) end
    if S.invisible then SetEntityVisible(ped, true, false) end
end)
