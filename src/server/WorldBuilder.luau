local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")

local WorldBuilder = {}

-- World layout constants shared across server modules.
WorldBuilder.CONVEYOR = {
	startX = -8,
	endX = 8,
	z = 0,
	y = 3,
	width = 3,
	lane = "z",
}

WorldBuilder.PLAYER_BASE = {
	center = Vector3.new(-16, 0, 0),
	facing = Vector3.new(-1, 0, 0),
}
WorldBuilder.RIVAL_BASE = {
	center = Vector3.new(16, 0, 0),
	facing = Vector3.new(1, 0, 0),
}

-- Pedestal spots on a base. Layout: 3 rows x 4 columns on the base floor (y=1.2).
local PEDESTAL_ROWS = 3
local PEDESTAL_COLS = 4
local PEDESTAL_DX = 1.9
local PEDESTAL_DZ = 1.9
local PEDESTAL_ORIGIN_DX = -2.8
local PEDESTAL_ORIGIN_DZ = -1.9
local PEDESTAL_Y = 1.2

local FACE_DECAL = "rbxassetid://10611106203"

function WorldBuilder.setupLighting()
	Lighting.ClockTime = 14
	Lighting.Ambient = Color3.fromRGB(210, 210, 220)
	Lighting.OutdoorAmbient = Color3.fromRGB(190, 190, 200)
	Lighting.Brightness = 1.4
	Lighting.GlobalShadows = true
	Lighting.FogEnd = 300
	Lighting.FogColor = Color3.fromRGB(140, 210, 255)
end

-- Build one raised platform (the bases and the conveyor are all platforms).
local function buildPlatform(name, pos, size, color, parent)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Position = pos
	part.Anchored = true
	part.Locked = true
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent or workspace
	return part
end

local function buildPillar(name, pos, size, color, parent)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Position = pos
	part.Anchored = true
	part.Locked = true
	part.Color = color
	part.Material = Enum.Material.Brick
	part.Parent = parent or workspace
	return part
end

-- Build a pedestal the player/brainrot stands on. Returns the top anchor part.
function WorldBuilder.buildPedestal(parent, position, color)
	local pillar = buildPillar("PedestalPillar", position - Vector3.new(0, 0.9, 0), Vector3.new(1.6, 1.8, 1.6), color, parent)
	local top = buildPlatform("PedestalTop", position, Vector3.new(1.8, 0.3, 1.8), color, parent)
	local glow = Instance.new("PointLight")
	glow.Color = color
	glow.Brightness = 1
	glow.Range = 6
	glow.Parent = top
	return top
end

-- Build a base: a raised platform ringed by pillars with pedestal slots on top.
-- Returns { model, pedestals = { [slot] = topPart } }.
function WorldBuilder.buildBase(name, baseInfo, pedestalCount, baseColor)
	local container = Instance.new("Model")
	container.Name = name
	container.Parent = workspace

	local center = baseInfo.center
	local platform = buildPlatform(name .. "Floor", center + Vector3.new(0, 0.6, 0), Vector3.new(14, 1.2, 12), Color3.fromRGB(140, 90, 60), container)
	-- top surface at y=1.2

	local border = Color3.fromRGB(70, 45, 25)
	for i = -7, 7, 2 do
		buildPillar(name .. "Wall", center + Vector3.new(i, 0.9, -6), Vector3.new(2, 1.8, 1), border, container)
		buildPillar(name .. "Wall", center + Vector3.new(i, 0.9, 6), Vector3.new(2, 1.8, 1), border, container)
	end
	for i = -5, 5, 2 do
		buildPillar(name .. "Wall", center + Vector3.new(-7, 0.9, i), Vector3.new(1, 1.8, 2), border, container)
		buildPillar(name .. "Wall", center + Vector3.new(7, 0.9, i), Vector3.new(1, 1.8, 2), border, container)
	end

	-- a bright flag pole at the back of the base
	local pole = buildPillar(name .. "Flag", center + Vector3.new(-6, 4.5, 0), Vector3.new(0.4, 8, 0.4), Color3.fromRGB(90, 90, 90), container)
	local flag = buildPlatform(name .. "FlagCloth", center + Vector3.new(-4.6, 4.4, 0), Vector3.new(3, 1.6, 0.2), baseColor or Color3.fromRGB(200, 60, 60), container)

	-- pedestals: 4 columns across the base floor, slots added as player upgrades.
	local pedestals = {}
	for slot = 1, pedestalCount do
		local slotPos = WorldBuilder.pedestalPosition(baseInfo, slot)
		pedestals[slot] = WorldBuilder.buildPedestal(container, slotPos, baseColor or Color3.fromRGB(220, 220, 60))
	end

	return { model = container, pedestals = pedestals }
