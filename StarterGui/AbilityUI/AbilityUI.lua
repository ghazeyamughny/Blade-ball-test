-- AbilityUI.lua
-- StarterGui/AbilityUI (LocalScript dalam ScreenGui)
-- UI untuk menampilkan ability dengan cooldown indicator

local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local screenGui = script.Parent

local RemoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local UseAbilityEvent = RemoteEvents:WaitForChild("UseAbility")
local UpdateUIEvent = RemoteEvents:WaitForChild("UpdateUI")

-- ============================================================
-- KONFIGURASI ABILITY UI
-- ============================================================
local ABILITIES_CONFIG = {
    { name = "Dash",       key = "Q", cooldown = 8,  color = Color3.fromRGB(0, 200, 255),  icon = "🏃" },
    { name = "Shield",     key = "F", cooldown = 15, color = Color3.fromRGB(50, 100, 255), icon = "🛡️" },
    { name = "Teleport",   key = "R", cooldown = 12, color = Color3.fromRGB(200, 50, 255), icon = "✨" },
    { name = "FreezeBall", key = "G", cooldown = 20, color = Color3.fromRGB(150, 220, 255),icon = "❄️" },
}

-- State cooldown lokal
local abilityCooldowns = {}
local abilityButtons = {}

-- ============================================================
-- HELPER
-- ============================================================
local function makeFrame(parent, name, size, pos, bgColor, bgTrans)
    local f = Instance.new("Frame")
    f.Name = name
    f.Size = size
    f.Position = pos
    f.BackgroundColor3 = bgColor or Color3.fromRGB(20, 20, 35)
    f.BackgroundTransparency = bgTrans or 0
    f.BorderSizePixel = 0
    f.Parent = parent
    local c = Instance.new("UICorner", f)
    c.CornerRadius = UDim.new(0, 10)
    return f
end

local function makeLabel(parent, name, text, size, pos, color, font)
    local l = Instance.new("TextLabel")
    l.Name = name
    l.Size = size
    l.Position = pos
    l.BackgroundTransparency = 1
    l.Text = text
    l.TextColor3 = color or Color3.fromRGB(255, 255, 255)
    l.TextScaled = true
    l.Font = font or Enum.Font.GothamBold
    l.BorderSizePixel = 0
    l.Parent = parent
    return l
end

