--[[ 
  Fabled Legacy Auto Farm — Rayfield Hub Integrated
  For use with dayum hub / standalone
]]

-- Auto-re-execute on teleport
pcall(queue_on_teleport or syn.queue_on_teleport or fluxus.queue_on_teleport,
    'loadstring(game:HttpGet("https://raw.githubusercontent.com/L13N6/JJ/main/FabledFarm.lua"))()')

-- Wait for game
if not game:IsLoaded() then game.Loaded:Wait() end

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")
local VirtualUser = game:GetService("VirtualUser")
local TweenService = game:GetService("TweenService")

-- Constants
local SWING = "Swing"
local SPELL = "useSpell"
local DUNGEON = "StartDungeon"
local VOTE = "voteRemote"
local ENEMIES_FOLDER = workspace:FindFirstChild("Enemies")

-- Player
local Player = Players.LocalPlayer
local Character = Player.Character or Player.CharacterAdded:Wait()
local RootPart

-- Config
local CONFIG_FILE = "fl_farm_cfg.json"
local cfg = {
    enabled = false,
    hoverDist = 12,
    autoDungeon = true,
    autoRetry = true,
    autoReset = false,
    useQ = true,
    useE = true,
    swing = true,
}

local function loadCfg()
    if isfile and isfile(CONFIG_FILE) then
        local s, d = pcall(function() return HttpService:JSONDecode(readfile(CONFIG_FILE)) end)
        if s and type(d) == "table" then
            for k, v in pairs(cfg) do if d[k] == nil then d[k] = v end end
            return d
        end
    end
    return cfg
end
cfg = loadCfg()
local function saveCfg()
    if writefile then writefile(CONFIG_FILE, HttpService:JSONEncode(cfg)) end
end

-- State
local state = {
    running = false,
    enemy = nil,
    lastDmg = 0,
    lastHp = nil,
    healZone = nil,
    conn = nil,
    afkConn = nil,
}

-- Validasi enemy
local function alive(e)
    if not e then return false end
    local h = e:FindFirstChildOfClass("Humanoid")
    local r = e:FindFirstChild("HumanoidRootPart")
    return h and r and h.Health > 0 and e.Parent
end

-- Cari enemy
local function findEnemy(pos)
    local f = ENEMIES_FOLDER
    if not f then return nil end
    local best, bestD = nil, math.huge
    for _, e in ipairs(f:GetChildren()) do
        if alive(e) then
            local d = (pos - e.HumanoidRootPart.Position).Magnitude
            if d < bestD then bestD, best = d, e end
        end
    end
    return best
end

-- Anti AFK
local function antiAfk(on)
    if state.afkConn then state.afkConn:Disconnect() end
    if on then
        state.afkConn = Player.Idled:Connect(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end)
    end
end

-- Farm loop
local function farmTick()
    if not state.running or not Character then return end
    local root = Character:FindFirstChild("HumanoidRootPart")
    if not root then return end

    local swing = ReplicatedStorage:FindFirstChild(SWING)
    local spell = ReplicatedStorage:FindFirstChild(SPELL)
    if not swing or not spell then return end

    -- Cari enemy baru
    if not state.enemy or not alive(state.enemy) then
        state.enemy = findEnemy(root.Position)
        state.lastHp = nil
    end

    if state.enemy then
        local eRoot = state.enemy:FindFirstChild("HumanoidRootPart")
        if eRoot then
            -- Face & hover
            local look = CFrame.lookAt(root.Position, Vector3.new(eRoot.Position.X, root.Position.Y, eRoot.Position.Z))
            local hover = eRoot.Position + Vector3.new(0, cfg.hoverDist, 0)
            root.CFrame = CFrame.new(hover, eRoot.Position)

            -- Swing
            if cfg.swing then pcall(function() swing:FireServer() end) end

            -- Spell Q
            if cfg.useQ then
                local qg = Player:FindFirstChild("PlayerGui")
                if qg then
                    local c = qg:FindFirstChild("coverQ", true)
                    if c and not c.Visible then pcall(function() spell:FireServer("Q") end) end
                end
            end

            -- Spell E
            if cfg.useE then
                local qg = Player:FindFirstChild("PlayerGui")
                if qg then
                    local c = qg:FindFirstChild("coverE", true)
                    if c and not c.Visible then pcall(function() spell:FireServer("E") end) end
                end
            end

            -- Damage check
            if cfg.autoReset then
                local eh = state.enemy:FindFirstChildOfClass("Humanoid")
                if eh then
                    if state.lastHp == nil then
                        state.lastHp = eh.Health
                    elseif eh.Health < state.lastHp then
                        state.lastHp = eh.Health
                        state.lastDmg = tick()
                    end
                end
            end
        end
    end

    -- Auto reset
    if cfg.autoReset and tick() - state.lastDmg > 10 then
        local h = Character:FindFirstChildOfClass("Humanoid")
        if h and h.Health > 0 then h.Health = 0 end
        state.lastDmg = tick()
    end
end

