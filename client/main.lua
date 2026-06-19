-- Ensure Locales is available (lua54 global scope fix)
if not Locales then Locales = {} end

local PHONE_RESOURCE = 'qs-smartphone'
local ui = 'https://cfx-nui-' .. string.lower(GetCurrentResourceName()) .. '/ui/build/'
local APP_ID = 'negocios_gta'

-- Local Cache for Blips
local blips = {}

-- GTA sprite and colour helpers
local function createOrUpdateBlip(biz)
    -- Remove old blip if exists
    if blips[biz.id] then
        RemoveBlip(blips[biz.id])
        blips[biz.id] = nil
    end

    -- Check if we should hide closed blips
    local isBizOpen = (biz.isOpen == true or biz.isOpen == 1 or biz.isOpen == "true" or biz.isOpen == "1")
    if Config.Blips and Config.Blips.HideWhenClosed and not isBizOpen then
        return
    end

    -- Create new blip
    local blip = AddBlipForCoord(biz.x + 0.0, biz.y + 0.0, 0.0)

    -- Sprite mapping based on config
    local catConfig = Config.Categories[biz.category] or Config.Categories['otro']
    local sprite = catConfig and catConfig.blipId or 66
    if biz.blipId and biz.blipId > 0 then
        sprite = biz.blipId
    end

    SetBlipSprite(blip, sprite)

    -- Color based on config
    local color = Config.Blips.ColorCerrado
    if biz.isOpen == true or biz.isOpen == 1 or biz.isOpen == "true" or biz.isOpen == "1" then
        color = Config.Blips.ColorAbierto
    end
    SetBlipColour(blip, color)

    SetBlipDisplay(blip, 4) -- Show on both minimap and large map
    SetBlipScale(blip, Config.Blips.Escala or 0.8)
    SetBlipAsShortRange(blip, true)

    -- Blip label
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(biz.name .. (biz.isOpen and " (Abierto)" or " (Cerrado)"))
    EndTextCommandSetBlipName(blip)

    blips[biz.id] = blip
end

local function removeBlip(id)
    if blips[id] then
        RemoveBlip(blips[id])
        blips[id] = nil
    end
end

local function syncAllBlips(businesses)
    for id, blip in pairs(blips) do
        RemoveBlip(blip)
    end
    blips = {}

    for _, biz in ipairs(businesses) do
        createOrUpdateBlip(biz)
    end
end

local function ShowNotification(title, msg, typeData, iconImage)
    local notiType = Config.Notifications and Config.Notifications.Type or 'ox_lib'
    
    local finalIcon = iconImage
    local resourceName = string.lower(GetCurrentResourceName())
    if not finalIcon or finalIcon == "" then
        finalIcon = 'https://cfx-nui-' .. resourceName .. '/ui/build/icon.png'
    elseif not string.find(finalIcon, "^http") then
        if string.find(finalIcon, "^%./") then
            finalIcon = 'https://cfx-nui-' .. resourceName .. '/' .. string.sub(finalIcon, 3)
        elseif string.find(finalIcon, "^/") then
            finalIcon = 'https://cfx-nui-' .. resourceName .. finalIcon
        else
            finalIcon = 'https://cfx-nui-' .. resourceName .. '/ui/build/icon.png'
        end
    end
    
    if notiType == 'ox_lib' and GetResourceState('ox_lib') == 'started' then
        exports.ox_lib:notify({
            title = title,
            description = msg,
            type = typeData or 'info',
            icon = 'bell'
        })
    elseif notiType == 'phone' and GetResourceState('qs-smartphone') == 'started' then
        -- Trigger server event to send the official phone notification via server-side export
        TriggerServerEvent('negocios_gta:server:sendPhoneNotification', title, msg, finalIcon)
    elseif notiType == 'custom' then
        SendNUIMessage({
            action = 'showCustomNotification',
            name = title,
            logo = finalIcon,
            description = msg,
            status = (typeData == 'success'),
            duration = 6000
        })
    else
        BeginTextCommandThefeedPost("STRING")
        AddTextComponentSubstringPlayerName("~g~" .. title .. ": ~w~" .. msg)
        EndTextCommandThefeedPostTicker(false, true)
    end
