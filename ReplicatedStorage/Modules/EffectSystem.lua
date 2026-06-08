-- EffectSystem.lua
-- ReplicatedStorage/Modules/EffectSystem
-- Mengelola visual effects, sounds, camera shake, screen flash
-- DIJALANKAN DI CLIENT

local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local SoundService = game:GetService("SoundService")

local EffectSystem = {}

-- ============================================================
-- KONFIGURASI SUARA
-- Ganti rbxassetid dengan ID sound yang valid
-- ============================================================
local SOUNDS = {
    BallSpawn    = "rbxassetid://9120444385",
    Parry        = "rbxassetid://9120444386",
    Hit          = "rbxassetid://9120444387",
    Explosion    = "rbxassetid://9120444388",
    Winner       = "rbxassetid://9120444389",
    Countdown    = "rbxassetid://9120444390",
    Dash         = "rbxassetid://9120444391",
    Shield       = "rbxassetid://9120444392",
    Teleport     = "rbxassetid://9120444393",
    Freeze       = "rbxassetid://9120444394",
}

-- Cache sound objects
local soundCache = {}

local function getSound(name)
    if soundCache[name] then return soundCache[name] end
    local sound = Instance.new("Sound")
    sound.SoundId = SOUNDS[name] or ""
    sound.Parent = SoundService
    soundCache[name] = sound
    return sound
end

local function playSound(name, volumeOverride)
    local sound = getSound(name)
    if sound then
        sound.Volume = volumeOverride or 0.7
        sound:Play()
    end
end

-- ============================================================
-- CAMERA SHAKE
-- ============================================================
local shakeActive = false
local shakeIntensity = 0
local shakeDuration = 0
local shakeTimer = 0

local camera = workspace.CurrentCamera

RunService.RenderStepped:Connect(function(dt)
    if not shakeActive then return end
    shakeTimer = shakeTimer + dt
    if shakeTimer >= shakeDuration then
        shakeActive = false
        shakeTimer = 0
        return
    end
    local factor = 1 - (shakeTimer / shakeDuration)
    local offset = Vector3.new(
        (math.random() - 0.5) * shakeIntensity * factor,
        (math.random() - 0.5) * shakeIntensity * factor,
        0
    )
    camera.CFrame = camera.CFrame * CFrame.new(offset)
end)

function EffectSystem:CameraShake(intensity, duration)
    shakeActive = true
    shakeIntensity = intensity or 1
    shakeDuration = duration or 0.4
    shakeTimer = 0
end

-- ============================================================
-- SCREEN FLASH
-- ============================================================
function EffectSystem:ScreenFlash(color, duration)
    local Players = game:GetService("Players")
    local player = Players.LocalPlayer
    local gui = player.PlayerGui

    local flashGui = Instance.new("ScreenGui")
    flashGui.Name = "FlashEffect"
    flashGui.IgnoreGuiInset = true
    flashGui.DisplayOrder = 100
    flashGui.Parent = gui

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 1, 0)
    frame.BackgroundColor3 = color or Color3.fromRGB(255, 255, 255)
    frame.BackgroundTransparency = 0
    frame.BorderSizePixel = 0
    frame.Parent = flashGui

    -- Fade out
    local tween = TweenService:Create(frame, TweenInfo.new(duration or 0.3), {
        BackgroundTransparency = 1
    })
    tween:Play()
    tween.Completed:Connect(function()
        flashGui:Destroy()
    end)
end

-- ============================================================
-- PARRY EFFECT
-- ============================================================
function EffectSystem:PlayParryEffect(position)
    playSound("Parry")
    EffectSystem:CameraShake(0.5, 0.2)
    EffectSystem:ScreenFlash(Color3.fromRGB(0, 255, 255), 0.15)

    -- Spark effect
    local part = Instance.new("Part")
    part.Size = Vector3.new(1, 1, 1)
    part.Anchored = true
    part.CanCollide = false
    part.Transparency = 1
    part.Position = position or Vector3.new(0, 0, 0)
    part.Parent = workspace

    local particles = Instance.new("ParticleEmitter")
    particles.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 0)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 150, 0)),
    })
    particles.LightEmission = 1
    particles.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.5),
        NumberSequenceKeypoint.new(1, 0),
    })
    particles.Speed = NumberRange.new(5, 15)
    particles.Lifetime = NumberRange.new(0.2, 0.5)
    particles.Rate = 0
    particles.Burst = 50
    particles.Parent = part

    particles:Emit(50)
    Debris:AddItem(part, 1)
