-- RoundUI.lua
-- StarterGui/RoundUI (LocalScript dalam ScreenGui)
-- UI utama dalam ronde: timer, alive count, target indicator, parry button

local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local player = Players.LocalPlayer

-- Referensi ScreenGui ini
local screenGui = script.Parent

-- ============================================================
-- BUAT KOMPONEN UI
-- ============================================================

-- Fungsi helper buat frame dengan corner
local function makeFrame(parent, name, size, pos, bgColor, bgTrans)
    local f = Instance.new("Frame")
    f.Name = name
    f.Size = size
    f.Position = pos
    f.BackgroundColor3 = bgColor or Color3.fromRGB(20, 20, 30)
    f.BackgroundTransparency = bgTrans or 0.3
    f.BorderSizePixel = 0
    f.Parent = parent
    local corner = Instance.new("UICorner", f)
    corner.CornerRadius = UDim.new(0, 10)
    return f
end

local function makeLabel(parent, name, text, size, pos, textColor, font, textScaled)
    local l = Instance.new("TextLabel")
    l.Name = name
    l.Size = size
    l.Position = pos
    l.BackgroundTransparency = 1
    l.Text = text
    l.TextColor3 = textColor or Color3.fromRGB(255, 255, 255)
    l.Font = font or Enum.Font.GothamBold
    l.TextScaled = textScaled ~= false
    l.BorderSizePixel = 0
    l.Parent = parent
    return l
end

-- ============================================================
-- STATUS GAME (atas tengah)
-- ============================================================
local statusFrame = makeFrame(screenGui, "StatusFrame",
    UDim2.new(0.35, 0, 0, 45),
    UDim2.new(0.325, 0, 0.01, 0),
    Color3.fromRGB(15, 15, 25), 0.2)

local statusLabel = makeLabel(statusFrame, "StatusLabel",
    "⏳ Menunggu Pemain...",
    UDim2.new(1, 0, 1, 0),
    UDim2.new(0, 0, 0, 0),
    Color3.fromRGB(255, 255, 255),
    Enum.Font.GothamBold)

local statusStroke = Instance.new("UIStroke", statusFrame)
statusStroke.Color = Color3.fromRGB(100, 150, 255)
statusStroke.Thickness = 2

-- ============================================================
-- ALIVE COUNTER (atas kanan)
-- ============================================================
local aliveFrame = makeFrame(screenGui, "AliveFrame",
    UDim2.new(0, 130, 0, 40),
    UDim2.new(0.99, -130, 0.01, 0),
    Color3.fromRGB(15, 15, 25), 0.2)

local aliveLabel = makeLabel(aliveFrame, "AliveLabel",
    "👤 Hidup: --",
    UDim2.new(1, -10, 1, 0),
    UDim2.new(0, 5, 0, 0),
    Color3.fromRGB(100, 255, 100),
    Enum.Font.Gotham)

-- ============================================================
-- COUNTDOWN (tengah layar)
-- ============================================================
local countdownLabel = makeLabel(screenGui, "CountdownLabel",
    "",
    UDim2.new(0, 120, 0, 120),
    UDim2.new(0.5, -60, 0.4, 0),
    Color3.fromRGB(255, 255, 0),
    Enum.Font.GothamBlack)
countdownLabel.TextStrokeTransparency = 0.5
countdownLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
countdownLabel.Visible = true
countdownLabel.ZIndex = 10

-- ============================================================
-- TARGET INDICATOR (tengah-atas, hanya tampil saat jadi target)
-- ============================================================
local targetFrame = makeFrame(screenGui, "TargetFrame",
    UDim2.new(0.5, 0, 0, 55),
    UDim2.new(0.25, 0, 0.07, 0),
    Color3.fromRGB(200, 0, 0), 0.15)
targetFrame.Visible = false

local targetIndicator = makeLabel(targetFrame, "TargetIndicator",
    "⚠️ BOLA MENGEJARMU! ⚠️",
    UDim2.new(1, 0, 1, 0),
    UDim2.new(0, 0, 0, 0),
    Color3.fromRGB(255, 80, 80),
    Enum.Font.GothamBlack)
targetIndicator.Visible = false

local targetStroke = Instance.new("UIStroke", targetFrame)
targetStroke.Color = Color3.fromRGB(255, 0, 0)
targetStroke.Thickness = 2

