-- BallSpawner.lua
-- ServerScriptService/BallSpawner
-- Script sederhana: spawn bola langsung, tanpa bergantung RoundSystem
-- Bola mengejar pemain/bot secara acak

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

print("[BallSpawner] Script mulai...")

-- Tunggu sampai ada pemain
task.wait(4)

-- ============================================================
-- KONFIGURASI
-- ============================================================
local BALL_SPEED       = 25   -- kecepatan awal
local SPEED_INCREMENT  = 4    -- tambah kecepatan per parry
local MAX_SPEED        = 100
local PARRY_DISTANCE   = 18   -- jarak maksimal bisa parry
local PARRY_COOLDOWN   = 0.6  -- detik

-- ============================================================
-- STATE
-- ============================================================
local ball         = nil
local ballTarget   = nil  -- {Name, Character} bisa player atau bot
local ballSpeed    = BALL_SPEED
local lastParrier  = nil
local moveConn     = nil
local parryCooldowns = {}  -- [playerName] = lastParryTime

-- ============================================================
-- KUMPULKAN SEMUA TARGETS (pemain asli + bot)
-- ============================================================
local function getAllTargets()
    local targets = {}

    -- Pemain asli
    for _, player in ipairs(Players:GetPlayers()) do
        if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            local hum = player.Character:FindFirstChild("Humanoid")
            if hum and hum.Health > 0 then
                targets[#targets + 1] = {
                    Name      = player.Name,
                    Character = player.Character,
                    IsPlayer  = true,
                    Player    = player,
                }
            end
        end
    end

    -- Bot (model di workspace dengan tag "Bot" atau nama "TestBot_")
    for _, obj in ipairs(workspace:GetChildren()) do
        if obj:IsA("Model") and obj.Name:find("Bot") then
            local hrp = obj:FindFirstChild("HumanoidRootPart")
            local hum = obj:FindFirstChild("Humanoid")
            if hrp and hum and hum.Health > 0 then
                targets[#targets + 1] = {
                    Name      = obj.Name,
                    Character = obj,
                    IsPlayer  = false,
                }
            end
        end
    end

    return targets
end

-- ============================================================
-- PILIH TARGET ACAK (exclude target sekarang)
-- ============================================================
local function pickTarget(excludeName)
    local targets = getAllTargets()
    local candidates = {}
    for _, t in ipairs(targets) do
        if t.Name ~= excludeName then
            candidates[#candidates + 1] = t
        end
    end
    if #candidates == 0 then return targets[1] end
    return candidates[math.random(#candidates)]
end

-- ============================================================
-- EFEK VISUAL BOLA
-- ============================================================
local function addBallEffects(part)
    -- Glow
    local light = Instance.new("PointLight")
    light.Brightness = 6
    light.Range = 22
    light.Color = Color3.fromRGB(0, 220, 255)
    light.Parent = part

    -- Trail
    local a0 = Instance.new("Attachment", part)
    a0.Position = Vector3.new(0, 0.8, 0)
    local a1 = Instance.new("Attachment", part)
    a1.Position = Vector3.new(0, -0.8, 0)

    local trail = Instance.new("Trail")
    trail.Attachment0 = a0
    trail.Attachment1 = a1
    trail.Lifetime = 0.35
    trail.MinLength = 0
    trail.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 255, 255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 80, 180)),
    })
    trail.Transparency = NumberSequence.new({
        ColorSequenceKeypoint.new(0, 0),
        ColorSequenceKeypoint.new(1, 1),
    })
    trail.Parent = part

    -- Partikel
    local emitter = Instance.new("ParticleEmitter")
    emitter.Color = ColorSequence.new(Color3.fromRGB(0, 200, 255))
    emitter.LightEmission = 1
    emitter.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.4),
        NumberSequenceKeypoint.new(1, 0),
    })
    emitter.Speed = NumberRange.new(2, 6)
    emitter.Lifetime = NumberRange.new(0.15, 0.4)
    emitter.Rate = 60
    emitter.Parent = part
end

