-- ============================================================
-- NIGHTSAKEN v63.3 - FIX CHANCE AIMBOT & 360 SPIN
-- ============================================================

local Players      = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService   = game:GetService("RunService")
local Debris       = game:GetService("Debris")
local Lighting     = game:GetService("Lighting")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer  = Players.LocalPlayer
local PlayerGui    = LocalPlayer:WaitForChild("PlayerGui")
local MainUI       = PlayerGui:WaitForChild("MainUI", 10)
local Camera       = workspace.CurrentCamera

local PlayersFolder = workspace:WaitForChild("Players", 10)
if not PlayersFolder then return end
local killersFolder   = PlayersFolder:WaitForChild("Killers", 10)
local survivorsFolder = PlayersFolder:WaitForChild("Survivors", 10)
if not killersFolder or not survivorsFolder then return end

local espFolder = workspace:FindFirstChild("ESP_Folder") or Instance.new("Folder", workspace)
espFolder.Name = "ESP_Folder"

local CONFIG = {
    AutoBlock = false,
    HitboxTransparency = 0.8,
    HitboxColor = Color3.fromRGB(255,255,255), HitboxHitColor = Color3.fromRGB(0,255,0),
    HitboxDistance = 3, ShowOutline = true, ShowHitboxVisual = true,
    OutlineThickness = 0.04, OutlineTransparencyValue = 0.6,
    HitboxWidth = 6, HitboxLength = 9, HitboxHeight = 6, HitboxMultiplier = 1,
    AutoPunch = false, AutoPunchAccuracy = 80,
    PunchAimbot = false, Prediction = 0.3, AimbotRange = 100, DepthOffset = 0,
    VoidRushControl = false, NoliTurnMult = 1000, NoliTurnSpeed = 10000,
    ESPKiller = false, ESPSurvivor = false, ESPGenerators = false, ESPItems = false,
    Fullbright = false, InfStamina = false, DEBUG = true,
    ESPNameSize = 10, ESPInfoSize = 8, ESPStudsOffsetY = 3.0, ESPBillboardHeight = 40,
    ShowName = true, ShowHP = true,
    ESPFillTransparency = 0.5, ESPOutlineTransparency = 0,
    ESPOutlineColor = Color3.fromRGB(0,0,0),
    FOV = 120,
    -- Chance Configs
    AutoCoinFlip = false,
    Shoot_Aim_helper = false,
    Shoot_Aim_helper_method = "HumanoidRoot Lock",
    Shoot_Aim_helper_look_loock = 1.6,
    Shoot_360_Spin = false,
}

local KILLER_HITBOX = {
    ["CoolKid"]   = { dura = 0.05, life = 0.05, width = 5, length = 7, height = 6 },
    ["Slasher"]   = { dura = 0.35, life = 0.35 },
    ["1x1x1x1"]   = { dura = 0.45, life = 0.45 },
    ["JohnDoe"]   = { dura = 0.45, life = 0.45 },
    ["John Doe"]  = { dura = 0.45, life = 0.45 },
    ["Nosferatu"] = { dura = 0.42, life = 0.42 },
    ["Sixer"]     = { dura = 0.42, life = 0.42, distance = 6.0 },
    ["Noli"]      = { dura = 0.37, life = 0.37 },
    ["Azure"]     = { dura = 0.35, life = 0.35 },
}
local DEFAULT_HITBOX = { dura = 0.26, life = 0.26 }

local function getKillerHitbox(killerName)
    if not killerName then return DEFAULT_HITBOX end
    for name, val in pairs(KILLER_HITBOX) do
        if string.find(killerName, name, 1, true) then return val end
    end
    return DEFAULT_HITBOX
end

local espConns = {}
local staminaThread = nil
local LocalCharacter, LocalHumanoid, LocalRoot, SpeedMultipliers, FOVMultipliers
local isPunching = false
local lastAbilityUsed, lastAbilitiesUsed, abilityBaitFlag = nil, nil, false
local _aimbotVelocityData = {}
local _punchAnimIds = {
    ["87259391926321"]=true,["99100240941590"]=true,["72685103823181"]=true,["81905101227053"]=true,
    ["113936304594883"]=true,["140703210927645"]=true,["136007065400978"]=true,["129843313690921"]=true,
    ["86709774283672"]=true,["108807732150251"]=true,["138040001965654"]=true,["86096387000557"]=true,
    ["119850211147676"]=true,["131696603025265"]=true,["119462383658044"]=true,["116618003477002"]=true,
    ["133491532453922"]=true,["76649505662612"]=true,["71190646367497"]=true,["72182155407310"]=true,
    ["82605295530067"]=true,["138407964761603"]=true,["133292581373127"]=true,["116427323741607"]=true,
    ["90970641235403"]=true,["87716278630738"]=true,["82036084568393"]=true,["138936949998619"]=true,
    ["78440860685556"]=true,["123825742002486"]=true,["125854302746190"]=true,["132298811847315"]=true,
    ["135209101640984"]=true,["18568553101"]=true,["423041300"]=true,["423041325"]=true,["423041356"]=true,
    ["81114852524420"]=true,["82772022662025"]=true,["108911997126897"]=true,["117216912143451"]=true,
    ["82137285150006"]=true,["102808968188291"]=true,["116616310968045"]=true,["117828699507982"]=true
}

local function log(msg) if CONFIG.DEBUG then warn("[NS] "..msg) end end

local _remote = nil
local function getRemote()
    if _remote and _remote.Parent then return _remote end
    local ok, re = pcall(function()
        return ReplicatedStorage:WaitForChild("Modules",10):WaitForChild("Network",5):WaitForChild("Network",5):WaitForChild("RemoteEvent",5)
    end)
    if ok and re then _remote = re; return re end
    local ok2, re2 = pcall(function() return ReplicatedStorage.Modules.Network.Network:FindFirstChild("RemoteEvent") end)
    if ok2 and re2 then _remote = re2; return re2 end
    return nil
end

local function fireBlock()
    local remote = getRemote()
    if not remote then return false end
    pcall(function()
        remote:FireServer(unpack({"UseActorAbility", {buffer.fromstring("\003\005\000\000\000Block")}}))
    end)
    return true
end

local blockSpamThread = nil
local function spamBlock(duration)
    if blockSpamThread then task.cancel(blockSpamThread) end
    blockSpamThread = task.spawn(function()
        local endTime = tick() + duration
        while tick() < endTime do
            fireBlock()
            task.wait(0.001)
        end
        blockSpamThread = nil
    end)
end

local function makeHitboxAndCheck(killerModel, onDetected)
    if not killerModel or not killerModel.Parent then return end
    local killerRoot = killerModel:FindFirstChild("HumanoidRootPart") or killerModel:FindFirstChild("RootPart")
    if not killerRoot then return end
    local hbCfg = getKillerHitbox(killerModel.Name)
    local m = CONFIG.HitboxMultiplier or 1
    local hbWidth = hbCfg.width or CONFIG.HitboxWidth
    local hbLength = hbCfg.length or CONFIG.HitboxLength
    local hbHeight = hbCfg.height or CONFIG.HitboxHeight
    local size = Vector3.new(hbWidth*m, hbHeight*m, hbLength*m)
    local op = OverlapParams.new()
    op.FilterType = Enum.RaycastFilterType.Exclude
    op.FilterDescendantsInstances = {killerModel}
    task.spawn(function()
        local startTime = tick()
        local blockedOnce = false
        while tick() - startTime < hbCfg.dura do
            if blockedOnce then break end
            local ckr = killerModel:FindFirstChild("HumanoidRootPart") or killerModel:FindFirstChild("RootPart")
            if not ckr then break end
            local frozenCFrame = ckr.CFrame * CFrame.new(0,0,-(hbCfg.distance or CONFIG.HitboxDistance or 3))
            local hb = Instance.new("Part")
            hb.Name = "AutoBlockHitbox_Frame"
            hb.Transparency = CONFIG.ShowHitboxVisual and CONFIG.HitboxTransparency or 1
            hb.CanCollide = false; hb.CanTouch = false; hb.CanQuery = false
            hb.CastShadow = false; hb.Anchored = true
            hb.Size = size; hb.Color = CONFIG.HitboxColor
            hb.Material = Enum.Material.ForceField
            hb.CFrame = frozenCFrame; hb.Parent = workspace
            local sb
            if CONFIG.ShowOutline and CONFIG.ShowHitboxVisual then
                sb = Instance.new("SelectionBox")
                sb.Adornee = hb; sb.Color3 = CONFIG.HitboxColor
                sb.LineThickness = CONFIG.OutlineThickness
                sb.Transparency = CONFIG.OutlineTransparencyValue or 0.6
                sb.Visible = true; sb.Parent = hb
            end
            Debris:AddItem(hb, hbCfg.life)
            local found = false
            for _, part in ipairs(workspace:GetPartsInPart(hb, op)) do
                local hum = part.Parent and part.Parent:FindFirstChildOfClass("Humanoid")
                if hum and hum.Health > 0 and Players:GetPlayerFromCharacter(hum.Parent) == LocalPlayer then found = true; break end
            end
            if found and not blockedOnce then
                blockedOnce = true
                pcall(function()
                    hb.Color = CONFIG.HitboxHitColor
                    if sb then sb.Color3 = CONFIG.HitboxHitColor end
                end)
                fireBlock()
                fireBlock()
                fireBlock()
                fireBlock()
                spamBlock(0.05)
                if onDetected then onDetected() end
                break
            end
            RunService.Heartbeat:Wait()
        end
    end)
