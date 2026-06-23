--[[ 
  Fabled Legacy Auto Farm — Merged Script
  Base: alyssagithub (open source auto-farm core)
  + Fitur: Silentzy18 (GUI, auto heal, hover, auto dungeon, auto retry)
  + Auto queue_on_teleport persistence
]]

-- Auto-re-execute on teleport
pcall(queue_on_teleport or syn.queue_on_teleport or fluxus.queue_on_teleport,
  'loadstring(game:HttpGet("https://raw.githubusercontent.com/alyssagithub/Scripts/main/Fabled%20Legacy.lua"))()')

-- Wait for game to load
if not game:IsLoaded() then game.Loaded:Wait() end

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")
local VirtualUser = game:GetService("VirtualUser")

-- Constants
local SWING_REMOTE = "Swing"
local SPELL_REMOTE = "useSpell"
local DUNGEON_REMOTE = "StartDungeon"
local VOTE_REMOTE = "voteRemote"
local ENEMIES_FOLDER = workspace:FindFirstChild("Enemies")
local HEAL_ZONES = workspace:FindFirstChild("HealingZones")

-- Player
local Player = Players.LocalPlayer
local Character = Player.Character or Player.CharacterAdded:Wait()
local RootPart

-- ─── GUI SETUP ──────────────────────────────────────────────────────────

-- Load UI Library (open source Wally by dementiaenjoyer / Silentzy18 compatible)
local Library
local success, lib = pcall(function()
    return loadstring(game:HttpGet("https://raw.githubusercontent.com/dementiaenjoyer/UI-LIBRARIES/refs/heads/main/wally-modified/source.lua"))()
end)
if success and lib then
    Library = lib
else
    -- Fallback: simple UI without library
    Library = nil
end

-- Config persistence
local CONFIG_FILE = "fl_autofarm_config.json"
local defaultConfig = {
    autofarm = false,
    hoverDistance = 12,
    healThreshold = 30,  -- percent
    autoReset = false,
    autoRetry = true,
    autoDungeon = true,
    useQ = true,
    useE = true,
    swingEnabled = true,
    keybind = "F",
}

local function loadConfig()
    if isfile and isfile(CONFIG_FILE) then
        local s, data = pcall(function()
            return HttpService:JSONDecode(readfile(CONFIG_FILE))
        end)
        if s and type(data) == "table" then
            for k, v in pairs(defaultConfig) do
                if data[k] == nil then data[k] = v end
            end
            return data
        end
    end
    return defaultConfig
end

local function saveConfig(cfg)
    if writefile then
        writefile(CONFIG_FILE, HttpService:JSONEncode(cfg))
    end
end

local config = loadConfig()

-- ─── AUTO FARM CORE ─────────────────────────────────────────────────────

local FarmState = {
    Running = false,
    CurrentEnemy = nil,
    LastDamageTime = 0,
    LastHealth = nil,
    LastHealthCheck = 0,
    Connections = {},
    AntiAfkConn = nil,
}

local function queueOnTeleport()
    pcall(queue_on_teleport or syn.queue_on_teleport or fluxus.queue_on_teleport,
        'loadstring(game:HttpGet("https://raw.githubusercontent.com/alyssagithub/Scripts/main/Fabled%20Legacy.lua"))()')
end
queueOnTeleport()

-- Anti-AFK
local function startAntiAfk()
    if FarmState.AntiAfkConn then
        FarmState.AntiAfkConn:Disconnect()
    end
    FarmState.AntiAfkConn = Player.Idled:Connect(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end)
end

local function stopAntiAfk()
    if FarmState.AntiAfkConn then
        FarmState.AntiAfkConn:Disconnect()
        FarmState.AntiAfkConn = nil
    end
end

-- Validasi enemy
local function isValidEnemy(enemy)
    if not enemy then return false end
    local hum = enemy:FindFirstChildOfClass("Humanoid")
    local hrp = enemy:FindFirstChild("HumanoidRootPart")
    return hum and hrp and hum.Health > 0 and enemy.Parent
end

-- Cari enemy terdekat
local function findClosestEnemy(pos)
    local folder = ENEMIES_FOLDER
    if not folder then return nil end

    local closest, dist = nil, math.huge
    for _, enemy in ipairs(folder:GetChildren()) do
        if isValidEnemy(enemy) then
            local d = (pos - enemy.HumanoidRootPart.Position).Magnitude
            if d < dist then
                dist = d
                closest = enemy
            end
        end
    end
    return closest
end

-- Start dungeon (FireServer)
local function startDungeon()
    if not config.autoDungeon then return end
    local remote = ReplicatedStorage:FindFirstChild(DUNGEON_REMOTE)
    if remote then
        pcall(function() remote:FireServer(true) end)
    end