end

-- --- Standalone Client-Server Callback System ---
local currentRequestId = 0
local serverCallbacks = {}

local function triggerServerCallback(name, cb, ...)
    currentRequestId = currentRequestId + 1
    serverCallbacks[currentRequestId] = cb
    TriggerServerEvent('negocios_gta:server:triggerCallback', name, currentRequestId, ...)
end

RegisterNetEvent('negocios_gta:client:serverCallback')
AddEventHandler('negocios_gta:client:serverCallback', function(requestId, ...)
    if serverCallbacks[requestId] then
        serverCallbacks[requestId](...)
        serverCallbacks[requestId] = nil
    end
end)

-- --- NUI Callbacks ---
RegisterNUICallback('negocios_gta:getData', function(data, cb)
    -- print("[negocios_gta] client: negocios_gta:getData triggered, fetching from server...")
    triggerServerCallback('negocios_gta:server:getData', function(dbData)
        local dataToSend = dbData or { businesses = {}, reviews = {}, events = {} }
        
        local localeData = {}
        if Locales and Config and Locales[Config.Language] then
            for k, v in pairs(Locales[Config.Language]) do
                localeData[tostring(k)] = tostring(v)
            end
        elseif Locales and Locales['en'] then
            for k, v in pairs(Locales['en']) do
                localeData[tostring(k)] = tostring(v)
            end
        else
            localeData['app_title'] = "ERROR LUA LOCALES IS NIL"
        end
        dataToSend.locale = localeData
        dataToSend.categories = Config.Categories or {}
        -- Ensure admin info is in the response for React refreshData
        dataToSend.isAdmin = (dbData and dbData.isAdmin == true) or false
        dataToSend.hideClosedBlips = Config.Blips and Config.Blips.HideWhenClosed or false
        dataToSend.playerJob = dbData and dbData.playerJob or ''
        dataToSend.availableJobs = dbData and dbData.availableJobs or {}
        dataToSend.myReviewIds = dbData and dbData.myReviewIds or {}
        
        cb(dataToSend)
        
        -- Also send via NUI message for the event listener
        SendNUIMessage({
            action = 'setAdmin',
            isAdmin = dataToSend.isAdmin,
            playerJob = dataToSend.playerJob,
            availableJobs = dataToSend.availableJobs
        })
    end)
end)

RegisterNUICallback('negocios_gta:saveBusinessToServer', function(data, cb)
    TriggerServerEvent('negocios_gta:server:saveBusiness', data)
    cb('ok')
end)

RegisterNUICallback('negocios_gta:deleteBusinessFromServer', function(data, cb)
    TriggerServerEvent('negocios_gta:server:deleteBusiness', data.id)
    cb('ok')
end)

RegisterNUICallback('negocios_gta:toggleBusinessOnServer', function(data, cb)
    TriggerServerEvent('negocios_gta:server:toggleBusiness', data.id)
    cb('ok')
end)

RegisterNUICallback('negocios_gta:sendBusinessAnnouncement', function(data, cb)
    if data and data.id and data.message then
        TriggerServerEvent('negocios_gta:server:sendBusinessAnnouncement', data.id, data.message)
    end
    cb('ok')
end)

RegisterNUICallback('negocios_gta:addReviewToServer', function(data, cb)
    triggerServerCallback('negocios_gta:server:addReview', function(result)
        cb(result or { ok = false, error = 'unknown' })
    end, data)
end)

RegisterNUICallback('negocios_gta:deleteReviewFromServer', function(data, cb)
    TriggerServerEvent('negocios_gta:server:deleteReview', data.id)
    cb('ok')
end)

RegisterNUICallback('negocios_gta:updateReviewOnServer', function(data, cb)
    TriggerServerEvent('negocios_gta:server:updateReview', data)
    cb('ok')
end)

RegisterNUICallback('negocios_gta:addEventToServer', function(data, cb)
    TriggerServerEvent('negocios_gta:server:addEvent', data)
    cb('ok')
end)

RegisterNUICallback('negocios_gta:updateEventToServer', function(data, cb)
    TriggerServerEvent('negocios_gta:server:updateEvent', data)
    cb('ok')
end)

