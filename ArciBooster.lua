local Workspace       = game:GetService("Workspace")
local Lighting        = game:GetService("Lighting")
local Players         = game:GetService("Players")
local MaterialService = game:GetService("MaterialService")
local RunService      = game:GetService("RunService")
local UserSettings    = game:GetService("UserSettings")
local TweenService    = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer

local SMALL_QUEUE = 40
local BURST_QUEUE = 250

local MICRO_BUDGET  = 0.0003
local NORMAL_BUDGET = 0.0006
local BURST_BUDGET  = 0.0015

local MICRO_MAX  = 25
local NORMAL_MAX = 60
local BURST_MAX  = 140

local GC_THRESHOLD = 3000
local COMPACT_MAX_REMAINING = 80
local CLOCK_CHECK_EVERY = 10

local SCAN_CHUNK_CHECK = 20
local SCAN_BUDGET = 0.0012

local WARMUP_BUDGET = 0.0012
local WARMUP_MAX = 90
local WARMUP_TIMEOUT = 12

local warmingUp = true

local queueObjs = table.create(2048)
local queueHandlers = table.create(2048)

local queueHead = 1
local queueLen = 0

local queued = setmetatable({}, {__mode = "k"})
local optimized = setmetatable({}, {__mode = "k"})
local cleanedCharacters = setmetatable({}, {__mode = "k"})

local function safe(fn)
	pcall(fn)
end

local function h_Animator(obj)
	safe(function()
		local tracks = obj:GetPlayingAnimationTracks()

		for i = 1, #tracks do
			tracks[i]:Stop(0)
		end
	end)

	safe(function()
		obj:Destroy()
	end)
end

local function h_AnimationController(obj)
	safe(function()
		obj:Destroy()
	end)
end

local function h_Animation(obj)
	safe(function()
		obj.AnimationId = "rbxassetid://0"
	end)
end

local function h_SurfaceAppearance(obj)
	safe(function()
		obj:Destroy()
	end)
end

local function h_DecalTexture(obj)
	safe(function()
		obj:Destroy()
	end)
end

local function h_MeshPart(obj)
	safe(function()
		obj.RenderFidelity = Enum.RenderFidelity.Performance
		obj.CastShadow = false
		obj.Reflectance = 0
		obj.MaterialVariant = ""
		obj.TextureID = ""

		if obj.Material ~= Enum.Material.Neon
			and obj.Material ~= Enum.Material.ForceField then
			obj.Material = Enum.Material.SmoothPlastic
		end
	end)
end

local function h_SpecialMesh(obj)
	safe(function()
		obj.TextureId = ""
	end)
end

local function h_BasePart(obj)
	safe(function()
		obj.CastShadow = false
		obj.Reflectance = 0
		obj.MaterialVariant = ""

		if obj.Material ~= Enum.Material.Neon
			and obj.Material ~= Enum.Material.ForceField then
			obj.Material = Enum.Material.SmoothPlastic
		end
	end)
end

local function h_EffectDisable(obj)
	safe(function()
		obj.Enabled = false
	end)
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