end

-- Auto Retry lobby
local function autoRetryLoop()
    if not config.autoRetry then return end
    task.spawn(function()
        local voteRemote
        repeat
            voteRemote = ReplicatedStorage:FindFirstChild(VOTE_REMOTE)
            task.wait(1)
        until voteRemote

        while FarmState.Running and voteRemote do
            pcall(function()
                voteRemote:FireServer("repeat")
            end)
            task.wait(2)
        end
    end)
end

-- Auto heal
local function healthMonitor(char)
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end

    humanoid.HealthChanged:Connect(function(health)
        if not FarmState.Running then return end
        local max = humanoid.MaxHealth
        if max == 0 then return end
        local pct = (health / max) * 100
        if pct < config.healThreshold then
            -- Find heal zone and teleport to it if config says so
            -- Or just let the game's natural healing happen
        end
    end)
end

-- Hover di atas enemy
local function hoverAboveEnemy(char)
    if not FarmState.CurrentEnemy or not isValidEnemy(FarmState.CurrentEnemy) then
        return false
    end

    local root = char:FindFirstChild("HumanoidRootPart")
    local enemyRoot = FarmState.CurrentEnemy:FindFirstChild("HumanoidRootPart")
    if not root or not enemyRoot then return false end

    local enemyPos = enemyRoot.Position
    local enemyLook = enemyRoot.CFrame.LookVector.Unit
    
    -- Posisi di belakang + di atas enemy
    local offsetBehind = -4
    local offsetAbove = config.hoverDistance
    local offset = Vector3.new(0, offsetAbove, 0) + (enemyLook * offsetBehind)

    root.CFrame = CFrame.new(enemyPos + offset, enemyPos)
    return true
end

-- Fungsi farming utama
local function farmTick()
    if not FarmState.Running then return end
    if not Character then return end

    local root = Character:FindFirstChild("HumanoidRootPart")
    if not root then return end

    local swing = ReplicatedStorage:FindFirstChild(SWING_REMOTE)
    local spell = ReplicatedStorage:FindFirstChild(SPELL_REMOTE)
    if not swing or not spell then return end

    -- Cari enemy baru jika current sudah mati
    if not FarmState.CurrentEnemy or not isValidEnemy(FarmState.CurrentEnemy) then
        FarmState.CurrentEnemy = findClosestEnemy(root.Position)
        FarmState.LastHealth = nil
    end

    -- Hover dan attack
    if FarmState.CurrentEnemy then
        -- Face enemy
        root.CFrame = CFrame.lookAt(root.Position, 
            Vector3.new(FarmState.CurrentEnemy.Position.X, root.Position.Y, FarmState.CurrentEnemy.Position.Z))

        -- Swing
        if config.swingEnabled then
            swing:FireServer()
        end

        -- Spell Q
        if config.useQ then
            local qFrame = Player:FindFirstChild("PlayerGui"):FindFirstChild("SpellGui"):FindFirstChild("qMainFrame"):FindFirstChild("coverQ")
            if qFrame and not qFrame.Visible then
                spell:FireServer("Q")
            end
        end

        -- Spell E
        if config.useE then
            local eFrame = Player:FindFirstChild("PlayerGui"):FindFirstChild("SpellGui"):FindFirstChild("eMainFrame"):FindFirstChild("coverE")
            if eFrame and not eFrame.Visible then
                spell:FireServer("E")
            end
        end

        -- Hover
        hoverAboveEnemy(Character)

        -- Damage check for auto reset
        if config.autoReset then
            local enemyHum = FarmState.CurrentEnemy:FindFirstChildOfClass("Humanoid")
            if enemyHum then
                if FarmState.LastHealth == nil then
                    FarmState.LastHealth = enemyHum.Health
                elseif enemyHum.Health < FarmState.LastHealth then
                    FarmState.LastHealth = enemyHum.Health
                    FarmState.LastDamageTime = tick()
                end
            end
        end
    end

    -- Auto reset jika no damage > 10 detik
    if config.autoReset and tick() - FarmState.LastDamageTime > 10 then
        local humanoid = Character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid.Health = 0
            FarmState.LastDamageTime = tick()
        end
    end
end

-- ─── START / STOP FARM ──────────────────────────────────────────────────

local function startFarming()
    if FarmState.Running then return end
    FarmState.Running = true
    FarmState.LastDamageTime = tick()

    -- Clean old connections
    for _, conn in ipairs(FarmState.Connections) do
        pcall(conn.Disconnect, conn)
    end
    FarmState.Connections = {}

    -- Ensure character
    Character = Player.Character or Player.CharacterAdded:Wait()
    if not Character then
        FarmState.Running = false
        return
    end

    RootPart = Character:WaitForChild("HumanoidRootPart")

    -- Start dungeon
    startDungeon()
    autoRetryLoop()
    startAntiAfk()
    healthMonitor(Character)

    -- Heartbeat farm loop
    local heartbeat = RunService.Heartbeat:Connect(function()
        farmTick()
    end)
    table.insert(FarmState.Connections, heartbeat)