-- ============================================================
-- EFEK LEDAKAN SAAT HIT
-- ============================================================
local function spawnExplosionEffect(pos)
    local ring = Instance.new("Part")
    ring.Size = Vector3.new(2, 0.3, 2)
    ring.Shape = Enum.PartType.Cylinder
    ring.Anchored = true
    ring.CanCollide = false
    ring.Material = Enum.Material.Neon
    ring.BrickColor = BrickColor.new("Bright orange")
    ring.Position = pos
    ring.Parent = workspace

    local TweenService = game:GetService("TweenService")
    TweenService:Create(ring, TweenInfo.new(0.4), {
        Size = Vector3.new(18, 0.1, 18),
        Transparency = 1,
    }):Play()
    Debris:AddItem(ring, 0.5)

    -- Cahaya kilat
    local flash = Instance.new("Part")
    flash.Size = Vector3.new(1, 1, 1)
    flash.Anchored = true
    flash.CanCollide = false
    flash.Transparency = 1
    flash.Position = pos
    flash.Parent = workspace
    local flashLight = Instance.new("PointLight", flash)
    flashLight.Brightness = 10
    flashLight.Range = 30
    flashLight.Color = Color3.fromRGB(255, 150, 0)
    Debris:AddItem(flash, 0.3)
end

-- ============================================================
-- EFEK PARRY
-- ============================================================
local function spawnParryEffect(pos)
    local spark = Instance.new("Part")
    spark.Size = Vector3.new(0.5, 0.5, 0.5)
    spark.Anchored = true
    spark.CanCollide = false
    spark.Transparency = 1
    spark.Position = pos
    spark.Parent = workspace

    local emitter = Instance.new("ParticleEmitter", spark)
    emitter.Color = ColorSequence.new(Color3.fromRGB(255, 255, 0))
    emitter.LightEmission = 1
    emitter.Size = NumberSequence.new(0.4)
    emitter.Speed = NumberRange.new(8, 20)
    emitter.Lifetime = NumberRange.new(0.2, 0.5)
    emitter.Rate = 0
    emitter:Emit(40)

    Debris:AddItem(spark, 1)
end

-- ============================================================
-- SPAWN BOLA
-- ============================================================
local function spawnBall()
    -- Hapus bola lama
    if ball and ball.Parent then ball:Destroy() end
    if moveConn then moveConn:Disconnect() end

    -- Cari posisi spawn
    local spawnPart = workspace:FindFirstChild("BallSpawn")
    local spawnPos = spawnPart and spawnPart.Position or Vector3.new(0, 10, 0)

    -- Buat bola
    ball = Instance.new("Part")
    ball.Name = "EnergyBall"
    ball.Shape = Enum.PartType.Ball
    ball.Size = Vector3.new(2.5, 2.5, 2.5)
    ball.BrickColor = BrickColor.new("Cyan")
    ball.Material = Enum.Material.Neon
    ball.Anchored = true
    ball.CanCollide = false
    ball.CastShadow = false
    ball.Position = spawnPos
    ball.Parent = workspace

    addBallEffects(ball)

    -- Pilih target awal
    local target = pickTarget("")
    if not target then
        print("[BallSpawner] Tidak ada target! Coba lagi...")
        task.delay(2, spawnBall)
        return
    end

    ballTarget = target
    ballSpeed  = BALL_SPEED

    print("[BallSpawner] Bola spawn! Target: " .. ballTarget.Name)

    -- ============================================================
    -- GERAKKAN BOLA
    -- ============================================================
    moveConn = RunService.Heartbeat:Connect(function(dt)
        if not ball or not ball.Parent then
            moveConn:Disconnect()
            return
        end

        -- Refresh target kalau hilang
        if not ballTarget or not ballTarget.Character or not ballTarget.Character.Parent then
            ballTarget = pickTarget("")
            if not ballTarget then return end
            print("[BallSpawner] Target baru: " .. ballTarget.Name)
        end

        local hrp = ballTarget.Character:FindFirstChild("HumanoidRootPart")
        if not hrp then
            ballTarget = pickTarget("")
            return
        end

        local hum = ballTarget.Character:FindFirstChild("Humanoid")
        if not hum or hum.Health <= 0 then
            ballTarget = pickTarget(ballTarget.Name)
            return
        end

        -- Gerak bola ke target
        local ballPos  = ball.Position
        local targetPos = hrp.Position
        local dir = targetPos - ballPos
        local dist = dir.Magnitude

        if dist < 2.5 then
            -- HIT TARGET
            print("[BallSpawner] HIT! " .. ballTarget.Name .. " terkena bola!")
            spawnExplosionEffect(ballPos)

            -- Matikan target
            if hum and hum.Health > 0 then
                hum.Health = 0
            end

            -- Pilih target baru setelah jeda
            local deadName = ballTarget.Name
            ballTarget = nil
            ball.Position = spawnPos  -- reset posisi bola ke tengah

            task.delay(1.5, function()
                local newTarget = pickTarget(deadName)
                if newTarget then
                    ballTarget = newTarget
                    ballSpeed = math.max(BALL_SPEED, ballSpeed - 8)
                    print("[BallSpawner] Target baru setelah kill: " .. newTarget.Name)
                else
                    -- Semua mati, spawn ulang nanti
                    print("[BallSpawner] Semua target mati, menunggu...")
                    task.delay(3, spawnBall)
                end
            end)
            return
        end

        local step = math.min(ballSpeed * dt, dist)
        ball.CFrame = CFrame.new(ballPos + dir.Unit * step, targetPos)
    end)

    -- ============================================================
    -- AI BOT PARRY (bot coba parry kalau jadi target)
    -- ============================================================
    task.spawn(function()
        while ball and ball.Parent do
            task.wait(0.15)
            if not ballTarget then continue end
            if ballTarget.IsPlayer then continue end  -- bot saja

            -- Bot jadi target: coba parry dengan delay reaksi
            local botChar = ballTarget.Character
            if not botChar then continue end
            local botHRP = botChar:FindFirstChild("HumanoidRootPart")
            if not botHRP then continue end

            local distToBall = ball and (ball.Position - botHRP.Position).Magnitude or 999
            if distToBall < PARRY_DISTANCE then
                -- Delay reaksi bot (0.3 - 0.8 detik)
                task.wait(math.random(30, 80) / 100)

                -- Cek masih target
                if ballTarget and not ballTarget.IsPlayer then
                    if math.random(100) <= 65 then
                        -- Bot parry berhasil!
                        if ball and ball.Parent then
                            spawnParryEffect(ball.Position)
                            ballSpeed = math.min(ballSpeed + SPEED_INCREMENT, MAX_SPEED)
                            local oldTarget = ballTarget.Name
                            ballTarget = pickTarget(oldTarget)
                            if ballTarget then
                                print("[BallSpawner] Bot " .. oldTarget .. " parry! Target baru: " .. ballTarget.Name)
                            end
                        end
                    end
                end
            end
        end
    end)
