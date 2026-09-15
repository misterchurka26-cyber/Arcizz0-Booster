local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local MaterialService = game:GetService("MaterialService")
local RunService = game:GetService("RunService")
local UserSettings = game:GetService("UserSettings")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer

local MAX_PER_FRAME = 350
local NORMAL_BUDGET = 0.0015
local BURST_BUDGET = 0.0035
local BURST_QUEUE = 120
local GC_THRESHOLD = 2500

local queue = table.create(2048)
local queueHead = 1
local queued = setmetatable({}, { __mode = "k" })

local function safe(fn)
    pcall(fn)
end

local function addToQueue(obj)
    if not obj or queued[obj] or not obj.Parent then
        return
    end
    queued[obj] = true
    queue[#queue + 1] = obj
end

local function optimizeAnimationObject(obj)
    if obj:IsA("Animator") then
        safe(function()
            local tracks = obj:GetPlayingAnimationTracks()
            for i = 1, #tracks do
                tracks[i]:Stop(0)
            end
        end)
        safe(function() obj:Destroy() end)
        return true
    end

    if obj:IsA("AnimationController") then
        safe(function() obj:Destroy() end)
        return true
    end

    if obj:IsA("Animation") then
        safe(function() obj.AnimationId = "rbxassetid://0" end)
        return true
    end

    return false
end

local function optimizeObject(obj)
    if not obj or not obj.Parent then
        return
    end

    if optimizeAnimationObject(obj) then
        return
    end

    if obj:IsA("SurfaceAppearance") then
        safe(function() obj:Destroy() end)
        return
    end

    if obj:IsA("Decal") or obj:IsA("Texture") then
        safe(function() obj:Destroy() end)
        return
    end

    if obj:IsA("ParticleEmitter")
        or obj:IsA("Smoke")
        or obj:IsA("Fire")
        or obj:IsA("Sparkles")
        or obj:IsA("Trail")
        or obj:IsA("Beam") then
        safe(function() obj.Enabled = false end)
        return
    end

    if obj:IsA("PointLight")
        or obj:IsA("SpotLight")
        or obj:IsA("SurfaceLight") then
        safe(function()
            obj.Shadows = false
            obj.Enabled = false
        end)
        return
    end

    if obj:IsA("VideoFrame") then
        safe(function()
            obj.Playing = false
            obj.Visible = false
        end)
        return
    end

    if obj:IsA("MeshPart") then
        safe(function()
            obj.RenderFidelity = Enum.RenderFidelity.Performance
            obj.CastShadow = false
            obj.Reflectance = 0
            obj.MaterialVariant = ""
            if obj.Material ~= Enum.Material.Neon then
                obj.Material = Enum.Material.SmoothPlastic
            end
        end)
        return
    end

    if obj:IsA("SpecialMesh") then
        safe(function() obj.TextureId = "" end)
        return
    end

    if obj:IsA("BasePart") then
        safe(function()
            obj.CastShadow = false
            obj.Reflectance = 0
            obj.MaterialVariant = ""
            if obj.Material ~= Enum.Material.Neon then
                obj.Material = Enum.Material.SmoothPlastic
            end
        end)
        return
    end
end

local function cleanCharacter(character)
    if not character or not character.Parent then
        return
    end

    for _, child in ipairs(character:GetChildren()) do
        if child:IsA("Accessory")
            or child:IsA("Shirt")
            or child:IsA("Pants")
            or child:IsA("ShirtGraphic") then
            safe(function() child:Destroy() end)
        end
    end

    local animate = character:FindFirstChild("Animate")
    if animate then
        safe(function() animate:Destroy() end)
    end

    local descendants = character:GetDescendants()
    for i = 1, #descendants do
        local obj = descendants[i]
        if obj:IsA("Animator")
            or obj:IsA("AnimationController")
            or obj:IsA("Animation")
            or obj:IsA("ParticleEmitter")
            or obj:IsA("Trail")
            or obj:IsA("Beam") then
            optimizeObject(obj)
        end
    end
end

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
    safe(function() Lighting.Brightness = 1 end)
    safe(function() Lighting.Technology = Enum.Technology.Compatibility end)

    for _, obj in ipairs(Lighting:GetChildren()) do
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
    for _, obj in ipairs(MaterialService:GetChildren()) do
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
            local a = TweenService:Create(gradient, TweenInfo.new(0.75, Enum.EasingStyle.Linear), {
                Offset = Vector2.new(1, 0)
            })
            a:Play()
            a.Completed:Wait()

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
        addToQueue(objects[i])
    end

    for _, player in ipairs(Players:GetPlayers()) do
        if player.Character then
            task.defer(cleanCharacter, player.Character)
        end
    end
end

task.spawn(scanInitialWorld)

Workspace.DescendantAdded:Connect(function(obj)
    addToQueue(obj)

    if obj:IsA("Model") then
        local humanoid = obj:FindFirstChildOfClass("Humanoid")
        if humanoid then
            task.defer(cleanCharacter, obj)
        end
    elseif obj:IsA("Humanoid") then
        local character = obj.Parent
        if character then
            task.defer(cleanCharacter, character)
        end
    end
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

RunService.Heartbeat:Connect(function()
    local remaining = #queue - queueHead + 1
    if remaining <= 0 then
        if queueHead > GC_THRESHOLD then
            table.clear(queue)
            queueHead = 1
        end
        return
    end

    local start = os.clock()
    local budget = remaining >= BURST_QUEUE and BURST_BUDGET or NORMAL_BUDGET
    local processed = 0

    while queueHead <= #queue and processed < MAX_PER_FRAME do
        local obj = queue[queueHead]
        queue[queueHead] = nil
        queueHead += 1
        queued[obj] = nil

        if obj and obj.Parent then
            optimizeObject(obj)
        end

        processed += 1
        if os.clock() - start >= budget then
            break
        end
    end

    if queueHead > GC_THRESHOLD then
        local compacted = table.create(#queue - queueHead + 1)
        for i = queueHead, #queue do
            compacted[#compacted + 1] = queue[i]
        end
        queue = compacted
        queueHead = 1
    end
end)