RegisterNUICallback('negocios_gta:deleteEventFromServer', function(data, cb)
    TriggerServerEvent('negocios_gta:server:deleteEvent', data.id)
    cb('ok')
end)

RegisterNUICallback('negocios_gta:toggleEvent', function(data, cb)
    TriggerServerEvent('negocios_gta:server:toggleEvent', data.id)
    cb('ok')
end)

RegisterNUICallback('negocios_gta:getPlayerLocation', function(data, cb)
    local playerPed = PlayerPedId()
    local coords = GetEntityCoords(playerPed)
    local streetHash = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
    local streetName = GetStreetNameFromHashKey(streetHash)
    cb({ 
        location = (streetName and streetName ~= "") and streetName or 'Ubicación actual',
        x = coords.x,
        y = coords.y
    })
end)

RegisterNUICallback('negocios_gta:setWaypoint', function(data, cb)
    if data and data.x and data.y then
        SetNewWaypoint(data.x + 0.0, data.y + 0.0)
    end
    cb('ok')
end)

local inputFocused = false

RegisterNUICallback('negocios_gta:focusInput', function(data, cb)
    inputFocused = data.focused
    SetNuiFocusKeepInput(not data.focused)
    cb('ok')
end)

RegisterNUICallback('negocios_gta:playSound', function(data, cb)
    if data and data.name and data.dict then
        PlaySoundFrontend(-1, data.name, data.dict, true)
    end
    cb('ok')
end)

CreateThread(function()
    while true do
        if inputFocused then
            -- Disable movement & interaction controls to prevent key registration in game
            DisableControlAction(0, 30, true) -- Move LR (A/D)
            DisableControlAction(0, 31, true) -- Move UD (W/S)
            DisableControlAction(0, 32, true) -- Move W
            DisableControlAction(0, 33, true) -- Move S
            DisableControlAction(0, 34, true) -- Move A
            DisableControlAction(0, 35, true) -- Move D
            DisableControlAction(0, 23, true) -- Enter vehicle (F)
            DisableControlAction(0, 75, true) -- Exit vehicle (F)
            DisableControlAction(0, 22, true) -- Jump (Space)
            DisableControlAction(0, 44, true) -- Cover (Q)
            DisableControlAction(0, 37, true) -- Weapon wheel (Tab)
            DisableControlAction(0, 245, true) -- Chat (T)
            DisableControlAction(0, 288, true) -- Phone (F1)
            DisableControlAction(0, 289, true) -- Inventory (F2)
            DisableControlAction(0, 170, true) -- F3
            DisableControlAction(0, 166, true) -- F5
            DisableControlAction(0, 167, true) -- F6
            DisableControlAction(0, 168, true) -- F7
            DisableControlAction(0, 56, true) -- F9
            DisableControlAction(0, 57, true) -- F10
            DisableControlAction(0, 244, true) -- M
            DisableControlAction(0, 71, true) -- Veh Throttle (W)
            DisableControlAction(0, 72, true) -- Veh Brake (S)
            DisableControlAction(0, 59, true) -- Veh Steer LR (A/D)
            DisableControlAction(0, 60, true) -- Veh Steer UD
            DisableControlAction(0, 76, true) -- Veh Handbrake (Space)
        end
        if inputFocused then
            Wait(0)
        else
            Wait(250)
        end
    end
end)

RegisterNUICallback('negocios_gta:addBlip', function(data, cb)
    createOrUpdateBlip(data)
    cb('ok')
end)

RegisterNUICallback('negocios_gta:removeBlip', function(data, cb)
    removeBlip(data.id)
    cb('ok')
end)

RegisterNUICallback('negocios_gta:updateBlip', function(data, cb)
    createOrUpdateBlip(data)
    cb('ok')
end)

RegisterNUICallback('negocios_gta:syncBlips', function(data, cb)
    syncAllBlips(data)
    cb('ok')
end)

RegisterNUICallback('negocios_gta:setWaypoint', function(data, cb)
    if data and data.x and data.y then
        SetNewWaypoint(data.x + 0.0, data.y + 0.0)
        local L = Locales[Config.Language] or Locales['en']
        ShowNotification(L.notif_success, string.format(L.notif_gps_set, data.name or 'el negocio'), 'success', 'location-dot')
    end
    cb('ok')
end)

