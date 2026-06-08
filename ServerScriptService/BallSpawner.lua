-- BallSpawner.lua (v3 - TweenService approach)
-- ServerScriptService/BallSpawner

local Players      = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Debris       = game:GetService("Debris")
local RunService   = game:GetService("RunService")

print("[BallSpawner] v3 mulai...")

local BALL_SPEED      = 20   -- studs/detik awal
local SPEED_INCREMENT = 3    -- tambah per parry
local MAX_SPEED       = 80
local PARRY_DIST      = 20   -- jarak max parry
local PARRY_COOLDOWN  = 0.6

local ball        = nil
local ballTarget  = nil
local ballSpeed   = BALL_SPEED
local activeTween = nil
local isMoving    = false
local parryCDs    = {}

-- ============================================================
-- KUMPULKAN SEMUA TARGET (pemain + bot dari workspace)
-- ============================================================
local function getAllTargets()
    local t = {}

    -- Pemain asli
    for _, p in ipairs(Players:GetPlayers()) do
        local char = p.Character
        if char then
            local hrp = char:FindFirstChild("HumanoidRootPart")
            local hum = char:FindFirstChild("Humanoid")
            if hrp and hum and hum.Health > 0 then
                t[#t+1] = { Name=p.Name, HRP=hrp, Hum=hum, IsPlayer=true, Player=p }
            end
        end
    end

    -- Bot dari workspace (nama mengandung "Bot")
    for _, obj in ipairs(workspace:GetChildren()) do
        if obj:IsA("Model") and (obj.Name:find("Bot") or obj.Name:find("bot")) then
            local hrp = obj:FindFirstChild("HumanoidRootPart")
            local hum = obj:FindFirstChild("Humanoid")
            if hrp and hum and hum.Health > 0 then
                t[#t+1] = { Name=obj.Name, HRP=hrp, Hum=hum, IsPlayer=false }
            end
        end
    end

    return t
end

local function pickRandom(excludeName)
    local all = getAllTargets()
    local candidates = {}
    for _, t in ipairs(all) do
        if t.Name ~= excludeName then candidates[#candidates+1] = t end
    end
    if #candidates == 0 then return all[1] end
    return candidates[math.random(#candidates)]
end

-- ============================================================
-- EFEK BOLA
-- ============================================================
local function addEffects(part)
    local light = Instance.new("PointLight", part)
    light.Brightness = 6; light.Range = 22
    light.Color = Color3.fromRGB(0, 220, 255)

    local a0 = Instance.new("Attachment", part); a0.Position = Vector3.new(0, 0.8, 0)
    local a1 = Instance.new("Attachment", part); a1.Position = Vector3.new(0, -0.8, 0)
    local trail = Instance.new("Trail", part)
    trail.Attachment0 = a0; trail.Attachment1 = a1
    trail.Lifetime = 0.3; trail.MinLength = 0
    trail.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(0,255,255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(0,80,200)),
    })
    trail.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0,0),
        NumberSequenceKeypoint.new(1,1),
    })

    local em = Instance.new("ParticleEmitter", part)
    em.Color = ColorSequence.new(Color3.fromRGB(0,200,255))
    em.LightEmission = 1
    em.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0,0.4), NumberSequenceKeypoint.new(1,0) })
    em.Speed = NumberRange.new(2,6)
    em.Lifetime = NumberRange.new(0.15,0.4)
    em.Rate = 60
end

local function fxExplosion(pos)
    local p = Instance.new("Part")
    p.Anchored = true; p.CanCollide = false
    p.Size = Vector3.new(2,0.3,2)
    p.Material = Enum.Material.Neon
    p.BrickColor = BrickColor.new("Bright orange")
    p.Position = pos; p.Parent = workspace
    TweenService:Create(p, TweenInfo.new(0.4), {
        Size = Vector3.new(20,0.1,20), Transparency = 1
    }):Play()
    Debris:AddItem(p, 0.5)
