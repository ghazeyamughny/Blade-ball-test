-- ShopUI.lua
-- StarterGui/ShopUI (LocalScript dalam ScreenGui)
-- UI toko untuk membeli item dengan coins

local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local screenGui = script.Parent

local RemoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local BuyItemEvent = RemoteEvents:WaitForChild("BuyItem")
local UpdateUIEvent = RemoteEvents:WaitForChild("UpdateUI")

-- ============================================================
-- DATA KATALOG ITEM (mirror dari ShopSystem untuk display)
-- ============================================================
local SHOP_ITEMS = {
    { id = "sword_golden",   name = "Golden Sword",    category = "Sword",     price = 150, desc = "Pedang emas berkilau" },
    { id = "sword_shadow",   name = "Shadow Blade",    category = "Sword",     price = 300, desc = "Pedang dari kegelapan" },
    { id = "sword_neon",     name = "Neon Saber",      category = "Sword",     price = 200, desc = "Pedang neon cyberpunk" },
    { id = "ball_fire",      name = "Fireball",        category = "Ball",      price = 100, desc = "Bola api membara" },
    { id = "ball_ice",       name = "Ice Orb",         category = "Ball",      price = 100, desc = "Bola es dingin" },
    { id = "ball_lightning", name = "Thunder Ball",    category = "Ball",      price = 200, desc = "Bola petir berenergi" },
    { id = "ball_rainbow",   name = "Rainbow Orb",     category = "Ball",      price = 350, desc = "Bola pelangi warna-warni" },
    { id = "emote_dance",    name = "Victory Dance",   category = "Emote",     price = 80,  desc = "Menari kemenangan" },
    { id = "emote_taunt",    name = "Taunt",           category = "Emote",     price = 60,  desc = "Gerakan mengejek" },
    { id = "kill_confetti",  name = "Confetti Kill",   category = "Effect",    price = 120, desc = "Konfeti saat kill" },
    { id = "kill_lightning", name = "Lightning Kill",  category = "Effect",    price = 180, desc = "Petir saat kill" },
    { id = "kill_skull",     name = "Skull Boom",      category = "Effect",    price = 250, desc = "Tengkorak meledak" },
    { id = "exp_galaxy",     name = "Galaxy Explosion",category = "Effect",    price = 200, desc = "Ledakan galaksi" },
    { id = "exp_nuke",       name = "Nuke Blast",      category = "Effect",    price = 280, desc = "Ledakan nuklir mini" },
}

local CATEGORY_COLORS = {
    Sword  = Color3.fromRGB(255, 200, 50),
    Ball   = Color3.fromRGB(0, 200, 255),
    Emote  = Color3.fromRGB(200, 100, 255),
    Effect = Color3.fromRGB(255, 100, 100),
}

-- ============================================================
-- HELPER FUNCTIONS
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
-- BUAT MAIN SHOP FRAME
-- ============================================================
local shopFrame = makeFrame(screenGui, "ShopFrame",
    UDim2.new(0.7, 0, 0.8, 0),
    UDim2.new(0.15, 0, 0.1, 0))
shopFrame.BackgroundColor3 = Color3.fromRGB(12, 12, 22)
shopFrame.Visible = false
shopFrame.ZIndex = 15

local shopStroke = Instance.new("UIStroke", shopFrame)
shopStroke.Color = Color3.fromRGB(0, 150, 255)
shopStroke.Thickness = 2

-- Title
local titleLabel = makeLabel(shopFrame, "TitleLabel",
    "🛒 TOKO", UDim2.new(0.6, 0, 0, 45),
    UDim2.new(0.05, 0, 0.01, 0),
    Color3.fromRGB(255, 215, 0), Enum.Font.GothamBlack)

-- Coins display
local coinsLabel = makeLabel(shopFrame, "CoinsLabel",
    "💰 0 Coins", UDim2.new(0.3, 0, 0, 40),
    UDim2.new(0.65, 0, 0.01, 5),
    Color3.fromRGB(255, 215, 0), Enum.Font.Gotham)

-- Close button
local closeBtn = makeButton(shopFrame, "CloseButton",
    "✕", UDim2.new(0, 40, 0, 40),
    UDim2.new(1, -50, 0, 5),
    Color3.fromRGB(200, 50, 50))

-- Category tabs
local tabFrame = makeFrame(shopFrame, "TabFrame",
    UDim2.new(0.96, 0, 0, 45),
    UDim2.new(0.02, 0, 0.1, 0),
    Color3.fromRGB(8, 8, 18))

local categories = {"Sword", "Ball", "Emote", "Effect"}
local tabButtons = {}
local currentCategory = "Sword"

for i, cat in ipairs(categories) do
    local tabBtn = makeButton(tabFrame, cat .. "Tab",
        cat,
        UDim2.new(0.23, 0, 1, 0),
        UDim2.new((i-1) * 0.25 + 0.005, 0, 0, 0),
        CATEGORY_COLORS[cat] or Color3.fromRGB(100, 100, 100))
    tabBtn.BackgroundTransparency = i == 1 and 0 or 0.5
    tabButtons[cat] = tabBtn
end

-- Item list scroll frame
local scrollFrame = Instance.new("ScrollingFrame")
scrollFrame.Name = "ItemScroll"
scrollFrame.Size = UDim2.new(0.96, 0, 0.75, 0)
scrollFrame.Position = UDim2.new(0.02, 0, 0.22, 0)
scrollFrame.BackgroundTransparency = 1
scrollFrame.BorderSizePixel = 0
scrollFrame.ScrollBarThickness = 6
scrollFrame.ScrollBarImageColor3 = Color3.fromRGB(0, 150, 255)
scrollFrame.Parent = shopFrame