RegisterNUICallback('negocios_gta:getPlayerCoords', function(data, cb)
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    cb({ x = coords.x, y = coords.y, z = coords.z })
end)

-- --- Server Sync Event Receiver ---
RegisterNUICallback('negocios_gta:setMuteNotifications', function(data, cb)
    local isMuted = data.muted
    SetResourceKvp("negocios_gta_muted", tostring(isMuted))
    TriggerServerEvent('negocios_gta:server:setMuted', isMuted)
    cb('ok')
end)

RegisterNetEvent('negocios_gta:client:syncData')
AddEventHandler('negocios_gta:client:syncData', function(businesses, reviews, events)
    syncAllBlips(businesses)
    SendNUIMessage({
        app = APP_ID,
        action = 'syncData',
        businesses = businesses,
        reviews = reviews,
        events = events
    })
end)

-- --- Granular Sync Events ---
RegisterNetEvent('negocios_gta:client:syncSingleBusiness')
AddEventHandler('negocios_gta:client:syncSingleBusiness', function(business)
    createOrUpdateBlip(business)
    SendNUIMessage({
        app = APP_ID,
        action = 'syncSingleBusiness',
        business = business
    })
end)

RegisterNetEvent('negocios_gta:client:syncToggleBusiness')
AddEventHandler('negocios_gta:client:syncToggleBusiness', function(id, isOpen, bizName, bizImage, bizDesc)
    -- Update blip color
    if blips[id] then
        SetBlipColour(blips[id], isOpen and 2 or 0)
    end
    
    if Config.Notifications and (Config.Notifications.NotifyOnToggle or Config.Notifications.NotifyOnOpen) then
        if Config.Notifications.Type ~= 'phone' then
            local isMuted = GetResourceKvpString("negocios_gta_muted")
            if isMuted ~= "true" then
                local statusText = isOpen and "🟢 ¡ABIERTO!" or "🔴 ¡CERRADO!"
                local cleanDesc = bizDesc or ''
                if string.len(cleanDesc) > 80 then
                    cleanDesc = string.sub(cleanDesc, 1, 77) .. "..."
                end
                
                local msg = string.format("%s - %s", statusText, cleanDesc)
                
                -- If it's a closed event, only notify if NotifyOnToggle is enabled. Always notify on open if NotifyOnOpen is enabled.
                if isOpen or Config.Notifications.NotifyOnToggle then
                    ShowNotification(bizName or 'Negocio', msg, isOpen and 'success' or 'error', bizImage)
                end
            end
        end
    end
    
    SendNUIMessage({
        app = APP_ID,
        action = 'syncToggleBusiness',
        id = id,
        isOpen = isOpen
    })
end)

RegisterNetEvent('negocios_gta:client:sendAnnouncementBroadcast')
AddEventHandler('negocios_gta:client:sendAnnouncementBroadcast', function(title, message, icon)
    local isMuted = GetResourceKvpString("negocios_gta_muted")
    if isMuted ~= "true" then
        ShowNotification(title, message, 'info', icon)
    end
end)

RegisterNetEvent('negocios_gta:client:syncNewReview')
AddEventHandler('negocios_gta:client:syncNewReview', function(review)
    SendNUIMessage({
        app = APP_ID,
        action = 'syncNewReview',
        review = review
    })
end)

RegisterNetEvent('negocios_gta:client:syncDeleteReview')
AddEventHandler('negocios_gta:client:syncDeleteReview', function(reviewId)
    SendNUIMessage({
        app = APP_ID,
        action = 'syncDeleteReview',
        id = reviewId
    })
end)

RegisterNetEvent('negocios_gta:client:syncUpdateReview')
AddEventHandler('negocios_gta:client:syncUpdateReview', function(review)
    SendNUIMessage({
        app = APP_ID,
        action = 'syncUpdateReview',
        review = review
    })
end)

