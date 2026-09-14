```lua
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local MaterialService = game:GetService("MaterialService")
local RunService = game:GetService("RunService")
local UserSettings = game:GetService("UserSettings")
local TweenService = game:GetService("TweenService")

local function CreateBoosterGui()
	local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if not playerGui then
		return
	end

	if playerGui:FindFirstChild("Arcizz0Booster") then
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
	frame.Position = UDim2.new(0.5, 0, 0, -95)
	frame.Size = UDim2.new(0, 390, 0, 70)
	frame.BackgroundColor3 = Color3.fromRGB(12, 2, 2)
	frame.BorderSizePixel = 0
	frame.ZIndex = 10
	frame.Parent = screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 13)
	corner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Transparency = 0.15
	stroke.Color = Color3.fromRGB(125, 0, 0)
	stroke.Parent = frame

	local topLine = Instance.new("Frame")
	topLine.Name = "TopLine"
	topLine.Position = UDim2.new(0, 0, 0, 0)
	topLine.Size = UDim2.new(1, 0, 0, 3)
	topLine.BackgroundColor3 = Color3.fromRGB(180, 0, 0)
	topLine.BorderSizePixel = 0
	topLine.ZIndex = 11
	topLine.Parent = frame

	local topCorner = Instance.new("UICorner")
	topCorner.CornerRadius = UDim.new(0, 3)
	topCorner.Parent = topLine

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.AnchorPoint = Vector2.new(0.5, 0.5)
	title.Position = UDim2.new(0.5, 0, 0.5, 0)
	title.Size = UDim2.new(1, -30, 1, -10)
	title.BackgroundTransparency = 1
	title.Text = "Arcizz0 Booster"
	title.Font = Enum.Font.GothamBold
	title.TextSize = 27
	title.TextXAlignment = Enum.TextXAlignment.Center
	title.TextYAlignment = Enum.TextYAlignment.Center
	title.TextColor3 = Color3.fromRGB(255, 0, 0)
	title.ZIndex = 12
	title.Parent = frame

	local gradient = Instance.new("UIGradient")
	gradient.Name = "RedGradient"
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(70, 0, 0)),
		ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 25, 25)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(100, 0, 0)),
		ColorSequenceKeypoint.new(0.75, Color3.fromRGB(255, 0, 0)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(65, 0, 0)),
	})
	gradient.Offset = Vector2.new(-1, 0)
	gradient.Parent = title

	local openTween = TweenService:Create(
		frame,
		TweenInfo.new(
			0.65,
			Enum.EasingStyle.Quint,
			Enum.EasingDirection.Out
		),
		{
			Position = UDim2.new(0.5, 0, 0, 18)
		}
	)

	local shine1 = TweenService:Create(
		gradient,
		TweenInfo.new(
			0.8,
			Enum.EasingStyle.Linear,
			Enum.EasingDirection.InOut
		),
		{
			Offset = Vector2.new(1, 0)
		}
	)

	local shine2 = TweenService:Create(
		gradient,
		TweenInfo.new(
			0.8,
			Enum.EasingStyle.Linear,
			Enum.EasingDirection.InOut
		),
		{
			Offset = Vector2.new(-1, 0)
		}
	)

	local shine3 = TweenService:Create(
		gradient,
		TweenInfo.new(
			0.8,
			Enum.EasingStyle.Linear,
			Enum.EasingDirection.InOut
		),
		{
			Offset = Vector2.new(1, 0)
		}
	)

	local closeTween = TweenService:Create(
		frame,
		TweenInfo.new(
			0.5,
			Enum.EasingStyle.Quint,
			Enum.EasingDirection.In
		),
		{
			Position = UDim2.new(0.5, 0, 0, -95)
		}
	)

	openTween:Play()
	shine1:Play()

	shine1.Completed:Connect(function()
		shine2:Play()
	end)

	shine2.Completed:Connect(function()
		shine3:Play()
	end)

	task.delay(3, function()
		if not screenGui.Parent then
			return
		end

		shine1:Cancel()
		shine2:Cancel()
		shine3:Cancel()

		closeTween:Play()

		closeTween.Completed:Connect(function()
			if screenGui then
				screenGui:Destroy()
			end
		end)
	end)
end

task.defer(CreateBoosterGui)

local FRAME_BUDGET_SECONDS = 0.0015
local MAX_PER_FRAME_HARD_CAP = 200

local function safe(fn)
	pcall(fn)
end

safe(function()
	local settingsObject =
		UserSettings():GetService("UserGameSettings")

	settingsObject.GraphicsQualityLevel = 1
end)

safe(function()
	settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
end)

safe(function()
	Lighting.GlobalShadows = false

	Lighting:GetPropertyChangedSignal("GlobalShadows"):Connect(function()
		if Lighting.GlobalShadows then
			Lighting.GlobalShadows = false
		end
	end)
end)

safe(function()
	Lighting.EnvironmentDiffuseScale = 0
end)

safe(function()
	Lighting.EnvironmentSpecularScale = 0
end)

safe(function()
	Lighting.ShadowSoftness = 0
end)

safe(function()
	Lighting.Brightness = 1
end)

safe(function()
	Lighting.Technology = Enum.Technology.Compatibility
end)

for _, obj in ipairs(Lighting:GetChildren()) do
	if obj:IsA("PostEffect") then
		safe(function()
			obj.Enabled = false
		end)
	end
end

for _, obj in ipairs(MaterialService:GetChildren()) do
	if obj:IsA("MaterialVariant") then
		safe(function()
			obj:Destroy()
		end)
	elseif obj:IsA("TerrainDetail") then
		safe(function()
			obj:Destroy()
		end)
	end
end

local terrain = Workspace:FindFirstChildOfClass("Terrain")

if terrain then
	safe(function()
		terrain.WaterWaveSize = 0
	end)

	safe(function()
		terrain.WaterWaveSpeed = 0
	end)

	safe(function()
		terrain.WaterReflectance = 0
	end)

	safe(function()
		terrain.WaterTransparency = 1
	end)
end

local function disableAnimationObject(obj)
	if obj:IsA("AnimationController") then
		safe(function()
			obj:Destroy()
		end)

		return
	end

	if obj:IsA("Animator") then
		pcall(function()
			for _, track in ipairs(obj:GetPlayingAnimationTracks()) do
				pcall(function()
					track:Stop(0)
				end)
			end

			obj:Destroy()
		end)

		return
	end

	if obj:IsA("Animation") then
		safe(function()
			obj.AnimationId = "rbxassetid://0"
		end)
	end
end

local function cleanupCharacter(character)
	if not character or not character.Parent then
		return
	end

	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Accessory")
			or child:IsA("Shirt")
			or child:IsA("Pants")
			or child:IsA("ShirtGraphic") then

			safe(function()
				child:Destroy()
			end)
		end
	end

	local animate = character:FindFirstChild("Animate")

	if animate then
		safe(function()
			animate:Destroy()
		end)
	end

	for _, obj in ipairs(character:GetDescendants()) do
		if obj:IsA("AnimationController")
			or obj:IsA("Animator")
			or obj:IsA("Animation") then

			disableAnimationObject(obj)
		end
	end
end

local function optimizeObject(obj)
	if not obj or not obj.Parent then
		return
	end

	if obj:IsA("AnimationController")
		or obj:IsA("Animator")
		or obj:IsA("Animation") then

		disableAnimationObject(obj)
		return
	end

	if obj:IsA("SurfaceAppearance") then
		pcall(function()
			obj:Destroy()
		end)

		return
	end

	if obj:IsA("MeshPart") then
		pcall(function()
			obj.TextureID = ""
			obj.MaterialVariant = ""
			obj.RenderFidelity = Enum.RenderFidelity.Performance
			obj.CastShadow = false
			obj.Reflectance = 0

			if obj.Material ~= Enum.Material.Neon then
				obj.Material = Enum.Material.SmoothPlastic
			end
		end)

		return
	end

	if obj:IsA("SpecialMesh") then
		pcall(function()
			obj.TextureId = ""
		end)

		return
	end

	if obj:IsA("BasePart") then
		pcall(function()
			obj.MaterialVariant = ""
			obj.CastShadow = false
			obj.Reflectance = 0

			if obj.Material ~= Enum.Material.Neon then
				obj.Material = Enum.Material.SmoothPlastic
			end
		end)

		return
	end

	if obj:IsA("Decal") then
		pcall(function()
			obj.Transparency = 1
		end)

		return
	end

	if obj:IsA("Texture") then
		pcall(function()
			obj.Transparency = 1
		end)

		return
	end

	if obj:IsA("ParticleEmitter")
		or obj:IsA("Smoke")
		or obj:IsA("Fire")
		or obj:IsA("Sparkles") then

		pcall(function()
			obj.Enabled = false
		end)

		return
	end

	if obj:IsA("Trail") then
		pcall(function()
			obj.Enabled = false
		end)

		return
	end

	if obj:IsA("Beam") then
		pcall(function()
			obj.Enabled = false
		end)

		return
	end

	if obj:IsA("PointLight")
		or obj:IsA("SpotLight")
		or obj:IsA("SurfaceLight") then

		pcall(function()
			obj.Shadows = false
			obj.Enabled = false
		end)

		return
	end

	if obj:IsA("VideoFrame") then
		pcall(function()
			obj.Playing = false
			obj.Visible = false
		end)

		return
	end
end

local pendingQueue = {}
local pendingSet = {}
local queueHead = 1

local function enqueueObject(obj)
	if pendingSet[obj] then
		return
	end

	pendingSet[obj] = true
	pendingQueue[#pendingQueue + 1] = obj
end

RunService.Heartbeat:Connect(function()
	if queueHead > #pendingQueue then
		return
	end

	local startTime = os.clock()
	local processedThisFrame = 0

	while queueHead <= #pendingQueue do
		local obj = pendingQueue[queueHead]
		queueHead += 1

		if obj then
			pendingSet[obj] = nil

			if obj.Parent then
				optimizeObject(obj)
			end
		end

		processedThisFrame += 1

		if processedThisFrame >= MAX_PER_FRAME_HARD_CAP then
			break
		end

		if os.clock() - startTime >= FRAME_BUDGET_SECONDS then
			break
		end
	end

	if queueHead > 2000 then
		local newQueue = table.create(#pendingQueue - queueHead + 1)

		for i = queueHead, #pendingQueue do
			newQueue[#newQueue + 1] = pendingQueue[i]
		end

		pendingQueue = newQueue
		queueHead = 1
	end
end)

task.spawn(function()
	if not game:IsLoaded() then
		game.Loaded:Wait()
	end

	local objects = Workspace:GetDescendants()

	for i = 1, #objects do
		enqueueObject(objects[i])
	end

	for _, obj in ipairs(objects) do
		if obj:IsA("Model") then
			if obj:FindFirstChildOfClass("Humanoid")
				or obj:FindFirstChildOfClass("AnimationController", true)
				or obj:FindFirstChildOfClass("Animator", true) then

				cleanupCharacter(obj)
			end
		end
	end
end)

Workspace.DescendantAdded:Connect(function(obj)
	if not obj then
		return
	end

	if obj:IsA("MeshPart")
		or obj:IsA("SpecialMesh")
		or obj:IsA("SurfaceAppearance")
		or obj:IsA("Decal")
		or obj:IsA("Texture")
		or obj:IsA("MaterialVariant")
		or obj:IsA("ParticleEmitter")
		or obj:IsA("Smoke")
		or obj:IsA("Fire")
		or obj:IsA("Sparkles")
		or obj:IsA("Trail")
		or obj:IsA("Beam")
		or obj:IsA("PointLight")
		or obj:IsA("SpotLight")
		or obj:IsA("SurfaceLight")
		or obj:IsA("AnimationController")
		or obj:IsA("Animator")
		or obj:IsA("Animation")
		or obj:IsA("VideoFrame") then

		enqueueObject(obj)
	end
end)

local function setupPlayer(player)
	if player.Character then
		task.defer(function()
			if player.Character then
				cleanupCharacter(player.Character)
			end
		end)
	end

	player.CharacterAdded:Connect(function(character)
		task.defer(function()
			if character and character.Parent then
				cleanupCharacter(character)
			end
		end)
	end)
end

for _, player in ipairs(Players:GetPlayers()) do
	setupPlayer(player)
end

Players.PlayerAdded:Connect(setupPlayer)
```