-- Override TargetIndicator.Visible property untuk juga toggle frame
local _targetMeta = {}
_targetMeta.__index = _targetMeta
function targetIndicator:SetVisible(vis)
    self.Visible = vis
    targetFrame.Visible = vis
end

-- ============================================================
-- PARRY BUTTON (bawah tengah)
-- ============================================================
local parryFrame = makeFrame(screenGui, "ParryFrame",
    UDim2.new(0, 140, 0, 140),
    UDim2.new(0.5, -70, 0.8, 0),
    Color3.fromRGB(15, 15, 25), 0.3)

local parryBtn = Instance.new("TextButton")
parryBtn.Name = "ParryButton"
parryBtn.Size = UDim2.new(0.85, 0, 0.6, 0)
parryBtn.Position = UDim2.new(0.075, 0, 0.1, 0)
parryBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 255)
parryBtn.BorderSizePixel = 0
parryBtn.Text = "⚔️ PARRY"
parryBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
parryBtn.TextScaled = true
parryBtn.Font = Enum.Font.GothamBlack
parryBtn.ZIndex = 5
parryBtn.Parent = parryFrame

local parryCorner = Instance.new("UICorner", parryBtn)
parryCorner.CornerRadius = UDim.new(0, 12)

local parryStroke = Instance.new("UIStroke", parryBtn)
parryStroke.Color = Color3.fromRGB(100, 200, 255)
parryStroke.Thickness = 2

local parryHint = makeLabel(parryFrame, "ParryHint",
    "[E] atau Klik",
    UDim2.new(1, 0, 0.25, 0),
    UDim2.new(0, 0, 0.72, 0),
    Color3.fromRGB(150, 150, 200),
    Enum.Font.Gotham)
parryHint.TextScaled = true

-- Animasi hover parry button
parryBtn.MouseEnter:Connect(function()
    TweenService:Create(parryBtn, TweenInfo.new(0.15), {
        BackgroundColor3 = Color3.fromRGB(50, 200, 255),
        Size = UDim2.new(0.9, 0, 0.65, 0)
    }):Play()
end)

parryBtn.MouseLeave:Connect(function()
    TweenService:Create(parryBtn, TweenInfo.new(0.15), {
        BackgroundColor3 = Color3.fromRGB(0, 150, 255),
        Size = UDim2.new(0.85, 0, 0.6, 0)
    }):Play()
end)

-- ============================================================
-- WINNER FRAME (tengah layar, hidden default)
-- ============================================================
local winnerFrame = makeFrame(screenGui, "WinnerFrame",
    UDim2.new(0, 0, 0, 0),
    UDim2.new(0.5, 0, 0.35, 0),
    Color3.fromRGB(10, 10, 20), 0.1)
winnerFrame.AnchorPoint = Vector2.new(0.5, 0.5)
winnerFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
winnerFrame.Visible = false
winnerFrame.ZIndex = 20

local winnerLabel = makeLabel(winnerFrame, "WinnerLabel",
    "🏆 WINNER!",
    UDim2.new(1, -20, 0.5, 0),
    UDim2.new(0, 10, 0.1, 0),
    Color3.fromRGB(255, 215, 0),
    Enum.Font.GothamBlack)
winnerLabel.TextStrokeTransparency = 0
winnerLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)

local winnerSub = makeLabel(winnerFrame, "WinnerSub",
    "Ronde baru segera dimulai...",
    UDim2.new(1, -20, 0.3, 0),
    UDim2.new(0, 10, 0.65, 0),
    Color3.fromRGB(200, 200, 200),
    Enum.Font.Gotham)

local winnerStroke = Instance.new("UIStroke", winnerFrame)
winnerStroke.Color = Color3.fromRGB(255, 215, 0)
winnerStroke.Thickness = 3

-- ============================================================
-- ROUND NUMBER (atas kiri)
-- ============================================================
local roundFrame = makeFrame(screenGui, "RoundFrame",
    UDim2.new(0, 130, 0, 40),
    UDim2.new(0.01, 0, 0.01, 0),
    Color3.fromRGB(15, 15, 25), 0.2)

local roundLabel = makeLabel(roundFrame, "RoundLabel",
    "Ronde #1",
    UDim2.new(1, -10, 1, 0),
    UDim2.new(0, 5, 0, 0),
    Color3.fromRGB(180, 180, 255),
    Enum.Font.Gotham)

print("[RoundUI] UI components created")
