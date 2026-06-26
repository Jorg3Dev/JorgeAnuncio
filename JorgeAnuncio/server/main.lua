-- Ensure Locales is available (lua54 global scope fix)
if not Locales then Locales = {} end

local MySQL = exports.oxmysql
local ESX = nil
local QBCore = nil

-- ESX Framework Detection
TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
if not ESX and GetResourceState('es_extended') == 'started' then
    ESX = exports['es_extended']:getSharedObject()
end

-- QBCore / Qbox Framework Detection
if GetResourceState('qb-core') == 'started' then
    QBCore = exports['qb-core']:GetCoreObject()
elseif GetResourceState('qbx-core') == 'started' then
    -- Qbox compatibility layers load QBCore shared objects
    QBCore = exports['qb-core']:GetCoreObject()
end

-- --- Standalone Server-Client Callback System ---
local serverCallbacks = {}

local function registerServerCallback(name, handler)
    serverCallbacks[name] = handler
end

RegisterServerEvent('negocios_gta:server:triggerCallback')
AddEventHandler('negocios_gta:server:triggerCallback', function(name, requestId, ...)
    local src = source
    if serverCallbacks[name] then
        serverCallbacks[name](src, function(...)
            TriggerClientEvent('negocios_gta:client:serverCallback', src, requestId, ...)
        end, ...)
    else
        print(('Server callback %s does not exist'):format(name))
    end
end)

local isDatabaseReady = false

-- --- Discord Log Helper ---
local function SendDiscordLog(title, message, color)
    if not Config.Logs or not Config.Logs.WebhookURL or Config.Logs.WebhookURL == "" then return end
    
    local embed = {
        {
            ["color"] = color,
            ["title"] = "**".. title .."**",
            ["description"] = message,
            ["footer"] = {
                ["text"] = "JorgeAnuncio Logs • " .. os.date("%Y-%m-%d %H:%M:%S")
            }
        }
    }
    
    PerformHttpRequest(Config.Logs.WebhookURL, function(err, text, headers) end, 'POST', json.encode({
        username = Config.Logs.BotName or "Negocios GTA Logs",
        avatar_url = Config.Logs.BotAvatar or "",
        embeds = embed
    }), { ['Content-Type'] = 'application/json' })
end

local function parseCreatedAt(msOrString)
    if not msOrString then return os.time() * 1000 end
    if type(msOrString) == 'string' then
        local y, m, d, h, min, s = msOrString:match("(%d+)-(%d+)-(%d+) (%d+):(%d+):(%d+)")
        if y then
            return os.time({year=y, month=m, day=d, hour=h, min=min, sec=s}) * 1000
        end
    elseif type(msOrString) == 'number' then
        if msOrString < 9999999999 then
            return msOrString * 1000
        end
        return msOrString
    end
    return os.time() * 1000
end

-- --- Data fetching helper ---
local function fetchAllData(cb)
    if not isDatabaseReady then
        CreateThread(function()
            while not isDatabaseReady do
                Wait(100)
            end
            fetchAllData(cb)
        end)
        return
    end

    MySQL:query('SELECT * FROM JorgeDev_businesses', {}, function(businesses)
        MySQL:query('SELECT * FROM JorgeDev_business_reviews', {}, function(reviews)
            MySQL:query('SELECT * FROM JorgeDev_business_events', {}, function(events)
                -- Format boolean from tinyint for JS
                for _, biz in ipairs(businesses or {}) do
                    biz.createdAt = parseCreatedAt(biz.createdAt)
                    biz.isOpen = (biz.isOpen == 1 or biz.isOpen == true or biz.isOpen == "1" or biz.isOpen == "true")
                    
                    if biz.featured_until then
                        if type(biz.featured_until) == 'string' then
                            local y, m, d, h, min, s = biz.featured_until:match("(%d+)-(%d+)-(%d+) (%d+):(%d+):(%d+)")
                            if y then
                                biz.featured_until = os.time({year=y, month=m, day=d, hour=h, min=min, sec=s})
                            end
                        elseif type(biz.featured_until) == 'number' then
                            if biz.featured_until > 9999999999 then
                                biz.featured_until = math.floor(biz.featured_until / 1000)
                            end
                        end
                    end
                    
                    -- Parse gallery JSON
                    if biz.gallery and type(biz.gallery) == 'string' then
                        local ok, parsed = pcall(json.decode, biz.gallery)
                        if ok and type(parsed) == 'table' then
                            biz.gallery = parsed
                        else
                            biz.gallery = {}
                        end
                    else
                        biz.gallery = {}
                    end
                end
                
                for _, rev in ipairs(reviews or {}) do
                    rev.createdAt = parseCreatedAt(rev.createdAt)
                end
                
                for _, ev in ipairs(events or {}) do
                    ev.createdAt = parseCreatedAt(ev.createdAt)
                    ev.isActive = (ev.isActive == 1 or ev.isActive == true or ev.isActive == "1" or ev.isActive == "true")
                    -- For compatibility with UI which expects 'time'
                    ev.time = ev.eventTime
                end

                cb({
                    businesses = businesses or {},
                    reviews = reviews or {},
                    events = events or {}
                })
            end)
        end)
    end)
