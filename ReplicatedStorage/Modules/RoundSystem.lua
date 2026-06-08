-- RoundSystem.lua
-- ReplicatedStorage/Modules/RoundSystem
-- Mengelola alur ronde game

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local RemoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local RoundStatusEvent = RemoteEvents:WaitForChild("RoundStatus")
local UpdateUIEvent = RemoteEvents:WaitForChild("UpdateUI")
local PlayerDiedEvent = RemoteEvents:WaitForChild("PlayerDied")

local RoundSystem = {}
RoundSystem.__index = RoundSystem

-- Konstanta
local MIN_PLAYERS = 1  -- 1 pemain asli sudah cukup, sisanya diisi bot
local MAX_PLAYERS = 20
local INTERMISSION_TIME = 10
local STARTING_TIME = 5
local WIN_REWARD_COINS = 50
local KILL_REWARD_COINS = 10

-- State
local gameState = "Waiting" -- Waiting, Intermission, Starting, Playing, Winner
local alivePlayers = {}
local spectators = {}
local currentWinner = nil
local roundNumber = 0

-- Broadcast state ke semua pemain
local function broadcastState(state, data)
    gameState = state
    local payload = {state = state, data = data or {}}
    RoundStatusEvent:FireAllClients(payload)
end

-- Broadcast UI update
local function broadcastUI(uiType, data)
    UpdateUIEvent:FireAllClients({type = uiType, data = data})
end