-- Auto retry loop
local function retryLoop()
    if not cfg.autoRetry then return end
    task.spawn(function()
        local vr
        repeat task.wait(1) vr = ReplicatedStorage:FindFirstChild(VOTE) until vr
        while state.running and vr do
            pcall(function() vr:FireServer("repeat") end)
            task.wait(2)
        end
    end)
end

-- Start/stop
local function startFarm()
    if state.running then return end
    state.running = true
    state.lastDmg = tick()
    Character = Player.Character or Player.CharacterAdded:Wait()
    RootPart = Character:WaitForChild("HumanoidRootPart")
    antiAfk(true)

    -- Auto dungeon
    if cfg.autoDungeon then
        local dr = ReplicatedStorage:FindFirstChild(DUNGEON)
        if dr then pcall(function() dr:FireServer(true) end) end
    end

    retryLoop()

    if state.conn then state.conn:Disconnect() end
    state.conn = RunService.Heartbeat:Connect(farmTick)
end

local function stopFarm()
    state.running = false
    state.enemy = nil
    if state.conn then state.conn:Disconnect() end
    antiAfk(false)
end

-- Character respawn
Player.CharacterAdded:Connect(function(char)
    Character = char
    RootPart = char:WaitForChild("HumanoidRootPart")
    task.wait(1)
    if state.running then
        Character = char
        RootPart = char:WaitForChild("HumanoidRootPart")
    end
end)

-- ─── INTEGRATE INTO RAYFIELD HUB ────────────────────────────────────────

-- Check if Rayfield is available (loaded from dayum hub)
local Rayfield = _G.Rayfield or nil
if not Rayfield then
    -- Try to find it from the script closure
    local r = getupvalues(getsenv(getscriptclosure()))
    for _, v in next, r do
        if type(v) == "table" and v.Flags and v.CreateWindow then
            Rayfield = v
            break
        end
    end
end

if Rayfield then
    -- Create tab in existing Rayfield
    local Tab = Rayfield:CreateTab({
        Name = "Fabled Farm",
        Image = 4483362458
    })

    Tab:CreateSection("Auto Farm")

    Tab:CreateToggle({
        Name = "Auto Farm",
        Default = cfg.enabled,
        Callback = function(v)
            cfg.enabled = v
            saveCfg()
            if v then startFarm() else stopFarm() end
        end
    })

    Tab:CreateToggle({
        Name = "Auto Dungeon",
        Default = cfg.autoDungeon,
        Callback = function(v)
            cfg.autoDungeon = v
            saveCfg()
        end
    })

    Tab:CreateToggle({
        Name = "Auto Retry Lobby",
        Default = cfg.autoRetry,
        Callback = function(v)
            cfg.autoRetry = v
            saveCfg()
        end
    })

    Tab:CreateToggle({
        Name = "Auto Reset (No Dmg 10s)",
        Default = cfg.autoReset,
        Callback = function(v)
            cfg.autoReset = v
            saveCfg()
        end
    })

    Tab:CreateSection("Abilities")

    Tab:CreateToggle({
        Name = "Use Q Spell",
        Default = cfg.useQ,
        Callback = function(v)
            cfg.useQ = v
            saveCfg()
        end
    })

    Tab:CreateToggle({
        Name = "Use E Spell",
        Default = cfg.useE,
        Callback = function(v)
            cfg.useE = v
            saveCfg()
        end
    })

    Tab:CreateToggle({
        Name = "Swing",
        Default = cfg.swing,
        Callback = function(v)
            cfg.swing = v
            saveCfg()
        end
    })

    Tab:CreateSection("Positioning")

    Tab:CreateSlider({
        Name = "Hover Distance",
        Min = 5,
        Max = 50,
        Default = cfg.hoverDist,
        Callback = function(v)
            cfg.hoverDist = v
            saveCfg()
        end
    })

    Tab:CreateLabel("Toggle: K key")
else
    -- Standalone mode: fallback chat commands
    print("Fabled Farm loaded! Chat commands:")
    print("  /farm on/off")
    print("  /q, /e, /swing toggle")
    print("  /dist <number>")

    if cfg.enabled then task.wait(1) startFarm() end

    Player.Chatted:Connect(function(m)
        m = m:lower()
        if m == "/farm on" or m == "/farm" then
            cfg.enabled = true
            saveCfg()
            startFarm()
        elseif m == "/farm off" then
            cfg.enabled = false
            saveCfg()
            stopFarm()
        elseif m == "/q" then cfg.useQ = not cfg.useQ saveCfg()
        elseif m == "/e" then cfg.useE = not cfg.useE saveCfg()
        elseif m == "/swing" then cfg.swing = not cfg.swing saveCfg()
        elseif m:match("^/dist ") then
            local d = tonumber(m:match("^/dist (.+)"))
            if d and d >= 5 and d <= 50 then cfg.hoverDist = d saveCfg() end
        end
    end)
end

-- ─── KEYBIND ────────────────────────────────────────────────────────────

UserInputService.InputBegan:Connect(function(inp, gp)
    if gp then return end
    if inp.KeyCode == Enum.KeyCode.K then
        cfg.enabled = not cfg.enabled
        saveCfg()
        if cfg.enabled then startFarm() else stopFarm() end
    end
end)

print("Fabled Farm loaded! (Key: K to toggle)")