end

-- Compute the world position of pedestal slot N on a base.
function WorldBuilder.pedestalPosition(baseInfo, slot)
	local col = ((slot - 1) % 4) + 1
	local row = math.floor((slot - 1) / 4)
	local colOff = (col - 2) * 2.4
	local rowOff = (row - 1) * 2.2
	local baseCenter = baseInfo.center
	return Vector3.new(baseCenter.x + (colOff + 1.0), 1.2, baseCenter.z + rowOff)
end

-- Build the conveyor belt lane.
function WorldBuilder.buildConveyor()
	local belt = Instance.new("Model")
	belt.Name = "Conveyor"
	belt.Parent = workspace

	local c = WorldBuilder.CONVEYOR
	local bed = buildPlatform("BeltBed", Vector3.new((c.startX + c.endX) / 2, c.y - 0.4, c.z), Vector3.new(c.endX - c.startX + 2, 0.8, c.width + 0.5), Color3.fromRGB(80, 80, 85), belt)

	-- moving stripes
	for i = c.startX, c.endX, 2 do
		local stripe = buildPlatform("BeltStripe", Vector3.new(i, c.y - 0.15, c.z), Vector3.new(1.2, 0.3, c.width), Color3.fromRGB(60, 60, 65), belt)
	end

	-- side rails
	buildPillar("RailN", Vector3.new((c.startX + c.endX) / 2, c.y + 0.2, c.z - (c.width / 2 + 0.3)), Vector3.new(c.endX - c.startX + 2, 0.6, 0.4), Color3.fromRGB(120, 120, 130), belt)
	buildPillar("RailS", Vector3.new((c.startX + c.endX) / 2, c.y + 0.2, c.z + (c.width / 2 + 0.3)), Vector3.new(c.endX - c.startX + 2, 0.6, 0.4), Color3.fromRGB(120, 120, 130), belt)

	return belt
end

-- A decorative tree.
function WorldBuilder.buildTree(pos)
	local model = Instance.new("Model")
	model.Name = "Tree"
	model.Parent = workspace
	local trunk = buildPillar("Trunk", pos + Vector3.new(0, 2, 0), Vector3.new(0.6, 4, 0.6), Color3.fromRGB(110, 75, 40), model)
	local foliage = buildPlatform("Foliage", pos + Vector3.new(0, 5, 0), Vector3.new(2.6, 2.6, 2.6), Color3.fromRGB(60, 160, 70), model)
	foliage.Material = Enum.Material.Grass
	return model
end

-- A rock prop.
function WorldBuilder.buildRock(pos, size)
	local model = Instance.new("Model")
	model.Name = "Rock"
	model.Parent = workspace
	local rock = buildPlatform("RockPart", pos + Vector3.new(0, size / 2, 0), Vector3.new(size, size * 0.7, size), Color3.fromRGB(120, 115, 105), model)
	rock.Material = Enum.Material.Slate
	return model
end

