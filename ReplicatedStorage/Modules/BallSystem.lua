-- BallSystem.lua
-- ReplicatedStorage/Modules/BallSystem
-- Logika utama bola energi (dijalankan di server melalui BallManager)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local CollectionService = game:GetService("CollectionService")

local BallSystem = {}
BallSystem.__index = BallSystem

-- Konstanta
local INITIAL_SPEED = 30       -- studs per detik
local SPEED_INCREMENT = 5      -- tambahan kecepatan per parry
local MAX_SPEED = 120
local BALL_SIZE = Vector3.new(2.5, 2.5, 2.5)
local PARRY_REWARD_COINS = 5
local KILL_REWARD_COINS = 10

-- State bola
local ballPart = nil
local targetPlayer = nil
local currentSpeed = INITIAL_SPEED
local lastParryPlayer = nil
local isActive = false

-- Remote events
local RemoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local ParryBallEvent = RemoteEvents:WaitForChild("ParryBall")
local BallTargetEvent = RemoteEvents:WaitForChild("BallTarget")
local SpawnEffectEvent = RemoteEvents:WaitForChild("SpawnEffect")

-- Pilih target acak dari pemain hidup (bukan target sekarang)
local function pickRandomTarget(excludePlayer, aliveGetter)
    local alive = aliveGetter()
    local candidates = {}
    for _, p in ipairs(alive) do
        if p ~= excludePlayer then
            candidates[#candidates + 1] = p
        end
    end
    if #candidates == 0 then
        -- Hanya 1 pemain tersisa, kembalikan dia
        return alive[1]
    end
    return candidates[math.random(1, #candidates)]
end

-- Buat bola
local function createBall()
    local ball = Instance.new("Part")
    ball.Name = "EnergyBall"
    ball.Shape = Enum.PartType.Ball
    ball.Size = BALL_SIZE
    ball.BrickColor = BrickColor.new("Cyan")
    ball.Material = Enum.Material.Neon
    ball.CastShadow = false
    ball.CanCollide = false
    ball.Anchored = true  -- Anchored, kita gerakkan manual via CFrame

    -- Glow / SelectionBox effect
    local selectionBox = Instance.new("SelectionSphere")
    selectionBox.SurfaceTransparency = 0.7
    selectionBox.SurfaceColor3 = Color3.fromRGB(0, 255, 255)
    selectionBox.Adornee = ball
    selectionBox.Parent = ball

    -- Trail
    local attachment0 = Instance.new("Attachment", ball)
    attachment0.Position = Vector3.new(0, 1, 0)
    local attachment1 = Instance.new("Attachment", ball)
    attachment1.Position = Vector3.new(0, -1, 0)

    local trail = Instance.new("Trail")
    trail.Attachment0 = attachment0
    trail.Attachment1 = attachment1
    trail.Lifetime = 0.4
    trail.MinLength = 0
    trail.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 255, 255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 100, 200)),
    })
    trail.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0),
        NumberSequenceKeypoint.new(1, 1),
    })
    trail.Parent = ball

    -- Particle
    local particles = Instance.new("ParticleEmitter")
    particles.Color = ColorSequence.new(Color3.fromRGB(0, 200, 255))
    particles.LightEmission = 1
    particles.LightInfluence = 0
    particles.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.3),
        NumberSequenceKeypoint.new(1, 0),
    })
    particles.Speed = NumberRange.new(2, 5)
    particles.Lifetime = NumberRange.new(0.2, 0.5)
    particles.Rate = 50
    particles.Parent = ball

    -- Point light
    local light = Instance.new("PointLight")
    light.Brightness = 5
    light.Color = Color3.fromRGB(0, 200, 255)
    light.Range = 20
    light.Parent = ball

    local ballSpawn = workspace:FindFirstChild("BallSpawn")
    ball.Position = ballSpawn and ballSpawn.Position or Vector3.new(0, 10, 0)
    ball.Parent = workspace

    CollectionService:AddTag(ball, "EnergyBall")
    return ball
end

-- Buat efek ledakan
local function createExplosionEffect(position, player)
    SpawnEffectEvent:FireAllClients({
        type = "Explosion",
        position = position,
        playerName = player and player.Name or nil
    })

    -- Server-side visual
    local explosion = Instance.new("Explosion")
    explosion.Position = position
    explosion.BlastRadius = 0
    explosion.BlastPressure = 0
    explosion.ExplosionType = Enum.ExplosionType.NoCraters
    explosion.Parent = workspace
    Debris:AddItem(explosion, 2)
end

-- Buat efek parry
local function createParryEffect(position)
    SpawnEffectEvent:FireAllClients({
        type = "Parry",
        position = position
    })
end

-- Update target indicator ke semua client
local function broadcastTarget(target)
    BallTargetEvent:FireAllClients({
        targetName = target and target.Name or nil,
        targetId = target and target.UserId or nil
    })
end

-- Fungsi utama gerak bola (dipanggil di RunService)
local moveConnection = nil