end

local lastAbilityLastUsed = nil
local lastAbilitiesUsed = nil
local blockLocked = false

local function checkKillerAttackC00l()
    local killers = workspace:FindFirstChild("Players") and workspace.Players:FindFirstChild("Killers")
    if not killers then return end
    local killer = killers:GetChildren()[1]
    if not killer or not killer:IsA("Model") then return end
    local currentAbilityLastUsed = killer:GetAttribute("AbilityLastUsed") or 0
    local currentAbilitiesUsed = killer:GetAttribute("AbilitiesUsed") or 0
    if lastAbilityLastUsed == nil then
        lastAbilityLastUsed = currentAbilityLastUsed
        lastAbilitiesUsed = currentAbilitiesUsed
        return
    end
    local abilityLastUsedIncreased = (currentAbilityLastUsed > lastAbilityLastUsed)
    local abilitiesUsedIncreased = (currentAbilitiesUsed > lastAbilitiesUsed)
    if abilitiesUsedIncreased then
        blockLocked = true
    end
    if abilityLastUsedIncreased then
        if blockLocked then
            blockLocked = false
        else
            makeHitboxAndCheck(killer, function() fireBlock() end)
        end
    end
    lastAbilityLastUsed = currentAbilityLastUsed
    lastAbilitiesUsed = currentAbilitiesUsed
end

RunService.Heartbeat:Connect(function() if CONFIG.AutoBlock then pcall(checkKillerAttackC00l) end end)

local function setAutoBlock(on)
    CONFIG.AutoBlock = on
    if on then
        lastAbilityLastUsed = nil
        lastAbilitiesUsed = nil
        blockLocked = false
    end
end

local function GetClosestKiller(Distance)
    Distance = Distance or 55
    local SK, SD
    for _, v in ipairs(killersFolder:GetChildren()) do
        if Players:GetPlayerFromCharacter(v) and LocalRoot and v:FindFirstChild("HumanoidRootPart") and v:FindFirstChildOfClass("Humanoid") and v:FindFirstChildOfClass("Humanoid").Health > 0 then
            local d = (v.HumanoidRootPart.Position - LocalRoot.Position).Magnitude
            if d < Distance then Distance = d; SK = v; SD = d end
        end
    end
    return SK, SD
end

local function FirePunch()
    local re = getRemote()
    if re then
        pcall(function()
            if game.GameId == 6331902150 or game.GameId == 7464167604 then
                re:FireServer("UseActorAbility", {"Punch"})
            else
                re:FireServer("UseActorAbility", "Punch")
                re:FireServer("UseActorAbility", {"Punch"})
            end
        end)
    end
end

local function getSurvivorVelocity(hrp)
    if not hrp then return Vector3.zero end
    local data = _aimbotVelocityData[hrp]
    local now = tick()
    if not data then _aimbotVelocityData[hrp] = {lastPos=hrp.Position, lastTime=now, velocity=Vector3.zero}; return Vector3.zero end
    local dt = now - data.lastTime
    if dt <= 0 then return data.velocity end
    local vel = (hrp.Position - data.lastPos) / dt
    data.lastPos = hrp.Position; data.lastTime = now; data.velocity = vel
    return vel
end

local function getNearestKillerAim()
    if not LocalCharacter or not LocalRoot then return nil end
    local best, bd = nil, CONFIG.AimbotRange
    local pos = LocalRoot.Position
    for _, model in ipairs(killersFolder:GetChildren()) do
        if model ~= LocalCharacter and model:IsA("Model") then
            local r = model:FindFirstChild("HumanoidRootPart")
            local h = model:FindFirstChildOfClass("Humanoid")
            if r and h and h.Health > 0 then
                local vel = getSurvivorVelocity(r)
                local pp = r.Position + (vel * CONFIG.Prediction) + Vector3.new(0, CONFIG.DepthOffset, 0)
                local d = (pp - pos).Magnitude
                if d < bd then bd = d; best = {root=r, pos=pp} end
            end
        end
    end
    return best
end

local function rotateToTarget(target)
    if not target or not target.root or not target.root.Parent or not LocalRoot then return end
    local tp = target.pos or target.root.Position
    local dir = Vector3.new(tp.X - LocalRoot.Position.X, 0, tp.Z - LocalRoot.Position.Z)
    if dir.Magnitude < 0.1 then return end
    LocalRoot.CFrame = CFrame.new(LocalRoot.Position, LocalRoot.Position + dir.Unit)
    if LocalHumanoid then LocalHumanoid.AutoRotate = true end
end

local function setupPunchAimbot(character)
    if not character then return end
    local hum = character:WaitForChild("Humanoid", 5)
    if not hum then return end
    local animator = hum:FindFirstChildOfClass("Animator")
    if not animator then return end
    animator.AnimationPlayed:Connect(function(track)
        if not CONFIG.PunchAimbot then return end
        local animId = track.Animation and track.Animation.AnimationId:match("%d+")
        if animId and _punchAnimIds[animId] then
            local target = getNearestKillerAim()
            if target then task.spawn(function() rotateToTarget(target) end) end
        end
    end)
end

task.spawn(function()
    while true do
        task.wait(5)
        local now = tick()
        for hrp, data in pairs(_aimbotVelocityData) do
            if not hrp or not hrp.Parent or (now - data.lastTime) > 2 then _aimbotVelocityData[hrp] = nil end
        end
    end
end)

local function SetupGodsakenPunch(character)
    LocalCharacter = character
    LocalHumanoid = character:WaitForChild("Humanoid", 5)
    LocalRoot = character:WaitForChild("HumanoidRootPart", 5)
    SpeedMultipliers = character:WaitForChild("SpeedMultipliers", 5)
    FOVMultipliers = character:WaitForChild("FOVMultipliers", 5)
    if not LocalHumanoid then return end
    setupPunchAimbot(character)
    LocalCharacter:GetAttributeChangedSignal("TimesHit"):Connect(function()
        if not CONFIG.AutoPunch or isPunching then return end
        if SpeedMultipliers and SpeedMultipliers:FindFirstChild("GuestBlocking") and LocalHumanoid:GetAttribute("Overheal") ~= nil and LocalHumanoid:GetAttribute("Overheal") >= 10 then
            local TK = GetClosestKiller()
            if not TK then return end
            isPunching = true
            task.spawn(function()
                task.wait(0.08)
                LocalCharacter:SetAttribute("DisableShiftLockMovement", true)
                FirePunch()
                local Timeout = workspace.DistributedGameTime + 1.25
                local CT, SV
                CT = RunService.RenderStepped:Connect(function()
                    local CK = GetClosestKiller()
                    if not CK or not CK:FindFirstChild("HumanoidRootPart") then return end
                    local KRP = CK.HumanoidRootPart.Position
                    local SP = Vector3.new(KRP.X, LocalRoot.Position.Y, KRP.Z)
                    local TCF = CFrame.new(LocalRoot.Position, SP)
                    LocalCharacter:SetPrimaryPartCFrame(TCF)
                    if not SV then LocalRoot.Velocity = TCF.LookVector * 32; SV = LocalRoot.Velocity
                    else SV = LocalRoot.Velocity:Lerp(SV or LocalRoot.Velocity, CONFIG.AutoPunchAccuracy/100); LocalRoot.Velocity = SV end
                end)
                repeat task.wait(0.1)
                until (FOVMultipliers and FOVMultipliers:FindFirstChild("HitRegistered")) or (SpeedMultipliers and not SpeedMultipliers:FindFirstChild("PunchAbility")) or workspace.DistributedGameTime > Timeout
                CT:Disconnect()
                task.wait(0.2)
                LocalCharacter:SetAttribute("DisableShiftLockMovement", false)
                isPunching = false
            end)
        end
    end)