end

-- ============================================================
-- EXPLOSION EFFECT
-- ============================================================
function EffectSystem:PlayExplosionEffect(position, effectId)
    playSound("Explosion")
    EffectSystem:CameraShake(2, 0.5)
    EffectSystem:ScreenFlash(Color3.fromRGB(255, 100, 0), 0.3)

    -- Ring explosion
    local ring = Instance.new("Part")
    ring.Size = Vector3.new(1, 0.2, 1)
    ring.Shape = Enum.PartType.Cylinder
    ring.Anchored = true
    ring.CanCollide = false
    ring.Material = Enum.Material.Neon
    ring.BrickColor = BrickColor.new("Bright orange")
    ring.Position = position or Vector3.new(0, 0, 0)
    ring.Parent = workspace

    TweenService:Create(ring, TweenInfo.new(0.4), {
        Size = Vector3.new(20, 0.2, 20),
        Transparency = 1
    }):Play()
    Debris:AddItem(ring, 0.5)

    -- Particle burst
    local burst = Instance.new("Part")
    burst.Size = Vector3.new(1, 1, 1)
    burst.Anchored = true
    burst.CanCollide = false
    burst.Transparency = 1
    burst.Position = position or Vector3.new(0, 0, 0)
    burst.Parent = workspace

    local particles = Instance.new("ParticleEmitter")
    particles.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 200, 0)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 100, 0)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 0, 0)),
    })
    particles.LightEmission = 1
    particles.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 1),
        NumberSequenceKeypoint.new(1, 0),
    })
    particles.Speed = NumberRange.new(10, 30)
    particles.Lifetime = NumberRange.new(0.3, 0.8)
    particles.Rate = 0
    particles.Parent = burst

    particles:Emit(80)
    Debris:AddItem(burst, 1)
end

-- ============================================================
-- BALL SPAWN EFFECT
-- ============================================================
function EffectSystem:PlayBallSpawnEffect(position)
    playSound("BallSpawn")

    local ring = Instance.new("Part")
    ring.Size = Vector3.new(5, 0.5, 5)
    ring.Shape = Enum.PartType.Cylinder
    ring.Anchored = true
    ring.CanCollide = false
    ring.Material = Enum.Material.Neon
    ring.BrickColor = BrickColor.new("Cyan")
    ring.Position = position or Vector3.new(0, 0, 0)
    ring.Parent = workspace

    TweenService:Create(ring, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = Vector3.new(15, 0.1, 15),
        Transparency = 1,
    }):Play()
    Debris:AddItem(ring, 0.6)
end

-- ============================================================
-- DASH EFFECT
-- ============================================================
function EffectSystem:PlayDashEffect(position)
    playSound("Dash")
    EffectSystem:ScreenFlash(Color3.fromRGB(100, 200, 255), 0.1)

    local trail = Instance.new("Part")
    trail.Size = Vector3.new(2, 2, 8)
    trail.Anchored = true
    trail.CanCollide = false
    trail.Material = Enum.Material.Neon
    trail.BrickColor = BrickColor.new("Cyan")
    trail.Transparency = 0.3
    trail.Position = position or Vector3.new(0, 0, 0)
    trail.Parent = workspace

    TweenService:Create(trail, TweenInfo.new(0.3), {Transparency = 1}):Play()
    Debris:AddItem(trail, 0.4)
end

