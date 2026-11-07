-- ============================================================
-- NIGHTSAKEN v63.4 - THAY ESP BẰNG OBSIDIAN STYLE ESP
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

-- ==========================================
-- NEW OBSIDIAN STYLE ESP SYSTEM
-- ==========================================
local EspLib = {}
local MapFolder = nil
local mapObj = Workspace:FindFirstChild("Map")
if mapObj then MapFolder = mapObj:FindFirstChild("Ingame") end
local DummyNames = {
    "PizzaDeliveryRig", "Mafiaso1", "Mafiaso2", "Builderman", "Elliot",
    "ShedletskyCORRUPT", "ChancecORRUPT", "ChanceCORRUPT", "Mafia1", "Mafia2",
    "Mafia3", "Mafia4", "Mafia5", "Mafia6", "Mafia7", "Mafia8", "Mafia9",
    "GreenGuy", "RedGuy", "BlueGuy", "PurpleGuy", "PinkGuy", "YellowGuy",
    "OrangeGuy", "GreyGuy"
}
local ObjectESPData = {}
local PlayerESPData = {}
local ESPSettings = {
    generatorESP = false, itemESP = false, pizzaEsp = false, pizzaDeliveryEsp = false,
    zombieEsp = false, taphTripwireEsp = false, tripMineEsp = false, twoTimeRespawnEsp = false,
    graffitiEsp = false,
    generatorColor = Color3.fromRGB(200, 100, 200), itemColor = Color3.fromRGB(200, 200, 0),
    pizzaColor = Color3.fromRGB(200, 150, 0), pizzaDeliveryColor = Color3.fromRGB(200, 100, 100),
    zombieColor = Color3.fromRGB(200, 100, 100), taphTripwireColor = Color3.fromRGB(100, 0, 100),
    tripMineColor = Color3.fromRGB(255, 0, 255), twoTimeRespawnColor = Color3.fromRGB(0, 150, 200),
    graffitiColor = Color3.fromRGB(255, 255, 255),
    limitDistance = false, maxDistance = 150,
    killerESP = false, playerESP = false, killerNameESP = true, survivorNameESP = true,
    killerHealthESP = true, survivorHealthESP = true, killerSkinESP = false, survivorSkinESP = false,
    killerColor = Color3.fromRGB(255, 100, 100), survivorColor = Color3.fromRGB(100, 255, 100),
    killerFillTransparency = 0.7, killerOutlineTransparency = 0.3,
    survivorFillTransparency = 0.7, survivorOutlineTransparency = 0.3,
    generatorTracers = false, itemTracers = false, pizzaTracers = false, pizzaDeliveryTracers = false,
    zombieTracers = false, taphTripwireTracers = false, tripMineTracers = false, twoTimeRespawnTracers = false,
    killerTracers = false, survivorTracers = false,
    showGeneratorName = true, showItemName = true, showPizzaName = true, showPizzaDeliveryName = true,
    showZombieName = true, showTaphTripwireName = true, showTripMineName = true, showTwoTimeRespawnName = true,
    showGraffitiName = true,
    azureGroundBulbESP = false,
    azureVineESP = false,
    azureGroundBulbColor = Color3.fromRGB(0, 255, 200),
    azureVineColor = Color3.fromRGB(200, 0, 255),
}
local function IsRagdoll(model)
    local ragdolls = Workspace:FindFirstChild("Ragdolls")
    return ragdolls and (model:IsDescendantOf(ragdolls) or model.Parent == ragdolls)
end
local function IsSpectating(player)
    if not player then return false end
    local pf = Workspace:FindFirstChild("Players")
    if not pf then return false end
    local sp = pf:FindFirstChild("Spectating")
    return sp and sp:FindFirstChild(player.Name) ~= nil
end
local function GetGeneratorPart(model)
    if not model then return nil end
    local instances = model:FindFirstChild("Instances")
    if instances then
        local generator = instances:FindFirstChild("Generator")
        if generator then
            local cube = generator:FindFirstChild("Cube.003")
            if cube and cube:IsA("BasePart") then return cube end
            for _, v in ipairs(generator:GetDescendants()) do if v:IsA("BasePart") then return v end end
        end
        for _, v in ipairs(instances:GetDescendants()) do if v:IsA("BasePart") and tostring(v.Name):lower():find("cube") then return v end end
    end
    for _, v in ipairs(model:GetDescendants()) do if v:IsA("BasePart") and v.Name:lower():find("cube") then return v end end
    for _, v in ipairs(model:GetDescendants()) do if v:IsA("BasePart") then return v end end
    return nil