end

if LocalPlayer.Character then SetupGodsakenPunch(LocalPlayer.Character) end
LocalPlayer.CharacterAdded:Connect(SetupGodsakenPunch)

local function ApplyVoidRushControl()
    if not CONFIG.VoidRushControl then return end
    pcall(function()
        local Assets = ReplicatedStorage:FindFirstChild("Assets")
        if not Assets then error("Assets not found") end
        local K = Assets:FindFirstChild("Killers")
        if not K then error("Killers not found") end
        local N = K:FindFirstChild("Noli")
        if not N then error("Noli not found") end
        local NC = require(N.Config)
        if NC then
            for k in pairs(NC) do
                if type(k) == "string" then
                    if k:find("InitialTurnMult") then NC[k] = CONFIG.NoliTurnMult end
                    if k:find("TurnSpeed") then NC[k] = CONFIG.NoliTurnSpeed end
                end
            end
            log("VoidRush Noli applied")
        end
    end)
end

local function setVoidRushControl(on)
    CONFIG.VoidRushControl = on
    if on then ApplyVoidRushControl() end
end

LocalPlayer.CharacterAdded:Connect(function()
    task.delay(1.5, function() if CONFIG.VoidRushControl then ApplyVoidRushControl() end end)
end)

task.spawn(function()
    while true do
        task.wait(2)
        if CONFIG.VoidRushControl then ApplyVoidRushControl() end
    end
end)

local function isInSurvivors(m) return survivorsFolder and m.Parent == survivorsFolder end
local function isInKillers(m) return killersFolder and m.Parent == killersFolder end
local function clearKillerESP() for _,o in ipairs(espFolder:GetChildren()) do if o.Name:sub(1,11) == "KillGlow_" then o:Destroy() end end end
local function clearSurvivorESP() for _,o in ipairs(espFolder:GetChildren()) do if o.Name:sub(1,12) == "SurvGlow_" then o:Destroy() end end end
local function clearGeneratorESP() for _,o in ipairs(espFolder:GetChildren()) do if o.Name:sub(1,8) == "GenGlow_" then o:Destroy() end end end
local function clearItemESP() for _,o in ipairs(espFolder:GetChildren()) do if o.Name:sub(1,9) == "ItemGlow_" then o:Destroy() end end end

local function applyHL(hl, fillColor, outlineFallback)
    if not hl then return end
    hl.FillColor = fillColor
    hl.OutlineColor = CONFIG.ESPOutlineColor or outlineFallback
    hl.FillTransparency = CONFIG.ESPFillTransparency
    hl.OutlineTransparency = CONFIG.ESPOutlineTransparency
end

local function makePlayerESP(player, isKiller)
    if player == LocalPlayer then return end
    local prefix = isKiller and "KillGlow_" or "SurvGlow_"
    local bbPrefix = isKiller and "Kill_BB_" or "Surv_BB_"
    local fillColor = isKiller and Color3.fromRGB(255,0,0) or Color3.fromRGB(0,255,0)
    local outlineColor = isKiller and Color3.fromRGB(100,0,0) or Color3.fromRGB(0,100,0)
    local function setup(character)
        if not character then return end
        local conn
        conn = RunService.RenderStepped:Connect(function()
            local hum = character:FindFirstChildOfClass("Humanoid")
            local hrp = character:FindFirstChild("HumanoidRootPart")
            local active = (isKiller and CONFIG.ESPKiller) or (not isKiller and CONFIG.ESPSurvivor)
            if not character:IsDescendantOf(workspace) or not active or (hum and hum.Health <= 0) then
                local g = espFolder:FindFirstChild(prefix..player.Name); if g then g:Destroy() end
                if hrp and hrp:FindFirstChild(bbPrefix..player.Name) then hrp[bbPrefix..player.Name]:Destroy() end
                if conn then conn:Disconnect() end
                return
            end
            local check = isKiller and isInKillers(character) or isInSurvivors(character)
            if check then
                local hl = espFolder:FindFirstChild(prefix..player.Name)
                if not hl then
                    hl = Instance.new("Highlight"); hl.Name = prefix..player.Name; hl.Adornee = character
                    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop; hl.Parent = espFolder
                end
                applyHL(hl, fillColor, outlineColor)
                if hrp then
                    local bb = hrp:FindFirstChild(bbPrefix..player.Name)
                    if not bb then
                        bb = Instance.new("BillboardGui"); bb.Name = bbPrefix..player.Name
                        bb.AlwaysOnTop = true; bb.ZIndexBehavior = Enum.ZIndexBehavior.Global; bb.Adornee = hrp; bb.Parent = hrp
                    end
                    bb.StudsOffset = Vector3.new(0, CONFIG.ESPStudsOffsetY, 0)
                    bb.Size = UDim2.new(0, 100, 0, CONFIG.ESPBillboardHeight)
                    local ln = bb:FindFirstChild("NameLabel")
                    if not ln then
                        ln = Instance.new("TextLabel"); ln.Name = "NameLabel"; ln.Size = UDim2.new(1,0,0.6,0)
                        ln.BackgroundTransparency = 1; ln.Font = Enum.Font.SourceSansBold
                        ln.TextStrokeTransparency = 0; ln.TextColor3 = fillColor; ln.ZIndex = 100; ln.Parent = bb
                    end
                    local lh = bb:FindFirstChild("HPLabel")
                    if not lh then
                        lh = Instance.new("TextLabel"); lh.Name = "HPLabel"; lh.Size = UDim2.new(1,0,0.4,0); lh.Position = UDim2.new(0,0,0.6,0)
                        lh.BackgroundTransparency = 1; lh.Font = Enum.Font.SourceSansBold
                        lh.TextStrokeTransparency = 0; lh.TextColor3 = fillColor; lh.ZIndex = 100; lh.Parent = bb
                    end
                    ln.Text = CONFIG.ShowName and character.Name or ""
                    if hum and CONFIG.ShowHP then lh.Text = tostring(math.floor(hum.Health)).." HP" end
                    ln.TextSize = CONFIG.ESPNameSize; lh.TextSize = CONFIG.ESPInfoSize
                end
            else
                local g = espFolder:FindFirstChild(prefix..player.Name); if g then g:Destroy() end
                if hrp and hrp:FindFirstChild(bbPrefix..player.Name) then hrp[bbPrefix..player.Name]:Destroy() end
            end
        end)
        table.insert(espConns, conn)
    end
    if player.Character then setup(player.Character) end
    player.CharacterAdded:Connect(setup)
end

local function makeGeneratorESP(gen)
    if not gen:IsA("Model") or gen.Name ~= "Generator" then return end
    local main = gen:FindFirstChild("Main") or gen:WaitForChild("Main", 5)
    if not main then return end
    local prog = gen:FindFirstChild("Progress")
    local done = prog and prog.Value >= 100 or false
    if prog then prog:GetPropertyChangedSignal("Value"):Connect(function()
        if prog.Value >= 100 then local g = espFolder:FindFirstChild("GenGlow_"..gen:GetDebugId()); if g then g:Destroy() end end
    end) end
    if not CONFIG.ESPGenerators or done then return end
    local id = gen:GetDebugId(); local color = Color3.fromRGB(0,255,255)
    local hl = espFolder:FindFirstChild("GenGlow_"..id)
    if not hl then
        hl = Instance.new("Highlight"); hl.Name = "GenGlow_"..id; hl.Adornee = gen
        hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop; hl.Parent = espFolder
    end
    applyHL(hl, color, Color3.fromRGB(0,150,150))
    if not main:FindFirstChild("Gen_BB_"..id) then
        local bb = Instance.new("BillboardGui"); bb.Name = "Gen_BB_"..id; bb.Size = UDim2.new(0,100,0,22)
        bb.AlwaysOnTop = true; bb.Adornee = main; bb.StudsOffset = Vector3.new(0,2.2,0); bb.Parent = main
        local lbl = Instance.new("TextLabel"); lbl.Size = UDim2.new(1,0,1,0); lbl.BackgroundTransparency = 1
        lbl.Font = Enum.Font.SourceSansBold; lbl.TextStrokeTransparency = 0; lbl.TextColor3 = color
        lbl.TextSize = CONFIG.ESPInfoSize; lbl.Text = "Generator"; lbl.Parent = bb
    end