end

local function fxParry(pos)
    local p = Instance.new("Part")
    p.Anchored = true; p.CanCollide = false; p.Transparency = 1
    p.Size = Vector3.new(1,1,1); p.Position = pos; p.Parent = workspace
    local em = Instance.new("ParticleEmitter", p)
    em.Color = ColorSequence.new(Color3.fromRGB(255,255,0))
    em.LightEmission = 1
    em.Size = NumberSequence.new(0.5)
    em.Speed = NumberRange.new(8,20)
    em.Lifetime = NumberRange.new(0.2,0.5)
    em.Rate = 0; em:Emit(50)
    Debris:AddItem(p, 1)
end

-- ============================================================
-- CORE: GERAK BOLA KE TARGET (pakai loop + CFrame setiap frame)
-- ============================================================
local moveThread = nil

local function stopMoving()
    if moveThread then
        task.cancel(moveThread)
        moveThread = nil
    end
    isMoving = false
end

local function moveToTarget(target)
    if not ball or not ball.Parent then return end
    if not target then return end

    ballTarget = target
    isMoving = true

    -- Gunakan loop task.spawn yang update posisi setiap 0.03 detik
    -- Ini lebih reliable dari Heartbeat di server
    moveThread = task.spawn(function()
        while ball and ball.Parent and isMoving do
            if not ballTarget then
                task.wait(0.1)
                continue
            end

            local hrp = ballTarget.HRP
            if not hrp or not hrp.Parent then
                -- Target hilang, cari baru
                local newT = pickRandom("")
                if newT then
                    ballTarget = newT
                    print("[BallSpawner] Target refresh: " .. newT.Name)
                end
                task.wait(0.1)
                continue
            end

            local hum = ballTarget.Hum
            if not hum or hum.Health <= 0 then
                local newT = pickRandom(ballTarget.Name)
                if newT then
                    ballTarget = newT
                    print("[BallSpawner] Target mati, pindah ke: " .. newT.Name)
                end
                task.wait(0.1)
                continue
            end

            local ballPos   = ball.Position
            local targetPos = hrp.Position
            local dist      = (targetPos - ballPos).Magnitude

            -- HIT CHECK
            if dist < 3 then
                print("[BallSpawner] 💥 HIT! " .. ballTarget.Name)
                fxExplosion(ballPos)

                local deadName = ballTarget.Name
                local deadHum  = hum

                isMoving = false

                -- Matikan target
                task.spawn(function()
                    if deadHum and deadHum.Health > 0 then
                        deadHum.Health = 0
                    end
                end)

                -- Reset bola ke tengah
                local spawnPt = workspace:FindFirstChild("BallSpawn")
                local center  = spawnPt and spawnPt.Position or Vector3.new(0, 10, 0)
                ball.CFrame   = CFrame.new(center)

                task.wait(1.5)

                local newT = pickRandom(deadName)
                if newT then
                    ballSpeed = math.max(BALL_SPEED, ballSpeed - 6)
                    moveToTarget(newT)
                else
                    print("[BallSpawner] Semua target habis!")
                end
                return
            end

            -- GERAK: update CFrame langsung ke arah target
            local direction = (targetPos - ballPos).Unit
            local step      = ballSpeed * 0.03  -- 0.03 = interval wait

            ball.CFrame = CFrame.new(ballPos + direction * step, targetPos)

            task.wait(0.03)
        end
    end)
end