-- ============================================================
-- BUAT ABILITY BAR (bawah kiri)
-- ============================================================
local abilityBar = makeFrame(screenGui, "AbilityBar",
    UDim2.new(0, #ABILITIES_CONFIG * 85 + 10, 0, 90),
    UDim2.new(0, 10, 1, -100),
    Color3.fromRGB(10, 10, 20), 0.2)

local barLayout = Instance.new("UIListLayout", abilityBar)
barLayout.FillDirection = Enum.FillDirection.Horizontal
barLayout.Padding = UDim.new(0, 8)
barLayout.VerticalAlignment = Enum.VerticalAlignment.Center

local barPadding = Instance.new("UIPadding", abilityBar)
barPadding.PaddingLeft = UDim.new(0, 5)
barPadding.PaddingRight = UDim.new(0, 5)

-- ============================================================
-- BUAT TOMBOL UNTUK SETIAP ABILITY
-- ============================================================
for i, abilityConfig in ipairs(ABILITIES_CONFIG) do
    local btnFrame = makeFrame(abilityBar, abilityConfig.name .. "Frame",
        UDim2.new(0, 75, 0, 75),
        UDim2.new(0, 0, 0, 0),
        Color3.fromRGB(15, 15, 30))

    -- Border warna ability
    local stroke = Instance.new("UIStroke", btnFrame)
    stroke.Color = abilityConfig.color
    stroke.Thickness = 2

    -- Ikon ability
    local iconLabel = makeLabel(btnFrame, "IconLabel",
        abilityConfig.icon,
        UDim2.new(1, 0, 0.55, 0),
        UDim2.new(0, 0, 0, 0),
        Color3.fromRGB(255, 255, 255),
        Enum.Font.GothamBlack)

    -- Nama ability
    makeLabel(btnFrame, "NameLabel",
        abilityConfig.name,
        UDim2.new(1, 0, 0.25, 0),
        UDim2.new(0, 0, 0.55, 0),
        abilityConfig.color,
        Enum.Font.Gotham)

    -- Key hint
    makeLabel(btnFrame, "KeyLabel",
        "[" .. abilityConfig.key .. "]",
        UDim2.new(1, 0, 0.22, 0),
        UDim2.new(0, 0, 0.78, 0),
        Color3.fromRGB(180, 180, 180),
        Enum.Font.Gotham)

    -- Cooldown overlay (transparan saat ready)
    local cooldownOverlay = Instance.new("Frame")
    cooldownOverlay.Name = "CooldownOverlay"
    cooldownOverlay.Size = UDim2.new(1, 0, 0, 0)
    cooldownOverlay.Position = UDim2.new(0, 0, 1, 0)  -- dimulai dari bawah
    cooldownOverlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    cooldownOverlay.BackgroundTransparency = 0.4
    cooldownOverlay.BorderSizePixel = 0
    cooldownOverlay.ZIndex = 5
    cooldownOverlay.Visible = false
    cooldownOverlay.Parent = btnFrame
    Instance.new("UICorner", cooldownOverlay).CornerRadius = UDim.new(0, 10)

    -- Cooldown text
    local cdText = makeLabel(cooldownOverlay, "CooldownLabel",
        "",
        UDim2.new(1, 0, 0, 30),
        UDim2.new(0, 0, 0.5, -15),
        Color3.fromRGB(255, 255, 255),
        Enum.Font.GothamBlack)
    cdText.ZIndex = 6

    -- Clickable button overlay
    local clickBtn = Instance.new("TextButton")
    clickBtn.Name = "AbilityButton"
    clickBtn.Size = UDim2.new(1, 0, 1, 0)
    clickBtn.BackgroundTransparency = 1
    clickBtn.Text = ""
    clickBtn.ZIndex = 10
    clickBtn.Parent = btnFrame

    -- Simpan referensi
    abilityButtons[abilityConfig.name] = {
        frame = btnFrame,
        overlay = cooldownOverlay,
        cdText = cdText,
        config = abilityConfig,
    }

    -- Click handler
    clickBtn.Activated:Connect(function()
        if abilityCooldowns[abilityConfig.name] then return end
        UseAbilityEvent:FireServer(abilityConfig.name)
    end)

    -- Hover
    clickBtn.MouseEnter:Connect(function()
        TweenService:Create(btnFrame, TweenInfo.new(0.1), {
            BackgroundColor3 = Color3.fromRGB(30, 30, 50)
        }):Play()
    end)
    clickBtn.MouseLeave:Connect(function()
        TweenService:Create(btnFrame, TweenInfo.new(0.1), {
            BackgroundColor3 = Color3.fromRGB(15, 15, 30)
        }):Play()
    end)
end

-- ============================================================
-- UPDATE COOLDOWN
-- ============================================================
local function startCooldownUI(abilityName, cooldown)
    local data = abilityButtons[abilityName]
    if not data then return end
    if abilityCooldowns[abilityName] then return end

    abilityCooldowns[abilityName] = true
    data.overlay.Visible = true

    local startTime = tick()
    task.spawn(function()
        while true do
            local elapsed = tick() - startTime
            local remaining = math.max(0, cooldown - elapsed)
            local progress = remaining / cooldown  -- 1 = full cooldown, 0 = ready

            -- Fill overlay dari atas (semakin berkurang)
            TweenService:Create(data.overlay, TweenInfo.new(0.1), {
                Size = UDim2.new(1, 0, progress, 0),
                Position = UDim2.new(0, 0, 1 - progress, 0),
            }):Play()

            data.cdText.Text = math.ceil(remaining) .. "s"

            if remaining <= 0 then
                data.overlay.Visible = false
                data.cdText.Text = ""
                abilityCooldowns[abilityName] = nil
                -- Flash ready
                TweenService:Create(data.frame, TweenInfo.new(0.2), {
                    BackgroundColor3 = data.config.color
                }):Play()
                task.delay(0.3, function()
                    TweenService:Create(data.frame, TweenInfo.new(0.3), {
                        BackgroundColor3 = Color3.fromRGB(15, 15, 30)
                    }):Play()
                end)
                break
            end
            task.wait(0.05)
        end
    end)
end

-- ============================================================
-- KEYBOARD SHORTCUTS
-- ============================================================
local keyBinds = {
    [Enum.KeyCode.Q] = "Dash",
    [Enum.KeyCode.F] = "Shield",
    [Enum.KeyCode.R] = "Teleport",
    [Enum.KeyCode.G] = "FreezeBall",
}

UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    local abilityName = keyBinds[input.KeyCode]
    if abilityName then
        if not abilityCooldowns[abilityName] then
            UseAbilityEvent:FireServer(abilityName)
        end
    end
end)

-- ============================================================
-- LISTEN UPDATE EVENTS
-- ============================================================
UpdateUIEvent.OnClientEvent:Connect(function(data)
    if not data then return end

    if data.type == "AbilityUsed" and data.abilityName and data.cooldown then
        startCooldownUI(data.abilityName, data.cooldown)
    elseif data.type == "AbilityCooldown" and data.abilityName then
        -- Server menolak, ability masih cooldown
        local btnData = abilityButtons[data.abilityName]
        if btnData then
            -- Shake effect kecil
            TweenService:Create(btnData.frame, TweenInfo.new(0.05), {
                Position = UDim2.new(btnData.frame.Position.X.Scale, 5, btnData.frame.Position.Y.Scale, 0)
            }):Play()
            task.delay(0.05, function()
                TweenService:Create(btnData.frame, TweenInfo.new(0.05), {
                    Position = UDim2.new(btnData.frame.Position.X.Scale, 0, btnData.frame.Position.Y.Scale, 0)
                }):Play()
            end)
        end
    end
end)

print("[AbilityUI] Initialized")
