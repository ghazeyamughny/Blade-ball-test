-- ShopSystem.lua
-- ReplicatedStorage/Modules/ShopSystem
-- Mengelola item shop dan transaksi pembelian

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local BuyItemEvent = RemoteEvents:WaitForChild("BuyItem")
local UpdateUIEvent = RemoteEvents:WaitForChild("UpdateUI")

local ShopSystem = {}

-- ============================================================
-- KATALOG ITEM SHOP
-- ============================================================
local SHOP_CATALOG = {
    -- Sword Skins
    {
        id = "sword_golden",
        name = "Golden Sword",
        category = "SwordSkin",
        price = 150,
        description = "Pedang berwarna emas berkilau",
        preview = "rbxassetid://0",
    },
    {
        id = "sword_shadow",
        name = "Shadow Blade",
        category = "SwordSkin",
        price = 300,
        description = "Pedang kegelapan dari dimensi lain",
        preview = "rbxassetid://0",
    },
    {
        id = "sword_neon",
        name = "Neon Saber",
        category = "SwordSkin",
        price = 200,
        description = "Pedang neon cyberpunk",
        preview = "rbxassetid://0",
    },

    -- Ball Skins
    {
        id = "ball_fire",
        name = "Fireball",
        category = "BallSkin",
        price = 100,
        description = "Bola api yang membara",
        preview = "rbxassetid://0",
    },
    {
        id = "ball_ice",
        name = "Ice Orb",
        category = "BallSkin",
        price = 100,
        description = "Bola es yang dingin",
        preview = "rbxassetid://0",
    },
    {
        id = "ball_lightning",
        name = "Thunder Ball",
        category = "BallSkin",
        price = 200,
        description = "Bola petir berenergi",
        preview = "rbxassetid://0",
    },
    {
        id = "ball_rainbow",
        name = "Rainbow Orb",
        category = "BallSkin",
        price = 350,
        description = "Bola pelangi warna-warni",
        preview = "rbxassetid://0",
    },

    -- Emotes
    {
        id = "emote_dance",
        name = "Victory Dance",
        category = "Emote",
        price = 80,
        description = "Menari kemenangan",
        preview = "rbxassetid://0",
    },
    {
        id = "emote_taunt",
        name = "Taunt",
        category = "Emote",
        price = 60,
        description = "Gerakan mengejek musuh",
        preview = "rbxassetid://0",
    },

    -- Kill Effects
    {
        id = "kill_confetti",
        name = "Confetti Kill",
        category = "KillEffect",
        price = 120,
        description = "Ledakan konfeti saat kill",
        preview = "rbxassetid://0",
    },
    {
        id = "kill_lightning",
        name = "Lightning Strike",
        category = "KillEffect",
        price = 180,
        description = "Petir menyambar saat kill",
        preview = "rbxassetid://0",
    },
    {
        id = "kill_skull",
        name = "Skull Boom",
        category = "KillEffect",
        price = 250,
        description = "Tengkorak meledak saat kill",
        preview = "rbxassetid://0",
    },

    -- Explosion Effects
    {
        id = "exp_galaxy",
        name = "Galaxy Explosion",
        category = "ExplosionEffect",
        price = 200,
        description = "Ledakan galaksi bintang",
        preview = "rbxassetid://0",
    },
    {
        id = "exp_nuke",
        name = "Nuke Blast",
        category = "ExplosionEffect",
        price = 280,
        description = "Ledakan nuklir mini",
        preview = "rbxassetid://0",
    },
}

-- Handle beli item dari client
BuyItemEvent.OnServerEvent:Connect(function(player, itemId)
    -- Validasi tipe data
    if type(itemId) ~= "string" then
        warn("[AntiCheat] Invalid itemId from " .. player.Name)
        return
    end

    -- Cari item di katalog
    local item = nil
    for _, catalogItem in ipairs(SHOP_CATALOG) do
        if catalogItem.id == itemId then
            item = catalogItem
            break
        end
    end

    if not item then
        UpdateUIEvent:FireClient(player, {
            type = "ShopError",
            message = "Item tidak ditemukan: " .. itemId
        })
        return
    end

    -- Proses pembelian via DataManager
    local DataManager = require(game.ServerScriptService:WaitForChild("DataManager"))
    local success, message = DataManager:PurchaseItem(player, itemId, item.price)

    UpdateUIEvent:FireClient(player, {
        type = "ShopResult",
        success = success,
        message = message,
        itemId = itemId,
        itemName = item.name,
        coins = DataManager:GetPlayerData(player) and DataManager:GetPlayerData(player).coins or 0
    })
end)

function ShopSystem:GetCatalog()
    return SHOP_CATALOG
end

function ShopSystem:GetItemById(id)
    for _, item in ipairs(SHOP_CATALOG) do
        if item.id == id then return item end
    end
    return nil
end

function ShopSystem:GetItemsByCategory(category)
    local result = {}
    for _, item in ipairs(SHOP_CATALOG) do
        if item.category == category then
            result[#result + 1] = item
        end
    end
    return result
end

return ShopSystem