end
local function createPlayerESP(model, color, isKiller)
    if model:FindFirstChild("Fixsaken_Highlight") then return end
    if IsRagdoll(model) then return end
    local hrp = model:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local highlight = Instance.new("Highlight")
    highlight.Name = "Fixsaken_Highlight"
    highlight.Adornee = model
    highlight.FillColor = color
    highlight.OutlineColor = color
    highlight.FillTransparency = isKiller and ESPSettings.killerFillTransparency or ESPSettings.survivorFillTransparency
    highlight.OutlineTransparency = isKiller and ESPSettings.killerOutlineTransparency or ESPSettings.survivorOutlineTransparency
    highlight.Parent = model
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "Fixsaken_Billboard"
    billboard.Adornee = hrp
    billboard.Size = UDim2.new(0, 120, 0, 50)
    billboard.StudsOffset = Vector3.new(0, 4, 0)
    billboard.AlwaysOnTop = true
    billboard.Parent = model
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(1, 0, 0.4, 0)
    nameLabel.Position = UDim2.new(0, 0, 0, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = "Loading..."
    nameLabel.Font = Enum.Font.Jura
    nameLabel.TextColor3 = color
    nameLabel.TextSize = 8
    nameLabel.TextStrokeTransparency = 0.6
    nameLabel.Parent = billboard
    local hpLabel = Instance.new("TextLabel")
    hpLabel.Size = UDim2.new(1, 0, 0.4, 0)
    hpLabel.Position = UDim2.new(0, 0, 0.4, 0)
    hpLabel.BackgroundTransparency = 1
    hpLabel.Text = "HP: N/A"
    hpLabel.Font = Enum.Font.Jura
    hpLabel.TextColor3 = color
    hpLabel.TextSize = 8
    hpLabel.TextStrokeTransparency = 0.6
    hpLabel.Parent = billboard
    local data = { model = model, nameLabel = nameLabel, hpLabel = hpLabel, isKiller = isKiller }
    table.insert(PlayerESPData, data)
    local function updateText()
        if not data.model or not data.model.Parent then return end
        local m = data.model
        local isK = data.isKiller
        local displayName = m:GetAttribute("ActorDisplayName") or (isK and "KILLER" or "SURVIVOR")
        local skinName = m:GetAttribute("SkinNameDisplay")
        local text = displayName
        if (isK and ESPSettings.killerSkinESP) or (not isK and ESPSettings.survivorSkinESP) then
            if skinName and skinName ~= "" then text = text .. " | " .. skinName end
        end
        nameLabel.Text = text
        local humanoid = m:FindFirstChild("Humanoid")
        if humanoid then
            hpLabel.Text = string.format("HP: %d/%d", math.floor(humanoid.Health), math.floor(humanoid.MaxHealth))
        end
        if highlight and highlight.Parent then
            if isK then
                highlight.FillTransparency = ESPSettings.killerFillTransparency
                highlight.OutlineTransparency = ESPSettings.killerOutlineTransparency
            else
                highlight.FillTransparency = ESPSettings.survivorFillTransparency
                highlight.OutlineTransparency = ESPSettings.survivorOutlineTransparency
            end
        end
    end
    updateText()
    model:GetAttributeChangedSignal("ActorDisplayName"):Connect(updateText)
    model:GetAttributeChangedSignal("SkinNameDisplay"):Connect(updateText)
    local humanoid = model:FindFirstChild("Humanoid")
    if humanoid then
        humanoid:GetPropertyChangedSignal("Health"):Connect(updateText)
        humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(updateText)
    end
end
local function removePlayerESP(model)
    for i = #PlayerESPData, 1, -1 do if PlayerESPData[i].model == model then table.remove(PlayerESPData, i) end end
    pcall(function()
        if model:FindFirstChild("Fixsaken_Highlight") then model.Fixsaken_Highlight:Destroy() end
        if model:FindFirstChild("Fixsaken_Billboard") then model.Fixsaken_Billboard:Destroy() end
    end)
end
local function CreateObjectESP(model, color, isGenerator, isItem, isPizza, isPizzaDelivery, isZombie, isTaph, isTripMine, isRespawn, isGraffiti, displayText)
    if not model then return end
    if model:FindFirstChild("TAOWARE_Highlight") then return end
    if isGenerator and model:FindFirstChild("Progress") and model.Progress.Value == 100 then return end
    if IsRagdoll(model) then return end
    if ESPSettings.limitDistance then
        local rootPart = model:IsA("BasePart") and model or model:FindFirstChild("HumanoidRootPart")
        if rootPart then
            local distance = (Camera.CFrame.Position - rootPart.Position).Magnitude
            if distance > ESPSettings.maxDistance then return end
        end
    end
    local targetPart
    if isGenerator then targetPart = GetGeneratorPart(model)
    elseif isItem then targetPart = model:FindFirstChild("ItemRoot")
    elseif isPizza then targetPart = model:IsA("BasePart") and model or model:FindFirstChildWhichIsA("BasePart", true)
    elseif isPizzaDelivery then targetPart = model:IsA("BasePart") and model or model:FindFirstChildWhichIsA("BasePart", true)
    elseif isZombie then targetPart = model:IsA("BasePart") and model or model:FindFirstChildWhichIsA("BasePart", true)
    elseif isTaph then targetPart = model:IsA("Model") and (GetGeneratorPart(model) or model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)) or model
    elseif isTripMine then targetPart = model:IsA("Model") and (GetGeneratorPart(model) or model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)) or model
    elseif isRespawn then targetPart = model:IsA("Model") and (GetGeneratorPart(model) or model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)) or model
    elseif isGraffiti then targetPart = model:IsA("BasePart") and model or model:FindFirstChildWhichIsA("BasePart", true)
    else return end
    if not targetPart then return end
    local highlight = Instance.new("Highlight")
    highlight.Name = "TAOWARE_Highlight"
    highlight.Adornee = model
    highlight.FillColor = color
    highlight.OutlineColor = color
    highlight.FillTransparency = 0.7
    highlight.OutlineTransparency = 0.3
    highlight.Parent = model
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "TAOWARE_Billboard"
    billboard.Adornee = targetPart
    billboard.Size = UDim2.new(0, 120, 0, 50)
    billboard.StudsOffset = Vector3.new(0, 4, 0)
    billboard.AlwaysOnTop = true
    billboard.Parent = model
    local textLabel = Instance.new("TextLabel")
    textLabel.Size = UDim2.new(1, 0, 1, 0)
    textLabel.BackgroundTransparency = 1
    if displayText then
        textLabel.Text = displayText
    else
        local typeAttr = model:GetAttribute("Type")
        if typeAttr then
            textLabel.Text = typeAttr
        else
            textLabel.Text = model.Name
        end
    end
    textLabel.Font = Enum.Font.Jura
    textLabel.TextColor3 = color
    textLabel.TextSize = 8
    textLabel.TextStrokeTransparency = 0.6
    textLabel.Parent = billboard
    local espData = {model = model, highlight = highlight, billboard = billboard}
    table.insert(ObjectESPData, espData)