-- ============================================================
-- SPAWN BOLA
-- ============================================================
local function spawnBall()
    stopMoving()

    if ball and ball.Parent then ball:Destroy() end

    local spawnPt  = workspace:FindFirstChild("BallSpawn")
    local spawnPos = spawnPt and spawnPt.Position or Vector3.new(0, 10, 0)

    ball = Instance.new("Part")
    ball.Name        = "EnergyBall"
    ball.Shape       = Enum.PartType.Ball
    ball.Size        = Vector3.new(2.5, 2.5, 2.5)
    ball.BrickColor  = BrickColor.new("Cyan")
    ball.Material    = Enum.Material.Neon
    ball.Anchored    = true   -- Anchored = true, gerak via CFrame
    ball.CanCollide  = false
    ball.CastShadow  = false
    ball.CFrame      = CFrame.new(spawnPos)
    ball.Parent      = workspace

    addEffects(ball)
    ballSpeed = BALL_SPEED

    local target = pickRandom("")
    if not target then
        print("[BallSpawner] Tidak ada target ditemukan, coba lagi 2 detik...")
        task.delay(2, spawnBall)
        return
    end

    print("[BallSpawner] ✅ Bola spawn! Target pertama: " .. target.Name)
    moveToTarget(target)
end

-- ============================================================
-- PARRY DARI PEMAIN ASLI
-- ============================================================
task.spawn(function()
    local RE = game.ReplicatedStorage:WaitForChild("RemoteEvents", 10)
    if not RE then return end
    local ParryEvent = RE:WaitForChild("ParryBall", 5)
    if not ParryEvent then return end

    ParryEvent.OnServerEvent:Connect(function(player)
        if not ball or not ball.Parent then return end
        if not ballTarget then return end
        if ballTarget.Name ~= player.Name then return end

        -- Cooldown check
        local now = tick()
        if parryCDs[player.Name] and now - parryCDs[player.Name] < PARRY_COOLDOWN then return end
        parryCDs[player.Name] = now

        -- Jarak check
        local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        if (hrp.Position - ball.Position).Magnitude > PARRY_DIST then return end

        -- PARRY!
        fxParry(ball.Position)
        ballSpeed = math.min(ballSpeed + SPEED_INCREMENT, MAX_SPEED)

        local newT = pickRandom(player.Name)
        if newT then
            print("[BallSpawner] ⚡ " .. player.Name .. " parry! Speed=" .. ballSpeed .. " | New target: " .. newT.Name)
            moveToTarget(newT)
        end

        -- Feedback UI
        local UpdateUI = RE:FindFirstChild("UpdateUI")
        if UpdateUI then
            UpdateUI:FireClient(player, {
                type = "ParrySuccess",
                message = "Parry! Speed: " .. ballSpeed
            })
        end
    end)
end)

-- ============================================================
-- BOT PARRY AI
-- ============================================================
task.spawn(function()
    while true do
        task.wait(0.2)
        if not ball or not ball.Parent then continue end
        if not ballTarget or ballTarget.IsPlayer then continue end

        local hrp = ballTarget.HRP
        if not hrp then continue end

        local dist = (ball.Position - hrp.Position).Magnitude
        if dist < PARRY_DIST then
            task.wait(math.random(30, 80) / 100)  -- delay reaksi bot

            -- Cek masih jadi target
            if ballTarget and not ballTarget.IsPlayer then
                if math.random(100) <= 60 then
                    -- Bot parry!
                    fxParry(ball.Position)
                    ballSpeed = math.min(ballSpeed + SPEED_INCREMENT, MAX_SPEED)
                    local oldName = ballTarget.Name
                    local newT = pickRandom(oldName)
                    if newT then
                        print("[BallSpawner] 🤖 Bot " .. oldName .. " parry! New target: " .. newT.Name)
                        moveToTarget(newT)
                    end
                end
            end
        end
    end
end)

-- ============================================================
-- START
-- ============================================================
print("[BallSpawner] Menunggu pemain join...")
repeat task.wait(0.5) until #Players:GetPlayers() > 0
task.wait(2)

-- Tunggu sampai ada target (pemain atau bot)
repeat
    task.wait(0.5)
    print("[BallSpawner] Nyari target... total: " .. #getAllTargets())
until #getAllTargets() > 0

spawnBall()
