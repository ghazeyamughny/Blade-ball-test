-- MainUI.lua
-- StarterGui/MainUI (LocalScript dalam ScreenGui)
-- Leaderboard, stats display, dan main menu

local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local screenGui = script.Parent

local RemoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local UpdateUIEvent = RemoteEvents:WaitForChild("UpdateUI")

-- ============================================================
-- HELPER
-- ============================================================
local function makeFrame(parent, name, size, pos, bgColor, bgTrans)
    local f = Instance.new("Frame")
    f.Name = name
    f.Size = size
    f.Position = pos
    f.BackgroundColor3 = bgColor or Color3.fromRGB(12, 12, 22)
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

local function makeButton(parent, name, text, size, pos, bgColor)
    local b = Instance.new("TextButton")
    b.Name = name
    b.Size = size
    b.Position = pos
    b.BackgroundColor3 = bgColor or Color3.fromRGB(0, 150, 255)
    b.BorderSizePixel = 0
    b.Text = text
    b.TextColor3 = Color3.fromRGB(255, 255, 255)
    b.TextScaled = true
    b.Font = Enum.Font.GothamBold
    b.Parent = parent
    local c = Instance.new("UICorner", b)
    c.CornerRadius = UDim.new(0, 8)
    return b
end

-- ============================================================
-- STATS PANEL (kiri bawah)
-- ============================================================
local statsFrame = makeFrame(screenGui, "StatsFrame",
    UDim2.new(0, 160, 0, 160),
    UDim2.new(0.01, 0, 0.65, 0),
    Color3.fromRGB(12, 12, 22), 0.1)

local statsStroke = Instance.new("UIStroke", statsFrame)
statsStroke.Color = Color3.fromRGB(100, 100, 200)
statsStroke.Thickness = 1.5

makeLabel(statsFrame, "StatsTitle", "📊 STATS",
    UDim2.new(1, 0, 0.2, 0),
    UDim2.new(0, 0, 0, 0),
    Color3.fromRGB(200, 200, 255), Enum.Font.GothamBlack)

local winsLabel    = makeLabel(statsFrame, "WinsLabel",    "🏆 Wins: 0",     UDim2.new(1, -10, 0.18, 0), UDim2.new(0, 5, 0.22, 0), Color3.fromRGB(255, 215, 0))
local coinsLabel   = makeLabel(statsFrame, "CoinsLabel",   "💰 Coins: 0",    UDim2.new(1, -10, 0.18, 0), UDim2.new(0, 5, 0.41, 0), Color3.fromRGB(255, 200, 50))
local killsLabel   = makeLabel(statsFrame, "KillsLabel",   "⚔️ Kills: 0",    UDim2.new(1, -10, 0.18, 0), UDim2.new(0, 5, 0.60, 0), Color3.fromRGB(255, 100, 100))
local streakLabel  = makeLabel(statsFrame, "StreakLabel",  "🔥 Streak: 0",   UDim2.new(1, -10, 0.18, 0), UDim2.new(0, 5, 0.79, 0), Color3.fromRGB(255, 150, 0))

-- ============================================================
-- LEADERBOARD PANEL (kanan tengah)
-- ============================================================
local leaderboardFrame = makeFrame(screenGui, "LeaderboardFrame",
    UDim2.new(0, 220, 0, 320),
    UDim2.new(0.99, -220, 0.1, 0),
    Color3.fromRGB(12, 12, 22), 0.1)
leaderboardFrame.Visible = false

local lbStroke = Instance.new("UIStroke", leaderboardFrame)
lbStroke.Color = Color3.fromRGB(255, 215, 0)
lbStroke.Thickness = 2

makeLabel(leaderboardFrame, "LBTitle", "🏆 LEADERBOARD",
    UDim2.new(1, 0, 0, 40),
    UDim2.new(0, 0, 0, 0),
    Color3.fromRGB(255, 215, 0), Enum.Font.GothamBlack)

-- Header
local headerFrame = makeFrame(leaderboardFrame, "Header",
    UDim2.new(0.95, 0, 0, 25),
    UDim2.new(0.025, 0, 0, 44),
    Color3.fromRGB(20, 20, 40), 0.3)

makeLabel(headerFrame, "H1", "#",     UDim2.new(0.1, 0, 1, 0), UDim2.new(0, 0, 0, 0),     Color3.fromRGB(180, 180, 180))
makeLabel(headerFrame, "H2", "Nama",  UDim2.new(0.4, 0, 1, 0), UDim2.new(0.1, 0, 0, 0),   Color3.fromRGB(180, 180, 180))
makeLabel(headerFrame, "H3", "Wins",  UDim2.new(0.25, 0, 1, 0), UDim2.new(0.5, 0, 0, 0),  Color3.fromRGB(180, 180, 180))
makeLabel(headerFrame, "H4", "Kills", UDim2.new(0.25, 0, 1, 0), UDim2.new(0.75, 0, 0, 0), Color3.fromRGB(180, 180, 180))