end
local function RemoveObjectESP(model)
    if not model then return end
    for i = #ObjectESPData, 1, -1 do if ObjectESPData[i].model == model then table.remove(ObjectESPData, i) end end
    pcall(function()
        if model:FindFirstChild("TAOWARE_Highlight") then model.TAOWARE_Highlight:Destroy() end
        if model:FindFirstChild("TAOWARE_Billboard") then model.TAOWARE_Billboard:Destroy() end
    end)
end
local function UpdateESP()
    local pf = Workspace:FindFirstChild("Players")
    if pf then
        local killersFolder = pf:FindFirstChild("Killers")
        local survivorsFolder = pf:FindFirstChild("Survivors")
        if killersFolder then
            for _, killer in ipairs(killersFolder:GetChildren()) do
                if killer == LocalPlayer.Character then continue end
                if IsRagdoll(killer) then removePlayerESP(killer); continue end
                local player = Players:GetPlayerFromCharacter(killer)
                if not player or IsSpectating(player) then removePlayerESP(killer); continue end
                if ESPSettings.killerESP then
                    if not killer:FindFirstChild("Fixsaken_Highlight") then createPlayerESP(killer, ESPSettings.killerColor, true) end
                else removePlayerESP(killer) end
            end
        end
        if survivorsFolder then
            for _, survivor in ipairs(survivorsFolder:GetChildren()) do
                if survivor == LocalPlayer.Character then continue end
                if IsRagdoll(survivor) then removePlayerESP(survivor); continue end
                local player = Players:GetPlayerFromCharacter(survivor)
                if not player or IsSpectating(player) then removePlayerESP(survivor); continue end
                if ESPSettings.playerESP then
                    if not survivor:FindFirstChild("Fixsaken_Highlight") then createPlayerESP(survivor, ESPSettings.survivorColor, false) end
                else removePlayerESP(survivor) end
            end
        end
    end
    if not MapFolder then return end
    local ingame = MapFolder
    if ingame:FindFirstChild("Map") then
        for _, gen in ipairs(ingame.Map:GetChildren()) do
            if gen:IsA("Model") and gen.Name:lower():find("generator") and gen.Name ~= "FakeGenerator" then
                if IsRagdoll(gen) then RemoveObjectESP(gen); continue end
                local progress = gen:FindFirstChild("Progress")
                if ESPSettings.generatorESP and progress and progress.Value < 100 and not gen:FindFirstChild("TAOWARE_Highlight") then
                    CreateObjectESP(gen, ESPSettings.generatorColor, true)
                elseif not ESPSettings.generatorESP or (progress and progress.Value >= 100) then RemoveObjectESP(gen) end
            end
        end
        for _, item in ipairs(ingame.Map:GetDescendants()) do
            if item.Name == "ItemRoot" and item.Parent and item.Parent:IsA("Model") then
                local itemModel = item.Parent
                if ESPSettings.itemESP and not itemModel:FindFirstChild("TAOWARE_Highlight") then
                    CreateObjectESP(itemModel, ESPSettings.itemColor, false, true)
                elseif not ESPSettings.itemESP then RemoveObjectESP(itemModel) end
            end
        end
    end
    for _, pizza in ipairs(ingame:GetChildren()) do
        if pizza.Name == "Pizza" and pizza:IsA("BasePart") then
            if ESPSettings.pizzaEsp and not pizza:FindFirstChild("TAOWARE_Highlight") then
                CreateObjectESP(pizza, ESPSettings.pizzaColor, false, false, true)
            elseif not ESPSettings.pizzaEsp then RemoveObjectESP(pizza) end
        end
    end
    for _, delivery in ipairs(ingame:GetChildren()) do
        if delivery:IsA("Model") and table.find(DummyNames, delivery.Name) then
            if ESPSettings.pizzaDeliveryEsp and not delivery:FindFirstChild("TAOWARE_Highlight") then
                if delivery:FindFirstChild("HumanoidRootPart") then
                    CreateObjectESP(delivery, ESPSettings.pizzaDeliveryColor, false, false, false, true)
                end
            elseif not ESPSettings.pizzaDeliveryEsp then RemoveObjectESP(delivery) end
        end
    end
    for _, zombie in ipairs(ingame:GetChildren()) do
        if zombie.Name == "1x1x1x1Zombie" and zombie:IsA("Model") then
            if ESPSettings.zombieEsp and not zombie:FindFirstChild("TAOWARE_Highlight") then
                if zombie:FindFirstChild("HumanoidRootPart") then
                    CreateObjectESP(zombie, ESPSettings.zombieColor, false, false, false, false, true)
                end
            elseif not ESPSettings.zombieEsp then RemoveObjectESP(zombie) end
        end
    end
    for _, obj in ipairs(ingame:GetChildren()) do
        if obj.Name:match("TaphTripwire$") and obj:IsA("Model") then
            if ESPSettings.taphTripwireEsp and not obj:FindFirstChild("TAOWARE_Highlight") then
                CreateObjectESP(obj, ESPSettings.taphTripwireColor, false, false, false, false, false, true)
            elseif not ESPSettings.taphTripwireEsp then RemoveObjectESP(obj) end
        end
        if obj.Name == "SubspaceTripmine" and obj:IsA("Model") then
            if ESPSettings.tripMineEsp and not obj:FindFirstChild("TAOWARE_Highlight") then
                CreateObjectESP(obj, ESPSettings.tripMineColor, false, false, false, false, false, false, true)
            elseif not ESPSettings.tripMineEsp then RemoveObjectESP(obj) end
        end
        if obj.Name == "GraffitiCL" and obj:IsA("BasePart") then
            if ESPSettings.graffitiEsp and not obj:FindFirstChild("TAOWARE_Highlight") then
                CreateObjectESP(obj, ESPSettings.graffitiColor, false, false, false, false, false, false, false, false, true)
            elseif not ESPSettings.graffitiEsp then RemoveObjectESP(obj) end
        end
    end
    for _, obj in ipairs(ingame:GetDescendants()) do
        if obj and obj.Name and tostring(obj.Name):lower():find("respawnlocation") then
            local target = obj:IsA("Model") and obj or obj:IsA("BasePart") and obj or (obj:FindFirstAncestorOfClass("Model") or obj)
            if not target or IsRagdoll(target) then continue end
            if ESPSettings.twoTimeRespawnEsp and not target:FindFirstChild("TAOWARE_Highlight") then
                CreateObjectESP(target, ESPSettings.twoTimeRespawnColor, false, false, false, false, false, false, false, true)
            elseif not ESPSettings.twoTimeRespawnEsp then RemoveObjectESP(target) end
        end
    end
    if MapFolder then
        for _, obj in ipairs(MapFolder:GetDescendants()) do
            if obj:IsA("Model") then
                local nameLower = obj.Name:lower()
                if nameLower == "groundbulbmodel" then
                    if ESPSettings.azureGroundBulbESP then
                        if not obj:FindFirstChild("TAOWARE_Highlight") then
                            CreateObjectESP(obj, ESPSettings.azureGroundBulbColor, false, false, false, false, false, false, false, false, true, "GroundBulb")
                        end
                    else
                        RemoveObjectESP(obj)
                    end
                elseif nameLower == "vinemodel" then
                    if ESPSettings.azureVineESP then
                        if not obj:FindFirstChild("TAOWARE_Highlight") then
                            CreateObjectESP(obj, ESPSettings.azureVineColor, false, false, false, false, false, false, false, false, true, "Vine")
                        end
                    else
                        RemoveObjectESP(obj)
                    end
                end
            end
        end
    end
