Config = {}

-- Idioma / Language: 'es' o 'en'
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
    -- Útil para darte acceso de forma directa e infalible mediante tu licencia.
    -- Ejemplos: 'license:1a2b3c4d5e...', 'steam:1100001...', 'discord:123456789...'
    Identifiers = {
        -- 'license:2e8c8ee08b18e3bcde787b443072344ca88989c3',
    },

    ACEPermissions = {
        'negocios.admin',
    }
}

-- Configuración de iconos en el mapa (Blips)
Config.Blips = {
    -- Si el negocio está abierto, ¿qué color de blip quieres? (2 = verde por defecto en GTA)
    ColorAbierto = 2,
    -- Si el negocio está cerrado, ¿qué color de blip quieres? (0 = blanco)
    ColorCerrado = 0,
    -- Tamaño del icono en el mapa
    Escala = 0.8
}

-- Configuración de Categorías de Negocios
-- Puedes añadir o quitar categorías libremente.
-- Las claves (ej: 'tienda', 'restaurante') se guardarán en la base de datos.
Config.Categories = {
    tienda = { label = "Tienda", icon = "🛒", color = "#3b82f6", blipId = 52 },
    restaurante = { label = "Restaurante", icon = "🍔", color = "#ef4444", blipId = 89 },
    taller = { label = "Taller", icon = "🔧", color = "#8b5cf6", blipId = 446 },
    bar = { label = "Bar", icon = "🍸", color = "#ec4899", blipId = 93 },
    club = { label = "Club", icon = "🎵", color = "#a855f7", blipId = 614 },
    gasolinera = { label = "Gasolinera", icon = "⛽", color = "#f59e0b", blipId = 361 },
    otro = { label = "Otro", icon = "📍", color = "#64748b", blipId = 66 }
}

-- Configuración de Notificaciones
Config.Notifications = {
    -- Tipo de notificación preferida: 'ox_lib', 'phone' (qs-smartphone), 'gta' (nativa), o 'custom' (React HUD)
    Type = 'custom',
    
    -- Notificar a todos los jugadores cuando un negocio abre o cierra
    NotifyOnToggle = true,
    
    -- Notificar a todos los jugadores cuando un negocio abre (Legacy compatibility)
    NotifyOnOpen = true
}

-- Cooldown (tiempo de espera) en segundos entre anuncios personalizados por cada negocio.
-- Ejemplo: 300 segundos = 5 minutos. Los administradores ignoran este cooldown.
Config.AnnouncementCooldown = 300

