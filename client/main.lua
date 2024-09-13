local Config = lib.load('config')
local PlayerVoiceMethod = false
local showingVehicleHUD = false
local showingPlayerHUD = false
local hunger = 100
local thirst = 100
local showingCompass = false

ESX = exports["es_extended"]:getSharedObject()

RegisterNetEvent("esx:playerLoaded", function()
    Wait(2000)
    startHUD()
end)

AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    Wait(500)
    startHUD()
end)

function startHUD()
    local ped = PlayerPedId()
    if not IsPedInAnyVehicle(ped) then
        DisplayRadar(false)
    else
        DisplayRadar(true)
        SendNUIMessage({ action = 'showVehicleHUD' })
    end
    TriggerEvent('hud:client:LoadMap')
    ShowNUI('setVisiblePlayer', true, false)
    showingPlayerHUD = true
end

RegisterNuiCallback('hideFrame', function(data, cb)
    ShowNUI(data.name, false, false)
    cb(true)
end)

ShowNUI = function(action, shouldShow, focus)
    SetNuiFocus(focus, focus)
    SendNUIMessage({ action = action, data = shouldShow })
end

SendNUI = function(action, data)
    SendNUIMessage({ action = action, data = data })
end

RegisterNetEvent('hud:client:LoadMap', function()
    Wait(50)
    local defaultAspectRatio = 1920 / 1080 -- Don't change this.
    local resolutionX, resolutionY = GetActiveScreenResolution()
    local aspectRatio = resolutionX / resolutionY
    local minimapOffset = 0
    if aspectRatio > defaultAspectRatio then minimapOffset = ((defaultAspectRatio - aspectRatio) / 3.6) - 0.008 end
    RequestStreamedTextureDict("squaremap", false)
    if not HasStreamedTextureDictLoaded("squaremap") then Wait(150) end
    SetMinimapClipType(0)
    AddReplaceTexture("platform:/textures/graphics", "radarmasksm", "squaremap", "radarmasksm")
    AddReplaceTexture("platform:/textures/graphics", "radarmask1g", "squaremap", "radarmasksm")

    -- Minimap main symbol and icons
    -- 0.0 = nav symbol and icons left
    -- 0.1638 = nav symbol and icons stretched
    -- 0.216 = nav symbol and icons raised up
    SetMinimapComponentPosition("minimap", "L", "B", -0.006 + minimapOffset, -0.040, 0.1638, 0.183)

    -- Icons within the minimap
    SetMinimapComponentPosition("minimap_mask", "L", "B", 0.0 + minimapOffset, 0.0, 0.128, 0.20)

    -- Minimap blur effect
    -- -0.015 = map pulled left
    -- 0.030 = map raised up
    -- 0.262 = map stretched
    -- 0.300 = map shortened
    SetMinimapComponentPosition('minimap_blur', 'L', 'B', -0.015 + minimapOffset, 0.030, 0.262, 0.300)
    SetBlipAlpha(GetNorthRadarBlip(), 0)
    SetRadarBigmapEnabled(true, false)
    SetMinimapClipType(0)
    Wait(50)
    SetRadarBigmapEnabled(false, false)
    SetRadarZoom(1000)
end)

AddEventHandler("pma-voice:radioActive", function(radioTalking)
    PlayerVoiceMethod = radioTalking and 'radio' or false
end)

local getPlayerVoiceMethod = function(player)
    if PlayerVoiceMethod ~= "radio" then
        if MumbleIsPlayerTalking(player) then
            PlayerVoiceMethod = "voice"
            return PlayerVoiceMethod
        else
            PlayerVoiceMethod = false
            return PlayerVoiceMethod
        end
    end
    return PlayerVoiceMethod
end

local getHeadingText = function(heading)
    if ((heading >= 0 and heading < 30) or (heading >= 330 and heading < 360)) then
        return 'N'
    elseif (heading >= 30 and heading < 60) then
        return 'NW'
    elseif (heading >= 60 and heading < 120) then
        return 'W'
    elseif (heading >= 120 and heading < 160) then
        return 'SW'
    elseif (heading >= 160 and heading < 210) then
        return 'S'
    elseif (heading >= 210 and heading < 240) then
        return 'SE'
    elseif (heading >= 240 and heading < 310) then
        return 'E'
    elseif (heading >= 310 and heading < 330) then
        return 'NE'
    end