-- Hitung pemain yang hidup (termasuk bot)
local function getAlivePlayers()
    local alive = {}
    -- Pemain asli
    for _, player in ipairs(Players:GetPlayers()) do
        if not spectators[player.UserId] then
            alive[#alive + 1] = player
        end
    end
    -- Bot (dari BotManager kalau sudah loaded)
    local ok, BotManager = pcall(function()
        return require(game.ServerScriptService:WaitForChild("BotManager", 3))
    end)
    if ok and BotManager then
        for _, botPlayer in ipairs(BotManager:GetBotPlayers()) do
            alive[#alive + 1] = botPlayer
        end
    end
    return alive
end

-- Respawn semua pemain ke spawn arena
local function spawnAllPlayers()
    local arena = workspace:FindFirstChild("Arena")
    local spawnPoints = workspace:FindFirstChild("SpawnPoints")
    
    for i, player in ipairs(Players:GetPlayers()) do
        spectators[player.UserId] = nil
        if player.Character then
            -- Humanoid reset
            local humanoid = player.Character:FindFirstChild("Humanoid")
            if humanoid then
                humanoid.Health = humanoid.MaxHealth
            end
        else
            player:LoadCharacter()
        end
        
        -- Posisikan ke spawn point
        task.spawn(function()
            task.wait(0.1)
            local character = player.Character
            if not character then return end
            local hrp = character:FindFirstChild("HumanoidRootPart")
            if not hrp then return end
            
            if spawnPoints then
                local spawnList = spawnPoints:GetChildren()
                if #spawnList > 0 then
                    local spawnPart = spawnList[(i - 1) % #spawnList + 1]
                    hrp.CFrame = spawnPart.CFrame + Vector3.new(0, 3, 0)
                end
            else
                -- Default spawn melingkar di arena
                local angle = (i - 1) * (math.pi * 2 / #Players:GetPlayers())
                local radius = 25
                hrp.CFrame = CFrame.new(
                    math.cos(angle) * radius,
                    5,
                    math.sin(angle) * radius
                )
            end
        end)
    end
end

-- Matikan semua kontrol selama countdown (opsional)
local function freezePlayers(freeze)
    for _, player in ipairs(Players:GetPlayers()) do
        if player.Character then
            local humanoid = player.Character:FindFirstChild("Humanoid")
            if humanoid then
                if freeze then
                    humanoid.WalkSpeed = 0
                    humanoid.JumpPower = 0
                else
                    humanoid.WalkSpeed = 16
                    humanoid.JumpPower = 50
                end
            end
        end
    end
end

-- Handle kematian bot
function RoundSystem:HandleBotDeath(bot)
    if gameState ~= "Playing" then return end

    -- Broadcast notif
    local RemoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
    local UpdateUIEvent = RemoteEvents:WaitForChild("UpdateUI")
    UpdateUIEvent:FireAllClients({
        type = "KillAnnouncement",
        dead = bot.name,
        killer = "Bola"
    })

    -- Cek kondisi menang
    local alive = getAlivePlayers()
    local aliveCount = #alive
    UpdateUIEvent:FireAllClients({type = "AliveCount", data = {count = aliveCount}})

    if aliveCount <= 1 then
        if aliveCount == 1 then
            local winner = alive[1]
            -- Cek apakah winner pemain asli atau bot
            if winner.IsBot then
                RoundSystem:EndRound(nil)
            else
                RoundSystem:AnnounceWinner(winner)
            end
        else
            RoundSystem:EndRound(nil)
        end
    end
end

-- Handle kematian pemain
function RoundSystem:HandlePlayerDeath(player)
    if gameState ~= "Playing" then return end
    if spectators[player.UserId] then return end

    spectators[player.UserId] = true
    PlayerDiedEvent:FireAllClients({playerName = player.Name})

    -- Berikan coins kill ke target terakhir bola
    -- (akan di-handle BallManager yang tahu siapa yang mem-parry terakhir)

    -- Update UI
    local alive = getAlivePlayers()
    broadcastUI("AliveCount", {count = #alive})

    -- Cek kondisi menang
    if #alive <= 1 then
        if #alive == 1 then
            RoundSystem:AnnounceWinner(alive[1])
        else
            -- Semua mati, restart tanpa winner
            RoundSystem:EndRound(nil)
        end
    end
end

-- Handle pemain keluar game
function RoundSystem:HandlePlayerLeave(player)
    spectators[player.UserId] = nil
    if gameState == "Playing" then
        local alive = getAlivePlayers()
        if #alive <= 1 then
            if #alive == 1 then
                RoundSystem:AnnounceWinner(alive[1])
            else
                RoundSystem:EndRound(nil)
            end
        end
    end
end

-- Umumkan pemenang
function RoundSystem:AnnounceWinner(player)
    currentWinner = player
    broadcastState("Winner", {winnerName = player and player.Name or "Tidak Ada"})

    -- Beri reward
    if player then
        local DataManager = require(game.ServerScriptService:WaitForChild("DataManager"))
        DataManager:AddWin(player)
        DataManager:AddCoins(player, WIN_REWARD_COINS)
    end

    task.wait(5)
    RoundSystem:EndRound(player)
end

-- Akhiri ronde
function RoundSystem:EndRound(winner)
    currentWinner = nil
    -- Reset semua spectator
    for k in pairs(spectators) do
        spectators[k] = nil
    end
    broadcastState("Intermission", {})
end

-- Main game loop
function RoundSystem:StartLoop()
    task.spawn(function()
        while true do
            -- WAITING
            broadcastState("Waiting", {minPlayers = MIN_PLAYERS})
            while #Players:GetPlayers() < MIN_PLAYERS do
                broadcastUI("PlayerCount", {count = #Players:GetPlayers(), min = MIN_PLAYERS})
                task.wait(2)
            end
            -- Pastikan ada minimal 1 pemain asli
            if #Players:GetPlayers() < 1 then continue end

            -- INTERMISSION
            broadcastState("Intermission", {})
            for i = INTERMISSION_TIME, 1, -1 do
                if #Players:GetPlayers() < MIN_PLAYERS then break end
                broadcastUI("Countdown", {time = i, phase = "Intermission"})
                task.wait(1)
            end

            if #Players:GetPlayers() < MIN_PLAYERS then
                continue
            end

            -- STARTING
            broadcastState("Starting", {})
            spawnAllPlayers()
            freezePlayers(true)

            for i = STARTING_TIME, 1, -1 do
                broadcastUI("Countdown", {time = i, phase = "Starting"})
                task.wait(1)
            end

            freezePlayers(false)

            -- PLAYING
            roundNumber = roundNumber + 1
            broadcastState("Playing", {round = roundNumber})
            
            -- Spawn bola (sinyal ke BallManager)
            local BallManager = require(game.ServerScriptService:WaitForChild("BallManager"))
            BallManager:SpawnBall()

            local alive = getAlivePlayers()
            broadcastUI("AliveCount", {count = #alive})

            -- Tunggu sampai ronde selesai
            while gameState == "Playing" do
                -- Cek pemain keluar arena
                for _, player in ipairs(Players:GetPlayers()) do
                    if spectators[player.UserId] then continue end
                    if player.Character then
                        local hrp = player.Character:FindFirstChild("HumanoidRootPart")
                        if hrp then
                            local pos = hrp.Position
                            local dist = math.sqrt(pos.X^2 + pos.Z^2)
                            -- Arena radius = 60
                            if dist > 62 then
                                local humanoid = player.Character:FindFirstChild("Humanoid")
                                if humanoid then
                                    humanoid.Health = 0
                                end
                            end
                        end
                    end
                end
                task.wait(0.5)
            end

            -- Setelah winner diumumkan, tunggu sebelum ronde baru
            task.wait(3)
        end
    end)
end

-- Getter untuk state saat ini
function RoundSystem:GetState()
    return gameState
end

function RoundSystem:GetAlivePlayers()
    return getAlivePlayers()
end

function RoundSystem:IsSpectator(player)
    return spectators[player.UserId] == true
end

return RoundSystem
