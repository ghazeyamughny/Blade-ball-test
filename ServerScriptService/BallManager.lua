-- BallManager.lua
-- ServerScriptService/BallManager
-- Server-side handler untuk bola, validasi parry, dan kill

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local RemoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")

local BallSystem = require(Modules:WaitForChild("BallSystem"))
local RoundSystem = require(Modules:WaitForChild("RoundSystem"))

local ParryBallEvent = RemoteEvents:WaitForChild("ParryBall")
local UpdateUIEvent = RemoteEvents:WaitForChild("UpdateUI")

local BallManager = {}

-- Anti-cheat: parry cooldown tracking per player
local parryCooldowns = {}
local PARRY_COOLDOWN = 0.5  -- detik minimum antar parry

-- Anti-cheat: rate limiting parry
local parryAttempts = {}
local PARRY_RATE_WINDOW = 2
local PARRY_RATE_MAX = 5

local function checkParryRateLimit(player)
    local uid = player.UserId
    local now = tick()
    if not parryAttempts[uid] then
        parryAttempts[uid] = {time = now, count = 1}
        return false
    end
    local t = parryAttempts[uid]
    if now - t.time > PARRY_RATE_WINDOW then
        t.time = now
        t.count = 1
        return false
    end
    t.count = t.count + 1
    if t.count > PARRY_RATE_MAX then
        warn("[AntiCheat] Parry spam detected: " .. player.Name)
        return true
    end
    return false
end

-- Handle kill: beri reward ke killer
local function onPlayerKilled(deadPlayer, killerPlayer)
    local DataManager = require(game.ServerScriptService:WaitForChild("DataManager"))
    DataManager:ResetStreak(deadPlayer)

    if killerPlayer and killerPlayer ~= deadPlayer then
        DataManager:AddKill(killerPlayer)
        DataManager:AddCoins(killerPlayer, 10)
        UpdateUIEvent:FireClient(killerPlayer, {
            type = "KillFeed",
            message = "Kamu membunuh " .. deadPlayer.Name .. "! +10 Coins"
        })
    end

    -- Notif ke semua
    UpdateUIEvent:FireAllClients({
        type = "KillAnnouncement",
        dead = deadPlayer.Name,
        killer = killerPlayer and killerPlayer.Name or "Bola"
    })
end

-- Spawn bola
function BallManager:SpawnBall()
    BallSystem:Spawn(
        function()
            return RoundSystem:GetAlivePlayers()
        end,
        onPlayerKilled
    )
end

-- Hentikan bola
function BallManager:StopBall()
    BallSystem:Destroy()
end

-- Freeze bola (dari ability)
function BallManager:FreezeBall(duration)
    BallSystem:Freeze(duration)
end

-- Handle parry dari client (divalidasi server)
ParryBallEvent.OnServerEvent:Connect(function(player)
    if RoundSystem:GetState() ~= "Playing" then return end
    if RoundSystem:IsSpectator(player) then return end

    -- Rate limit check
    if checkParryRateLimit(player) then
        warn("[AntiCheat] Parry rate limit: " .. player.Name)
        return
    end

    -- Cooldown check
    local uid = player.UserId
    local now = tick()
    if parryCooldowns[uid] and now - parryCooldowns[uid] < PARRY_COOLDOWN then
        return  -- Silent reject, bukan exploit
    end
    parryCooldowns[uid] = now

    -- Validasi dan proses parry
    local success, message = BallSystem:TryParry(player, function()
        return RoundSystem:GetAlivePlayers()
    end)

    if success then
        -- Feedback ke player
        UpdateUIEvent:FireClient(player, {
            type = "ParrySuccess",
            message = "Parry! +" .. 5 .. " Coins"
        })
    else
        -- Feedback gagal (timing/jarak salah)
        UpdateUIEvent:FireClient(player, {
            type = "ParryFail",
            message = message
        })
    end
end)

-- Cleanup saat player leave
Players.PlayerRemoving:Connect(function(player)
    parryCooldowns[player.UserId] = nil
    parryAttempts[player.UserId] = nil
end)

return BallManager
