-- LocalManager.lua
-- StarterPlayer/StarterPlayerScripts/LocalManager
-- Client-side manager: input handling, parry, abilities, effects

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

local Modules = ReplicatedStorage:WaitForChild("Modules")
local RemoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")

local EffectSystem = require(Modules:WaitForChild("EffectSystem"))

local ParryBallEvent = RemoteEvents:WaitForChild("ParryBall")
local UseAbilityEvent = RemoteEvents:WaitForChild("UseAbility")
local UpdateUIEvent = RemoteEvents:WaitForChild("UpdateUI")
local RoundStatusEvent = RemoteEvents:WaitForChild("RoundStatus")
local BallTargetEvent = RemoteEvents:WaitForChild("BallTarget")
local PlayerDiedEvent = RemoteEvents:WaitForChild("PlayerDied")
local SpawnEffectEvent = RemoteEvents:WaitForChild("SpawnEffect")

-- State client
local isTarget = false
local gameState = "Waiting"
local canParry = true
local parryCooldown = 0.5

-- Referensi UI (akan diisi setelah UI ready)
local mainUI = nil
local roundUI = nil
local abilityUI = nil
local shopUI = nil

-- Tunggu GUI siap
local function waitForGUI()
    local gui = player.PlayerGui
    mainUI = gui:WaitForChild("MainUI", 10)
    roundUI = gui:WaitForChild("RoundUI", 10)
    abilityUI = gui:WaitForChild("AbilityUI", 10)
    shopUI = gui:WaitForChild("ShopUI", 10)
end

task.spawn(waitForGUI)

-- ============================================================
-- INPUT HANDLING
-- ============================================================

-- Parry: klik kiri mouse atau tombol E
local function tryParry()
    if not canParry then return end
    canParry = false
    ParryBallEvent:FireServer()

    -- Animasi parry lokal (feedback instan)
    if roundUI then
        local parryBtn = roundUI:FindFirstChild("ParryButton", true)
        if parryBtn then
            TweenService:Create(parryBtn, TweenInfo.new(0.1), {
                BackgroundColor3 = Color3.fromRGB(255, 255, 0)
            }):Play()
            task.delay(0.1, function()
                TweenService:Create(parryBtn, TweenInfo.new(0.2), {
                    BackgroundColor3 = Color3.fromRGB(50, 50, 80)
                }):Play()
            end)
        end
    end

    -- Cooldown visual
    task.delay(parryCooldown, function()
        canParry = true
    end)
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if gameState ~= "Playing" then return end

    -- E key atau klik kiri = Parry
    if input.KeyCode == Enum.KeyCode.E or input.UserInputType == Enum.UserInputType.MouseButton1 then
        tryParry()
    end

    -- Q key = Ability 1
    if input.KeyCode == Enum.KeyCode.Q then
        local abilityName = getEquippedAbility()
        if abilityName then
            UseAbilityEvent:FireServer(abilityName)
        end
    end

    -- F key = Ability 2 (cadangan)
    if input.KeyCode == Enum.KeyCode.F then
        UseAbilityEvent:FireServer("Shield")
    end
end)

-- Touch support (mobile)
local function setupMobileInput()
    local gui = player.PlayerGui
    task.spawn(function()
        local rUI = gui:WaitForChild("RoundUI", 15)
        if not rUI then return end
        local parryBtn = rUI:FindFirstChild("ParryButton", true)
        if parryBtn then
            parryBtn.Activated:Connect(function()
                if gameState == "Playing" then
                    tryParry()
                end
            end)
        end
    end)
end
task.spawn(setupMobileInput)

-- Dapatkan ability yang di-equip (dari data lokal)
function getEquippedAbility()
    -- Default Dash, bisa dikembangkan dari data
    return "Dash"
end