end

local function stopFarming()
    FarmState.Running = false
    FarmState.CurrentEnemy = nil
    for _, conn in ipairs(FarmState.Connections) do
        pcall(conn.Disconnect, conn)
    end
    FarmState.Connections = {}
    stopAntiAfk()
end

-- Character respawn handler
Player.CharacterAdded:Connect(function(char)
    Character = char
    RootPart = char:WaitForChild("HumanoidRootPart")
    task.wait(1)
    if FarmState.Running then
        -- Restart farm with new character
        startFarming()
    end
end)

-- ─── GUI ─────────────────────────────────────────────────────────────────

-- Try Wally library, fallback to simple GUI
local window

if Library then
    window = Library:CreateWindow("Fabled Legacy — Auto Farm")
    
    window:Section("Auto Farm Settings")
    
    window:Toggle("Auto Farm", {default = config.autofarm}, function(val)
        config.autofarm = val
        saveConfig(config)
        if val then
            startFarming()
        else
            stopFarming()
        end
    end)
    
    window:Toggle("Auto Dungeon", {default = config.autoDungeon}, function(val)
        config.autoDungeon = val
        saveConfig(config)
    end)
    
    window:Toggle("Auto Retry Lobby", {default = config.autoRetry}, function(val)
        config.autoRetry = val
        saveConfig(config)
    end)
    
    window:Toggle("Auto Reset (No Dmg > 10s)", {default = config.autoReset}, function(val)
        config.autoReset = val
        saveConfig(config)
    end)
    
    window:Section("Abilities")
    
    window:Toggle("Use Q Spell", {default = config.useQ}, function(val)
        config.useQ = val
        saveConfig(config)
    end)
    
    window:Toggle("Use E Spell", {default = config.useE}, function(val)
        config.useE = val
        saveConfig(config)
    end)
    
    window:Toggle("Swing", {default = config.swingEnabled}, function(val)
        config.swingEnabled = val
        saveConfig(config)
    end)
    
    window:Section("Positioning")
    
    window:Slider("Hover Distance", {
        min = 5, max = 50, default = config.hoverDistance,
    }, function(val)
        config.hoverDistance = val
        saveConfig(config)
    end)
    
    window:Slider("Heal HP (%)", {
        min = 10, max = 100, default = config.healThreshold,
    }, function(val)
        config.healThreshold = val
        saveConfig(config)
    end)
    
    window:Section("Keybinds")
    
    window:Label("Toggle Auto Farm: " .. config.keybind .. " key")
    
else
    -- Simple fallback: print instructions to chat
    print("Fabled Legacy Auto Farm loaded!")
    print("Use /auto to toggle farm")
    print("Use /q, /e, /swing to toggle spells")
    print("Use /dist <number> for hover distance")
    
    -- Chat command listener
    Player.Chatted:Connect(function(msg)
        msg = msg:lower()
        if msg == "/auto" then
            config.autofarm = not config.autofarm
            print(config.autofarm and "Auto Farm ON" or "Auto Farm OFF")
            if config.autofarm then startFarming() else stopFarming() end
        elseif msg == "/q" then
            config.useQ = not config.useQ
            print(config.useQ and "Q Spell ON" or "Q Spell OFF")
        elseif msg == "/e" then
            config.useE = not config.useE
            print(config.useE and "E Spell ON" or "E Spell OFF")
        elseif msg == "/swing" then
            config.swingEnabled = not config.swingEnabled
            print(config.swingEnabled and "Swing ON" or "Swing OFF")
        elseif msg:match("^/dist ") then
            local d = tonumber(msg:match("^/dist (.+)"))
            if d and d >= 5 and d <= 50 then
                config.hoverDistance = d
                print("Hover Distance set to " .. d)
            end
        end
    end)
end

-- ─── KEYBIND ─────────────────────────────────────────────────────────────

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode[config.keybind] then
        config.autofarm = not config.autofarm
        saveConfig(config)
        if config.autofarm then
            startFarming()
        else
            stopFarming()
        end
        -- Update GUI toggle if available
        if window and window.UpdateToggle then
            window:UpdateToggle("Auto Farm", config.autofarm)
        end
    end
end)

-- ─── AUTO START ─────────────────────────────────────────────────────────

if config.autofarm then
    task.wait(2)
    startFarming()
end

print("Fabled Legacy script loaded! (Key: " .. config.keybind .. " to toggle)")
