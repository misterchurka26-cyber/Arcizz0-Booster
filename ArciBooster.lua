--============================================================
-- ARCIZZ0 ULTRA / EXTREME CLIENT FPS BOOSTER (rework)
-- Цель: минимизировать freeze от массового появления Instances
-- (например база другого игрока в Steal a Brainrot)
--============================================================

local Workspace       = game:GetService("Workspace")
local Lighting        = game:GetService("Lighting")
local Players         = game:GetService("Players")
local MaterialService = game:GetService("MaterialService")
local RunService      = game:GetService("RunService")
local UserSettings    = game:GetService("UserSettings")
local TweenService    = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer

--============================================================
-- CONFIG (adaptive batching)
--============================================================
local SMALL_QUEUE   = 40    -- почти пустая очередь -> нано-режим
local BURST_QUEUE   = 150   -- массовый спавн -> burst-режим

local MICRO_BUDGET  = 0.0008
local NORMAL_BUDGET = 0.0015
local BURST_BUDGET  = 0.0035

local MICRO_MAX      = 60
local NORMAL_MAX     = 180
local BURST_MAX      = 420

local GC_THRESHOLD  = 2500
local CLOCK_CHECK_EVERY = 8  -- os.clock() проверяем не каждую итерацию

--============================================================
-- STATE
--============================================================
local queueObjs     = table.create(2048)
local queueHandlers = table.create(2048)
local queueHead = 1
local queueLen  = 0

-- weak-key таблицы: без property-write, без сигналов, без репликации,
-- сами чистятся при GC уничтоженного объекта. Это дешевле, чем Attribute
-- (Attribute = запись свойства в engine storage + потенциальные listeners)
-- и дешевле, чем CollectionService tag (доп. система индексации тегов,
-- которая тут не нужна, т.к. queried/lookup нам не требуется).
local queued    = setmetatable({}, { __mode = "k" }) -- уже в очереди
local optimized = setmetatable({}, { __mode = "k" }) -- уже обработан

local function safe(fn)
    pcall(fn)
end

--============================================================
-- HANDLERS (по одному pcall на объект, не по одному на свойство)
--============================================================
local function h_Animator(obj)
    safe(function()
        local tracks = obj:GetPlayingAnimationTracks()
        for i = 1, #tracks do
            tracks[i]:Stop(0)
        end
    end)
    safe(function() obj:Destroy() end)
end

local function h_AnimationController(obj)
    safe(function() obj:Destroy() end)
end

local function h_Animation(obj)
    safe(function() obj.AnimationId = "rbxassetid://0" end)
end

local function h_SurfaceAppearance(obj)
    safe(function() obj:Destroy() end)
end

local function h_DecalTexture(obj)
    safe(function() obj:Destroy() end)
end

local function h_EffectDisable(obj)
    safe(function() obj.Enabled = false end)
end

local function h_Light(obj)
    safe(function()
        obj.Shadows = false
        obj.Enabled = false
    end)
end

local function h_Video(obj)
    safe(function()
        obj.Playing = false
        obj.Visible = false
    end)
end

local function h_MeshPart(obj)
    safe(function()
        obj.RenderFidelity = Enum.RenderFidelity.Performance
        obj.CastShadow = false
        obj.Reflectance = 0
        obj.MaterialVariant = ""
        if obj.Material ~= Enum.Material.Neon and obj.Material ~= Enum.Material.ForceField then
            obj.Material = Enum.Material.SmoothPlastic
        end
    end)
end

local function h_SpecialMesh(obj)
    safe(function() obj.TextureId = "" end)
end

local function h_BasePart(obj)
    safe(function()
        obj.CastShadow = false
        obj.Reflectance = 0
        obj.MaterialVariant = ""
        if obj.Material ~= Enum.Material.Neon and obj.Material ~= Enum.Material.ForceField then
            obj.Material = Enum.Material.SmoothPlastic
        end
    end)
end

--============================================================
-- DISPATCH TABLE (ClassName -> handler), O(1) вместо цепочки IsA
--============================================================
local classHandlers = {
    Animator = h_Animator,
    AnimationController = h_AnimationController,
    Animation = h_Animation,

    SurfaceAppearance = h_SurfaceAppearance,
    Decal = h_DecalTexture,
    Texture = h_DecalTexture,

    ParticleEmitter = h_EffectDisable,
    Smoke = h_EffectDisable,
    Fire = h_EffectDisable,
    Sparkles = h_EffectDisable,
    Trail = h_EffectDisable,
    Beam = h_EffectDisable,

    PointLight = h_Light,
    SpotLight = h_Light,
    SurfaceLight = h_Light,

    VideoFrame = h_Video,

    MeshPart = h_MeshPart,
    SpecialMesh = h_SpecialMesh,

    -- частые наследники BasePart без лишнего IsA-фоллбэка
    Part = h_BasePart,
    WedgePart = h_BasePart,
    CornerWedgePart = h_BasePart,
    TrussPart = h_BasePart,
    UnionOperation = h_BasePart,
    NegateOperation = h_BasePart,
    Seat = h_BasePart,
    VehicleSeat = h_BasePart,
    SpawnLocation = h_BasePart,
}