end

local function makeItemESP(tool)
    if not tool:IsA("Tool") then return end
    local handle = tool:FindFirstChild("Handle") or tool:FindFirstChildWhichIsA("BasePart")
    if not handle then return end
    local ok, id = pcall(function() return tool:GetDebugId() end)
    if not ok then return end
    local isHeld = false
    if tool.Parent then
        if tool.Parent:FindFirstChildOfClass("Humanoid") or tool.Parent:IsA("Backpack") then isHeld = true end
    end
    if not CONFIG.ESPItems or isHeld then
        local g = espFolder:FindFirstChild("ItemGlow_"..id); if g then g:Destroy() end
        local ob = handle:FindFirstChild("Item_BB_"..id); if ob then ob:Destroy() end
        return
    end
    local color = Color3.fromRGB(255,215,0)
    local hl = espFolder:FindFirstChild("ItemGlow_"..id)
    if not hl then
        hl = Instance.new("Highlight"); hl.Name = "ItemGlow_"..id; hl.Adornee = tool
        hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop; hl.Parent = espFolder
    end
    applyHL(hl, color, Color3.fromRGB(180,140,0))
    if not handle:FindFirstChild("Item_BB_"..id) then
        local bb = Instance.new("BillboardGui"); bb.Name = "Item_BB_"..id; bb.Size = UDim2.new(0,90,0,20)
        bb.AlwaysOnTop = true; bb.Adornee = handle; bb.StudsOffset = Vector3.new(0,1.8,0); bb.Parent = handle
        local lbl = Instance.new("TextLabel"); lbl.Size = UDim2.new(1,0,1,0); lbl.BackgroundTransparency = 1
        lbl.Font = Enum.Font.SourceSansBold; lbl.TextStrokeTransparency = 0; lbl.TextColor3 = color
        lbl.TextSize = CONFIG.ESPInfoSize; lbl.Text = tool.Name; lbl.Parent = bb
    end
end

local function updateAllESPTransparency()
    for _, obj in ipairs(espFolder:GetChildren()) do
        if obj:IsA("Highlight") then
            obj.FillTransparency = CONFIG.ESPFillTransparency
            obj.OutlineTransparency = CONFIG.ESPOutlineTransparency
            if CONFIG.ESPOutlineColor then obj.OutlineColor = CONFIG.ESPOutlineColor end
        end
    end
end

local function setESPSurvivor(on)
    CONFIG.ESPSurvivor = on
    if not on then clearSurvivorESP() else for _,p in ipairs(Players:GetPlayers()) do makePlayerESP(p, false) end end
end
local function setESPKiller(on)
    CONFIG.ESPKiller = on
    if not on then clearKillerESP() else for _,p in ipairs(Players:GetPlayers()) do makePlayerESP(p, true) end end
end
local function setESPGenerators(on)
    CONFIG.ESPGenerators = on
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj.Name == "Generator" then
            if on then makeGeneratorESP(obj)
            else
                local id = obj:GetDebugId(); local g = espFolder:FindFirstChild("GenGlow_"..id); if g then g:Destroy() end
                local main = obj:FindFirstChild("Main"); if main and main:FindFirstChild("Gen_BB_"..id) then main["Gen_BB_"..id]:Destroy() end
            end
        end
    end
end
local function setESPItems(on)
    CONFIG.ESPItems = on
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Tool") then
            if on then makeItemESP(obj)
            else
                local ok, id = pcall(function() return obj:GetDebugId() end)
                if ok then
                    local g = espFolder:FindFirstChild("ItemGlow_"..id); if g then g:Destroy() end
                    local h = obj:FindFirstChild("Handle"); if h and h:FindFirstChild("Item_BB_"..id) then h["Item_BB_"..id]:Destroy() end
                end
            end
        end
    end
end

task.spawn(function()
    while true do
        task.wait(0.5)
        if CONFIG.ESPItems then
            pcall(function()
                for _, obj in ipairs(workspace:GetDescendants()) do
                    if obj:IsA("Tool") then makeItemESP(obj) end
                end
            end)
        end
    end
end)

Players.PlayerAdded:Connect(function(p)
    if CONFIG.ESPSurvivor then makePlayerESP(p, false) end
    if CONFIG.ESPKiller then makePlayerESP(p, true) end
end)
workspace.DescendantAdded:Connect(function(o)
    if o.Name == "Generator" and CONFIG.ESPGenerators then task.wait(0.2); makeGeneratorESP(o)
    elseif o:IsA("Tool") and CONFIG.ESPItems then task.wait(0.1); makeItemESP(o) end
end)

local function applyFullbright()
    if not CONFIG.Fullbright then return end
    Lighting.Brightness = 3; Lighting.ClockTime = 14
    Lighting.Ambient = Color3.new(1,1,1); Lighting.OutdoorAmbient = Color3.new(1,1,1)
    Lighting.FogEnd = 1e100; Lighting.GlobalShadows = false
    for _, e in ipairs(Lighting:GetChildren()) do
        if e:IsA("Atmosphere") or e:IsA("BloomEffect") or e:IsA("ColorCorrectionEffect") or e:IsA("BlurEffect") or e:IsA("SunRaysEffect") or e:IsA("DepthOfFieldEffect") then e:Destroy() end
    end
    pcall(function()
        local net = ReplicatedStorage:WaitForChild("Modules", 2):WaitForChild("Network", 2)
        if net then local rf = net:FindFirstChild("RemoteFunction"); if rf then rf:InvokeServer("GetCurrentLighting") end end
    end)
end
Lighting.ChildAdded:Connect(function()
    if CONFIG.Fullbright then task.defer(function() task.wait(0.2); applyFullbright() end) end
end)
local function setFullbright(on) CONFIG.Fullbright = on; if on then applyFullbright() end end

local function applyInfStamina()
    pcall(function()
        local ok, m = pcall(function() return require(ReplicatedStorage.Systems.Character.Game.Sprinting) end)
        if not ok or not m then return end
        if not m.DefaultsSet then pcall(function() m.Init() end) end
        m.StaminaLoss = 0; m.StaminaGain = 999; m.MaxStamina = 999
        m.StaminaLossDisabled = true
        if m.Stamina and m.Stamina < 999 then m.Stamina = 999 end
        if type(m.StaminaCap) == "number" then m.StaminaCap = 999 end
        pcall(function() if m.__staminaChangedEvent then m.__staminaChangedEvent:Fire() end end)
    end)
end
local function startInfStamina()
    if staminaThread then return end
    staminaThread = task.spawn(function()
        while CONFIG.InfStamina do
            pcall(applyInfStamina)
            task.wait(0.3)
        end
        staminaThread = nil
    end)
end
local function stopInfStamina()
    if staminaThread then task.cancel(staminaThread); staminaThread = nil end
end
local function setInfStamina(on)
    CONFIG.InfStamina = on
    if on then applyInfStamina(); startInfStamina() else stopInfStamina() end
end
LocalPlayer.CharacterAdded:Connect(function()
    task.delay(1.5, function()
        if CONFIG.InfStamina then applyInfStamina(); if not staminaThread then startInfStamina() end end
    end)
end)

local MIN_FOV = 30
local MAX_FOV = 120
local FOV_BIND = "NIGHTSAKEN_FOVForce"
local FOVValue = 120
local fovWatchConn = nil
CONFIG.FOV = 120

local function ApplyFOV()
    local cam = workspace.CurrentCamera
    if cam and cam.FieldOfView ~= FOVValue then
        pcall(function() cam.FieldOfView = FOVValue end)
    end
end