end
task.spawn(function() while task.wait(0.5) do pcall(UpdateESP) end end)
function EspLib:GetSettings() return ESPSettings end
function EspLib:UpdateAllPlayerText()
    for _, d in ipairs(PlayerESPData) do
        local m = d.model
        local isK = d.isKiller
        local displayName = m:GetAttribute("ActorDisplayName") or (isK and "KILLER" or "SURVIVOR")
        local skinName = m:GetAttribute("SkinNameDisplay")
        local text = displayName
        if (isK and ESPSettings.killerSkinESP) or (not isK and ESPSettings.survivorSkinESP) then
            if skinName and skinName ~= "" then text = text .. " | " .. skinName end
        end
        d.nameLabel.Text = text
        local humanoid = m:FindFirstChild("Humanoid")
        if humanoid then
            d.hpLabel.Text = string.format("HP: %d/%d", math.floor(humanoid.Health), math.floor(humanoid.MaxHealth))
        end
    end
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

-- Tab ESP Mới (Obsidian Style)
local espTab = window:CreateTab({ name = "ESP", icon = 93364949241311 })

local KillerGroup = espTab:CreateSection("Killer")
KillerGroup:CreateToggle({ name = "Killer ESP", currentValue = ESPSettings.killerESP, callback = function(v) ESPSettings.killerESP = v end })
KillerGroup:CreateToggle({ name = "Show Killer Name", currentValue = ESPSettings.killerNameESP, callback = function(v) ESPSettings.killerNameESP = v; EspLib:UpdateAllPlayerText() end })
KillerGroup:CreateToggle({ name = "Show Killer Health", currentValue = ESPSettings.killerHealthESP, callback = function(v) ESPSettings.killerHealthESP = v; EspLib:UpdateAllPlayerText() end })
KillerGroup:CreateToggle({ name = "Show Killer Skin", currentValue = ESPSettings.killerSkinESP, callback = function(v) ESPSettings.killerSkinESP = v; EspLib:UpdateAllPlayerText() end })
KillerGroup:CreateSlider({ name = "Killer Fill Transparency", currentValue = ESPSettings.killerFillTransparency, min = 0, max = 1, rounding = 2, callback = function(v) ESPSettings.killerFillTransparency = v; EspLib:UpdateAllPlayerText() end })
KillerGroup:CreateSlider({ name = "Killer Outline Transparency", currentValue = ESPSettings.killerOutlineTransparency, min = 0, max = 1, rounding = 2, callback = function(v) ESPSettings.killerOutlineTransparency = v; EspLib:UpdateAllPlayerText() end })
KillerGroup:CreateColorPicker({ name = "Killer Color", currentValue = ESPSettings.killerColor, callback = function(v) ESPSettings.killerColor = v end })