RegisterNetEvent('negocios_gta:client:syncNewEvent')
AddEventHandler('negocios_gta:client:syncNewEvent', function(event)
    SendNUIMessage({
        app = APP_ID,
        action = 'syncNewEvent',
        event = event
    })
end)

RegisterNetEvent('negocios_gta:client:syncUpdateEvent')
AddEventHandler('negocios_gta:client:syncUpdateEvent', function(event)
    SendNUIMessage({
        app = APP_ID,
        action = 'syncUpdateEvent',
        event = event
    })
end)

RegisterNetEvent('negocios_gta:client:syncDeleteEvent')
AddEventHandler('negocios_gta:client:syncDeleteEvent', function(eventId)
    SendNUIMessage({
        app = APP_ID,
        action = 'syncDeleteEvent',
        id = eventId
    })
end)

RegisterNetEvent('negocios_gta:client:syncToggleEvent')
AddEventHandler('negocios_gta:client:syncToggleEvent', function(eventData)
    SendNUIMessage({
        app = APP_ID,
        action = 'syncToggleEvent',
        event = eventData
    })
end)

-- --- App Registration ---
local function registerApp()
    local ok, err = exports[PHONE_RESOURCE]:addCustomApp({
        id = APP_ID,
        label = 'Negocios GTA',
        icon = ui .. 'icon.png',
        category = 'Business',
        creator = 'JorgeDev',
        description = 'Publica, reseña y localiza los negocios de la ciudad.',
        extraDescription = {
            {
                header = 'Encuentra Negocios',
                head = 'Busca tiendas, talleres, bares y locales abiertos en tiempo real',
                image = 'https://cdn.discordapp.com/attachments/581555294828494888/1514053139605753866/ezgif.com-resize.gif?ex=6a29f75e&is=6a28a5de&hm=4bbfc61bd24f5436da8e3471afbc78484be0a0aebcdaced768d2c9a354b5118b&',
                footer = 'Navega por el mapa interactivo de la ciudad',
            },
        },
        appStoreOnly = true,
        sizeMb = 4,
        iframe = {
            url = ui .. 'index.html',
        },
        custom = {
            enabled = true,
            bridge = {
                enabled = true,
                allowedOrigins = { 'https://cfx-nui-' .. string.lower(GetCurrentResourceName()) },
            },
        },
    })

    if not ok then
        print(('[negocios_gta] addCustomApp failed: %s'):format(err or 'unknown'))
        return
    end
    print('[negocios_gta] Custom app registered OK')
end

CreateThread(function()
    while GetResourceState(PHONE_RESOURCE) ~= 'started' do
        Wait(500)
    end
    registerApp()
    
    Wait(1000)
    local mutedState = GetResourceKvpString("negocios_gta_muted")
    if mutedState == "true" then
        TriggerServerEvent('negocios_gta:server:setMuted', true)
    end

    -- Request initial data for blips on resource start
    TriggerServerEvent('negocios_gta:server:requestSync')
end)

-- Request initial data for blips when player joins/loads
RegisterNetEvent('esx:playerLoaded')
AddEventHandler('esx:playerLoaded', function()
    TriggerServerEvent('negocios_gta:server:requestSync')
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded')
AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
    TriggerServerEvent('negocios_gta:server:requestSync')
end)

-- --- Auto-Refresh on Permission/Job Changes ---
RegisterNetEvent('esx:setGroup')
AddEventHandler('esx:setGroup', function(group)
    Wait(500)
    SendNUIMessage({ app = APP_ID, action = 'forceRefresh' })
end)

RegisterNetEvent('esx:setJob')
AddEventHandler('esx:setJob', function(job)
    Wait(500)
    SendNUIMessage({ app = APP_ID, action = 'forceRefresh' })
end)

RegisterNetEvent('QBCore:Client:OnPermissionUpdate')
AddEventHandler('QBCore:Client:OnPermissionUpdate', function(permission)
    Wait(500)
    SendNUIMessage({ app = APP_ID, action = 'forceRefresh' })
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate')
AddEventHandler('QBCore:Client:OnJobUpdate', function(jobInfo)
    Wait(500)
    SendNUIMessage({ app = APP_ID, action = 'forceRefresh' })
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == PHONE_RESOURCE then
        registerApp()
    end
end)