--============================================================
-- QUEUEING: фильтрация нерелевантных объектов ДО очереди
--============================================================
local function tryQueue(obj)
    if not obj or not obj.Parent then
        return
    end
    if queued[obj] or optimized[obj] then
        return
    end

    local handler = classHandlers[obj.ClassName]
    if not handler then
        -- единственный fallback IsA-вызов, только для редких/экзотических
        -- наследников BasePart, которых нет в таблице выше
        if obj:IsA("BasePart") then
            handler = h_BasePart
        else
            return -- Script/Value/Weld/Attachment/Sound и т.п. — не трогаем
        end
    end

    queued[obj] = true
    queueLen += 1
    queueObjs[queueLen] = obj
    queueHandlers[queueLen] = handler
end

--============================================================
-- CHARACTER FAST-PATH (без GetDescendants!)
--============================================================
local function cleanCharacter(character)
    if not character or not character.Parent then
        return
    end

    local children = character:GetChildren()
    for i = 1, #children do
        local child = children[i]
        local cn = child.ClassName
        if cn == "Accessory" or cn == "Shirt" or cn == "Pants" or cn == "ShirtGraphic" then
            safe(function() child:Destroy() end)
        end
    end

    local animate = character:FindFirstChild("Animate")
    if animate then
        safe(function() animate:Destroy() end)
    end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        local animator = humanoid:FindFirstChildOfClass("Animator")
        if animator then
            h_Animator(animator)
        end
        local animController = humanoid:FindFirstChildOfClass("AnimationController")
        if animController then
            h_AnimationController(animController)
        end
    end
    -- Trail/Beam/ParticleEmitter внутри Accessory уже уничтожены вместе
    -- с самим Accessory выше — отдельный обход дерева не нужен.
end

--============================================================
-- LIGHTING / MATERIALSERVICE / TERRAIN (разово при старте)
--============================================================
local function cleanLighting()
    safe(function()
        local settingsObject = UserSettings():GetService("UserGameSettings")
        settingsObject.GraphicsQualityLevel = 1
    end)

    safe(function()
        settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
    end)

    safe(function() Lighting.GlobalShadows = false end)
    safe(function() Lighting.EnvironmentDiffuseScale = 0 end)
    safe(function() Lighting.EnvironmentSpecularScale = 0 end)
    safe(function() Lighting.ShadowSoftness = 0 end)
    safe(function() Lighting.Technology = Enum.Technology.Compatibility end)

    local children = Lighting:GetChildren()
    for i = 1, #children do
        local obj = children[i]
        if obj:IsA("PostEffect") then
            safe(function() obj.Enabled = false end)
        end
    end

    safe(function()
        Lighting:GetPropertyChangedSignal("GlobalShadows"):Connect(function()
            if Lighting.GlobalShadows then
                Lighting.GlobalShadows = false
            end
        end)
    end)
end

local function cleanMaterialService()
    local children = MaterialService:GetChildren()
    for i = 1, #children do
        local obj = children[i]
        if obj:IsA("MaterialVariant") or obj:IsA("TerrainDetail") then
            safe(function() obj:Destroy() end)
        end
    end
end

local function cleanTerrain()
    local terrain = Workspace:FindFirstChildOfClass("Terrain")
    if not terrain then
        return
    end
    safe(function() terrain.WaterWaveSize = 0 end)
    safe(function() terrain.WaterWaveSpeed = 0 end)
    safe(function() terrain.WaterReflectance = 0 end)
    safe(function() terrain.WaterTransparency = 1 end)
end