local SurvivorGroup = espTab:CreateSection("Survivor")
SurvivorGroup:CreateToggle({ name = "Survivor ESP", currentValue = ESPSettings.playerESP, callback = function(v) ESPSettings.playerESP = v end })
SurvivorGroup:CreateToggle({ name = "Show Survivor Name", currentValue = ESPSettings.survivorNameESP, callback = function(v) ESPSettings.survivorNameESP = v; EspLib:UpdateAllPlayerText() end })
SurvivorGroup:CreateToggle({ name = "Show Survivor Health", currentValue = ESPSettings.survivorHealthESP, callback = function(v) ESPSettings.survivorHealthESP = v; EspLib:UpdateAllPlayerText() end })
SurvivorGroup:CreateToggle({ name = "Show Survivor Skin", currentValue = ESPSettings.survivorSkinESP, callback = function(v) ESPSettings.survivorSkinESP = v; EspLib:UpdateAllPlayerText() end })
SurvivorGroup:CreateSlider({ name = "Survivor Fill Transparency", currentValue = ESPSettings.survivorFillTransparency, min = 0, max = 1, rounding = 2, callback = function(v) ESPSettings.survivorFillTransparency = v; EspLib:UpdateAllPlayerText() end })
SurvivorGroup:CreateSlider({ name = "Survivor Outline Transparency", currentValue = ESPSettings.survivorOutlineTransparency, min = 0, max = 1, rounding = 2, callback = function(v) ESPSettings.survivorOutlineTransparency = v; EspLib:UpdateAllPlayerText() end })
SurvivorGroup:CreateColorPicker({ name = "Survivor Color", currentValue = ESPSettings.survivorColor, callback = function(v) ESPSettings.survivorColor = v end })

local ItemGroup = espTab:CreateSection("Items")
ItemGroup:CreateToggle({ name = "Generator ESP", currentValue = ESPSettings.generatorESP, callback = function(v) ESPSettings.generatorESP = v end })
ItemGroup:CreateColorPicker({ name = "Generator Color", currentValue = ESPSettings.generatorColor, callback = function(v) ESPSettings.generatorColor = v end })
ItemGroup:CreateToggle({ name = "Item ESP", currentValue = ESPSettings.itemESP, callback = function(v) ESPSettings.itemESP = v end })
ItemGroup:CreateColorPicker({ name = "Item Color", currentValue = ESPSettings.itemColor, callback = function(v) ESPSettings.itemColor = v end })
ItemGroup:CreateToggle({ name = "Pizza ESP", currentValue = ESPSettings.pizzaEsp, callback = function(v) ESPSettings.pizzaEsp = v end })
ItemGroup:CreateColorPicker({ name = "Pizza Color", currentValue = ESPSettings.pizzaColor, callback = function(v) ESPSettings.pizzaColor = v end })

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

print("[NIGHTSAKEN-v63.4] LOADED - Replaced ESP with Obsidian Style")