pcall(function() RunService:UnbindFromRenderStep(FOV_BIND) end)
pcall(function()
    RunService:BindToRenderStep(FOV_BIND, Enum.RenderPriority.Last.Value + 1, function()
        local cam = workspace.CurrentCamera
        if cam and cam.FieldOfView ~= FOVValue then
            pcall(function() cam.FieldOfView = FOVValue end)
        end
    end)
end)

local function WatchCameraFOV(cam)
    if fovWatchConn then pcall(function() fovWatchConn:Disconnect() end); fovWatchConn = nil end
    if not cam then return end
    fovWatchConn = cam:GetPropertyChangedSignal("FieldOfView"):Connect(function()
        if cam.FieldOfView ~= FOVValue then
            pcall(function() cam.FieldOfView = FOVValue end)
        end
    end)
end
WatchCameraFOV(workspace.CurrentCamera)
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
    WatchCameraFOV(workspace.CurrentCamera)
    ApplyFOV()
end)

local function setFOVByPercent(percent)
    percent = math.clamp(percent, 0, 100)
    FOVValue = MIN_FOV + ((MAX_FOV - MIN_FOV) * (percent / 100))
    CONFIG.FOV = FOVValue
    ApplyFOV()
end
local function setFOV(value)
    FOVValue = math.clamp(value, MIN_FOV, MAX_FOV)
    CONFIG.FOV = FOVValue
    ApplyFOV()
end
local function resetFOV()
    FOVValue = 120
    CONFIG.FOV = 120
    ApplyFOV()
end

local TARGET_ANIMATION_ID = "100725497418533"
local DASHSTAB_ANIM_ID = "89448354637442"
local bsEnabled = false
local bsAutoStuds = false
local bsDetectPing = false
local bsMoreDirect = false
local bsMoreDirectRN = false
local bsMoreDirectEnd = false
local bsDistCheck = false
local bsDistCheckStuds = 7
local bsStartDelay = 0.05
local bsDuration = 0.2
local bsBehindStuds = 4
local bsAutoStandStuds = 5.5
local bsAutoRunStuds = 3.4
local bsDashstabEnabled = false
local bsDsStartDelay = 0.1
local bsRunning = false
local bsDoitmate = false
local bsSpeed = nil

local function refreshBsSpeed()
    if LocalPlayer.Character then
        local sm = LocalPlayer.Character:FindFirstChild("SpeedMultipliers")
        if sm then bsSpeed = sm:FindFirstChild("Sprinting") end
    end
end
refreshBsSpeed()
LocalPlayer.CharacterAdded:Connect(function() task.wait(0.5); refreshBsSpeed() end)

local function getFirstValidKillerAB()
    local pf = workspace:FindFirstChild("Players")
    if not pf then return nil end
    local kf = pf:FindFirstChild("Killers")
    if not kf then return nil end
    for _, inst in ipairs(kf:GetDescendants()) do
        if inst:IsA("Model") then
            local hum = inst:FindFirstChildOfClass("Humanoid")
            local hrp = inst:FindFirstChild("HumanoidRootPart")
            if hum and hrp and hum.Health > 0 then return inst end
        end
    end
    return nil
end

local function getPingAB()
    local ok, val = pcall(function() return game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue() end)
    if ok and val then return val end
    local ok2, val2 = pcall(function() return LocalPlayer:GetNetworkPing() * 1000 end)
    if ok2 and val2 then return val2 end
    return 20
end

local function runPlaceSequence()
    if not bsEnabled or bsRunning then return end
    bsRunning = true
    local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    task.wait(bsStartDelay)
    if not char.Parent then bsRunning = false; return end
    local place = Instance.new("Part")
    place.Name = "place"; place.Size = Vector3.new(2,2,2); place.Transparency = 0
    place.CanCollide = false; place.Anchored = true; place.Parent = char
    local oldPP = char.PrimaryPart
    local oldSpeed = bsSpeed and bsSpeed.Value or 16
    if bsMoreDirect then bsMoreDirectRN = true; task.wait(0.01); bsMoreDirectRN = false end
    local st = os.clock()
    while os.clock() - st < bsDuration do
        if not char.Parent or not place.Parent or not bsEnabled then break end
        if bsSpeed then bsSpeed.Value = 0 end
        bsDoitmate = true
        RunService.PreRender:Wait()
    end
    if place and place.Parent then place:Destroy() end
    if char and char.Parent then char.PrimaryPart = oldPP end
    if bsSpeed then bsSpeed.Value = oldSpeed end
    bsDoitmate = false
    if bsMoreDirect then
        bsMoreDirectRN = true; task.wait(0.01); bsMoreDirectEnd = true; bsMoreDirectRN = false; task.wait(0.01); bsMoreDirectEnd = false
    end
    bsRunning = false
end

local function runDashstabSequence()
    if not bsDashstabEnabled or bsRunning then return end
    bsRunning = true
    local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    task.wait(bsDsStartDelay)
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not char.Parent or not hrp then bsRunning = false; return end
    local place = Instance.new("Part")
    place.Name = "place"; place.Size = Vector3.new(2,2,2); place.Transparency = 0
    place.CanCollide = false; place.Anchored = true; place.Parent = char
    local oldPP = char.PrimaryPart
    local oldSpeed = bsSpeed and bsSpeed.Value or 16
    if bsMoreDirect then bsMoreDirectRN = true; task.wait(0.01); bsMoreDirectRN = false end
    local st = os.clock()
    while os.clock() - st < bsDuration do
        if not char.Parent or not place.Parent or not bsDashstabEnabled then break end
        if bsSpeed then bsSpeed.Value = 0 end
        bsDoitmate = true
        RunService.PreRender:Wait()
    end
    if bsSpeed then bsSpeed.Value = oldSpeed end
    bsDoitmate = false
    if bsMoreDirect then
        bsMoreDirectRN = true; task.wait(0.001); bsMoreDirectEnd = true; bsMoreDirectRN = false; task.wait(0.001); bsMoreDirectEnd = false
    end
    if place and place.Parent then place:Destroy() end
    if char and char.Parent then char.PrimaryPart = oldPP end
    bsRunning = false
end

pcall(function()
    local NetworkModuleAB = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Network"):WaitForChild("Network"))
    local CharReplicationAB = require(ReplicatedStorage:WaitForChild("Systems"):WaitForChild("Player"):WaitForChild("Game"):WaitForChild("CharacterReplication"))
    if hookfunction then
        local oldFire
        oldFire = hookfunction(NetworkModuleAB.FireServerConnection, function(self, connectionName, eventType, ...)
            local args = {...}
            if connectionName == "UpdateCharacterPosition" then
                local char = LocalPlayer.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                local killer = getFirstValidKillerAB()
                if killer and hrp then
                    local kHrp = killer:FindFirstChild("HumanoidRootPart")
                    if kHrp then
                        local tCF = kHrp.CFrame * CFrame.new(0, 0, bsBehindStuds)
                        local tDir = hrp.CFrame * CFrame.new(0, -90000, 0)
                        local tEnd = hrp.CFrame * CFrame.new(0, 0, 0)
                        if bsMoreDirectRN then
                            args[1] = CharReplicationAB.Serialize(tDir, hrp.AssemblyLinearVelocity)
                        elseif bsMoreDirectEnd then
                            args[1] = CharReplicationAB.Serialize(tEnd, hrp.AssemblyLinearVelocity)
                        elseif bsDoitmate then
                            args[1] = CharReplicationAB.Serialize(tCF, hrp.AssemblyLinearVelocity)
                        end
                    end
                end
            end
            return oldFire(self, connectionName, eventType, unpack(args))
        end)
    end
end)

local function checkDistAB(h1, h2, range)
    if not h1 or not h2 then return false end
    return (h1.Position - h2.Position).Magnitude <= range
end

local function hookCharAB(character)
    local hum = character:WaitForChild("Humanoid")
    local animator = hum:FindFirstChild("Animator")
    if not animator then return end
    animator.AnimationPlayed:Connect(function(track)
        if not track or not track.Animation then return end
        local killer = getFirstValidKillerAB()
        if not killer then return end
        local id = tostring(track.Animation.AnimationId or ""):gsub("%D", "")
        if (id == TARGET_ANIMATION_ID or id == "106086955212611") and bsEnabled then
            if bsDistCheck then
                if not checkDistAB(character.HumanoidRootPart, killer.HumanoidRootPart, bsDistCheckStuds) then return end
            end
            task.spawn(runPlaceSequence)
        elseif (id == DASHSTAB_ANIM_ID or id == "107640065977686") and bsDashstabEnabled then
            if bsDistCheck then
                if not checkDistAB(character.HumanoidRootPart, killer.HumanoidRootPart, bsDistCheckStuds) then return end
            end
            task.spawn(runDashstabSequence)
        end
    end)