-- ============================================================
-- SHIELD EFFECT
-- ============================================================
function EffectSystem:PlayShieldEffect(position, active)
    if active then
        playSound("Shield")
    end

    local sphere = Instance.new("Part")
    sphere.Shape = Enum.PartType.Ball
    sphere.Size = Vector3.new(6, 6, 6)
    sphere.Anchored = true
    sphere.CanCollide = false
    sphere.Material = Enum.Material.Neon
    sphere.BrickColor = BrickColor.new("Bright blue")
    sphere.Transparency = 0.6
    sphere.Position = position or Vector3.new(0, 0, 0)
    sphere.Parent = workspace

    TweenService:Create(sphere, TweenInfo.new(0.5), {
        Size = Vector3.new(8, 8, 8),
        Transparency = 1
    }):Play()
    Debris:AddItem(sphere, 0.6)
end

-- ============================================================
-- TELEPORT EFFECT
-- ============================================================
function EffectSystem:PlayTeleportEffect(position, isOut)
    playSound("Teleport")

    local color = isOut and Color3.fromRGB(150, 0, 255) or Color3.fromRGB(255, 200, 0)

    local part = Instance.new("Part")
    part.Size = Vector3.new(1, 1, 1)
    part.Anchored = true
    part.CanCollide = false
    part.Transparency = 1
    part.Position = position or Vector3.new(0, 0, 0)
    part.Parent = workspace

    local particles = Instance.new("ParticleEmitter")
    particles.Color = ColorSequence.new(color)
    particles.LightEmission = 1
    particles.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.8),
        NumberSequenceKeypoint.new(1, 0),
    })
    particles.Speed = NumberRange.new(8, 20)
    particles.Lifetime = NumberRange.new(0.3, 0.7)
    particles.Rate = 0
    particles.Parent = part

    particles:Emit(60)
    Debris:AddItem(part, 1)
end

-- ============================================================
-- FREEZE BALL EFFECT
-- ============================================================
function EffectSystem:PlayFreezeBallEffect(position)
    playSound("Freeze")

    local ice = Instance.new("Part")
    ice.Size = Vector3.new(3, 3, 3)
    ice.Anchored = true
    ice.CanCollide = false
    ice.Material = Enum.Material.Ice
    ice.BrickColor = BrickColor.new("Light blue")
    ice.Transparency = 0.3
    ice.Position = position or Vector3.new(0, 0, 0)
    ice.Parent = workspace

    TweenService:Create(ice, TweenInfo.new(2), {Transparency = 1}):Play()
    Debris:AddItem(ice, 2.1)
end

-- ============================================================
-- COUNTDOWN SOUND
-- ============================================================
function EffectSystem:PlayCountdownSound()
    playSound("Countdown", 0.5)
end

function EffectSystem:PlayWinnerSound()
    playSound("Winner", 1)
end

-- ============================================================
-- DISPATCH EFFECT DARI EVENT
-- ============================================================
function EffectSystem:DispatchEffect(data)
    if not data or not data.type then return end

    local pos = data.position

    if data.type == "Parry" then
        EffectSystem:PlayParryEffect(pos)
    elseif data.type == "Explosion" then
        EffectSystem:PlayExplosionEffect(pos, data.effectId)
    elseif data.type == "BallSpawn" then
        EffectSystem:PlayBallSpawnEffect(pos)
    elseif data.type == "BallDespawn" then
        -- Bola despawn, efek kecil
        if pos then EffectSystem:PlayParryEffect(pos) end
    elseif data.type == "Dash" then
        EffectSystem:PlayDashEffect(pos)
    elseif data.type == "Shield" or data.type == "ShieldEnd" then
        EffectSystem:PlayShieldEffect(pos, data.type == "Shield")
    elseif data.type == "TeleportOut" then
        EffectSystem:PlayTeleportEffect(pos, true)
    elseif data.type == "TeleportIn" then
        EffectSystem:PlayTeleportEffect(pos, false)
    elseif data.type == "FreezeBall" then
        EffectSystem:PlayFreezeBallEffect(pos)
    end
end

return EffectSystem