end

-- ============================================================
-- PARRY DARI PEMAIN ASLI
-- ============================================================
local RemoteEvents = game.ReplicatedStorage:WaitForChild("RemoteEvents", 10)
if RemoteEvents then
    local ParryEvent = RemoteEvents:WaitForChild("ParryBall", 5)
    if ParryEvent then
        ParryEvent.OnServerEvent:Connect(function(player)
            if not ball or not ball.Parent then return end
            if not ballTarget then return end
            if ballTarget.Name ~= player.Name then return end

            -- Cek cooldown
            local now = tick()
            if parryCooldowns[player.Name] and now - parryCooldowns[player.Name] < PARRY_COOLDOWN then
                return
            end
            parryCooldowns[player.Name] = now

            -- Cek jarak
            local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
            if not hrp then return end
            local dist = (hrp.Position - ball.Position).Magnitude
            if dist > PARRY_DISTANCE then return end

            -- PARRY BERHASIL!
            spawnParryEffect(ball.Position)
            ballSpeed = math.min(ballSpeed + SPEED_INCREMENT, MAX_SPEED)
            lastParrier = player.Name

            local newTarget = pickTarget(player.Name)
            if newTarget then
                ballTarget = newTarget
                print("[BallSpawner] " .. player.Name .. " parry! Kecepatan: " .. ballSpeed .. " | Target baru: " .. newTarget.Name)
            end

            -- Feedback ke pemain
            local UpdateUI = RemoteEvents:FindFirstChild("UpdateUI")
            if UpdateUI then
                UpdateUI:FireClient(player, {
                    type = "ParrySuccess",
                    message = "Parry! Kecepatan: " .. ballSpeed
                })
            end
        end)
    end
end

-- ============================================================
-- MULAI!
-- ============================================================
print("[BallSpawner] Menunggu pemain...")
-- Tunggu sampai ada minimal 1 pemain
repeat task.wait(1) until #Players:GetPlayers() > 0
task.wait(1)
spawnBall()
print("[BallSpawner] Bola sudah di-spawn!")