end

if LocalPlayer.Character then hookCharAB(LocalPlayer.Character) end
LocalPlayer.CharacterAdded:Connect(hookCharAB)

local lastK, lastKPos, smoothSpd = nil, nil, 0
RunService.Heartbeat:Connect(function(dt)
    if bsAutoStuds then
        local killer = getFirstValidKillerAB()
        if killer then
            local kHrp = killer:FindFirstChild("HumanoidRootPart")
            if kHrp then
                local curPos = kHrp.Position
                local rawSpd = 0
                if lastK == killer and lastKPos then
                    local hd = Vector3.new(curPos.X,0,curPos.Z) - Vector3.new(lastKPos.X,0,lastKPos.Z)
                    rawSpd = hd.Magnitude / dt
                end
                lastK = killer; lastKPos = curPos
                smoothSpd = smoothSpd + (rawSpd - smoothSpd) * math.min(dt*15, 1)
                local fs = math.clamp(smoothSpd, 0, 30)
                local sRun = bsAutoRunStuds
                if bsDetectPing then
                    local ping = math.max(getPingAB(), 20)
                    sRun = bsAutoRunStuds - ((ping - 20) / 100) * 1.5
                    sRun = math.max(sRun, 1.0)
                end
                local slope = (bsAutoStandStuds - sRun) / 26.0
                bsBehindStuds = bsAutoStandStuds - (fs * slope)
            else lastK = nil end
        else lastK = nil; smoothSpd = 0 end
    else lastK = nil; smoothSpd = 0 end
end)