-- Player list scroll
local lbScroll = Instance.new("ScrollingFrame")
lbScroll.Name = "LBScroll"
lbScroll.Size = UDim2.new(0.95, 0, 0.75, 0)
lbScroll.Position = UDim2.new(0.025, 0, 0.25, 0)
lbScroll.BackgroundTransparency = 1
lbScroll.BorderSizePixel = 0
lbScroll.ScrollBarThickness = 4
lbScroll.ScrollBarImageColor3 = Color3.fromRGB(255, 215, 0)
lbScroll.Parent = leaderboardFrame

local lbListLayout = Instance.new("UIListLayout", lbScroll)
lbListLayout.Padding = UDim.new(0, 3)

-- Toggle leaderboard button
local lbToggleBtn = makeButton(screenGui, "LeaderboardToggle",
    "🏆 Leaderboard",
    UDim2.new(0, 140, 0, 38),
    UDim2.new(0.01, 0, 0.86, 0),
    Color3.fromRGB(180, 130, 0))

local lbOpen = false
lbToggleBtn.Activated:Connect(function()
    lbOpen = not lbOpen
    leaderboardFrame.Visible = lbOpen
    if lbOpen then
        updateLeaderboard()
    end
end)

-- ============================================================
-- UPDATE LEADERBOARD
-- ============================================================
function updateLeaderboard()
    -- Clear entries
    for _, child in ipairs(lbScroll:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end

    -- Kumpulkan data pemain
    local playerData = {}
    for _, p in ipairs(Players:GetPlayers()) do
        local ls = p:FindFirstChild("leaderstats")
        local wins = ls and ls:FindFirstChild("Wins") and ls.Wins.Value or 0
        local kills = ls and ls:FindFirstChild("Kills") and ls.Kills.Value or 0
        playerData[#playerData + 1] = {
            name = p.Name,
            wins = wins,
            kills = kills,
        }
    end

    -- Sort by wins then kills
    table.sort(playerData, function(a, b)
        if a.wins ~= b.wins then return a.wins > b.wins end
        return a.kills > b.kills
    end)

    -- Buat rows
    for rank, data in ipairs(playerData) do
        local rowColors = {
            Color3.fromRGB(255, 215, 0),   -- Gold
            Color3.fromRGB(192, 192, 192), -- Silver
            Color3.fromRGB(205, 127, 50),  -- Bronze
        }
        local rowColor = rowColors[rank] or Color3.fromRGB(180, 180, 180)

        local row = makeFrame(lbScroll, "Row_" .. rank,
            UDim2.new(1, 0, 0, 32),
            UDim2.new(0, 0, 0, 0),
            Color3.fromRGB(18, 18, 30), 0.3)
        row.LayoutOrder = rank

        makeLabel(row, "Rank",  "#" .. rank,    UDim2.new(0.1, 0, 1, 0), UDim2.new(0, 0, 0, 0),     rowColor, Enum.Font.GothamBold)
        makeLabel(row, "Name",  data.name,       UDim2.new(0.4, 0, 1, 0), UDim2.new(0.1, 0, 0, 0),  Color3.fromRGB(255, 255, 255), Enum.Font.Gotham)
        makeLabel(row, "Wins",  tostring(data.wins),  UDim2.new(0.25, 0, 1, 0), UDim2.new(0.5, 0, 0, 0),  Color3.fromRGB(255, 215, 0), Enum.Font.Gotham)
        makeLabel(row, "Kills", tostring(data.kills), UDim2.new(0.25, 0, 1, 0), UDim2.new(0.75, 0, 0, 0), Color3.fromRGB(255, 100, 100), Enum.Font.Gotham)
    end

    lbScroll.CanvasSize = UDim2.new(0, 0, 0, lbListLayout.AbsoluteContentSize.Y + 10)
end

-- ============================================================
-- UPDATE STATS REAL-TIME
-- ============================================================
task.spawn(function()
    while true do
        task.wait(2)
        local ls = player:FindFirstChild("leaderstats")
        if ls then
            if ls:FindFirstChild("Wins")   then winsLabel.Text   = "🏆 Wins: "   .. ls.Wins.Value   end
            if ls:FindFirstChild("Coins")  then coinsLabel.Text  = "💰 Coins: "  .. ls.Coins.Value  end
            if ls:FindFirstChild("Kills")  then killsLabel.Text  = "⚔️ Kills: "  .. ls.Kills.Value  end
            if ls:FindFirstChild("Streak") then streakLabel.Text = "🔥 Streak: " .. ls.Streak.Value end
        end
    end
end)

-- ============================================================
-- PLAYER NAME TAG (hover info - optional)
-- ============================================================
-- Auto-refresh leaderboard setiap 10 detik jika open
task.spawn(function()
    while true do
        task.wait(10)
        if lbOpen then
            updateLeaderboard()
        end
    end
end)

print("[MainUI] Initialized")