local function startMoving(aliveGetter, onKillCallback)
    if moveConnection then
        moveConnection:Disconnect()
        moveConnection = nil
    end

    moveConnection = RunService.Heartbeat:Connect(function(dt)
        if not isActive then
            moveConnection:Disconnect()
            moveConnection = nil
            return
        end

        if not ballPart or not ballPart.Parent then
            isActive = false
            moveConnection:Disconnect()
            moveConnection = nil
            return
        end

        if not targetPlayer or not targetPlayer.Character then
            -- Cari target baru
            local alive = aliveGetter()
            if #alive == 0 then
                isActive = false
                return
            end
            targetPlayer = alive[math.random(1, #alive)]
            broadcastTarget(targetPlayer)
            return
        end

        local targetHRP = targetPlayer.Character:FindFirstChild("HumanoidRootPart")
        if not targetHRP then return end

        local ballPos = ballPart.Position
        local targetPos = targetHRP.Position

        local direction = (targetPos - ballPos)
        local dist = direction.Magnitude

        if dist < 3 then
            -- Bola mencapai target - HIT!
            createExplosionEffect(ballPos, lastParryPlayer)

            -- Matikan target
            local humanoid = targetPlayer.Character:FindFirstChild("Humanoid")
            if humanoid and humanoid.Health > 0 then
                humanoid.Health = 0
                if onKillCallback then
                    onKillCallback(targetPlayer, lastParryPlayer)
                end
            end

            -- Pilih target baru setelah delay
            task.spawn(function()
                task.wait(1.5)
                if not isActive then return end
                local alive = aliveGetter()
                if #alive == 0 then
                    isActive = false
                    return
                end
                targetPlayer = alive[math.random(1, #alive)]
                broadcastTarget(targetPlayer)
                -- Reset kecepatan sedikit setelah kill
                currentSpeed = math.max(INITIAL_SPEED, currentSpeed - 10)

                -- Teleport bola ke tengah
                local ballSpawn = workspace:FindFirstChild("BallSpawn")
                ballPart.Position = ballSpawn and ballSpawn.Position or Vector3.new(0, 10, 0)
            end)
            return
        end

        -- Gerakkan bola
        local step = math.min(currentSpeed * dt, dist)
        local newPos = ballPos + direction.Unit * step
        ballPart.CFrame = CFrame.new(newPos, targetPos)
    end)
end

-- PUBLIC API

-- Spawn bola baru
function BallSystem:Spawn(aliveGetter, onKillCallback)
    self:Destroy()
    currentSpeed = INITIAL_SPEED
    lastParryPlayer = nil

    ballPart = createBall()
    isActive = true

    -- Pilih target awal
    local alive = aliveGetter()
    if #alive == 0 then return end
    targetPlayer = alive[math.random(1, #alive)]
    broadcastTarget(targetPlayer)

    SpawnEffectEvent:FireAllClients({type = "BallSpawn", position = ballPart.Position})

    startMoving(aliveGetter, onKillCallback)
    return ballPart
end

-- Proses parry dari BOT (tidak perlu validasi jarak/remote)
function BallSystem:TryParryBot(fakePlayer, aliveGetter)
    if not isActive then return false end
    if not ballPart then return false end
    if not targetPlayer then return false end
    if targetPlayer.Name ~= fakePlayer.Name then return false end

    -- PARRY BOT BERHASIL
    lastParryPlayer = fakePlayer

    createParryEffect(ballPart.Position)

    currentSpeed = math.min(currentSpeed + SPEED_INCREMENT, MAX_SPEED)

    local newTarget = pickRandomTarget(fakePlayer, aliveGetter)
    targetPlayer = newTarget
    broadcastTarget(newTarget)

    return true
end

-- Proses parry dari pemain
function BallSystem:TryParry(player, aliveGetter)
    if not isActive then return false, "Bola tidak aktif" end
    if not ballPart then return false, "Bola tidak ada" end

    -- Validasi: Apakah ini target saat ini?
    if player ~= targetPlayer then
        return false, "Kamu bukan target saat ini"
    end

    -- Validasi jarak parry (harus dekat dengan bola)
    local character = player.Character
    if not character then return false, "Character tidak ada" end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return false, "HRP tidak ada" end

    local dist = (hrp.Position - ballPart.Position).Magnitude
    if dist > 20 then
        return false, "Terlalu jauh untuk parry (dist: " .. math.floor(dist) .. ")"
    end

    -- PARRY BERHASIL!
    lastParryPlayer = player

    -- Efek
    createParryEffect(ballPart.Position)

    -- Tambah kecepatan
    currentSpeed = math.min(currentSpeed + SPEED_INCREMENT, MAX_SPEED)

    -- Pindahkan target ke pemain lain
    local newTarget = pickRandomTarget(player, aliveGetter)
    targetPlayer = newTarget
    broadcastTarget(newTarget)

    -- Reward coins
    local DataManager = require(game.ServerScriptService:WaitForChild("DataManager"))
    DataManager:AddCoins(player, PARRY_REWARD_COINS)

    return true, "Parry berhasil! Target: " .. (newTarget and newTarget.Name or "?")
end

-- Freeze bola (ability)
function BallSystem:Freeze(duration)
    if not isActive then return end
    isActive = false
    task.delay(duration, function()
        isActive = true
    end)
end

-- Hancurkan bola
function BallSystem:Destroy()
    isActive = false
    if moveConnection then
        moveConnection:Disconnect()
        moveConnection = nil
    end
    if ballPart and ballPart.Parent then
        -- Efek destroy
        SpawnEffectEvent:FireAllClients({type = "BallDespawn", position = ballPart.Position})
        ballPart:Destroy()
        ballPart = nil
    end
    targetPlayer = nil
    lastParryPlayer = nil
    currentSpeed = INITIAL_SPEED
end

function BallSystem:GetTarget()
    return targetPlayer
end

function BallSystem:GetSpeed()
    return currentSpeed
end

function BallSystem:IsActive()
    return isActive
end

function BallSystem:GetLastParryPlayer()
    return lastParryPlayer
end

return BallSystem
