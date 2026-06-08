-- BotTest.lua
-- Script test SEDERHANA untuk cek apakah bot bisa spawn
-- Taruh di ServerScriptService sebagai Script biasa
-- Setelah berhasil, script ini bisa dihapus

print("[BotTest] Script mulai jalan...")

task.wait(3) -- tunggu 3 detik setelah game start

print("[BotTest] Mulai spawn bot test...")

for i = 1, 10 do
    local botName = "TestBot_" .. i

    -- Posisi melingkar di arena
    local angle = (i / 10) * math.pi * 2
    local spawnPos = Vector3.new(
        math.cos(angle) * 30,
        5,
        math.sin(angle) * 30
    )

    -- Buat model sederhana
    local model = Instance.new("Model")
    model.Name = botName
    model.Parent = workspace

    -- Body utama (kotak berwarna)
    local body = Instance.new("Part")
    body.Name = "HumanoidRootPart"
    body.Size = Vector3.new(2, 3, 1)
    body.CFrame = CFrame.new(spawnPos)
    body.BrickColor = BrickColor.Random()
    body.Material = Enum.Material.SmoothPlastic
    body.Anchored = false
    body.CanCollide = true
    body.Parent = model
    model.PrimaryPart = body

    -- Humanoid wajib ada
    local humanoid = Instance.new("Humanoid")
    humanoid.DisplayName = botName
    humanoid.Parent = model

    -- Name tag
    local billGui = Instance.new("BillboardGui")
    billGui.Size = UDim2.new(0, 120, 0, 40)
    billGui.StudsOffset = Vector3.new(0, 3, 0)
    billGui.AlwaysOnTop = true
    billGui.Parent = body

    local label = Instance.new("TextLabel", billGui)
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = "🤖 " .. botName
    label.TextColor3 = Color3.fromRGB(255, 255, 0)
    label.TextScaled = true
    label.Font = Enum.Font.GothamBold

    print("[BotTest] Spawned: " .. botName .. " di posisi " .. tostring(spawnPos))
    task.wait(0.1)
end

print("[BotTest] Selesai! 10 bot harusnya sudah muncul di arena.")