local gridLayout = Instance.new("UIGridLayout", scrollFrame)
gridLayout.CellSize = UDim2.new(0.3, -5, 0, 140)
gridLayout.CellPadding = UDim2.new(0, 8, 0, 8)
gridLayout.SortOrder = Enum.SortOrder.LayoutOrder

-- ============================================================
-- POPULATE ITEMS
-- ============================================================
local function populateCategory(cat)
    -- Clear existing
    for _, child in ipairs(scrollFrame:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end

    for _, item in ipairs(SHOP_ITEMS) do
        if item.category == cat then
            local card = makeFrame(scrollFrame, item.id .. "_card",
                UDim2.new(0, 0, 0, 0),
                UDim2.new(0, 0, 0, 0),
                Color3.fromRGB(20, 20, 35))
            card.LayoutOrder = 1

            -- Item name
            makeLabel(card, "NameLabel", item.name,
                UDim2.new(1, -8, 0, 28),
                UDim2.new(0, 4, 0, 5),
                CATEGORY_COLORS[cat] or Color3.fromRGB(255, 255, 255),
                Enum.Font.GothamBold)

            -- Description
            makeLabel(card, "DescLabel", item.desc,
                UDim2.new(1, -8, 0, 45),
                UDim2.new(0, 4, 0, 38),
                Color3.fromRGB(180, 180, 180),
                Enum.Font.Gotham)

            -- Price
            makeLabel(card, "PriceLabel", "💰 " .. item.price,
                UDim2.new(1, -8, 0, 25),
                UDim2.new(0, 4, 0, 88),
                Color3.fromRGB(255, 215, 0),
                Enum.Font.GothamBold)

            -- Buy button
            local buyBtn = makeButton(card, "BuyButton", "Beli",
                UDim2.new(0.85, 0, 0, 28),
                UDim2.new(0.075, 0, 1, -33),
                Color3.fromRGB(0, 180, 80))

            local cardStroke = Instance.new("UIStroke", card)
            cardStroke.Color = CATEGORY_COLORS[cat] or Color3.fromRGB(100, 100, 100)
            cardStroke.Thickness = 1
            cardStroke.Transparency = 0.5

            -- Buy action
            buyBtn.Activated:Connect(function()
                BuyItemEvent:FireServer(item.id)
                TweenService:Create(buyBtn, TweenInfo.new(0.1), {
                    BackgroundColor3 = Color3.fromRGB(255, 255, 0)
                }):Play()
                task.delay(0.2, function()
                    TweenService:Create(buyBtn, TweenInfo.new(0.2), {
                        BackgroundColor3 = Color3.fromRGB(0, 180, 80)
                    }):Play()
                end)
            end)

            -- Hover effect
            buyBtn.MouseEnter:Connect(function()
                TweenService:Create(buyBtn, TweenInfo.new(0.1), {
                    BackgroundColor3 = Color3.fromRGB(0, 220, 100)
                }):Play()
            end)
            buyBtn.MouseLeave:Connect(function()
                TweenService:Create(buyBtn, TweenInfo.new(0.1), {
                    BackgroundColor3 = Color3.fromRGB(0, 180, 80)
                }):Play()
            end)
        end
    end

    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, gridLayout.AbsoluteContentSize.Y + 20)
end

-- Tab switching
for _, cat in ipairs(categories) do
    tabButtons[cat].Activated:Connect(function()
        currentCategory = cat
        for _, c in ipairs(categories) do
            TweenService:Create(tabButtons[c], TweenInfo.new(0.15), {
                BackgroundTransparency = c == cat and 0 or 0.5
            }):Play()
        end
        populateCategory(cat)
    end)
end

populateCategory(currentCategory)

-- ============================================================
-- TOGGLE SHOP BUTTON (tombol buka shop)
-- ============================================================
local shopToggleBtn = makeButton(screenGui, "ShopToggle",
    "🛒 Shop",
    UDim2.new(0, 100, 0, 38),
    UDim2.new(0.01, 0, 0.9, 0),
    Color3.fromRGB(0, 120, 200))

local isOpen = false
shopToggleBtn.Activated:Connect(function()
    isOpen = not isOpen
    shopFrame.Visible = isOpen
    if isOpen then
        shopFrame.Size = UDim2.new(0, 0, 0, 0)
        TweenService:Create(shopFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back), {
            Size = UDim2.new(0.7, 0, 0.8, 0)
        }):Play()
    end
end)

closeBtn.Activated:Connect(function()
    TweenService:Create(shopFrame, TweenInfo.new(0.2), {
        Size = UDim2.new(0, 0, 0, 0)
    }):Play()
    task.delay(0.2, function()
        shopFrame.Visible = false
        isOpen = false
    end)
end)

-- Update coins saat dapat event
UpdateUIEvent.OnClientEvent:Connect(function(data)
    if data.type == "ShopResult" and data.coins then
        coinsLabel.Text = "💰 " .. data.coins .. " Coins"
    end
end)

-- Sync coins dari leaderstats
task.spawn(function()
    while true do
        task.wait(3)
        local leaderstats = player:FindFirstChild("leaderstats")
        if leaderstats and leaderstats:FindFirstChild("Coins") then
            coinsLabel.Text = "💰 " .. leaderstats.Coins.Value .. " Coins"
        end
    end
end)

print("[ShopUI] Initialized")