-- Build a blocky brainrot character. spec: { name, rarity, color, size, mutation }.
-- Returns { model, body, head, label }. The label floats above the head showing name, rarity, $/s.
function WorldBuilder.buildBrainrotModel(spec)
	local model = Instance.new("Model")
	model.Name = spec.name
	model.Parent = workspace

	local size = spec.size or 1
	local bodyColor = spec.color
	if spec.mutation and spec.mutation ~= "None" then
		bodyColor = spec.mutationColor or spec.color
	end

	local body = buildPlatform("Body", Vector3.new(0, 1.0 * size, 0), Vector3.new(1.0 * size, 1.0 * size, 0.8 * size), bodyColor, model)
	body.Anchored = true

	local head = buildPlatform("Head", Vector3.new(0, 1.9 * size, 0), Vector3.new(0.8 * size, 0.8 * size, 0.8 * size), bodyColor, model)
	head.Anchored = true

	local face = Instance.new("Decal")
	face.Texture = FACE_DECAL
	face.Face = Enum.NormalId.Front
	face.Parent = head

	local eye1 = buildPlatform("Eye", head.Position + Vector3.new(-0.18 * size, 0.08 * size, -0.41 * size), Vector3.new(0.16 * size, 0.16 * size, 0.05 * size), Color3.fromRGB(255, 255, 255), model)
	eye1.Anchored = true
	local eye2 = buildPlatform("Eye", head.Position + Vector3.new(0.18 * size, 0.08 * size, -0.41 * size), Vector3.new(0.16 * size, 0.16 * size, 0.05 * size), Color3.fromRGB(255, 255, 255), model)
	eye2.Anchored = true

	-- floating name / rarity / $/s label
	local label = Instance.new("BillboardGui")
	label.Name = "Label"
	label.Size = UDim2.new(6, 0, 0, 0)
	label.SizeOffset = Vector2.new(0, 96)
	label.StudsOffsetWorldSpace = Vector3.new(0, 1.5 * size, 0)
	label.AlwaysOnTop = true
	label.MaxDistance = 120
	label.Parent = model

	local topFrame = Instance.new("Frame")
	topFrame.BackgroundTransparency = 0.3
	topFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	topFrame.Size = UDim2.new(1, 0, 0, 44)
	topFrame.AutomaticSize = Enum.AutomaticSize.Y
	topFrame.Parent = label

	local nameText = Instance.new("TextLabel")
	nameText.Size = UDim2.new(1, 0, 0, 22)
	nameText.BackgroundTransparency = 1
	nameText.Font = Enum.Font.GothamBold
	nameText.TextScaled = true
	nameText.Text = spec.name
	nameText.TextColor3 = spec.rarityColor or Color3.fromRGB(255, 255, 255)
	nameText.Parent = topFrame

	local infoText = Instance.new("TextLabel")
	infoText.Size = UDim2.new(1, 0, 0, 20)
	infoText.BackgroundTransparency = 1
	infoText.Font = Enum.Font.GothamBold
	infoText.TextScaled = true
	infoText.Text = (spec.rarity or "") .. " - $" .. tostring(math.floor(spec.income or 0)) .. "/s"
	infoText.TextColor3 = Color3.fromRGB(120, 255, 160)
	infoText.Parent = topFrame

	return { model = model, body = body, head = head, label = label }
end

-- Build the whole arena floor + decorations, and return spawn point.
function WorldBuilder.buildArena()
	buildPlatform("Ground", Vector3.new(0, -0.6, 0), Vector3.new(60, 1.2, 40), Color3.fromRGB(90, 170, 80), workspace)
	for _, pos in ipairs({
		Vector3.new(-30, 0, -14), Vector3.new(30, 0, 14), Vector3.new(-26, 0, 14),
		Vector3.new(26, 0, -14), Vector3.new(0, 0, -17), Vector3.new(4, 0, 16),
	}) do
		WorldBuilder.buildTree(pos)
	end
	for _, pos in ipairs({ Vector3.new(-12, 0, -16), Vector3.new(12, 0, 16), Vector3.new(-6, 0, 15) }) do
		WorldBuilder.buildRock(pos, 1.4)
	end
	return Vector3.new(-16, 5, 0) -- player spawn above their base
end

return WorldBuilder