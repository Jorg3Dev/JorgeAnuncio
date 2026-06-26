Config = {}

-- Idioma / Language: 'es' (Spanish), 'en' (English), 'de' (German), 'it' (Italian)
Config.Language = 'es'

-- Configuración del sistema de Administración
Config.Admin = {
    ESXGroups = {
        'admin',
        'superadmin',
        'moderator',
        'god',
        'owner',
        'founder',
    },

    -- Identificadores de FiveM (licencias, steam, discord, etc.) que tendrán acceso automático de administrador.
    -- FiveM Identifiers (license, steam, discord, etc.) that will have automatic admin access.
    -- Útil para darte acceso de forma directa e infalible mediante tu licencia. / Useful to give yourself direct access via license.
    -- Ejemplos / Examples: 'license:1a2b3c4d5e...', 'steam:1100001...', 'discord:123456789...'
    Identifiers = {
        -- 'license:2e8c8ee08b18e3bcde787b443072344ca88989c3',
    },

    ACEPermissions = {
        'negocios.admin',
    }
}

-- Configuración de iconos en el mapa (Blips) / Map Blip Configuration
Config.Blips = {
    -- Si el negocio está abierto, ¿qué color de blip quieres? / Blip color when open (2 = default green in GTA)
    ColorAbierto = 2,
    -- Si el negocio está cerrado, ¿qué color de blip quieres? / Blip color when closed (0 = white)
    ColorCerrado = 0,
    -- Formato del nombre en el mapa cuando está abierto / Name format when open (%s será reemplazado por el nombre)
    FormatAbierto = "%s (Abierto)",
    -- Formato del nombre en el mapa cuando está cerrado / Name format when closed (%s será reemplazado por el nombre)
    FormatCerrado = "%s (Cerrado)",
    -- Tamaño del icono en el mapa / Blip scale on the map
    Escala = 0.8,
    -- ¿Ocultar completamente los blips de negocios cerrados? / Hide completely when closed? (true = Hide, false = Show in grey/red)
    HideWhenClosed = true
}

-- Configuración de Categorías de Negocios / Business Categories Configuration
-- Puedes añadir o quitar categorías libremente. / You can freely add or remove categories.
-- Las claves (ej: 'tienda', 'restaurante') se guardarán en la base de datos. / Keys are saved in the DB.
Config.Categories = {
    tienda = { label = "Tienda", icon = "🛒", color = "#3b82f6", blipId = 52 },
    restaurante = { label = "Restaurante", icon = "🍔", color = "#ef4444", blipId = 89 },
    taller = { label = "Taller", icon = "🔧", color = "#8b5cf6", blipId = 446 },
    bar = { label = "Bar", icon = "🍸", color = "#ec4899", blipId = 93 },
    club = { label = "Club", icon = "🎵", color = "#a855f7", blipId = 614 },
    gasolinera = { label = "Gasolinera", icon = "⛽", color = "#f59e0b", blipId = 361 },
    ocio = { label = "Ocio", icon = "🎭", color = "#10b981", blipId = 120 },
    otro = { label = "Otro", icon = "📍", color = "#64748b", blipId = 66 }
}

-- Configuración de Notificaciones / Notifications Configuration
Config.Notifications = {
    -- Tipo de notificación preferida / Preferred notification type: 'ox_lib', 'phone' (qs-smartphone), 'gta' (native), or 'custom' (React HUD)
    Type = 'custom',
    
    -- Notificar a todos los jugadores cuando un negocio abre o cierra / Notify all players on toggle
    NotifyOnToggle = true,
    
    -- Notificar a todos los jugadores cuando un negocio abre (Legacy compatibility) / Notify on open
    NotifyOnOpen = true
}

-- Cooldown (tiempo de espera) en segundos entre anuncios personalizados por cada negocio.
-- Cooldown (wait time) in seconds between custom city announcements for each business.
-- Ejemplo / Example: 300 segundos = 5 minutos. Administradores ignoran este cooldown / Admins ignore this cooldown.
Config.AnnouncementCooldown = 300

-- Sistema de Logs (Discord Webhooks) / Logging System
Config.Logs = {
    -- Pon aquí la URL de tu webhook de Discord / Put your Discord webhook URL here. (Leave empty "" to disable)
    WebhookURL = "https://canary.discord.com/api/webhooks/1517539550291951768/vEt9UIgALZY9X6EzfFqKr7pC9YrhGKy46IXxMGGcloFR7JHWU2PQTbmnrSNfyJXUEgsJ",
    
    -- Nombre que tendrá el bot al enviar el mensaje / Bot name
    BotName = "Negocios GTA Logs",
    
    -- Imagen de perfil del bot (URL) / Bot avatar URL
    BotAvatar = "https://i.imgur.com/8Qj874M.png",
    
    -- Colores en formato Decimal para cada tipo de log / Decimal colors for each log type
    Colors = {
        CreateBusiness = 3066993, -- Verde
        DeleteBusiness = 15158332, -- Rojo
        ToggleOpen = 3066993, -- Verde
        ToggleClose = 15158332, -- Rojo
        Announcement = 3447003, -- Azul
        CreateEvent = 10181046, -- Morado
        DeleteEvent = 15158332 -- Rojo
    }
}

-- Configuración de Publicidad (Negocios Patrocinados) / Ads Configuration (Sponsored Businesses)
Config.Ads = {
    -- Habilitar o deshabilitar el sistema de patrocinados / Enable or disable sponsored system
    Enabled = true,
    
    -- Precio para patrocinar el negocio / Cost to sponsor the business
    Cost = 500,
    
    -- Duración del patrocinio en horas / Sponsor duration in hours
    DurationHours = 24,
    
    -- Tipo de cuenta de donde se cobrará / Account type to charge from ('society' or 'bank')
    -- Si está en 'society' pero el negocio no tiene un job asignado, usará 'bank' como respaldo automáticamente.
    -- If 'society' but the business has no job assigned, it will default to 'bank'.
    PaymentAccount = 'bank'
}

