--[[ 
  Fabled Legacy Auto Farm — Mobile Ready
]]

-- Queue on teleport (safety wrapper)
pcall(function()
    local qot = queue_on_teleport or (syn and syn.queue_on_teleport) or
                (fluxus and fluxus.queue_on_teleport)
    if qot then
        qot('loadstring(game:HttpGet("https://raw.githubusercontent.com/L13N6/JJ/main/FabledFarm.lua"))()')
    end
end)

-- Wait for game
if not game:IsLoaded() then game.Loaded:Wait() end
task.wait(1)

-- Services
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RSvc = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local VU = game:GetService("VirtualUser")
local HttpService = game:GetService("HttpService")

-- Player
local Me = Players.LocalPlayer
local Char = Me.Character or Me.CharacterAdded:Wait()
local Root

-- Nama remote (FL umum)
local REMOTES = {
    Swing = "Swing",
    Spell = "useSpell",
    Dungeon = "StartDungeon",
    Vote = "voteRemote",
}

-- Config
local cfg = { enabled = false, hover = 12, q = true, e = true, swing = true,
              autoReset = false, autoDungeon = true, autoRetry = true }

-- Load/save config (try pcall wrapper)
local function tryApi(fn, ...)
    local s, r = pcall(fn, ...)
    return s and r
end

local function readCfg()
    if tryApi(isfile, "fl_cfg.json") then
        local d = tryApi(function() return HttpService:JSONDecode(tryApi(readfile, "fl_cfg.json")) end)
        if d then for k, v in pairs(cfg) do if d[k] == nil then d[k] = v end end; return d end
    end
    return cfg
end
local function writeCfg()
    pcall(function()
        if tryApi(writefile) then
            tryApi(writefile, "fl_cfg.json", HttpService:JSONEncode(cfg))
        end
    end)
end
cfg = readCfg()

-- State
local S = { on = false, e = nil, dmg = 0, hp = nil, hb = nil, afk = nil }

-- Enemy helpers
local function alive(e)
    if not e then return false end
    local h, r = e:FindFirstChildOfClass("Humanoid"), e:FindFirstChild("HumanoidRootPart")
    return h and h.Health > 0 and r and e.Parent
end

local function findEnemy(pos)
    local f = workspace:FindFirstChild("Enemies")
    if not f then return end
    local b, bd = nil, 1e9
    for _, e in pairs(f:GetChildren()) do
        if alive(e) then
            local d = (pos - e.HumanoidRootPart.Position).Magnitude
            if d < bd then bd, b = d, e end
        end
    end
    return b
end

-- Anti AFK
local function afk(on)
    if S.afk then pcall(S.afk.Disconnect, S.afk) end
    if on then
        S.afk = Me.Idled:Connect(function()
            VU:CaptureController()
            VU:ClickButton2(Vector2.new())
        end)
    end
end

-- Auto retry
local function retryLoop()
    if not cfg.autoRetry then return end
    task.spawn(function()
        local vr
        repeat task.wait(1) vr = RS:FindFirstChild(REMOTES.Vote) until vr
        while S.on and vr do
            pcall(function() vr:FireServer("repeat") end)
            task.wait(2)
        end
    end)
end

-- Core tick
local function tick()
    if not S.on or not Char then return end
    local r = Char:FindFirstChild("HumanoidRootPart")
    if not r then return end
    local sw, sp = RS:FindFirstChild(REMOTES.Swing), RS:FindFirstChild(REMOTES.Spell)
    if not sw or not sp then return end

    if not S.e or not alive(S.e) then
        S.e = findEnemy(r.Position)
        S.hp = nil
    end

    if S.e and alive(S.e) then
        local er = S.e:FindFirstChild("HumanoidRootPart")
        if er then
            r.CFrame = CFrame.new(er.Position + Vector3.new(0, cfg.hover, 0), er.Position)
            if cfg.swing then pcall(sw.FireServer, sw) end
            if cfg.q then
                local c = Me.PlayerGui:FindFirstChild("coverQ", true)
                if c and not c.Visible then pcall(sp.FireServer, sp, "Q") end
            end
            if cfg.e then
                local c = Me.PlayerGui:FindFirstChild("coverE", true)
                if c and not c.Visible then pcall(sp.FireServer, sp, "E") end
            end
            if cfg.autoReset then
                local eh = S.e:FindFirstChildOfClass("Humanoid")
                if eh then
                    if S.hp == nil then S.hp = eh.Health
                    elseif eh.Health < S.hp then S.hp = eh.Health; S.dmg = tick() end
                end
            end
        end
    end

    if cfg.autoReset and tick() - S.dmg > 10 then
        local h = Char:FindFirstChildOfClass("Humanoid")
        if h and h.Health > 0 then h.Health = 0 end
        S.dmg = tick()
    end
