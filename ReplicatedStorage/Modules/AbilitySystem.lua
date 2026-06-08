-- AbilitySystem.lua
-- ReplicatedStorage/Modules/AbilitySystem
-- Sistem ability modular: Dash, Shield, Teleport, Freeze Ball

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local RemoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local UseAbilityEvent = RemoteEvents:WaitForChild("UseAbility")
local UpdateUIEvent = RemoteEvents:WaitForChild("UpdateUI")
local SpawnEffectEvent = RemoteEvents:WaitForChild("SpawnEffect")

local AbilitySystem = {}
AbilitySystem.__index = AbilitySystem

-- ============================================================
-- DEFINISI ABILITY
-- Mudah ditambah: cukup tambah entry baru di tabel ini
-- ============================================================
local ABILITIES = {
    Dash = {
        name = "Dash",
        description = "Bergerak cepat ke depan",
        cooldown = 8,
        icon = "rbxassetid://0",  -- Ganti dengan asset id ikon
        execute = function(player, params)
            local character = player.Character
            if not character then return false, "No character" end
            local hrp = character:FindFirstChild("HumanoidRootPart")
            local humanoid = character:FindFirstChild("Humanoid")
            if not hrp or not humanoid then return false, "No HRP" end

            -- Dash ke arah hadap
            local dashDistance = 30
            local lookVector = hrp.CFrame.LookVector
            local targetPos = hrp.Position + lookVector * dashDistance

            -- Cek batas arena
            local dist = math.sqrt(targetPos.X^2 + targetPos.Z^2)
            if dist > 58 then
                -- Batasi ke batas arena
                local norm = Vector2.new(targetPos.X, targetPos.Z).Unit
                targetPos = Vector3.new(norm.X * 55, targetPos.Y, norm.Y * 55)
            end

            -- Tween dash
            local dashTween = TweenService:Create(hrp, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                CFrame = CFrame.new(targetPos, targetPos + lookVector)
            })

            -- Naikkan kecepatan sementara (tidak perlu, pakai tween)
            humanoid.WalkSpeed = 0
            dashTween:Play()
            dashTween.Completed:Wait()
            humanoid.WalkSpeed = 16

            SpawnEffectEvent:FireAllClients({
                type = "Dash",
                position = hrp.Position,
                playerName = player.Name
            })

            return true, "Dash!"
        end
    },

    Shield = {
        name = "Shield",
        description = "Menahan satu serangan bola",
        cooldown = 15,
        icon = "rbxassetid://0",
        execute = function(player, params)
            local character = player.Character
            if not character then return false, "No character" end

            -- Tambahkan tag Shield
            local CollectionService = game:GetService("CollectionService")
            if CollectionService:HasTag(character, "ShieldActive") then
                return false, "Shield sudah aktif"
            end

            CollectionService:AddTag(character, "ShieldActive")

            -- Visual shield
            SpawnEffectEvent:FireAllClients({
                type = "Shield",
                position = character.HumanoidRootPart.Position,
                playerName = player.Name
            })

            -- Shield hilang setelah 10 detik atau kena bola
            task.delay(10, function()
                if CollectionService:HasTag(character, "ShieldActive") then
                    CollectionService:RemoveTag(character, "ShieldActive")
                    SpawnEffectEvent:FireAllClients({
                        type = "ShieldEnd",
                        playerName = player.Name
                    })
                end
            end)

            return true, "Shield aktif!"
        end
    },

    Teleport = {
        name = "Teleport",
        description = "Berpindah beberapa meter secara acak",
        cooldown = 12,
        icon = "rbxassetid://0",
        execute = function(player, params)
            local character = player.Character
            if not character then return false, "No character" end
            local hrp = character:FindFirstChild("HumanoidRootPart")
            if not hrp then return false, "No HRP" end

            -- Teleport ke posisi acak dalam arena
            local angle = math.random() * math.pi * 2
            local radius = math.random(10, 45)
            local newPos = Vector3.new(
                math.cos(angle) * radius,
                hrp.Position.Y,
                math.sin(angle) * radius
            )

            -- Efek sebelum teleport
            SpawnEffectEvent:FireAllClients({
                type = "TeleportOut",
                position = hrp.Position,
                playerName = player.Name
            })

            task.wait(0.2)
            hrp.CFrame = CFrame.new(newPos)

            SpawnEffectEvent:FireAllClients({
                type = "TeleportIn",
                position = newPos,
                playerName = player.Name
            })

            return true, "Teleport!"
        end
    },

    FreezeBall = {
        name = "FreezeBall",
        description = "Memperlambat bola selama 2 detik",
        cooldown = 20,
        icon = "rbxassetid://0",
        execute = function(player, params)
            -- Freeze bola via BallManager
            local BallManager = require(game.ServerScriptService:WaitForChild("BallManager"))
            BallManager:FreezeBall(2)

            SpawnEffectEvent:FireAllClients({
                type = "FreezeBall",
                playerName = player.Name
            })

            return true, "Bola dibekukan 2 detik!"
        end
    },
}

