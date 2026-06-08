-- BotManager.lua
-- ServerScriptService/BotManager
-- Spawn 10 bot langsung saat server start

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local BallSystem = require(Modules:WaitForChild("BallSystem"))

local BOT_COUNT = 10
local BOT_NAMES = {
    "ShadowBlade", "NeonStriker", "VoidHunter", "StormRider", "IronFist",
    "GhostParry", "ThunderWolf", "CrimsonEdge", "SilverMoon", "DarkPulse"
}

local bots = {}

-- ============================================================
-- BUAT MODEL BOT
-- ============================================================
local function createBotCharacter(name, spawnPos)
    local model = Instance.new("Model")
    model.Name = name

    local hrp = Instance.new("Part")
    hrp.Name = "HumanoidRootPart"
    hrp.Size = Vector3.new(2, 2, 1)
    hrp.CFrame = CFrame.new(spawnPos)
    hrp.Anchored = false
    hrp.CanCollide = true
    hrp.Transparency = 1
    hrp.Parent = model

    local torso = Instance.new("Part")
    torso.Name = "Torso"
    torso.Size = Vector3.new(2, 2, 1)
    torso.CFrame = CFrame.new(spawnPos)
    torso.BrickColor = BrickColor.Random()
    torso.Material = Enum.Material.SmoothPlastic
    torso.Parent = model

    local head = Instance.new("Part")
    head.Name = "Head"
    head.Size = Vector3.new(2, 1, 1)
    head.CFrame = CFrame.new(spawnPos + Vector3.new(0, 1.5, 0))
    head.BrickColor = BrickColor.new("Bright yellow")
    head.Parent = model

    -- Name tag
    local billboard = Instance.new("BillboardGui")
    billboard.Size = UDim2.new(0, 120, 0, 35)
    billboard.StudsOffset = Vector3.new(0, 3, 0)
    billboard.AlwaysOnTop = true
    billboard.Parent = head

    local nameLabel = Instance.new("TextLabel", billboard)
    nameLabel.Size = UDim2.new(1, 0, 1, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = "🤖 " .. name
    nameLabel.TextColor3 = Color3.fromRGB(255, 255, 100)
    nameLabel.TextScaled = true
    nameLabel.Font = Enum.Font.GothamBold

    -- Weld parts ke HRP
    local weldTorso = Instance.new("WeldConstraint")
    weldTorso.Part0 = hrp
    weldTorso.Part1 = torso
    weldTorso.Parent = hrp

    local weldHead = Instance.new("WeldConstraint")
    weldHead.Part0 = hrp
    weldHead.Part1 = head
    weldHead.Parent = hrp

    -- Humanoid
    local humanoid = Instance.new("Humanoid")
    humanoid.MaxHealth = 100
    humanoid.Health = 100
    humanoid.WalkSpeed = 14
    humanoid.DisplayName = name
    humanoid.Parent = model

    model.PrimaryPart = hrp
    model.Parent = workspace

    print("[BotManager] Created bot: " .. name .. " at " .. tostring(spawnPos))
    return model
end

-- ============================================================
-- AI BOT: gerak acak + parry saat jadi target
-- ============================================================
local function runBotAI(bot)
    task.spawn(function()
        while true do
            task.wait(0.2)

            local model = bot.model
            if not model or not model.Parent then break end

            local humanoid = model:FindFirstChild("Humanoid")
            if not humanoid or humanoid.Health <= 0 then break end

            local hrp = model:FindFirstChild("HumanoidRootPart")
            if not hrp then break end

            -- Cek apakah bot ini target bola
            local target = BallSystem:GetTarget()
            if target and target.Name == bot.name then
                -- Jadi target: tunggu sebentar lalu coba parry
                task.wait(math.random(30, 80) / 100)

                -- Cek lagi
                local currentTarget = BallSystem:GetTarget()
                if currentTarget and currentTarget.Name == bot.name then
                    if math.random(100) <= 65 then
                        -- Parry berhasil
                        local RoundSystem = require(Modules:WaitForChild("RoundSystem"))
                        BallSystem:TryParryBot(
                            { Name = bot.name, UserId = bot.userId, Character = model },
                            function() return RoundSystem:GetAlivePlayers() end
                        )
                    end
                    -- Kalau tidak parry, bola akan kena dan bot mati via Humanoid.Died
                end
            else
                -- Tidak jadi target: gerak acak
                local angle = math.random() * math.pi * 2
                local radius = math.random(15, 40)
                local targetPos = Vector3.new(
                    math.cos(angle) * radius,
                    hrp.Position.Y,
                    math.sin(angle) * radius
                )
                local dir = (targetPos - hrp.Position)
                if dir.Magnitude > 3 then
                    hrp.AssemblyLinearVelocity = Vector3.new(
                        dir.Unit.X * 10,
                        hrp.AssemblyLinearVelocity.Y,
                        dir.Unit.Z * 10
                    )
                end
                task.wait(math.random(1, 3))
            end
        end
    end)
end

-- ============================================================
-- SPAWN SEMUA BOT — dipanggil langsung saat server start
-- ============================================================
local function spawnBots()
    -- Bersihkan bot lama
    for _, bot in ipairs(bots) do
        if bot.model and bot.model.Parent then
            bot.model:Destroy()
        end
    end
    bots = {}

    print("[BotManager] Spawning " .. BOT_COUNT .. " bots...")

    for i = 1, BOT_COUNT do
        local botName = BOT_NAMES[i] or ("Bot_" .. i)
        local angle = (i / BOT_COUNT) * math.pi * 2
        local spawnPos = Vector3.new(
            math.cos(angle) * 35,
            5,
            math.sin(angle) * 35
        )

        local model = createBotCharacter(botName, spawnPos)
        local bot = {
            name = botName,
            model = model,
            userId = -(i * 1000),
            isAlive = true,
        }
        bots[#bots + 1] = bot

        -- Handle kematian bot
        local humanoid = model:FindFirstChild("Humanoid")
        if humanoid then
            humanoid.Died:Connect(function()
                bot.isAlive = false
                print("[BotManager] Bot mati: " .. botName)

                -- Cek menang via RoundSystem
                task.spawn(function()
                    task.wait(0.5)
                    local RoundSystem = require(Modules:WaitForChild("RoundSystem"))
                    RoundSystem:HandleBotDeath(bot)
                end)

                task.delay(3, function()
                    if model and model.Parent then
                        model:Destroy()
                    end
                end)
            end)
        end

        runBotAI(bot)
        task.wait(0.05)
    end

    print("[BotManager] Semua " .. BOT_COUNT .. " bot berhasil di-spawn!")
end

-- ============================================================
-- MODULE API
-- ============================================================
local BotManager = {}

function BotManager:SpawnBots()
    spawnBots()
end

function BotManager:ClearBots()
    for _, bot in ipairs(bots) do
        if bot.model and bot.model.Parent then
            bot.model:Destroy()
        end
    end
    bots = {}
    print("[BotManager] Semua bot dibersihkan")
end

function BotManager:GetBotPlayers()
    local result = {}
    for _, bot in ipairs(bots) do
        if bot.isAlive and bot.model and bot.model.Parent then
            result[#result + 1] = {
                Name = bot.name,
                UserId = bot.userId,
                Character = bot.model,
                IsBot = true,
            }
        end
    end
    return result
end

function BotManager:GetAliveBotCount()
    local count = 0
    for _, bot in ipairs(bots) do
        if bot.isAlive then count += 1 end
    end
    return count
end

-- ============================================================
-- SPAWN LANGSUNG SAAT SERVER START (tanpa tunggu state apapun)
-- ============================================================
task.wait(2) -- tunggu arena selesai dibuat oleh RoundManager
spawnBots()

return BotManager