--============================================================
-- GUI
--============================================================
local function createGui()
    if not LocalPlayer then
        return
    end

    local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if not playerGui or playerGui:FindFirstChild("Arcizz0Booster") then
        return
    end

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "Arcizz0Booster"
    screenGui.ResetOnSpawn = false
    screenGui.IgnoreGuiInset = true
    screenGui.DisplayOrder = 999999
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = playerGui

    local frame = Instance.new("Frame")
    frame.Name = "BoosterFrame"
    frame.AnchorPoint = Vector2.new(0.5, 0)
    frame.Position = UDim2.new(0.5, 0, 0, -88)
    frame.Size = UDim2.new(0, 390, 0, 70)
    frame.BackgroundColor3 = Color3.fromRGB(12, 2, 2)
    frame.BorderSizePixel = 0
    frame.Parent = screenGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 13)
    corner.Parent = frame

    local stroke = Instance.new("UIStroke")
    stroke.Thickness = 2
    stroke.Transparency = 0.15
    stroke.Color = Color3.fromRGB(125, 0, 0)
    stroke.Parent = frame

    local line = Instance.new("Frame")
    line.Size = UDim2.new(1, 0, 0, 3)
    line.BackgroundColor3 = Color3.fromRGB(180, 0, 0)
    line.BorderSizePixel = 0
    line.Parent = frame

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -30, 1, -10)
    title.Position = UDim2.new(0.5, 0, 0.5, 0)
    title.AnchorPoint = Vector2.new(0.5, 0.5)
    title.BackgroundTransparency = 1
    title.Text = "Arcizz0 Booster"
    title.Font = Enum.Font.GothamBold
    title.TextSize = 27
    title.TextColor3 = Color3.fromRGB(255, 0, 0)
    title.Parent = frame

    local gradient = Instance.new("UIGradient")
    gradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(70, 0, 0)),
        ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 25, 25)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(100, 0, 0)),
        ColorSequenceKeypoint.new(0.75, Color3.fromRGB(255, 0, 0)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(65, 0, 0)),
    })
    gradient.Offset = Vector2.new(-1, 0)
    gradient.Parent = title

    TweenService:Create(frame, TweenInfo.new(0.55, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
        Position = UDim2.new(0.5, 0, 0, 18)
    }):Play()

    task.spawn(function()
        for _ = 1, 3 do
            if not screenGui.Parent then break end
            local a = TweenService:Create(gradient, TweenInfo.new(0.75, Enum.EasingStyle.Linear), {
                Offset = Vector2.new(1, 0)
            })
            a:Play()
            a.Completed:Wait()
            if not screenGui.Parent then break end

            local b = TweenService:Create(gradient, TweenInfo.new(0.75, Enum.EasingStyle.Linear), {
                Offset = Vector2.new(-1, 0)
            })
            b:Play()
            b.Completed:Wait()
        end
    end)

    task.delay(3.0, function()
        if not screenGui.Parent then
            return
        end
        local closeTween = TweenService:Create(frame, TweenInfo.new(0.45, Enum.EasingStyle.Quint, Enum.EasingDirection.In), {
            Position = UDim2.new(0.5, 0, 0, -88)
        })
        closeTween:Play()
        closeTween.Completed:Connect(function()
            if screenGui.Parent then
                screenGui:Destroy()
            end
        end)
    end)
end

--============================================================
-- STARTUP
--============================================================
cleanLighting()
cleanMaterialService()
cleanTerrain()
task.defer(createGui)

local function scanInitialWorld()
    if not game:IsLoaded() then
        game.Loaded:Wait()
    end

    local objects = Workspace:GetDescendants()
    for i = 1, #objects do
        tryQueue(objects[i])
    end

    for _, player in ipairs(Players:GetPlayers()) do
        if player.Character then
            task.defer(cleanCharacter, player.Character)
        end
    end
end

task.spawn(scanInitialWorld)

--============================================================
-- LIVE STREAMING / SPAWN HANDLER
--============================================================
Workspace.DescendantAdded:Connect(function(obj)
    -- fast-path: персонаж обрабатывается напрямую, минуя очередь
    if obj.ClassName == "Humanoid" then
        local character = obj.Parent
        if character then
            task.defer(cleanCharacter, character)
        end
        return
    end

    tryQueue(obj)
end)

local function setupPlayer(player)
    if player.Character then
        task.defer(cleanCharacter, player.Character)
    end

    player.CharacterAdded:Connect(function(character)
        task.defer(cleanCharacter, character)
    end)
end

for _, player in ipairs(Players:GetPlayers()) do
    setupPlayer(player)
end

Players.PlayerAdded:Connect(setupPlayer)

--============================================================
-- HEARTBEAT WORKER (adaptive batching)
--============================================================
RunService.Heartbeat:Connect(function()
    local remaining = queueLen - queueHead + 1

    if remaining <= 0 then
        if queueHead > GC_THRESHOLD then
            table.clear(queueObjs)
            table.clear(queueHandlers)
            queueHead = 1
            queueLen = 0
        end
        return
    end

    local budget, maxPerFrame
    if remaining >= BURST_QUEUE then
        budget, maxPerFrame = BURST_BUDGET, BURST_MAX
    elseif remaining <= SMALL_QUEUE then
        budget, maxPerFrame = MICRO_BUDGET, MICRO_MAX
    else
        budget, maxPerFrame = NORMAL_BUDGET, NORMAL_MAX
    end

    local start = os.clock()
    local processed = 0

    while queueHead <= queueLen and processed < maxPerFrame do
        local obj = queueObjs[queueHead]
        local handler = queueHandlers[queueHead]
        queueObjs[queueHead] = nil
        queueHandlers[queueHead] = nil
        queueHead += 1

        if obj then
            queued[obj] = nil
            if obj.Parent then
                handler(obj)
                optimized[obj] = true
            end
        end

        processed += 1
        if processed % CLOCK_CHECK_EVERY == 0 and (os.clock() - start) >= budget then
            break
        end
    end

    if queueHead > GC_THRESHOLD then
        local newLen = queueLen - queueHead + 1
        local compactedObjs = table.create(newLen)
        local compactedHandlers = table.create(newLen)
        for i = queueHead, queueLen do
            compactedObjs[#compactedObjs + 1] = queueObjs[i]
            compactedHandlers[#compactedHandlers + 1] = queueHandlers[i]
        end
        queueObjs = compactedObjs
        queueHandlers = compactedHandlers
        queueLen = #compactedObjs
        queueHead = 1
    end
end)