-- ============================================================
-- HANDLE ROUND STATUS
-- ============================================================
RoundStatusEvent.OnClientEvent:Connect(function(payload)
    gameState = payload.state

    if roundUI then
        local statusLabel = roundUI:FindFirstChild("StatusLabel", true)
        if statusLabel then
            local stateText = {
                Waiting = "⏳ Menunggu Pemain...",
                Intermission = "🔄 Intermission",
                Starting = "🚀 Segera Dimulai!",
                Playing = "⚔️ BERTARUNG!",
                Winner = "🏆 " .. (payload.data and payload.data.winnerName or "?") .. " Menang!",
            }
            statusLabel.Text = stateText[payload.state] or payload.state
        end
    end

    if payload.state == "Winner" then
        EffectSystem:PlayWinnerSound()
        EffectSystem:ScreenFlash(Color3.fromRGB(255, 215, 0), 0.5)

        -- Tampilkan winner screen
        if roundUI then
            local winnerFrame = roundUI:FindFirstChild("WinnerFrame", true)
            if winnerFrame then
                winnerFrame.Visible = true
                local winnerLabel = winnerFrame:FindFirstChild("WinnerLabel", true)
                if winnerLabel and payload.data then
                    winnerLabel.Text = "🏆 " .. payload.data.winnerName .. " MENANG!"
                end
                TweenService:Create(winnerFrame, TweenInfo.new(0.5, Enum.EasingStyle.Back), {
                    Size = UDim2.new(0.6, 0, 0.3, 0)
                }):Play()
                task.delay(4, function()
                    winnerFrame.Visible = false
                end)
            end
        end
    end

    if payload.state == "Playing" then
        -- Reset state lokal
        canParry = true
    end
end)

-- ============================================================
-- HANDLE UI UPDATE
-- ============================================================
UpdateUIEvent.OnClientEvent:Connect(function(data)
    if not data then return end

    if data.type == "Countdown" then
        if roundUI then
            local countdownLabel = roundUI:FindFirstChild("CountdownLabel", true)
            if countdownLabel then
                countdownLabel.Text = tostring(data.time)
                countdownLabel.Visible = true
                -- Animasi
                countdownLabel.Size = UDim2.new(0, 80, 0, 80)
                TweenService:Create(countdownLabel, TweenInfo.new(0.3, Enum.EasingStyle.Elastic), {
                    Size = UDim2.new(0, 60, 0, 60)
                }):Play()
                if data.phase == "Starting" then
                    EffectSystem:PlayCountdownSound()
                end
            end
        end

    elseif data.type == "AliveCount" then
        if roundUI then
            local aliveLabel = roundUI:FindFirstChild("AliveLabel", true)
            if aliveLabel then
                aliveLabel.Text = "👤 Hidup: " .. (data.count or "?")
            end
        end

    elseif data.type == "PlayerCount" then
        if roundUI then
            local statusLabel = roundUI:FindFirstChild("StatusLabel", true)
            if statusLabel then
                statusLabel.Text = "⏳ Menunggu " .. (data.count or 0) .. "/" .. (data.min or 2) .. " pemain"
            end
        end

    elseif data.type == "ParrySuccess" then
        EffectSystem:ScreenFlash(Color3.fromRGB(0, 255, 100), 0.1)
        showNotification("✅ " .. (data.message or "Parry!"), Color3.fromRGB(0, 255, 100))

    elseif data.type == "ParryFail" then
        -- Tidak perlu feedback visual yang mengganggu untuk parry fail

    elseif data.type == "KillAnnouncement" then
        local msg = data.killer ~= "Bola" 
            and (data.killer .. " membunuh " .. data.dead)
            or (data.dead .. " terkena bola!")
        showNotification("💀 " .. msg, Color3.fromRGB(255, 100, 100))

    elseif data.type == "KillFeed" then
        showNotification("⚔️ " .. (data.message or "Kill!"), Color3.fromRGB(255, 200, 0))

    elseif data.type == "AbilityUsed" then
        showNotification("✨ " .. (data.message or "Ability!"), Color3.fromRGB(100, 100, 255))
        -- Update cooldown UI
        if abilityUI then
            updateAbilityCooldown(data.abilityName, data.cooldown)
        end

    elseif data.type == "AbilityCooldown" then
        showNotification("⏱️ Cooldown: " .. math.floor(data.remaining or 0) .. "s", Color3.fromRGB(200, 200, 200))

    elseif data.type == "ShopResult" then
        if shopUI then
            local msg = data.success 
                and ("✅ Dibeli: " .. (data.itemName or "?"))
                or ("❌ " .. (data.message or "Gagal"))
            showNotification(msg, data.success and Color3.fromRGB(0, 255, 100) or Color3.fromRGB(255, 100, 100))
        end

    elseif data.type == "ShopError" then
        showNotification("❌ " .. (data.message or "Error"), Color3.fromRGB(255, 100, 100))
    end
end)