end

-- --- Broadcast Sync ---
local function broadcastSync()
    fetchAllData(function(data)
        TriggerClientEvent('negocios_gta:client:syncData', -1, data.businesses, data.reviews, data.events)
    end)
end

RegisterServerEvent('negocios_gta:server:requestSync')
AddEventHandler('negocios_gta:server:requestSync', function()
    local src = source
    fetchAllData(function(data)
        TriggerClientEvent('negocios_gta:client:syncData', src, data.businesses, data.reviews, data.events)
    end)
end)

-- --- Prepopulate default data if table is empty ---
local function prepopulateData()
    local createBusinessesTable = [[
        CREATE TABLE IF NOT EXISTS `JorgeDev_businesses` (
          `id` VARCHAR(50) NOT NULL,
          `name` VARCHAR(100) NOT NULL,
          `category` VARCHAR(50) NOT NULL,
          `description` TEXT NOT NULL,
          `x` FLOAT NOT NULL,
          `y` FLOAT NOT NULL,
          `isOpen` TINYINT(1) NOT NULL DEFAULT 1,
          `owner` VARCHAR(100) NOT NULL,
          `phone` VARCHAR(50) NOT NULL,
          `job` VARCHAR(50) NOT NULL DEFAULT '',
          `image` LONGTEXT,
          `blipId` INT NOT NULL DEFAULT 0,
          `createdAt` DATETIME DEFAULT CURRENT_TIMESTAMP,
          PRIMARY KEY (`id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]]

    local createReviewsTable = [[
        CREATE TABLE IF NOT EXISTS `JorgeDev_business_reviews` (
          `id` VARCHAR(50) NOT NULL,
          `businessId` VARCHAR(50) NOT NULL,
          `author` VARCHAR(100) NOT NULL,
          `rating` INT NOT NULL,
          `comment` TEXT NOT NULL,
          `createdAt` DATETIME DEFAULT CURRENT_TIMESTAMP,
          PRIMARY KEY (`id`),
          CONSTRAINT `fk_jorgedev_business_reviews` FOREIGN KEY (`businessId`) REFERENCES `JorgeDev_businesses`(`id`) ON DELETE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]]

    local createEventsTable = [[
        CREATE TABLE IF NOT EXISTS `JorgeDev_business_events` (
          `id` VARCHAR(50) NOT NULL,
          `businessId` VARCHAR(50) NOT NULL,
          `title` VARCHAR(255) NOT NULL,
          `description` TEXT NOT NULL,
          `eventTime` VARCHAR(100) NOT NULL,
          `image` VARCHAR(255) NOT NULL DEFAULT '',
          `isActive` TINYINT(1) NOT NULL DEFAULT 1,
          `createdAt` DATETIME DEFAULT CURRENT_TIMESTAMP,
          PRIMARY KEY (`id`),
          CONSTRAINT `fk_jorgedev_business_events` FOREIGN KEY (`businessId`) REFERENCES `JorgeDev_businesses`(`id`) ON DELETE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]]

    MySQL:query(createBusinessesTable, {}, function()
        MySQL:query(createReviewsTable, {}, function()
            MySQL:query(createEventsTable, {}, function()
                MySQL:query("ALTER TABLE `JorgeDev_business_events` ADD COLUMN IF NOT EXISTS `isActive` TINYINT(1) NOT NULL DEFAULT 1", {}, function() end)
                MySQL:query("ALTER TABLE `JorgeDev_business_events` ADD COLUMN IF NOT EXISTS `price` VARCHAR(50) NOT NULL DEFAULT 'Gratis'", {}, function() end)
                MySQL:query("ALTER TABLE `JorgeDev_business_events` ADD COLUMN IF NOT EXISTS `location` VARCHAR(100) NOT NULL DEFAULT ''", {}, function() end)
                MySQL:query("ALTER TABLE `JorgeDev_business_events` ADD COLUMN IF NOT EXISTS `requirements` VARCHAR(100) NOT NULL DEFAULT ''", {}, function() end)
                MySQL:query("ALTER TABLE `JorgeDev_business_events` ADD COLUMN IF NOT EXISTS `locationX` FLOAT DEFAULT NULL", {}, function() end)
                MySQL:query("ALTER TABLE `JorgeDev_business_events` ADD COLUMN IF NOT EXISTS `locationY` FLOAT DEFAULT NULL", {}, function() end)
                MySQL:query("ALTER TABLE `JorgeDev_business_reviews` ADD COLUMN IF NOT EXISTS `identifier` VARCHAR(100) NOT NULL DEFAULT ''", {}, function() end)
                MySQL:query("ALTER TABLE `JorgeDev_businesses` ADD COLUMN IF NOT EXISTS `job` VARCHAR(50) NOT NULL DEFAULT ''", {}, function()
                    MySQL:query("ALTER TABLE `JorgeDev_businesses` ADD COLUMN IF NOT EXISTS `image` LONGTEXT", {}, function()
                        MySQL:query("ALTER TABLE `JorgeDev_businesses` ADD COLUMN IF NOT EXISTS `blipId` INT NOT NULL DEFAULT 0", {}, function()
                            MySQL:query("ALTER TABLE `JorgeDev_businesses` ADD COLUMN IF NOT EXISTS `gallery` LONGTEXT DEFAULT '[]'", {}, function()
                                MySQL:query("ALTER TABLE `JorgeDev_businesses` ADD COLUMN IF NOT EXISTS `banner` LONGTEXT", {}, function()
                                    MySQL:query("ALTER TABLE `JorgeDev_businesses` ADD COLUMN IF NOT EXISTS `featured_until` DATETIME NULL DEFAULT NULL", {}, function()
                                        MySQL:query("ALTER TABLE `JorgeDev_businesses` MODIFY COLUMN `featured_until` DATETIME NULL DEFAULT NULL", {}, function()
                                            print('[negocios_gta] Database tables verified.')
                                            isDatabaseReady = true
                                        end)
                                    end)
                                end)
                            end)
                        end)
                    end)
                end)
            end)
        end)
    end)
end

local function getIdentifierValue(idStr)
    local colonPos = string.find(idStr, ":")
    if colonPos then
        return string.sub(idStr, colonPos + 1)
    end
    return idStr
end

local function getPrimaryIdentifier(source)
    local identifiers = GetPlayerIdentifiers(source)
    if not identifiers then return "id:" .. tostring(source) end
    
    local types = {'license:', 'steam:', 'discord:', 'fivem:', 'live:', 'xbl:'}
    for _, prefix in ipairs(types) do
        for _, id in ipairs(identifiers) do
            if string.sub(id, 1, string.len(prefix)) == prefix then
                return id
            end
        end
    end
    
    for _, id in ipairs(identifiers) do
        if string.sub(id, 1, 3) ~= 'ip:' then
            return id
        end
    end
    return "id:" .. tostring(source)
end

local function checkAdminStatus(source)
    local player = source
    -- print("[negocios_gta] Checking admin status for source: " .. tostring(player))

    -- 1. Check by identifiers
    local identifiers = GetPlayerIdentifiers(player)
    if identifiers then
        for _, id in ipairs(identifiers) do
            -- print("[negocios_gta] Player identifier: " .. tostring(id))
            local cleanId = getIdentifierValue(id)
            for _, allowedId in ipairs(Config.Admin.Identifiers) do
                local cleanAllowedId = getIdentifierValue(allowedId)
                if string.lower(id) == string.lower(allowedId) or string.lower(cleanId) == string.lower(cleanAllowedId) then
                    -- print("[negocios_gta] MATCH FOUND! Player is Admin by identifier: " .. tostring(id))
                    return true
                end
            end
        end
    end

    -- 2. Check by ESX groups
    if ESX then
        local xPlayer = ESX.GetPlayerFromId(player)
        if xPlayer then
            local playerGroup = xPlayer.getGroup()
            -- print("[negocios_gta] Player ESX group: " .. tostring(playerGroup))
            for _, allowedGroup in ipairs(Config.Admin.ESXGroups) do
                if playerGroup == allowedGroup then
                    -- print("[negocios_gta] MATCH FOUND! Player is Admin by ESX group: " .. tostring(playerGroup))
                    return true
                end
            end
        end
    end

    -- Check by QBCore / Qbox permissions
    if QBCore then
        for _, allowedGroup in ipairs(Config.Admin.ESXGroups) do
            if QBCore.Functions.HasPermission(player, allowedGroup) or QBCore.Functions.HasPermission(player, 'god') then
                return true
            end
        end
    end

    -- 3. Check by ACE permissions
    if Config.Admin.ACEPermissions then
        for _, permission in ipairs(Config.Admin.ACEPermissions) do
            if IsPlayerAceAllowed(tostring(player), permission) then
                -- print("[negocios_gta] MATCH FOUND! Player is Admin by ACE permission: " .. tostring(permission))
                return true
            end
        end
    end

    -- print("[negocios_gta] Player is NOT Admin.")
    return false
end

-- --- Database Callbacks Registry ---
registerServerCallback('negocios_gta:server:getData', function(source, cb)
    local isAdmin = checkAdminStatus(source)
    local playerJob = ''
    local availableJobs = {}
    
    if ESX then
        local xPlayer = ESX.GetPlayerFromId(source)
        if xPlayer and xPlayer.getJob then
            local job = xPlayer.getJob()
            if job then
                playerJob = job.name
            end
        end
        if ESX.GetJobs then
            for k, v in pairs(ESX.GetJobs()) do
                availableJobs[k] = v.label
            end
        end
    elseif QBCore then
        local Player = QBCore.Functions.GetPlayer(source)
        if Player and Player.PlayerData and Player.PlayerData.job then
            playerJob = Player.PlayerData.job.name
        end
        local qbJobs = QBCore.Shared.Jobs
        if qbJobs then
            for k, v in pairs(qbJobs) do
                availableJobs[k] = v.label or k
            end
        end
    end

    local playerLicense = getPrimaryIdentifier(source)

    fetchAllData(function(data)
        data.isAdmin = isAdmin
        data.playerJob = playerJob
        data.availableJobs = availableJobs

        local myReviewIds = {}
        for _, rev in ipairs(data.reviews) do
            if rev.identifier == playerLicense then
                table.insert(myReviewIds, rev.id)
            end
        end
        data.myReviewIds = myReviewIds
        data.locale = (Locales and Locales[Config.Language]) or (Locales and Locales['en']) or {}
        data.categories = Config.Categories or {}

        cb(data)
    end)
end)

-- --- Server Events ---
RegisterServerEvent('negocios_gta:server:saveBusiness')
AddEventHandler('negocios_gta:server:saveBusiness', function(biz)
    local openVal = biz.isOpen and 1 or 0
    local jobVal = biz.job or ''
    local imageVal = biz.image or ''
    local bannerVal = biz.banner or ''
    local blipIdVal = biz.blipId or 0
    local galleryVal = biz.gallery or '[]'
    if type(galleryVal) == 'table' then
        galleryVal = json.encode(galleryVal)
    end

    local function afterSave()
        MySQL:single('SELECT * FROM JorgeDev_businesses WHERE id = ?', { biz.id }, function(savedBiz)
            if savedBiz then
                savedBiz.isOpen = (savedBiz.isOpen == 1 or savedBiz.isOpen == true)
                -- Parse gallery JSON
                if savedBiz.gallery and type(savedBiz.gallery) == 'string' then
                    local ok, parsed = pcall(json.decode, savedBiz.gallery)
                    if ok and type(parsed) == 'table' then
                        savedBiz.gallery = parsed
                    else
                        savedBiz.gallery = {}
                    end
                else
                    savedBiz.gallery = {}
                end
                print(string.format("[negocios_gta] Business saved: %s | category: %s", savedBiz.name, savedBiz.category))
                TriggerClientEvent('negocios_gta:client:syncSingleBusiness', -1, savedBiz)
                SendDiscordLog("Negocio Guardado/Creado", "El negocio **" .. savedBiz.name .. "** ha sido guardado por un administrador.", Config.Logs.Colors.CreateBusiness)
            else
                print("[negocios_gta] ERROR: Business not found after save: " .. tostring(biz.id))
            end
        end)
    end

    -- Check if business already exists
    MySQL:single('SELECT id FROM JorgeDev_businesses WHERE id = ?', { biz.id }, function(existing)
        if existing then
            -- UPDATE existing business
            MySQL:execute('UPDATE JorgeDev_businesses SET name=?, category=?, description=?, x=?, y=?, isOpen=?, owner=?, phone=?, job=?, image=?, banner=?, blipId=?, gallery=? WHERE id=?', {
                biz.name, biz.category, biz.description, biz.x, biz.y, openVal, biz.owner, biz.phone, jobVal, imageVal, bannerVal, blipIdVal, galleryVal, biz.id
            }, function(rowsChanged)
                print(string.format("[negocios_gta] UPDATE executed for %s, rows affected: %s, new category: %s", tostring(biz.name), tostring(rowsChanged), tostring(biz.category)))
                afterSave()
            end)
        else
            -- INSERT new business
            local createdAtVal = biz.createdAt or (os.time() * 1000)
            MySQL:execute('INSERT INTO JorgeDev_businesses (id, name, category, description, x, y, isOpen, owner, phone, job, image, banner, blipId, gallery, createdAt) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, FROM_UNIXTIME(? / 1000))', {
                biz.id, biz.name, biz.category, biz.description, biz.x, biz.y, openVal, biz.owner, biz.phone, jobVal, imageVal, bannerVal, blipIdVal, galleryVal, createdAtVal
            }, function(rowsChanged)
                print(string.format("[negocios_gta] INSERT executed for %s, rows affected: %s", tostring(biz.name), tostring(rowsChanged)))
                afterSave()
            end)
        end
    end)
end)

RegisterServerEvent('negocios_gta:server:deleteBusiness')
AddEventHandler('negocios_gta:server:deleteBusiness', function(id)
    MySQL:single('SELECT name FROM JorgeDev_businesses WHERE id = ?', { id }, function(biz)
        if biz then
            SendDiscordLog("Negocio Eliminado", "Un administrador ha eliminado el negocio **" .. biz.name .. "**.", Config.Logs.Colors.DeleteBusiness)
        end
        MySQL:execute('DELETE FROM JorgeDev_businesses WHERE id = ?', { id }, function()
            broadcastSync()
        end)
    end)
end)

local mutedPlayers = {}

RegisterServerEvent('negocios_gta:server:setMuted')
AddEventHandler('negocios_gta:server:setMuted', function(isMuted)
    local src = source
    mutedPlayers[src] = isMuted
end)

RegisterServerEvent('negocios_gta:server:sendPhoneNotification')
AddEventHandler('negocios_gta:server:sendPhoneNotification', function(title, msg, icon)
    local src = source
    if Config.Notifications and Config.Notifications.Type == 'phone' then
        pcall(function()
            exports['qs-smartphone']:sendPhoneNotification(src, {
                appId = 'negocios_gta',
                title = title,
                text = msg,
                message = msg,
                icon = icon or './img/apps/business.png',
                closeTimeout = 5000
            })
        end)
    end
end)

RegisterServerEvent('negocios_gta:server:toggleBusiness')
AddEventHandler('negocios_gta:server:toggleBusiness', function(id)
    MySQL:single('SELECT isOpen, name, image, description FROM JorgeDev_businesses WHERE id = ?', { id }, function(biz)
        if biz then
            local isOpen = biz.isOpen == 1 or biz.isOpen == true or biz.isOpen == "1" or biz.isOpen == "true"
            local newStatus = isOpen and 0 or 1
            MySQL:execute('UPDATE JorgeDev_businesses SET isOpen = ? WHERE id = ?', { newStatus, id }, function()
                local color = newStatus == 1 and Config.Logs.Colors.ToggleOpen or Config.Logs.Colors.ToggleClose
                local stateStr = newStatus == 1 and "Abierto" or "Cerrado"
                SendDiscordLog("Estado de Negocio", "El negocio **" .. biz.name .. "** ahora está **" .. stateStr .. "**.", color)
                TriggerClientEvent('negocios_gta:client:syncToggleBusiness', -1, id, newStatus == 1, biz.name, biz.image, biz.description)
                
                -- Broadcast phone notifications directly from server side using Quasar server-side exports
                if Config.Notifications and Config.Notifications.Type == 'phone' then
                    if newStatus == 1 or Config.Notifications.NotifyOnToggle then
                        local statusText = (newStatus == 1) and "🟢 ¡ABIERTO!" or "🔴 ¡CERRADO!"
                        local cleanDesc = biz.description or ''
                        if string.len(cleanDesc) > 80 then
                            cleanDesc = string.sub(cleanDesc, 1, 77) .. "..."
                        end
                        local title = biz.name or 'Negocio'
                        local msg = string.format("%s - %s", statusText, cleanDesc)
                        
                        local finalIcon = biz.image
                        if not finalIcon or finalIcon == "" then
                            finalIcon = './img/apps/business.png'
                        elseif not string.find(finalIcon, "^http") then
                            finalIcon = './img/apps/business.png'
                        end

                        local players = GetPlayers()
                        for _, playerStr in ipairs(players) do
                            local playerSrc = tonumber(playerStr)
                            if playerSrc and not mutedPlayers[playerSrc] then
                                pcall(function()
                                    exports['qs-smartphone']:sendPhoneNotification(playerSrc, {
                                        appId = 'negocios_gta',
                                        title = title,
                                        text = msg,
                                        message = msg,
                                        icon = finalIcon,
                                        closeTimeout = 5000
                                    })
                                end)
                            end
                        end
                    end
                end
            end)
        end
    end)
end)

local businessCooldowns = {}

registerServerCallback('negocios_gta:server:sendBusinessAnnouncement', function(src, cb, id, message)
    local isAdmin = checkAdminStatus(src)
    
    -- Check cooldown first (admins bypass cooldowns)
    local currentTime = os.time()
    if not isAdmin and businessCooldowns[id] and currentTime < businessCooldowns[id] then
        local timeLeft = businessCooldowns[id] - currentTime
        local minutes = math.floor(timeLeft / 60)
        local seconds = timeLeft % 60
        local timeStr = ""
        if minutes > 0 then
            timeStr = string.format("%d min y %d seg", minutes, seconds)
        else
            timeStr = string.format("%d seg", seconds)
        end
        
        -- We no longer need to send a phone notification because the UI will handle it
        cb({ ok = false, error = string.format("Tu negocio está en cooldown. Espera %s.", timeStr), cooldown = timeLeft })
        return
    end

    -- Fetch business details to verify permissions and get metadata
    MySQL:single('SELECT name, image, job FROM JorgeDev_businesses WHERE id = ?', { id }, function(biz)
        if biz then
            -- Verify if the player is admin or has the business job
            local hasJob = false
            if ESX then
                local xPlayer = ESX.GetPlayerFromId(src)
                if xPlayer and xPlayer.getJob then
                    local job = xPlayer.getJob()
                    if job and job.name == biz.job then
                        hasJob = true
                    end
                end
            elseif QBCore then
                local Player = QBCore.Functions.GetPlayer(src)
                if Player and Player.PlayerData and Player.PlayerData.job then
                    if Player.PlayerData.job.name == biz.job then
                        hasJob = true
                    end
                end
            end
            
            if isAdmin or hasJob then
                -- Set cooldown duration
                local cooldownSecs = Config.AnnouncementCooldown or 300
                if not isAdmin then
                    businessCooldowns[id] = currentTime + cooldownSecs
                end
                
                SendDiscordLog("Anuncio de Negocio", "El negocio **" .. (biz.name or 'Anuncio') .. "** ha enviado un anuncio global:\n\n> " .. message, Config.Logs.Colors.Announcement)

                local title = string.format("📢 %s", biz.name or 'Anuncio')
                local finalIcon = biz.image
                if not finalIcon or finalIcon == "" then
                    finalIcon = './img/apps/business.png'
                elseif not string.find(finalIcon, "^http") then
                    finalIcon = './img/apps/business.png'
                end
                
                -- Send announcement
                if Config.Notifications and Config.Notifications.Type == 'phone' then
                    -- 1. Using Quasar server-side notification export for all active unmuted players
                    local players = GetPlayers()
                    for _, playerStr in ipairs(players) do
                        local playerSrc = tonumber(playerStr)
                        if playerSrc and not mutedPlayers[playerSrc] then
                            pcall(function()
                                exports['qs-smartphone']:sendPhoneNotification(playerSrc, {
                                    appId = 'negocios_gta',
                                    title = title,
                                    text = message,
                                    message = message,
                                    icon = finalIcon,
                                    closeTimeout = 8000
                                })
                            end)
                        end
                    end
                else
                    -- 2. Fallback to client-side notification trigger (like ox_lib or native GTA) for all players
                    TriggerClientEvent('negocios_gta:client:sendAnnouncementBroadcast', -1, title, message, finalIcon)
                end
                
                cb({ ok = true, cooldown = cooldownSecs })
            else
                print(string.format("[negocios_gta] Player %s tried to send announcement for %s without permission!", tostring(src), tostring(id)))
                cb({ ok = false, error = "No tienes permiso para hacer esto." })
            end
        else
            cb({ ok = false, error = "Negocio no encontrado." })
        end
    end)
end)

registerServerCallback('negocios_gta:server:buyFeaturedAd', function(source, cb, businessId)
    local src = source
    if not Config.Ads or not Config.Ads.Enabled then
        cb({ ok = false, error = 'El sistema de patrocinados está desactivado.' })
        return
    end

    local cost = Config.Ads.Cost or 50000
    local durationSecs = (Config.Ads.DurationHours or 24) * 3600

    MySQL:single('SELECT name, job, featured_until FROM JorgeDev_businesses WHERE id = ?', { businessId }, function(biz)
        if not biz then
            cb({ ok = false, error = 'Negocio no encontrado.' })
            return
        end

        local currentTime = os.time()
        local currentUntilUnix = 0
        if biz.featured_until then
            if type(biz.featured_until) == 'string' then
                local y, m, d, h, min, s = biz.featured_until:match("(%d+)-(%d+)-(%d+) (%d+):(%d+):(%d+)")
                if y then currentUntilUnix = os.time({year=y, month=m, day=d, hour=h, min=min, sec=s}) end
            elseif type(biz.featured_until) == 'number' then
                currentUntilUnix = biz.featured_until > 9999999999 and math.floor(biz.featured_until / 1000) or biz.featured_until
            end
        end

        if currentUntilUnix > currentTime then
            cb({ ok = false, error = 'El negocio ya está patrocinado actualmente.' })
            return
        end

        local function applyAd()
            local newUntil = os.date('%Y-%m-%d %H:%M:%S', currentTime + durationSecs)
            MySQL:update('UPDATE JorgeDev_businesses SET featured_until = ? WHERE id = ?', { newUntil, businessId }, function(affectedRows)
                if affectedRows > 0 then
                    cb({ ok = true })
                    SendDiscordLog("Negocio Patrocinado", "El negocio **" .. (biz.name or businessId) .. "** ha comprado publicidad por " .. cost .. "$ (" .. (Config.Ads.DurationHours or 24) .. "h).", 3066993)
                    broadcastSync()
                else
                    cb({ ok = false, error = 'Error al actualizar la base de datos.' })
                end
            end)
        end

        local function chargeBank(xPlayer, qbPlayer)
            if ESX and xPlayer then
                local bank = xPlayer.getAccount('bank')
                if bank and bank.money >= cost then
                    xPlayer.removeAccountMoney('bank', cost)
                    applyAd()
                else
                    cb({ ok = false, error = 'No tienes suficiente dinero en el banco personal.' })
                end
            elseif QBCore and qbPlayer then
                local bank = qbPlayer.PlayerData.money['bank']
                if bank >= cost then
                    qbPlayer.Functions.RemoveMoney('bank', cost, "featured-ad")
                    applyAd()
                else
                    cb({ ok = false, error = 'No tienes suficiente dinero en el banco personal.' })
                end
            else
                cb({ ok = false, error = 'Error en framework.' })
            end
        end

        if Config.Ads.PaymentAccount == 'society' and biz.job and biz.job ~= '' then
            if ESX then
                local xPlayer = ESX.GetPlayerFromId(src)
                TriggerEvent('esx_addonaccount:getSharedAccount', 'society_' .. biz.job, function(account)
                    if account then
                        if account.money >= cost then
                            account.removeMoney(cost)
                            applyAd()
                        else
                            cb({ ok = false, error = 'La sociedad no tiene fondos suficientes (' .. cost .. '$).' })
                        end
                    else
                        chargeBank(xPlayer, nil)
                    end
                end)
            elseif QBCore then
                local Player = QBCore.Functions.GetPlayer(src)
                local balance = exports['qb-management']:GetAccount(biz.job)
                if balance and balance >= cost then
                    exports['qb-management']:RemoveMoney(biz.job, cost)
                    applyAd()
                else
                    if balance then
                        cb({ ok = false, error = 'La sociedad no tiene fondos suficientes (' .. cost .. '$).' })
                    else
                        chargeBank(nil, Player)
                    end
                end
            end
        else
            if ESX then
                chargeBank(ESX.GetPlayerFromId(src), nil)
            elseif QBCore then
                chargeBank(nil, QBCore.Functions.GetPlayer(src))
            end
        end
    end)
end)

RegisterServerEvent('negocios_gta:server:removeAd')
AddEventHandler('negocios_gta:server:removeAd', function(businessId)
    local src = source
    if checkAdminStatus(src) then
        MySQL:execute('UPDATE JorgeDev_businesses SET featured_until = NULL WHERE id = ?', { businessId }, function()
            broadcastSync()
        end)
    end
end)

registerServerCallback('negocios_gta:server:addReview', function(source, cb, rev)
    local playerLicense = getPrimaryIdentifier(source)
    local serverTime = os.time() * 1000
    rev.createdAt = serverTime -- Forzar tiempo del servidor

    -- Buscar la reseña más reciente de este jugador en este negocio
    MySQL:single('SELECT createdAt FROM JorgeDev_business_reviews WHERE businessId = ? AND identifier = ? ORDER BY createdAt DESC LIMIT 1', { rev.businessId, playerLicense }, function(existing)
        if existing and existing.createdAt then
            local timeDiff = serverTime - existing.createdAt
            local oneDayMs = 24 * 60 * 60 * 1000
            
            if timeDiff < oneDayMs then
                cb({ ok = false, error = 'limit_exceeded' })
                return
            end
        end

        MySQL:insert('INSERT INTO JorgeDev_business_reviews (id, businessId, author, rating, comment, identifier, createdAt) VALUES (?, ?, ?, ?, ?, ?, FROM_UNIXTIME(? / 1000))', {
            rev.id, rev.businessId, rev.author, rev.rating, rev.comment, playerLicense, rev.createdAt
        }, function()
            cb({ ok = true })
            MySQL:single('SELECT * FROM JorgeDev_business_reviews WHERE id = ?', { rev.id }, function(savedRev)
                if savedRev then
                    TriggerClientEvent('negocios_gta:client:syncNewReview', -1, savedRev)
                end
            end)
        end)
    end)
end)

RegisterServerEvent('negocios_gta:server:deleteReview')
AddEventHandler('negocios_gta:server:deleteReview', function(reviewId)
    local src = source
    local isAdmin = checkAdminStatus(src)

    -- Get player license
    local playerLicense = getPrimaryIdentifier(src)

    -- Check ownership or admin
    MySQL:single('SELECT identifier FROM JorgeDev_business_reviews WHERE id = ?', { reviewId }, function(rev)
        if rev and (isAdmin or rev.identifier == playerLicense) then
            MySQL:execute('DELETE FROM JorgeDev_business_reviews WHERE id = ?', { reviewId }, function()
                TriggerClientEvent('negocios_gta:client:syncDeleteReview', -1, reviewId)
            end)
        end
    end)
end)

RegisterServerEvent('negocios_gta:server:updateReview')
AddEventHandler('negocios_gta:server:updateReview', function(data)
    local src = source

    local playerLicense = getPrimaryIdentifier(src)

    MySQL:single('SELECT identifier FROM JorgeDev_business_reviews WHERE id = ?', { data.id }, function(rev)
        if rev and rev.identifier == playerLicense then
            MySQL:execute('UPDATE JorgeDev_business_reviews SET rating = ?, comment = ? WHERE id = ?', 
                { data.rating, data.comment, data.id }, function()
                    MySQL:single('SELECT * FROM JorgeDev_business_reviews WHERE id = ?', { data.id }, function(updatedRev)
                        if updatedRev then
                            TriggerClientEvent('negocios_gta:client:syncUpdateReview', -1, updatedRev)
                        end
                    end)
                end)
        end
    end)
end)

RegisterServerEvent('negocios_gta:server:addEvent')
AddEventHandler('negocios_gta:server:addEvent', function(ev)
    local serverTime = os.time() * 1000
    ev.createdAt = serverTime
    
    MySQL:insert('INSERT INTO JorgeDev_business_events (id, businessId, title, description, eventTime, image, isActive, price, location, locationX, locationY, requirements, createdAt) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, FROM_UNIXTIME(? / 1000))', {
        ev.id, ev.businessId, ev.title, ev.description, ev.eventTime or ev.time, ev.image or '', 1, ev.price or 'Gratis', ev.location or '', ev.locationX, ev.locationY, ev.requirements or '', ev.createdAt
    }, function()
        MySQL:single('SELECT * FROM JorgeDev_business_events WHERE id = ?', { ev.id }, function(savedEv)
            if savedEv then
                -- For compatibility with UI which expects 'time'
                savedEv.time = savedEv.eventTime
                SendDiscordLog("Evento Creado", "Se ha publicado un nuevo evento: **" .. savedEv.title .. "**.", Config.Logs.Colors.CreateEvent)
                TriggerClientEvent('negocios_gta:client:syncNewEvent', -1, savedEv)
            end
        end)
    end)
end)

RegisterServerEvent('negocios_gta:server:updateEvent')
AddEventHandler('negocios_gta:server:updateEvent', function(ev)
    MySQL:execute('UPDATE JorgeDev_business_events SET title = ?, description = ?, eventTime = ?, image = ?, price = ?, location = ?, locationX = ?, locationY = ?, requirements = ? WHERE id = ?', {
        ev.title, ev.description, ev.eventTime or ev.time, ev.image or '', ev.price or 'Gratis', ev.location or '', ev.locationX, ev.locationY, ev.requirements or '', ev.id
    }, function()
        MySQL:single('SELECT * FROM JorgeDev_business_events WHERE id = ?', { ev.id }, function(updatedEv)
            if updatedEv then
                updatedEv.time = updatedEv.eventTime
                TriggerClientEvent('negocios_gta:client:syncUpdateEvent', -1, updatedEv)
            end
        end)
    end)
end)

RegisterServerEvent('negocios_gta:server:deleteEvent')
AddEventHandler('negocios_gta:server:deleteEvent', function(eventId)
    MySQL:single('SELECT title FROM JorgeDev_business_events WHERE id = ?', { eventId }, function(ev)
        if ev then
            SendDiscordLog("Evento Eliminado", "El evento **" .. ev.title .. "** ha sido cancelado/eliminado.", Config.Logs.Colors.DeleteEvent)
        end
        MySQL:execute('DELETE FROM JorgeDev_business_events WHERE id = ?', { eventId }, function()
            TriggerClientEvent('negocios_gta:client:syncDeleteEvent', -1, eventId)
        end)
    end)
end)

RegisterServerEvent('negocios_gta:server:toggleEvent')
AddEventHandler('negocios_gta:server:toggleEvent', function(eventId)
    MySQL:single('SELECT isActive FROM JorgeDev_business_events WHERE id = ?', { eventId }, function(ev)
        if ev then
            -- If isActive is nil/NULL, it defaults to 1 (active). So we toggle from 1 to 0.
            local newStatus = (ev.isActive == nil or ev.isActive == 1) and 0 or 1
            MySQL:execute('UPDATE JorgeDev_business_events SET isActive = ? WHERE id = ?', { newStatus, eventId }, function()
                TriggerClientEvent('negocios_gta:client:syncToggleEvent', -1, { id = eventId, isActive = newStatus == 1 })
            end)
        end
    end)
end)

-- Initialize database check on start
CreateThread(function()
    prepopulateData()
end)