local classHandlers = {
	Animator = h_Animator,
	AnimationController = h_AnimationController,
	Animation = h_Animation,

	SurfaceAppearance = h_SurfaceAppearance,

	Decal = h_DecalTexture,
	Texture = h_DecalTexture,

	MeshPart = h_MeshPart,
	SpecialMesh = h_SpecialMesh,

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

local function tryQueue(obj)
	if not obj or not obj.Parent then
		return
	end

	if queued[obj] or optimized[obj] then
		return
	end

	local handler = classHandlers[obj.ClassName]

	if not handler then
		if obj:IsA("BasePart") then
			handler = h_BasePart
		else
			return
		end
	end

	queued[obj] = true

	queueLen += 1
	queueObjs[queueLen] = obj
	queueHandlers[queueLen] = handler
end

local function cleanCharacter(character)
	if not character or not character.Parent then
		return
	end

	if cleanedCharacters[character] then
		return
	end

	cleanedCharacters[character] = true

	local children = character:GetChildren()

	for i = 1, #children do
		local child = children[i]
		local cn = child.ClassName

		if cn == "Accessory"
			or cn == "Shirt"
			or cn == "Pants"
			or cn == "ShirtGraphic" then

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

	local humanoid = character:FindFirstChildOfClass("Humanoid")

	if humanoid then
		local animator = humanoid:FindFirstChildOfClass("Animator")

		if animator then
			h_Animator(animator)
		end

		local animController =
			humanoid:FindFirstChildOfClass("AnimationController")

		if animController then
			h_AnimationController(animController)
		end

		-- Name/health billboard GUIs are rendered per-character every
		-- frame; with many players/NPCs nearby this is a real, steady
		-- render cost. Turning it off is a genuine FPS gain, not just
		-- "not adding overhead".
		safe(function()
			humanoid.DisplayDistanceType =
				Enum.HumanoidDisplayDistanceType.None

			humanoid.NameDisplayDistance = 0
			humanoid.HealthDisplayDistance = 0
		end)
	end
end

local function cleanLighting()
	safe(function()
		local settingsObject =
			UserSettings():GetService("UserGameSettings")

		settingsObject.GraphicsQualityLevel = 1
	end)

	safe(function()
		settings().Rendering.QualityLevel =
			Enum.QualityLevel.Level01
	end)

	safe(function()
		Lighting.GlobalShadows = false
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
		Lighting.Technology =
			Enum.Technology.Compatibility
	end)

	local children = Lighting:GetChildren()

	for i = 1, #children do
		local obj = children[i]

		if obj:IsA("PostEffect") then
			safe(function()
				obj.Enabled = false
			end)

		elseif obj:IsA("Atmosphere") then
			-- Atmosphere adds a full-screen fog/haze pass every frame
			-- (fill-rate cost). Zeroing it out removes that pass
			-- without deleting the instance (avoids breaking scripts
			-- that reference it).
			safe(function()
				obj.Density = 0
				obj.Haze = 0
				obj.Glare = 0
			end)
		end
	end

	safe(function()
		Lighting.FogEnd = 100000
		Lighting.FogStart = 100000
	end)

	safe(function()
		Lighting:GetPropertyChangedSignal(
			"GlobalShadows"
		):Connect(function()

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

		if obj:IsA("MaterialVariant")
			or obj:IsA("TerrainDetail") then

			safe(function()
				obj:Destroy()
			end)
		end
	end
end

local function cleanTerrain()
	local terrain =
		Workspace:FindFirstChildOfClass("Terrain")

	if not terrain then
		return
	end

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

	-- Terrain grass/rock decoration is extra geometry drawn on top of
	-- the terrain mesh -- disabling it is a straightforward render cost
	-- cut, especially on grassy/foliage-heavy maps.
	safe(function()
		terrain.Decoration = false
	end)
end

local function createGui()
	if not LocalPlayer then
		return
	end

	local playerGui =
		LocalPlayer:FindFirstChildOfClass("PlayerGui")

	if not playerGui
		or playerGui:FindFirstChild("Arcizz0Booster") then
		return
	end

	local screenGui = Instance.new("ScreenGui")

	screenGui.Name = "Arcizz0Booster"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.DisplayOrder = 999999
	screenGui.ZIndexBehavior =
		Enum.ZIndexBehavior.Sibling

	screenGui.Parent = playerGui

	local frame = Instance.new("Frame")

	frame.Name = "BoosterFrame"
	frame.AnchorPoint = Vector2.new(0.5, 0)
	frame.Position =
		UDim2.new(0.5, 0, 0, -88)

	frame.Size =
		UDim2.new(0, 390, 0, 70)

	frame.BackgroundColor3 =
		Color3.fromRGB(12, 2, 2)

	frame.BorderSizePixel = 0
	frame.Parent = screenGui

	local corner = Instance.new("UICorner")

	corner.CornerRadius =
		UDim.new(0, 13)

	corner.Parent = frame

	local stroke = Instance.new("UIStroke")

	stroke.Thickness = 2
	stroke.Transparency = 0.15

	stroke.Color =
		Color3.fromRGB(125, 0, 0)

	stroke.Parent = frame

	local line = Instance.new("Frame")

	line.Size =
		UDim2.new(1, 0, 0, 3)

	line.BackgroundColor3 =
		Color3.fromRGB(180, 0, 0)

	line.BorderSizePixel = 0
	line.Parent = frame

	local title = Instance.new("TextLabel")

	title.Size =
		UDim2.new(1, -30, 1, -10)

	title.Position =
		UDim2.new(0.5, 0, 0.5, 0)

	title.AnchorPoint =
		Vector2.new(0.5, 0.5)

	title.BackgroundTransparency = 1

	title.Text = "Arcizz0 Booster"

	title.Font = Enum.Font.GothamBold

	title.TextSize = 27

	title.TextColor3 =
		Color3.fromRGB(255, 0, 0)

	title.Parent = frame

	local gradient = Instance.new("UIGradient")

	gradient.Color = ColorSequence.new({

		ColorSequenceKeypoint.new(
			0,
			Color3.fromRGB(70, 0, 0)
		),

		ColorSequenceKeypoint.new(
			0.25,
			Color3.fromRGB(255, 25, 25)
		),

		ColorSequenceKeypoint.new(
			0.5,
			Color3.fromRGB(100, 0, 0)
		),

		ColorSequenceKeypoint.new(
			0.75,
			Color3.fromRGB(255, 0, 0)
		),

		ColorSequenceKeypoint.new(
			1,
			Color3.fromRGB(65, 0, 0)
		),
	})

	gradient.Offset =
		Vector2.new(-1, 0)

	gradient.Parent = title

	TweenService:Create(
		frame,
		TweenInfo.new(
			0.55,
			Enum.EasingStyle.Quint,
			Enum.EasingDirection.Out
		),
		{
			Position =
				UDim2.new(0.5, 0, 0, 18)
		}
	):Play()

	task.spawn(function()
		for _ = 1, 3 do
			if not screenGui.Parent then
				break
			end

			local a =
				TweenService:Create(
					gradient,
					TweenInfo.new(
						0.75,
						Enum.EasingStyle.Linear
					),
					{
						Offset =
							Vector2.new(1, 0)
					}
				)

			a:Play()
			a.Completed:Wait()

			if not screenGui.Parent then
				break
			end

			local b =
				TweenService:Create(
					gradient,
					TweenInfo.new(
						0.75,
						Enum.EasingStyle.Linear
					),
					{
						Offset =
							Vector2.new(-1, 0)
					}
				)

			b:Play()
			b.Completed:Wait()
		end
	end)

	task.delay(3, function()
		if not screenGui.Parent then
			return
		end

		local closeTween =
			TweenService:Create(
				frame,
				TweenInfo.new(
					0.45,
					Enum.EasingStyle.Quint,
					Enum.EasingDirection.In
				),
				{
					Position =
						UDim2.new(
							0.5,
							0,
							0,
							-88
						)
				}
			)

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

	local objects =
		Workspace:GetDescendants()

	local total = #objects

	-- Time-budgeted instead of a fixed item count: each slice uses up
	-- to SCAN_BUDGET of real time before yielding, so a frame is never
	-- blocked longer than that -- but unlike a fixed chunk size, it
	-- doesn't yield early (and pay a ~16ms frame-wait) when objects are
	-- cheap to queue, which is what was adding up to the ~0.4s delay.
	local sliceStart = os.clock()

	for i = 1, total do
		tryQueue(objects[i])

		if i % SCAN_CHUNK_CHECK == 0
			and os.clock() - sliceStart >= SCAN_BUDGET then

			task.wait()
			sliceStart = os.clock()
		end
	end

	for _, player in ipairs(
		Players:GetPlayers()
	) do
		if player.Character then
			task.defer(
				cleanCharacter,
				player.Character
			)
		end
	end
end

task.spawn(scanInitialWorld)

-- Safety net: if the queue never drops low enough on its own
-- (e.g. objects keep streaming in), drop out of warm-up anyway
-- after WARMUP_TIMEOUT seconds so the elevated budget doesn't
-- keep running indefinitely during normal gameplay.
task.delay(WARMUP_TIMEOUT, function()
	warmingUp = false
end)

Workspace.DescendantAdded:Connect(function(obj)

	tryQueue(obj)

	if obj.ClassName == "Humanoid" then
		local character = obj.Parent

		if character then
			task.defer(
				cleanCharacter,
				character
			)
		end
	end
end)

local function setupPlayer(player)
	if player.Character then
		task.defer(
			cleanCharacter,
			player.Character
		)
	end

	player.CharacterAdded:Connect(
		function(character)
			task.defer(
				cleanCharacter,
				character
			)
		end
	)
end

for _, player in ipairs(
	Players:GetPlayers()
) do
	setupPlayer(player)
end

Players.PlayerAdded:Connect(setupPlayer)

RunService.Heartbeat:Connect(function()

	local remaining =
		queueLen - queueHead + 1

	if remaining <= 0 then

		if queueHead > GC_THRESHOLD then
			table.clear(queueObjs)
			table.clear(queueHandlers)

			queueHead = 1
			queueLen = 0
		end

		return
	end

	local budget
	local maxPerFrame

	if warmingUp then
		-- Wider budget just for the initial load burst -- 2.5ms is
		-- still a small slice of a 16.6ms (60fps) frame, so it doesn't
		-- read as a freeze, but it clears a big base's queue far
		-- faster than the steady-state budgets below, which are
		-- deliberately conservative so they don't cost FPS mid-game.
		budget = WARMUP_BUDGET
		maxPerFrame = WARMUP_MAX

		if remaining <= SMALL_QUEUE then
			warmingUp = false
		end

	elseif remaining >= BURST_QUEUE then
		budget = BURST_BUDGET
		maxPerFrame = BURST_MAX

	elseif remaining <= SMALL_QUEUE then
		budget = MICRO_BUDGET
		maxPerFrame = MICRO_MAX

	else
		budget = NORMAL_BUDGET
		maxPerFrame = NORMAL_MAX
	end

	local start = os.clock()
	local processed = 0

	while queueHead <= queueLen
		and processed < maxPerFrame do

		local obj =
			queueObjs[queueHead]

		local handler =
			queueHandlers[queueHead]

		queueObjs[queueHead] = nil
		queueHandlers[queueHead] = nil

		queueHead += 1

		if obj then

			queued[obj] = nil

			if obj.Parent and not optimized[obj] then

				handler(obj)

				optimized[obj] = true
			end
		end

		processed += 1

		if processed % CLOCK_CHECK_EVERY == 0
			and os.clock() - start >= budget then
			break
		end
	end

	-- Compaction only runs once the *unprocessed tail* is small
	-- (<= COMPACT_MAX_REMAINING). That caps the cost of table.move
	-- to a small, constant amount of work no matter how big queueHead
	-- has grown, so it can never cause a noticeable pause -- regardless
	-- of GC_THRESHOLD or how large the queue was historically.
	if queueHead > GC_THRESHOLD then

		local newLen =
			queueLen - queueHead + 1

		if newLen <= COMPACT_MAX_REMAINING then

			if newLen > 0 then
				table.move(queueObjs, queueHead, queueLen, 1)
				table.move(queueHandlers, queueHead, queueLen, 1)
			end

			for i = newLen + 1, queueLen do
				queueObjs[i] = nil
				queueHandlers[i] = nil
			end

			queueLen = newLen
			queueHead = 1
		end
		-- else: tail still large, defer compaction to a later frame
		-- when it's naturally shrunk down (cheap), instead of paying
		-- for a big move right now.
	end
end)
