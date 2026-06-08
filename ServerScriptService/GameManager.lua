-- GameManager.lua
-- ServerScriptService/GameManager
-- Mengelola state game utama, koordinasi antar sistem

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Tunggu modules loaded
local Modules = ReplicatedStorage:WaitForChild("Modules")
local RemoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")

local RoundSystem = require(Modules:WaitForChild("RoundSystem"))
local DataManager = require(game.ServerScriptService:WaitForChild("DataManager"))

-- Remote Events
local RoundStatusEvent = RemoteEvents:WaitForChild("RoundStatus")
local UpdateUIEvent = RemoteEvents:WaitForChild("UpdateUI")
local PlayerDiedEvent = RemoteEvents:WaitForChild("PlayerDied")

-- Anti-cheat rate limiting
local remoteCallTracker = {} -- [player] = {lastCall = tick(), count = 0}
local RATE_LIMIT_WINDOW = 1  -- detik
local RATE_LIMIT_MAX = 10    -- max calls per window

local function isRateLimited(player)
    local userId = player.UserId
    local now = tick()
    if not remoteCallTracker[userId] then
        remoteCallTracker[userId] = {lastCall = now, count = 1}
        return false
    end
    local tracker = remoteCallTracker[userId]
    if now - tracker.lastCall > RATE_LIMIT_WINDOW then
        tracker.lastCall = now
        tracker.count = 1
        return false
    end
    tracker.count = tracker.count + 1
    if tracker.count > RATE_LIMIT_MAX then
        warn("[AntiCheat] Rate limit exceeded by: " .. player.Name)
        return true
    end
    return false
end

-- Setup player saat join
local function onPlayerAdded(player)
    remoteCallTracker[player.UserId] = nil

    -- Load data pemain
    DataManager:LoadPlayerData(player)

    -- Setup character
    player.CharacterAdded:Connect(function(character)
        -- Tambah tag untuk CollectionService
        local CollectionService = game:GetService("CollectionService")
        CollectionService:AddTag(character, "Player")

        -- Setup humanoid died
        local humanoid = character:WaitForChild("Humanoid")
        humanoid.Died:Connect(function()
            RoundSystem:HandlePlayerDeath(player)
        end)
    end)
end

-- Cleanup saat player leave
local function onPlayerRemoving(player)
    DataManager:SavePlayerData(player)
    remoteCallTracker[player.UserId] = nil
    RoundSystem:HandlePlayerLeave(player)
end

-- Connections
Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

-- Handle pemain yang sudah ada (jika server restart saat ada player)
for _, player in ipairs(Players:GetPlayers()) do
    onPlayerAdded(player)
end

-- Mulai Round System loop
RoundSystem:StartLoop()

print("[GameManager] Initialized successfully")