end

-- Start/stop
local function start()
    if S.on then return end
    S.on = true
    S.dmg = tick()
    Char = Me.Character or Me.CharacterAdded:Wait()
    Root = Char:WaitForChild("HumanoidRootPart")
    afk(true)
    if cfg.autoDungeon then
        local dr = RS:FindFirstChild(REMOTES.Dungeon)
        if dr then pcall(dr.FireServer, dr, true) end
    end
    retryLoop()
    if S.hb then S.hb:Disconnect() end
    S.hb = RSvc.Heartbeat:Connect(tick)
end

local function stop()
    S.on = false; S.e = nil
    if S.hb then S.hb:Disconnect() end
    afk(false)
end

-- Respawn
Me.CharacterAdded:Connect(function(c)
    Char = c; Root = c:WaitForChild("HumanoidRootPart")
    task.wait(1)
    if S.on then end
end)

-- ─── MOBILE-FRIENDLY GUI ────────────────────────────────────────────────

-- Try to detect if Rayfield is already loaded
local Rayfield
pcall(function()
    -- Check global
    if _G.Rayfield then Rayfield = _G.Rayfield return end
    -- Try finding in syn context
    if syn and syn.running then
        for _, v in next, syn.threads() do
            local e = getsenv(v)
            for k, val in next, e do
                if type(val) == "table" and val.CreateWindow and val.Flags then
                    Rayfield = val
                    return
                end
            end
        end
    end
end)

if Rayfield then
    local Tab = Rayfield:CreateTab({ Name = "Fabled Farm", Image = 4483362458 })

    local toggleRef
    Tab:CreateSection("Auto Farm")
    Tab:CreateToggle({ Name = "Auto Farm", Default = cfg.enabled, Callback = function(v)
        cfg.enabled = v; writeCfg()
        if v then start() else stop() end
    end})
    Tab:CreateToggle({ Name = "Auto Dungeon", Default = cfg.autoDungeon, Callback = function(v)
        cfg.autoDungeon = v; writeCfg()
    end})
    Tab:CreateToggle({ Name = "Auto Retry", Default = cfg.autoRetry, Callback = function(v)
        cfg.autoRetry = v; writeCfg()
    end})
    Tab:CreateToggle({ Name = "Auto Reset (No Dmg)", Default = cfg.autoReset, Callback = function(v)
        cfg.autoReset = v; writeCfg()
    end})
    Tab:CreateSection("Abilities")
    Tab:CreateToggle({ Name = "Use Q", Default = cfg.q, Callback = function(v) cfg.q = v; writeCfg() end})
    Tab:CreateToggle({ Name = "Use E", Default = cfg.e, Callback = function(v) cfg.e = v; writeCfg() end})
    Tab:CreateToggle({ Name = "Swing", Default = cfg.swing, Callback = function(v) cfg.swing = v; writeCfg() end})
    Tab:CreateSection("Positioning")
    Tab:CreateSlider({ Name = "Hover", Min = 5, Max = 50, Default = cfg.hover, Callback = function(v)
        cfg.hover = v; writeCfg()
    end})
    Tab:CreateLabel("K key to toggle farm")
else
    -- Fallback: simple notification or print
    local warnMsg = function(msg)
        pcall(function()
            game:GetService("StarterGui"):SetCore("SendNotification", {
                Title = "Fabled Farm", Text = msg, Duration = 3
            })
        end)
    end
    warnMsg("Fabled Farm loaded! Use K key or chat commands")

    -- Chat commands
    Me.Chatted:Connect(function(m)
        m = m:lower()
        if m == "/farm" then
            cfg.enabled = not cfg.enabled; writeCfg()
            if cfg.enabled then start() else stop() end
            warnMsg(cfg.enabled and "Farm ON" or "Farm OFF")
        elseif m == "/q" then cfg.q = not cfg.q; writeCfg()
        elseif m == "/e" then cfg.e = not cfg.e; writeCfg()
        elseif m == "/swing" then cfg.swing = not cfg.swing; writeCfg()
        elseif m:match("^/dist ") then
            local d = tonumber(m:match("^/dist (.+)"))
            if d and d >= 5 and d <= 50 then cfg.hover = d; writeCfg() end
        end
    end)
end

-- Keybind (K)
UIS.InputBegan:Connect(function(inp, gp)
    if gp then return end
    if inp.KeyCode == Enum.KeyCode.K then
        cfg.enabled = not cfg.enabled; writeCfg()
        if cfg.enabled then start() else stop() end
        warnMsg(cfg.enabled and "Farm ON" or "Farm OFF")
    end
end)

print("Fabled Farm loaded! K to toggle")