-- ============================================================
-- HANDLE BALL TARGET
-- ============================================================
BallTargetEvent.OnClientEvent:Connect(function(data)
    isTarget = (data.targetId == player.UserId)

    if roundUI then
        local targetIndicator = roundUI:FindFirstChild("TargetIndicator", true)
        if targetIndicator then
            if isTarget then
                targetIndicator.Visible = true
                targetIndicator.Text = "⚠️ BOLA MENGEJARMU! ⚠️"
                -- Animasi berkedip
                task.spawn(function()
                    while targetIndicator.Visible and isTarget do
                        TweenService:Create(targetIndicator, TweenInfo.new(0.3), {
                            TextTransparency = 0
                        }):Play()
                        task.wait(0.3)
                        TweenService:Create(targetIndicator, TweenInfo.new(0.3), {
                            TextTransparency = 0.6
                        }):Play()
                        task.wait(0.3)
                    end
                end)

                -- Screen tint merah saat jadi target
                EffectSystem:ScreenFlash(Color3.fromRGB(255, 0, 0), 0.5)
            else
                targetIndicator.Visible = false
            end
        end
    end
end)

-- ============================================================
-- HANDLE PLAYER DIED
-- ============================================================
PlayerDiedEvent.OnClientEvent:Connect(function(data)
    if data.playerName == player.Name then
        -- Pemain lokal mati
        EffectSystem:ScreenFlash(Color3.fromRGB(255, 0, 0), 0.8)
        showNotification("💀 Kamu Tereliminasi!", Color3.fromRGB(255, 0, 0))
    end
end)

-- ============================================================
-- HANDLE SPAWN EFFECTS
-- ============================================================
SpawnEffectEvent.OnClientEvent:Connect(function(data)
    EffectSystem:DispatchEffect(data)
end)

-- ============================================================
-- NOTIFICATION SYSTEM
-- ============================================================
function showNotification(text, color)
    local gui = player.PlayerGui
    local notifGui = gui:FindFirstChild("NotificationGui")
    if not notifGui then
        notifGui = Instance.new("ScreenGui")
        notifGui.Name = "NotificationGui"
        notifGui.ResetOnSpawn = false
        notifGui.DisplayOrder = 50
        notifGui.Parent = gui
    end

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0.35, 0, 0, 50)
    frame.Position = UDim2.new(0.325, 0, 0.75, 0)
    frame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
    frame.BackgroundTransparency = 0.2
    frame.BorderSizePixel = 0
    frame.Parent = notifGui

    local corner = Instance.new("UICorner", frame)
    corner.CornerRadius = UDim.new(0, 8)

    local stroke = Instance.new("UIStroke", frame)
    stroke.Color = color or Color3.fromRGB(255, 255, 255)
    stroke.Thickness = 2

    local label = Instance.new("TextLabel", frame)
    label.Size = UDim2.new(1, -10, 1, 0)
    label.Position = UDim2.new(0, 5, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = color or Color3.fromRGB(255, 255, 255)
    label.TextScaled = true
    label.Font = Enum.Font.GothamBold
    label.TextXAlignment = Enum.TextXAlignment.Center

    -- Animasi masuk
    frame.Position = UDim2.new(0.325, 0, 0.85, 0)
    TweenService:Create(frame, TweenInfo.new(0.3, Enum.EasingStyle.Back), {
        Position = UDim2.new(0.325, 0, 0.75, 0)
    }):Play()

    -- Hilang setelah 2.5 detik
    task.delay(2, function()
        TweenService:Create(frame, TweenInfo.new(0.3), {
            Position = UDim2.new(0.325, 0, 0.65, 0),
            BackgroundTransparency = 1
        }):Play()
        TweenService:Create(label, TweenInfo.new(0.3), {TextTransparency = 1}):Play()
        task.wait(0.3)
        frame:Destroy()
    end)
end

-- ============================================================
-- ABILITY COOLDOWN UI
-- ============================================================
function updateAbilityCooldown(abilityName, cooldown)
    if not abilityUI then return end
    local abilityBtn = abilityUI:FindFirstChild("AbilityButton", true)
    if not abilityBtn then return end

    local cooldownLabel = abilityBtn:FindFirstChild("CooldownLabel")
    if not cooldownLabel then return end

    local startTime = tick()
    task.spawn(function()
        while true do
            local elapsed = tick() - startTime
            local remaining = math.max(0, cooldown - elapsed)
            if remaining <= 0 then
                cooldownLabel.Text = ""
                cooldownLabel.Visible = false
                abilityBtn.BackgroundTransparency = 0
                break
            end
            cooldownLabel.Text = math.ceil(remaining) .. "s"
            cooldownLabel.Visible = true
            abilityBtn.BackgroundTransparency = 0.5
            task.wait(0.1)
        end
    end)
end

print("[LocalManager] Initialized for " .. player.Name)
