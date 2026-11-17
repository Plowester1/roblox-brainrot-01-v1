-- WorldBuilder.luau
-- Builds the 3D world at runtime from a compact data table: base platforms,
-- pedestals, conveyor belt, walls, decorations, and the brainrot character
-- models (blocky Part assemblies with a face decal + name label).

local WorldBuilder = {}

local BrainrotData = require(script.Parent.BrainrotData)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

WorldBuilder.BrainrotData = BrainrotData

-- World geometry constants shared with Conveyor and Rival.
WorldBuilder.Layout = {
	ArenaSize = Vector3.new(60, 1, 130),
	ConveyorZStart = -42,
	ConveyorZEnd = 42,
	ConveyorX = 0,
	ConveyorWidth = 8,
	ConveyorY = 1,
	PlayerBaseZ = 56,
	RivalBaseZ = -56,
	BasePlatformSize = Vector3.new(26, 3, 14),
	PedestalSlots = {},
}

-- Build the 12 pedestal slot offsets in two rows of 6.
for i = 1, 12 do
	local col = (i - 1) % 6
	local row = math.floor((i - 1) / 6)
	local x = -7.5 + col * 3
	local z = (row == 0) and 2.5 or -2.5
	WorldBuilder.Layout.PedestalSlots[i] = Vector3.new(x, 4.5, z)
end

local function newPart(name, parent, size, color, pos, anchored)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Position = pos
	p.Anchored = anchored
	p.Material = Enum.Material.Plastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function makeTree(parent, pos, scale)
	local trunk = newPart("Trunk", parent, Vector3.new(0.6, 3, 0.6) * scale,
		Color3.fromRGB(94, 64, 42), pos + Vector3.new(0, 1.5 * scale, 0), true)
	trunk.Material = Enum.Material.Wood
	local leaf = newPart("Leaf", parent, Vector3.new(2.6, 2.4, 2.6) * scale,
		Color3.fromRGB(52, 130, 60), pos + Vector3.new(0, 4 * scale, 0), true)
	leaf.Material = Enum.Material.Foliage
	leaf.Shape = Enum.PartType.Ball
end

-- Build the static arena: floor, bases, pedestals, conveyor, walls, props.
function WorldBuilder.BuildWorld()
	local ws = workspace

	newPart("ArenaFloor", ws, WorldBuilder.Layout.ArenaSize,
		Color3.fromRGB(96, 150, 78), Vector3.new(0, 0, 0), true)

	local conv = newPart("ConveyorBelt", ws, Vector3.new(
		WorldBuilder.Layout.ConveyorWidth, 0.8,
		math.abs(WorldBuilder.Layout.ConveyorZEnd - WorldBuilder.Layout.ConveyorZStart) + 12),
		Color3.fromRGB(70, 70, 78),
		Vector3.new(WorldBuilder.Layout.ConveyorX, 1,
			(WorldBuilder.Layout.ConveyorZStart + WorldBuilder.Layout.ConveyorZEnd) / 2), true)
	conv.Material = Enum.Material.Concrete

	for z = WorldBuilder.Layout.ConveyorZStart + 5, WorldBuilder.Layout.ConveyorZEnd - 5, 8 do
		local arrow = newPart("LaneArrow", ws, Vector3.new(2, 0.25, 4),
			Color3.fromRGB(240, 220, 120),
			Vector3.new(0, 1.6, z), true)
		arrow.CanCollide = false
		arrow.Material = Enum.Material.Neon
	end

	local pb = newPart("PlayerBase", ws, WorldBuilder.Layout.BasePlatformSize,
		Color3.fromRGB(84, 130, 200), Vector3.new(0, 1.5, WorldBuilder.Layout.PlayerBaseZ), true)
	local pbRim = newPart("PlayerBaseRim", pb, Vector3.new(
		WorldBuilder.Layout.BasePlatformSize.X + 2, 0.6,
		WorldBuilder.Layout.BasePlatformSize.Z + 2),
		Color3.fromRGB(60, 100, 170), Vector3.new(0, 0.2, 0), false)
	pbRim.Anchored = true
	pbRim.CanCollide = true

	newPart("RivalBase", ws, WorldBuilder.Layout.BasePlatformSize,
		Color3.fromRGB(180, 80, 90), Vector3.new(0, 1.5, WorldBuilder.Layout.RivalBaseZ), true)

	local pedestals = Instance.new("Folder")
	pedestals.Name = "Pedestals"
	pedestals.Parent = ws

	local sides = {
		{ name = "Player", z = WorldBuilder.Layout.PlayerBaseZ },
		{ name = "Rival", z = WorldBuilder.Layout.RivalBaseZ },
	}
	for _, side in ipairs(sides) do
		for slot = 1, 12 do
			local p = newPart(side.name .. "Pedestal" .. slot, pedestals,
				Vector3.new(2.2, 0.4, 2.2), Color3.fromRGB(220, 220, 230),
				WorldBuilder.Layout.PedestalSlots[slot] + Vector3.new(0, 0, side.z), true)
			p.Name = side.name .. "Pedestal" .. slot
		end
	end

	local wallColor = Color3.fromRGB(120, 110, 100)
	newPart("WallNorth", ws, Vector3.new(60, 3, 1), wallColor,
		Vector3.new(0, 1.5, 63), true)
	newPart("WallSouth", ws, Vector3.new(60, 3, 1), wallColor,
		Vector3.new(0, 1.5, -63), true)
	newPart("WallEast", ws, Vector3.new(1, 3, 126), wallColor,
		Vector3.new(30, 1.5, 0), true)
	newPart("WallWest", ws, Vector3.new(1, 3, 126), wallColor,
		Vector3.new(-30, 1.5, 0), true)

	local props = Instance.new("Folder")
	props.Name = "Props"
	props.Parent = ws
	makeTree(props, Vector3.new(-14, 0, 12), 1)
	makeTree(props, Vector3.new(14, 0, -8), 1.2)
	makeTree(props, Vector3.new(-16, 0, -14), 0.9)
	makeTree(props, Vector3.new(15, 0, 6), 1.1)
	newPart("Rock", props, Vector3.new(1.6, 1.2, 1.6), Color3.fromRGB(140, 140, 150),
		Vector3.new(-6, 0.6, -30), true)
	newPart("Rock", props, Vector3.new(2, 1.5, 2), Color3.fromRGB(130, 130, 140),
		Vector3.new(7, 0.75, 30), true)
	newPart("GoalFlag", props, Vector3.new(0.4, 2.4, 0.4), Color3.fromRGB(240, 200, 80),
		Vector3.new(-3, 1.2, WorldBuilder.Layout.PlayerBaseZ - 8), true)

	local lighting = game:GetService("Lighting")
	lighting.ClockTime = 14
	lighting.Brightness = 1.2
	lighting.Ambient = Color3.fromRGB(150, 150, 160)
	lighting.OutdoorAmbient = Color3.fromRGB(200, 200, 210)
	lighting.GlobalShadows = true
	lighting.FogColor = Color3.fromRGB(170, 200, 230)
	lighting.FogEnd = 500
	lighting.FogStart = 250

	return ws