end

local lastCrossroadUpdate = 0
local lastCrossroadCheck = {}
local getCrossroads = function(vehicle)
    local updateTick = GetGameTimer()
    if updateTick - lastCrossroadUpdate > 1500 then
        local pos = GetEntityCoords(vehicle)
        local street1, street2 = GetStreetNameAtCoord(pos.x, pos.y, pos.z)
        lastCrossroadUpdate = updateTick
        lastCrossroadCheck = { GetStreetNameFromHashKey(street1), GetStreetNameFromHashKey(street2) }
    end
    return lastCrossroadCheck
end

CreateThread(function()
    while true do
        if not IsPauseMenuActive() and ESX.IsPlayerLoaded() then
            if not showingPlayerHUD then
                DisplayRadar(false)
                ShowNUI('setVisiblePlayer', true, false)
                showingPlayerHUD = true
            end
            TriggerEvent('esx_status:getStatus', 'hunger', function(status) hunger = status.getPercent() end)
            TriggerEvent('esx_status:getStatus', 'thirst', function(status) thirst = status.getPercent() end)
            SendNUI('player', {
                health = (GetEntityHealth(cache.ped) - 100),
                armor = GetPedArmour(cache.ped),
                thirst = thirst,
                hunger = hunger,
                voice = LocalPlayer.state['proximity'].distance,
                talking = getPlayerVoiceMethod(cache.playerId),
                colors = Config.colors,
                engine = (cache.vehicle and GetIsVehicleEngineRunning(cache.vehicle)) and
                    math.ceil(GetVehicleEngineHealth(cache.vehicle) / 10) or false,
                fuel = (cache.vehicle and GetIsVehicleEngineRunning(cache.vehicle)) and
                    math.ceil(GetVehicleFuelLevel(cache.vehicle)) or false,
            })
            if cache.vehicle and GetIsVehicleEngineRunning(cache.vehicle) then
                DisplayRadar(true)
                if not showingVehicleHUD then
                    ShowNUI('setVisibleVehicle', true, false)
                    TriggerEvent('hud:client:LoadMap')
                    showingVehicleHUD = true
                end
                ShowNUI('setVisibleVehicle', true, false)
                SendNUI('vehicle', {
                    speed = math.ceil(GetEntitySpeed(cache.vehicle) * (Config.speedType == 'kmh' and 3.6 or 2.23694)),
                    gear = GetVehicleCurrentGear(cache.vehicle),
                    speedType = Config.speedType,
                    engine = (cache.vehicle and GetIsVehicleEngineRunning(cache.vehicle)) and
                        math.ceil(GetVehicleEngineHealth(cache.vehicle) / 10) or false,
                    fuel = (cache.vehicle and GetIsVehicleEngineRunning(cache.vehicle)) and
                        math.ceil(GetVehicleFuelLevel(cache.vehicle)) or false,
                })
                local crossroads = getCrossroads(cache.vehicle)
                if not showingCompass then
                    ShowNUI('setVisibleCompass', true, false)
                    showingCompass = true
                end
                SendNUI('compass', {
                    heading = getHeadingText(GetEntityHeading(cache.vehicle)),
                    street1 = crossroads[1],
                    street2 = crossroads[2]
                })
                Wait(300)
            else
                if showingCompass then
                    ShowNUI('setVisibleCompass', false, false)
                    showingCompass = false
                end
                if showingVehicleHUD then
                    DisplayRadar(false)
                    ShowNUI('setVisibleVehicle', false, false)
                    showingVehicleHUD = false
                end
                Wait(300)
            end
        else
            if showingPlayerHUD then
                ShowNUI('setVisiblePlayer', false, false)
                showingPlayerHUD = false
            end
            Wait(500)
        end
    end
end)
