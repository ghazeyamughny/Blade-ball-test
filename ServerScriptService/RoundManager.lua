-- RoundManager.lua
-- ServerScriptService/RoundManager
-- Bootstrap: memastikan semua RemoteEvents dan Module tersedia

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- ============================================================
-- BUAT FOLDER STRUKTUR DI REPLICATEDSTORAGE
-- ============================================================
local function ensureFolder(parent, name)
    local existing = parent:FindFirstChild(name)
    if existing then return existing end
    local folder = Instance.new("Folder")
    folder.Name = name
    folder.Parent = parent
    return folder
end

local function ensureRemoteEvent(parent, name)
    local existing = parent:FindFirstChild(name)
    if existing then return existing end
    local re = Instance.new("RemoteEvent")
    re.Name = name
    re.Parent = parent
    return re
end

-- Buat Modules folder
local modulesFolder = ensureFolder(ReplicatedStorage, "Modules")
local remoteEventsFolder = ensureFolder(ReplicatedStorage, "RemoteEvents")

-- Buat semua RemoteEvents yang diperlukan
local requiredEvents = {
    "ParryBall",
    "PlayerDied",
    "RoundStatus",
    "UpdateUI",
    "UseAbility",
    "BuyItem",
    "BallTarget",
    "SpawnEffect",
}

for _, eventName in ipairs(requiredEvents) do
    ensureRemoteEvent(remoteEventsFolder, eventName)
end

print("[RoundManager] RemoteEvents created: " .. #requiredEvents)

-- ============================================================
-- PASTIKAN MODUL-MODUL BERADA DI POSISI BENAR
-- Modul sudah ada di ReplicatedStorage/Modules dari script placement
-- ini hanya verifikasi
-- ============================================================

-- Setup ShopSystem listener (hanya perlu satu kali)
local Modules = ReplicatedStorage:WaitForChild("Modules")
local ShopSystem = require(Modules:WaitForChild("ShopSystem"))
local AbilitySystem = require(Modules:WaitForChild("AbilitySystem"))

-- BotManager akan spawn bot sendiri saat server start
-- Tidak perlu dipanggil lagi dari sini
print("[RoundManager] Modules loaded: ShopSystem, AbilitySystem")

-- ============================================================
-- ARENA SETUP (buat bagian arena jika belum ada)
-- ============================================================
local function setupArena()
    -- Cek apakah arena sudah ada
    if workspace:FindFirstChild("Arena") then return end

    print("[RoundManager] Creating arena...")

    -- Model utama arena
    local arenaModel = Instance.new("Model")
    arenaModel.Name = "Arena"
    arenaModel.Parent = workspace

    -- Platform utama (lantai arena lingkaran)
    local floor = Instance.new("Part")
    floor.Name = "ArenaFloor"
    floor.Size = Vector3.new(120, 2, 120)
    floor.Position = Vector3.new(0, -1, 0)
    floor.Anchored = true
    floor.BrickColor = BrickColor.new("Dark stone grey")
    floor.Material = Enum.Material.SmoothPlastic
    floor.Parent = arenaModel

    -- Decal tengah arena
    local decal = Instance.new("Decal")
    decal.Face = Enum.NormalId.Top
    decal.Color3 = Color3.fromRGB(0, 100, 200)
    decal.Transparency = 0.7
    decal.Parent = floor

    -- Batas arena lingkaran (invisible wall transparan)
    -- Buat 36 bagian untuk membentuk lingkaran
    local segments = 36
    local arenaRadius = 60
    local wallHeight = 8

    for i = 1, segments do
        local angle = (i / segments) * math.pi * 2
        local nextAngle = ((i + 1) / segments) * math.pi * 2

        local midAngle = (angle + nextAngle) / 2
        local wallWidth = 2 * arenaRadius * math.sin(math.pi / segments) + 0.5

        local wall = Instance.new("Part")
        wall.Name = "ArenaBoundary"
        wall.Size = Vector3.new(wallWidth, wallHeight, 1.5)
        wall.Position = Vector3.new(
            math.cos(midAngle) * arenaRadius,
            wallHeight / 2,
            math.sin(midAngle) * arenaRadius
        )
        wall.CFrame = CFrame.new(
            math.cos(midAngle) * arenaRadius,
            wallHeight / 2,
            math.sin(midAngle) * arenaRadius
        ) * CFrame.Angles(0, -midAngle + math.pi / 2, 0)

        wall.Anchored = true
        wall.CanCollide = true
        wall.Transparency = 0.85
        wall.BrickColor = BrickColor.new("Cyan")
        wall.Material = Enum.Material.Neon
        wall.Parent = arenaModel

        -- Efek cahaya di batas
        if i % 4 == 0 then
            local light = Instance.new("PointLight")
            light.Brightness = 2
            light.Range = 15
            light.Color = Color3.fromRGB(0, 200, 255)
            light.Parent = wall
        end
    end

    -- Lingkaran cahaya di lantai (dekorasi)
    for ring = 1, 3 do
        local ringRadius = ring * 18
        local ringParts = 24
        for i = 1, ringParts do
            local angle = (i / ringParts) * math.pi * 2
            local dot = Instance.new("Part")
            dot.Size = Vector3.new(1.5, 0.15, 1.5)
            dot.Position = Vector3.new(
                math.cos(angle) * ringRadius,
                0.01,
                math.sin(angle) * ringRadius
            )
            dot.Anchored = true
            dot.CanCollide = false
            dot.Material = Enum.Material.Neon
            dot.BrickColor = ring == 2 and BrickColor.new("Cyan") or BrickColor.new("Deep blue")
            dot.Transparency = 0.2
            dot.Parent = arenaModel
        end
    end

    -- BallSpawn point di tengah
    if not workspace:FindFirstChild("BallSpawn") then
        local ballSpawn = Instance.new("Part")
        ballSpawn.Name = "BallSpawn"
        ballSpawn.Size = Vector3.new(2, 2, 2)
        ballSpawn.Position = Vector3.new(0, 8, 0)
        ballSpawn.Anchored = true
        ballSpawn.Transparency = 1
        ballSpawn.CanCollide = false
        ballSpawn.Parent = workspace
    end

    -- SpawnPoints untuk pemain
    if not workspace:FindFirstChild("SpawnPoints") then
        local spawnFolder = Instance.new("Folder")
        spawnFolder.Name = "SpawnPoints"
        spawnFolder.Parent = workspace

        for i = 1, 20 do
            local angle = (i / 20) * math.pi * 2
            local radius = 40
            local spawnPart = Instance.new("SpawnLocation")
            spawnPart.Name = "Spawn_" .. i
            spawnPart.Size = Vector3.new(4, 1, 4)
            spawnPart.Position = Vector3.new(
                math.cos(angle) * radius,
                1,
                math.sin(angle) * radius
            )
            spawnPart.Anchored = true
            spawnPart.BrickColor = BrickColor.new("Cyan")
            spawnPart.Transparency = 0.7
            spawnPart.Neutral = true
            spawnPart.Duration = 0
            spawnPart.Parent = spawnFolder
        end
    end

    print("[RoundManager] Arena created successfully")
end

-- Setup arena
setupArena()

print("[RoundManager] Fully initialized")