-- Cooldown tracking per player per ability
local cooldownTracker = {}  -- [userId][abilityName] = lastUsedTick

-- Anti-cheat: cooldown minimum
local function isOnCooldown(player, abilityName)
    local uid = player.UserId
    if not cooldownTracker[uid] then return false end
    if not cooldownTracker[uid][abilityName] then return false end
    local ab = ABILITIES[abilityName]
    if not ab then return false end
    local elapsed = tick() - cooldownTracker[uid][abilityName]
    return elapsed < ab.cooldown
end

local function setCooldown(player, abilityName)
    local uid = player.UserId
    if not cooldownTracker[uid] then cooldownTracker[uid] = {} end
    cooldownTracker[uid][abilityName] = tick()
end

local function getCooldownRemaining(player, abilityName)
    local uid = player.UserId
    if not cooldownTracker[uid] then return 0 end
    if not cooldownTracker[uid][abilityName] then return 0 end
    local ab = ABILITIES[abilityName]
    if not ab then return 0 end
    local elapsed = tick() - cooldownTracker[uid][abilityName]
    return math.max(0, ab.cooldown - elapsed)
end

-- Handle use ability dari client
UseAbilityEvent.OnServerEvent:Connect(function(player, abilityName)
    local RoundSystem = require(ReplicatedStorage.Modules:WaitForChild("RoundSystem"))
    if RoundSystem:GetState() ~= "Playing" then return end
    if RoundSystem:IsSpectator(player) then return end

    -- Validasi ability name
    if type(abilityName) ~= "string" then return end
    local ability = ABILITIES[abilityName]
    if not ability then
        warn("[AntiCheat] Invalid ability: " .. tostring(abilityName) .. " from " .. player.Name)
        return
    end

    -- Cek cooldown
    if isOnCooldown(player, abilityName) then
        local remaining = getCooldownRemaining(player, abilityName)
        UpdateUIEvent:FireClient(player, {
            type = "AbilityCooldown",
            remaining = remaining,
            abilityName = abilityName
        })
        return
    end

    -- Cek apakah pemain punya ability ini equipped
    local DataManager = require(game.ServerScriptService:WaitForChild("DataManager"))
    local data = DataManager:GetPlayerData(player)
    if data and data.equippedAbility ~= abilityName then
        -- Hanya boleh pakai ability yang di-equip
        -- Tapi default-nya semua ability tersedia untuk testing
        -- Uncomment baris berikut untuk enforce equip:
        -- return
    end

    -- Jalankan ability
    local success, msg = ability.execute(player, {})
    if success then
        setCooldown(player, abilityName)
        UpdateUIEvent:FireClient(player, {
            type = "AbilityUsed",
            abilityName = abilityName,
            cooldown = ability.cooldown,
            message = msg
        })
    end
end)

-- Cleanup
Players.PlayerRemoving:Connect(function(player)
    cooldownTracker[player.UserId] = nil
end)

-- Getter list ability
function AbilitySystem:GetAbilities()
    local list = {}
    for name, data in pairs(ABILITIES) do
        list[#list + 1] = {
            name = name,
            description = data.description,
            cooldown = data.cooldown,
            icon = data.icon,
        }
    end
    return list
end

function AbilitySystem:GetAbility(name)
    return ABILITIES[name]
end

return AbilitySystem
