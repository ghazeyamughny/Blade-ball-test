-- DataManager.lua
-- ServerScriptService/DataManager
-- Mengelola penyimpanan data pemain menggunakan DataStore

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local DataManager = {}
DataManager.__index = DataManager

-- DataStore
local PlayerDataStore = DataStoreService:GetDataStore("BladeBallPlayerData_v1")

-- Default data struktur
local DEFAULT_DATA = {
    wins = 0,
    coins = 0,
    kills = 0,
    deaths = 0,
    highestStreak = 0,
    currentStreak = 0,
    -- Shop items yang dimiliki
    ownedItems = {},
    -- Equipped items
    equippedSwordSkin = "Default",
    equippedBallSkin = "Default",
    equippedKillEffect = "Default",
    equippedExplosionEffect = "Default",
    equippedEmote = "Default",
    -- Ability equipped
    equippedAbility = "Dash",
}

-- Cache data in-memory
local playerData = {}

-- Deep copy table
local function deepCopy(original)
    local copy = {}
    for k, v in pairs(original) do
        if type(v) == "table" then
            copy[k] = deepCopy(v)
        else
            copy[k] = v
        end
    end
    return copy
end

-- Load data pemain dari DataStore
function DataManager:LoadPlayerData(player)
    local userId = player.UserId
    local success, data = pcall(function()
        return PlayerDataStore:GetAsync("Player_" .. userId)
    end)

    if success and data then
        -- Merge dengan default (untuk field baru)
        local loadedData = deepCopy(DEFAULT_DATA)
        for k, v in pairs(data) do
            loadedData[k] = v
        end
        playerData[userId] = loadedData
    else
        playerData[userId] = deepCopy(DEFAULT_DATA)
        if not success then
            warn("[DataManager] Failed to load data for " .. player.Name .. ": " .. tostring(data))
        end
    end

    -- Set leaderstats
    DataManager:SetupLeaderstats(player)
    return playerData[userId]
end

-- Setup leaderboard in-game
function DataManager:SetupLeaderstats(player)
    local userId = player.UserId
    local data = playerData[userId]
    if not data then return end

    local leaderstats = Instance.new("Folder")
    leaderstats.Name = "leaderstats"
    leaderstats.Parent = player

    local wins = Instance.new("IntValue")
    wins.Name = "Wins"
    wins.Value = data.wins
    wins.Parent = leaderstats

    local coins = Instance.new("IntValue")
    coins.Name = "Coins"
    coins.Value = data.coins
    coins.Parent = leaderstats

    local kills = Instance.new("IntValue")
    kills.Name = "Kills"
    kills.Value = data.kills
    kills.Parent = leaderstats

    local streak = Instance.new("IntValue")
    streak.Name = "Streak"
    streak.Value = data.highestStreak
    streak.Parent = leaderstats
end

-- Save data pemain ke DataStore
function DataManager:SavePlayerData(player)
    local userId = player.UserId
    local data = playerData[userId]
    if not data then return end

    -- Sync dari leaderstats sebelum save
    local leaderstats = player:FindFirstChild("leaderstats")
    if leaderstats then
        data.wins = leaderstats.Wins and leaderstats.Wins.Value or data.wins
        data.coins = leaderstats.Coins and leaderstats.Coins.Value or data.coins
        data.kills = leaderstats.Kills and leaderstats.Kills.Value or data.kills
    end

    local success, err = pcall(function()
        PlayerDataStore:SetAsync("Player_" .. userId, data)
    end)

    if not success then
        warn("[DataManager] Failed to save data for " .. player.Name .. ": " .. tostring(err))
    else
        print("[DataManager] Saved data for " .. player.Name)
    end

    playerData[userId] = nil
end

-- Get data pemain
function DataManager:GetPlayerData(player)
    return playerData[player.UserId]
end

-- Tambah coins
function DataManager:AddCoins(player, amount)
    local data = playerData[player.UserId]
    if not data then return end
    data.coins = data.coins + amount
    local leaderstats = player:FindFirstChild("leaderstats")
    if leaderstats and leaderstats:FindFirstChild("Coins") then
        leaderstats.Coins.Value = data.coins
    end
end

-- Tambah kills
function DataManager:AddKill(player)
    local data = playerData[player.UserId]
    if not data then return end
    data.kills = data.kills + 1
    data.currentStreak = data.currentStreak + 1
    if data.currentStreak > data.highestStreak then
        data.highestStreak = data.currentStreak
    end
    local leaderstats = player:FindFirstChild("leaderstats")
    if leaderstats then
        if leaderstats:FindFirstChild("Kills") then
            leaderstats.Kills.Value = data.kills
        end
        if leaderstats:FindFirstChild("Streak") then
            leaderstats.Streak.Value = data.highestStreak
        end
    end
end

-- Reset streak saat mati
function DataManager:ResetStreak(player)
    local data = playerData[player.UserId]
    if not data then return end
    data.currentStreak = 0
end

-- Tambah win
function DataManager:AddWin(player)
    local data = playerData[player.UserId]
    if not data then return end
    data.wins = data.wins + 1
    -- Bonus coins untuk menang
    DataManager:AddCoins(player, 50)
    local leaderstats = player:FindFirstChild("leaderstats")
    if leaderstats and leaderstats:FindFirstChild("Wins") then
        leaderstats.Wins.Value = data.wins
    end
end

-- Beli item
function DataManager:PurchaseItem(player, itemId, price)
    local data = playerData[player.UserId]
    if not data then return false, "Data tidak ditemukan" end
    if data.coins < price then return false, "Coins tidak cukup" end
    if data.ownedItems[itemId] then return false, "Item sudah dimiliki" end

    data.coins = data.coins - price
    data.ownedItems[itemId] = true

    local leaderstats = player:FindFirstChild("leaderstats")
    if leaderstats and leaderstats:FindFirstChild("Coins") then
        leaderstats.Coins.Value = data.coins
    end

    return true, "Berhasil membeli " .. itemId
end

-- Equip item
function DataManager:EquipItem(player, category, itemId)
    local data = playerData[player.UserId]
    if not data then return false end
    if not data.ownedItems[itemId] and itemId ~= "Default" then
        return false
    end
    data["equipped" .. category] = itemId
    return true
end

-- Auto-save setiap 60 detik
local function autoSave()
    while true do
        task.wait(60)
        for _, player in ipairs(Players:GetPlayers()) do
            DataManager:SavePlayerData(player)
            -- Reload fresh agar tidak kehilangan data
            DataManager:LoadPlayerData(player)
        end
    end
end
task.spawn(autoSave)

return DataManager