end

-- Build a brainrot character model: a blocky Part assembly with a face decal
-- (a simple emoji-style surface) and a floating name label above it. Returns a
-- Model with the label stored under .Configuration so callers can update it.
function WorldBuilder.BuildBrainrot(entry, mutation)
	local model = Instance.new("Model")
	model.Name = "Brainrot"

	local tier = WorldBuilder.BrainrotData.Tiers[entry.tier]
	local mut = WorldBuilder.BrainrotData.Mutations[mutation or "None"]

	local body = newPart("Body", model, Vector3.new(2, 2.2, 2),
		mut and mut.color or tier.color, Vector3.new(0, 1.1, 0), true)
	body.Shape = Enum.PartType.Block

	local head = newPart("Head", model, Vector3.new(1.6, 1.6, 1.6),
		mut and mut.color or tier.color, Vector3.new(0, 3.2, 0), true)
	head.Material = Enum.Material.SmoothPlastic

	-- Simple face decal: a darker circle on the front.
	local face = Instance.new("SpecialMesh")
	face.MeshType = Enum.MeshType.Sphere
	face.Scale = Vector3.new(0.3, 0.3, 0.05)
	face.Parent = head

	-- Name label: shows name, rarity, $/s (and mutation).
	local label = Instance.new("BillboardGui")
	label.Name = "Label"
	label.Size = UDim2.new(0, 160, 0, 60)
	label.StudsOffsetWorldSpace = Vector3.new(0, 5, 0)
	label.AlwaysOnTop = true

	local text = Instance.new("TextLabel")
	text.Name = "Text"
	text.Size = UDim2.new(1, 0, 1, 0)
	text.BackgroundTransparency = 1
	text.TextScaled = true
	text.Font = Enum.Font.FredokaOne
	text.TextColor3 = Color3.fromRGB(255, 255, 255)
	text.TextStrokeTransparency = 0.3
	text.Parent = label

	local cfg = Instance.new("Configuration")
	cfg.Name = "LabelData"
	cfg.Parent = label

	label.Parent = model

	-- Store entry metadata on the model via attributes (works for a single
	-- brainrot model instance and is readable by Rival/Conveyor).
	model:SetAttribute("Name", entry.name)
	model:SetAttribute("Tier", entry.tier)
	model:SetAttribute("Mutation", mutation or "None")
	model:SetAttribute("BaseMoney", entry.baseMoney)

	WorldBuilder.UpdateLabel(model, entry, mutation)

	return model
end

-- Update a brainrot's floating label text.
function WorldBuilder.UpdateLabel(model, entry, mutation)
	local label = model:FindFirstChild("Label")
	if not label then
		return
	end
	local text = label:FindFirstChild("Text")
	if not text then
		return
	end
	local mut = WorldBuilder.BrainrotData.Mutations[mutation or "None"]
	local mult = mut and mut.mult or 1
	local dps = entry.baseMoney * mult
	local mutTag = (mutation and mutation ~= "None") and (" [" .. mutation .. "]") or ""
	text.Text = entry.name .. mutTag .. "\n" .. entry.tier .. "  $" .. tostring(dps) .. "/s"
end

return WorldBuilder