-- ==========================================
-- CHANCE MODULE LOGIC
-- ==========================================
local autoCoinFlipThread = nil
local function SetupAutoCoinFlip()
    if autoCoinFlipThread then
        task.cancel(autoCoinFlipThread)
        autoCoinFlipThread = nil
    end

    local isChance = false
    local charges = nil

    local function startLoop()
        if autoCoinFlipThread then
            task.cancel(autoCoinFlipThread)
        end
        autoCoinFlipThread = task.spawn(function()
            while task.wait(1.85) do
                if CONFIG.AutoCoinFlip then
                    if isChance then
                        if charges and charges.Text ~= "3" then
                            pcall(function()
                                local re = getRemote()
                                if re then
                                    re:FireServer("UseActorAbility", { buffer.fromstring(string.pack("<Bi4", 3, # "CoinFlip") .. "CoinFlip") })
                                end
                            end)
                        end
                        continue
                    end
                end
                break
            end
        end)
    end

    if CONFIG.AutoCoinFlip then
        if LocalPlayer.Character and LocalPlayer.Character.Name == "Chance" then
            isChance = true
            pcall(function()
                charges = LocalPlayer.PlayerGui.MainUI.AbilityContainer.Shoot.Charges
            end)
            startLoop()
        end

        LocalPlayer.CharacterAdded:Connect(function(character)
            isChance = false
            if autoCoinFlipThread then
                task.cancel(autoCoinFlipThread)
                autoCoinFlipThread = nil
            end

            if character.Name == "Chance" then
                isChance = true
                task.wait(2)
                pcall(function()
                    charges = Players:GetPlayerFromCharacter(character).PlayerGui.MainUI.AbilityContainer.Shoot.Charges
                end)
                startLoop()
            end
        end)
    end
end

local shootConn1, shootConn2, shootConn3 = nil, nil, nil
local function SetupShootAimHelper()
    local animIds = {}
    
    pcall(function()
        local assets = ReplicatedStorage:FindFirstChild("Assets")
        if assets then
            local config = require(assets.Survivors.Chance.Config)
            if config and config.Animations then
                table.insert(animIds, config.Animations.AimGun)
            end
            local chanceSkins = assets.Skins.Survivors:FindFirstChild("Chance")
            if chanceSkins then
                for _, child in pairs(chanceSkins:GetChildren()) do
                    if child:FindFirstChild("Config") then
                        local skinConfig = require(child.Config)
                        if skinConfig and skinConfig.Animations then
                            table.insert(animIds, skinConfig.Animations.AimGun)
                        end
                    end
                end
            end
        end
    end)

    if shootConn1 then shootConn1:Disconnect(); shootConn1 = nil end
    if shootConn2 then shootConn2:Disconnect(); shootConn2 = nil end
    if shootConn3 then shootConn3:Disconnect(); shootConn3 = nil end

    if not CONFIG.Shoot_Aim_helper then return end

    local function hookCharacter()
        local humanoid = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid")
        if humanoid then
            shootConn1 = humanoid.AnimationPlayed:Connect(function(track)
                if track.Animation and table.find(animIds, track.Animation.AnimationId) then
                    task.spawn(function()
                        local char = LocalPlayer.Character
                        local hrp = char and char:FindFirstChild("HumanoidRootPart")
                        if not hrp then return end

                        local target = nil
                        local closest = math.huge
                        for _, p in ipairs(Players:GetPlayers()) do
                            if p ~= LocalPlayer and p.Character and p.Character:FindFirstChild("HumanoidRootPart") and p.Character:FindFirstChildOfClass("Humanoid").Health > 0 then
                                local d = (p.Character.HumanoidRootPart.Position - hrp.Position).Magnitude
                                if d < closest then closest = d; target = p.Character end
                            end
                        end

                        if target then
                            local startTime = tick()
                            local originalAutoRotate = humanoid.AutoRotate
                            humanoid.AutoRotate = false

                            -- 360 Spin
                            if CONFIG.Shoot_360_Spin then
                                local spinThread = task.spawn(function()
                                    while tick() - startTime < CONFIG.Shoot_Aim_helper_look_loock do
                                        hrp.CFrame = hrp.CFrame * CFrame.Angles(0, math.rad(45), 0)
                                        RunService.RenderStepped:Wait()
                                    end
                                end)
                                task.wait(CONFIG.Shoot_Aim_helper_look_loock)
                                if spinThread then task.cancel(spinThread) end
                            end

                            -- Aim Lock
                            local aimThread = task.spawn(function()
                                while tick() - startTime < CONFIG.Shoot_Aim_helper_look_loock do
                                    if target and target.Parent and target:FindFirstChild("HumanoidRootPart") then
                                        local tHrp = target.HumanoidRootPart
                                        local dir = (tHrp.Position - hrp.Position).Unit
                                        hrp.CFrame = CFrame.lookAt(hrp.Position, hrp.Position + Vector3.new(dir.X, 0, dir.Z))
                                        
                                        if CONFIG.Shoot_Aim_helper_method == "HumanoidRoot Lock + Camera Lock" then
                                            Camera.CFrame = CFrame.lookAt(Camera.CFrame.Position, tHrp.Position)
                                        end
                                    end
                                    RunService.RenderStepped:Wait()
                                end
                            end)
                            
                            task.wait(CONFIG.Shoot_Aim_helper_look_loock)
                            if aimThread then task.cancel(aimThread) end
                            humanoid.AutoRotate = originalAutoRotate
                        end
                    end)
                end
            end)
        end
    end

    hookCharacter()
    shootConn2 = LocalPlayer.CharacterAdded:Connect(function()
        task.wait(1)
        hookCharacter()
    end)
    shootConn3 = LocalPlayer.CharacterRemoving:Connect(function()
        if shootConn1 then shootConn1:Disconnect(); shootConn1 = nil end
    end)
end

local Rayfield = nil
pcall(function() Rayfield = loadstring(game:HttpGet("https://sirius.menu/gen2", true))() end)

if not Rayfield or type(Rayfield) ~= "table" or not Rayfield.CreateWindow then
    warn("[NS] Rayfield load failed!")
    return
end

local window = Rayfield:CreateWindow({
    name = "NIGHTSAKEN + AUTO BACKSTAB",
    subtitle = "by molettao5 GODSAKEN & duongji1",
    sidebarLayout = true,
})

local combatTab = window:CreateTab({ name = "Combat", icon = 93364949241311 })
combatTab:CreateToggle({ name = "Auto Block (Forsaken style)", currentValue = false, callback = function(v) setAutoBlock(v) end })
combatTab:CreateToggle({ name = "Auto Punch (Godsaken)", currentValue = false, callback = function(v) CONFIG.AutoPunch = v end })
combatTab:CreateSlider({ name = "Punch Tracking Smoothness", range = {1,100}, increment = 1, currentValue = 80, callback = function(v) CONFIG.AutoPunchAccuracy = v end })

combatTab:CreateSection("Punch Aimbot")
combatTab:CreateToggle({ name = "Enable Punch Aimbot", currentValue = false, callback = function(v) CONFIG.PunchAimbot = v end })
combatTab:CreateSlider({ name = "Prediction", range = {0,1}, increment = 0.05, currentValue = 0.3, callback = function(v) CONFIG.Prediction = v end })
combatTab:CreateSlider({ name = "Aimbot Range", range = {10,200}, increment = 5, currentValue = 100, callback = function(v) CONFIG.AimbotRange = v end })
combatTab:CreateSlider({ name = "Depth Offset", range = {-5,5}, increment = 0.5, currentValue = 0, callback = function(v) CONFIG.DepthOffset = v end })

combatTab:CreateSection("Hitbox (Visual)")
combatTab:CreateToggle({ name = "Show Hitbox Visual", currentValue = true, callback = function(v) CONFIG.ShowHitboxVisual = v end })
combatTab:CreateToggle({ name = "Show Outline", currentValue = true, callback = function(v) CONFIG.ShowOutline = v end })
combatTab:CreateSlider({ name = "Hitbox Multiplier", range = {0.1,5}, increment = 0.1, currentValue = 1, callback = function(v) CONFIG.HitboxMultiplier = v end })
combatTab:CreateSlider({ name = "Hitbox Distance", range = {1,20}, increment = 0.5, currentValue = 3, callback = function(v) CONFIG.HitboxDistance = v end })
combatTab:CreateSlider({ name = "Hitbox Transparency", range = {0,1}, increment = 0.05, currentValue = 0.8, callback = function(v) CONFIG.HitboxTransparency = v end })
combatTab:CreateSlider({ name = "Outline Transparency", range = {0,1}, increment = 0.05, currentValue = 0.6, callback = function(v) CONFIG.OutlineTransparencyValue = v end })

combatTab:CreateSection("Hitbox Color")
combatTab:CreateColorPicker({ name = "Hitbox Color", currentValue = CONFIG.HitboxColor, callback = function(v) CONFIG.HitboxColor = v end })

combatTab:CreateToggle({ name = "Debug Log", currentValue = true, callback = function(v) CONFIG.DEBUG = v end })

combatTab:CreateSection("Auto Backstab v4")
combatTab:CreateToggle({ name = "Auto Backstab (Main)", currentValue = false, callback = function(v) bsEnabled = v end })
combatTab:CreateSlider({ name = "Start Delay", range = {0,1}, increment = 0.01, currentValue = 0.05, callback = function(v) bsStartDelay = v end })
combatTab:CreateSlider({ name = "Duration", range = {0.05,1}, increment = 0.01, currentValue = 0.2, callback = function(v) bsDuration = v end })
combatTab:CreateSlider({ name = "Behind Studs", range = {1,15}, increment = 0.1, currentValue = 4, callback = function(v) bsBehindStuds = v end })
combatTab:CreateToggle({ name = "Distance Check", currentValue = false, callback = function(v) bsDistCheck = v end })
combatTab:CreateSlider({ name = "Distance Check Studs", range = {1,30}, increment = 1, currentValue = 7, callback = function(v) bsDistCheckStuds = v end })
combatTab:CreateToggle({ name = "Auto Studs (Speed-based)", currentValue = false, callback = function(v) bsAutoStuds = v end })
combatTab:CreateSlider({ name = "Auto Studs Stand", range = {1,15}, increment = 0.1, currentValue = 5.5, callback = function(v) bsAutoStandStuds = v end })
combatTab:CreateSlider({ name = "Auto Studs Run", range = {1,15}, increment = 0.1, currentValue = 3.4, callback = function(v) bsAutoRunStuds = v end })
combatTab:CreateToggle({ name = "Also Detect Ping", currentValue = false, callback = function(v) bsDetectPing = v end })
combatTab:CreateToggle({ name = "More Direct", currentValue = false, callback = function(v) bsMoreDirect = v end })
combatTab:CreateToggle({ name = "Dashstab", currentValue = false, callback = function(v) bsDashstabEnabled = v end })
combatTab:CreateSlider({ name = "Dashstab Start Delay", range = {0,1}, increment = 0.01, currentValue = 0.1, callback = function(v) bsDsStartDelay = v end })

local killerTab = window:CreateTab({ name = "Combat Killer", icon = 93364949241311 })
killerTab:CreateSection("Void Rush (Noli)")
killerTab:CreateToggle({ name = "Void Rush Control (Noli)", currentValue = false, callback = function(v) setVoidRushControl(v) end })
killerTab:CreateSlider({ name = "Noli InitialTurnMult", range = {100,5000}, increment = 100, currentValue = 1000, callback = function(v) CONFIG.NoliTurnMult = v; if CONFIG.VoidRushControl then ApplyVoidRushControl() end end })
killerTab:CreateSlider({ name = "Noli TurnSpeed", range = {1000,50000}, increment = 500, currentValue = 10000, callback = function(v) CONFIG.NoliTurnSpeed = v; if CONFIG.VoidRushControl then ApplyVoidRushControl() end end })
killerTab:CreateButton({ name = "Force Apply Void Rush", callback = function() ApplyVoidRushControl() end })

-- Tab Chance Riêng Biệt
local chanceTab = window:CreateTab({ name = "Chance", icon = 93364949241311 })
chanceTab:CreateSection("Chance Combat Utilities")
chanceTab:CreateDropdown({
    Name = "Aim method",
    Options = { "HumanoidRoot Lock", "HumanoidRoot Lock + Camera Lock" },
    CurrentOption = CONFIG.Shoot_Aim_helper_method,
    Callback = function(val)
        CONFIG.Shoot_Aim_helper_method = val
    end,
})
chanceTab:CreateToggle({
    Name = "Shoot Aim helper",
    CurrentValue = CONFIG.Shoot_Aim_helper,
    Callback = function(val)
        CONFIG.Shoot_Aim_helper = val
        SetupShootAimHelper()
    end,
})
chanceTab:CreateSlider({
    Name = "Lock Aim (seconds)",
    Range = {1, 2},
    Increment = 0.1,
    CurrentValue = CONFIG.Shoot_Aim_helper_look_loock,
    Callback = function(val)
        CONFIG.Shoot_Aim_helper_look_loock = val
    end,
})
chanceTab:CreateToggle({
    Name = "Shoot 360 Spin",
    CurrentValue = CONFIG.Shoot_360_Spin,
    Callback = function(val)
        CONFIG.Shoot_360_Spin = val
    end,
})
chanceTab:CreateToggle({
    Name = "Auto Coin Flip",
    CurrentValue = CONFIG.AutoCoinFlip,
    Callback = function(val)
        CONFIG.AutoCoinFlip = val
        SetupAutoCoinFlip()
    end,
})

local espTab = window:CreateTab({ name = "ESP", icon = 93364949241311 })
espTab:CreateSection("Toggles")
espTab:CreateToggle({ name = "ESP Killer", currentValue = false, callback = function(v) setESPKiller(v) end })
espTab:CreateToggle({ name = "ESP Survivor", currentValue = false, callback = function(v) setESPSurvivor(v) end })
espTab:CreateToggle({ name = "ESP Generator", currentValue = false, callback = function(v) setESPGenerators(v) end })
espTab:CreateToggle({ name = "ESP Item", currentValue = false, callback = function(v) setESPItems(v) end })

espTab:CreateSection("ESP Transparency")
espTab:CreateSlider({ name = "ESP Fill Transparency", range = {0,1}, increment = 0.05, currentValue = 0.5, callback = function(v) CONFIG.ESPFillTransparency = v; updateAllESPTransparency() end })
espTab:CreateSlider({ name = "ESP Outline Transparency", range = {0,1}, increment = 0.05, currentValue = 0, callback = function(v) CONFIG.ESPOutlineTransparency = v; updateAllESPTransparency() end })
espTab:CreateColorPicker({ name = "ESP Outline Color", currentValue = Color3.fromRGB(0,0,0), callback = function(v) CONFIG.ESPOutlineColor = v; updateAllESPTransparency() end })

espTab:CreateSection("Text Options")
espTab:CreateToggle({ name = "Show Name", currentValue = true, callback = function(v) CONFIG.ShowName = v end })
espTab:CreateToggle({ name = "Show HP", currentValue = true, callback = function(v) CONFIG.ShowHP = v end })
espTab:CreateSlider({ name = "Name Text Size", range = {6,20}, increment = 1, currentValue = 10, callback = function(v) CONFIG.ESPNameSize = v end })
espTab:CreateSlider({ name = "HP Text Size", range = {6,20}, increment = 1, currentValue = 8, callback = function(v) CONFIG.ESPInfoSize = v end })
espTab:CreateSlider({ name = "Billboard Offset Y", range = {0,10}, increment = 0.1, currentValue = 3.0, callback = function(v) CONFIG.ESPStudsOffsetY = v end })
espTab:CreateSlider({ name = "Billboard Height", range = {10,60}, increment = 1, currentValue = 40, callback = function(v) CONFIG.ESPBillboardHeight = v end })

espTab:CreateSection("Actions")
espTab:CreateButton({ name = "Clear All ESP", callback = function()
    clearKillerESP(); clearSurvivorESP(); clearGeneratorESP(); clearItemESP()
end })

local fovTab = window:CreateTab({ name = "FOV", icon = 93364949241311 })
fovTab:CreateSection("Camera FOV (30-120, Skidsaken Style)")
fovTab:CreateSlider({ name = "FOV Direct (30-120)", range = {MIN_FOV, MAX_FOV}, increment = 1, currentValue = 120, callback = function(v) setFOV(v) end })
fovTab:CreateSlider({ name = "FOV Percent (0=30, 100=120)", range = {0, 100}, increment = 1, currentValue = 100, callback = function(v) setFOVByPercent(v) end })
fovTab:CreateButton({ name = "Reapply FOV Now", callback = function() ApplyFOV() end })
fovTab:CreateButton({ name = "Reset FOV to 120", callback = function() resetFOV() end })
fovTab:CreateButton({ name = "Set FOV to 30 (Min)", callback = function() setFOV(30) end })

local visualTab = window:CreateTab({ name = "Visual", icon = 93364949241311 })
visualTab:CreateToggle({ name = "Fullbright", currentValue = false, callback = function(v) setFullbright(v) end })

local miscTab = window:CreateTab({ name = "Misc", icon = 93364949241311 })
miscTab:CreateToggle({ name = "Infinite Stamina", currentValue = false, callback = function(v) setInfStamina(v) end })
miscTab:CreateButton({ name = "Test Fire Block (Forsaken)", callback = function() fireBlock() end })

local autoBlockBtnHidden = false

local function updateAutoBlockButtonVisibility()
    local gui = LocalPlayer.PlayerGui:FindFirstChild("AutoBlockButtonGui")
    if gui then gui.Enabled = not autoBlockBtnHidden end
end

local function createAutoBlockFloatingButton()
    local oldGui = LocalPlayer.PlayerGui:FindFirstChild("AutoBlockButtonGui")
    if oldGui then oldGui:Destroy() end

    local pxScale, pxOffset = 0, 20
    local pyScale, pyOffset = 0.5, -35
    pcall(function()
        if isfile and isfile("NIGHTSAKEN_ButtonPos.txt") then
            local data = readfile("NIGHTSAKEN_ButtonPos.txt")
            if data and data ~= "" then
                local parts = string.split(data, ",")
                if #parts >= 4 then
                    pxScale = tonumber(parts[1]) or pxScale
                    pxOffset = tonumber(parts[2]) or pxOffset
                    pyScale = tonumber(parts[3]) or pyScale
                    pyOffset = tonumber(parts[4]) or pyOffset
                end
            end
        end
    end)

    local buttonGui = Instance.new("ScreenGui")
    buttonGui.Name = "AutoBlockButtonGui"
    buttonGui.ResetOnSpawn = false
    buttonGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    buttonGui.DisplayOrder = 999
    buttonGui.Enabled = not autoBlockBtnHidden
    buttonGui.Parent = LocalPlayer.PlayerGui

    local button = Instance.new("TextButton")
    button.Name = "AutoBlockButton"
    button.Size = UDim2.new(0, 70, 0, 70)
    button.Position = UDim2.new(pxScale, pxOffset, pyScale, pyOffset)
    button.BackgroundColor3 = Color3.fromRGB(200, 0, 0)
    button.TextColor3 = Color3.fromRGB(255, 255, 255)
    button.Text = "OFF"
    button.TextSize = 16
    button.Font = Enum.Font.GothamBold
    button.BorderSizePixel = 0
    button.AutoButtonColor = false
    button.Parent = buttonGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(1, 0)
    corner.Parent = button

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(255, 255, 255)
    stroke.Thickness = 3
    stroke.Parent = button

    local isOn = false
    local isHolding = false
    local holdStartTime = 0
    local holdTimer = nil
    local dragging = false
    local dragStart, startPos
    local movedDistance = 0
    local CLICK_THRESHOLD = 5
    local HOLD_DURATION = 0.3

    local function updateButton()
        if isOn then
            button.BackgroundColor3 = Color3.fromRGB(0, 200, 0)
            button.Text = "ON"
        else
            button.BackgroundColor3 = Color3.fromRGB(200, 0, 0)
            button.Text = "OFF"
        end
    end

    button.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            holdStartTime = tick()
            movedDistance = 0
            dragStart = input.Position
            startPos = button.Position
            isHolding = true
            holdTimer = task.delay(HOLD_DURATION, function()
                if isHolding then
                    dragging = true
                    pcall(function()
                        stroke.Color = Color3.fromRGB(255, 255, 0)
                        stroke.Thickness = 4
                    end)
                end
            end)
        end
    end)

    button.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            local heldTime = tick() - holdStartTime
            isHolding = false
            if holdTimer then task.cancel(holdTimer); holdTimer = nil end
            if dragging then
                dragging = false
                pcall(function()
                    stroke.Color = Color3.fromRGB(255, 255, 255)
                    stroke.Thickness = 3
                end)
                pcall(function()
                    if writefile then
                        local p = button.Position
                        local saveData = tostring(p.X.Scale)..","..tostring(p.X.Offset)..","..tostring(p.Y.Scale)..","..tostring(p.Y.Offset)
                        writefile("NIGHTSAKEN_ButtonPos.txt", saveData)
                    end
                end)
            else
                if heldTime < HOLD_DURATION and movedDistance < CLICK_THRESHOLD then
                    isOn = not isOn
                    setAutoBlock(isOn)
                    updateButton()
                end
            end
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if not dragging then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            local delta = input.Position - dragStart
            movedDistance = math.sqrt(delta.X*delta.X + delta.Y*delta.Y)
            button.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)

    updateButton()
end

createAutoBlockFloatingButton()

miscTab:CreateSection("Auto Block Button")
miscTab:CreateToggle({
    name = "Hide Auto Block Button",
    currentValue = false,
    callback = function(v)
        autoBlockBtnHidden = v
        updateAutoBlockButtonVisibility()
        log("Auto Block Button: " .. (v and "HIDDEN" or "VISIBLE"))
    end
})
miscTab:CreateButton({
    name = "Force Show Auto Block Button",
    callback = function()
        autoBlockBtnHidden = false
        updateAutoBlockButtonVisibility()
        if not LocalPlayer.PlayerGui:FindFirstChild("AutoBlockButtonGui") then
            createAutoBlockFloatingButton()
        end
        log("Auto Block Button force shown")
    end
})

LocalPlayer.CharacterAdded:Connect(function()
    task.wait(1)
    if not LocalPlayer.PlayerGui:FindFirstChild("AutoBlockButtonGui") then
        createAutoBlockFloatingButton()
    end
    task.wait(0.2)
    updateAutoBlockButtonVisibility()
end)

print("[NIGHTSAKEN-v63.3] LOADED - FIXED Chance Aimbot & 360 Spin")
