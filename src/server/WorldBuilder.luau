-- WorldBuilder.luau
-- Builds the whole 3D arena at runtime: base platforms, pedestals, the
-- conveyor belt, boundary walls, decorations, and blocky brainrot models.

local WorldBuilder = {}

local arenaFolder, basesFolder, decoFolder, beltFolder, dropsFolder

local function part(name, size, color, position, parent, transparency)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Size = size
	p.Color = color
	p.Position = position
	p.Transparency = transparency or 0
	p.Parent = parent
	return p
end
WorldBuilder.part = part

function WorldBuilder.init()
	arenaFolder = game.Workspace:FindFirstChild("World")
	if not arenaFolder then
		arenaFolder = Instance.new("Folder")
		arenaFolder.Name = "World"
		arenaFolder.Parent = game.Workspace
	end
	local function folder(name)
		local f = arenaFolder:FindFirstChild(name)
		if not f then
			f = Instance.new("Folder")
			f.Name = name
			f.Parent = arenaFolder
		end
		return f
	end
	basesFolder = folder("Bases")
	decoFolder = folder("Decor")
	beltFolder = folder("Conveyor")
	dropsFolder = folder("Drops")
	WorldBuilder.bases = basesFolder
	WorldBuilder.decor = decoFolder
	WorldBuilder.belt = beltFolder
	WorldBuilder.drops = dropsFolder
	return WorldBuilder
end

-- Build a raised base platform with a row of pedestals in front of it.
-- position is the base's anchor point. Returns { model, platform, pedestals }.
local function buildBase(name, position, color)
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = basesFolder

	local platform = part(name .. "Platform", Vector3.new(44, 3, 16), color, position + Vector3.new(0, 1.5, 0), model)

	local pedestals = {}
	local slots = 12
	for i = 1, slots do
		local x = position.X + (i - slots / 2 - 0.5) * 3.2
		local ped = part(name .. "Pedestal_" .. i, Vector3.new(2.6, 5.5, 2.6), Color3.fromRGB(70, 74, 90), Vector3.new(x, position.Y + 1.0, position.Z + 8), model)
		pedestals[i] = ped
	end
	return { model = model, platform = platform, pedestals = pedestals }
end

WorldBuilder.buildBase = buildBase

-- Build the conveyor belt down the middle of the arena. Returns the belt part.
function WorldBuilder.buildConveyor(length, speedColor)
	local belt = part("ConveyorBelt", Vector3.new(10, 1, length), Color3.fromRGB(120, 120, 130), Vector3.new(0, 0.5, 0), beltFolder)

	local stripe = part("ConveyorStripe", Vector3.new(10, 1.05, length - 1), Color3.fromRGB(90, 92, 100), Vector3.new(0, 0.55, 0), beltFolder, 0.3)

	-- Moving chevron stripes to sell the "conveyor" feel.
	local chevron = part("ConveyorChevron", Vector3.new(10, 1.06, 8), Color3.fromRGB(180, 60, 60), Vector3.new(0, 0.58, 0), beltFolder, 0.2)

	belt.CFrame = CFrame.new(Vector3.new(0, 0.5, 0), Vector3.new(0, 0.5, 1))
	return { belt = belt, stripe = stripe, chevron = chevron }
end

-- Simple decorative props around the arena (trees and rocks).
function WorldBuilder.buildDecor()
	local specs = {
		{ Vector3.new(-24, 1.5, -28), Color3.fromRGB(120, 85, 40) },
		{ Vector3.new(24, 1.5, -28), Color3.fromRGB(120, 85, 40) },
		{ Vector3.new(-24, 1.5, 28), Color3.fromRGB(120, 85, 40) },
		{ Vector3.new(24, 1.5, 28), Color3.fromRGB(120, 85, 40) },
		{ Vector3.new(0, 1.2, -34), Color3.fromRGB(150, 110, 60) },
		{ Vector3.new(0, 1.2, 34), Color3.fromRGB(150, 110, 60) },
	}
	for _, s in ipairs(specs) do
		part("TreeTrunk", Vector3.new(1.2, 3, 1.2), s[2], s[1], decoFolder)
		part("TreeTop", Vector3.new(4.5, 4.5, 4.5), Color3.fromRGB(70, 170, 100), s[1] + Vector3.new(0, 4, 0), decoFolder)
	end
end

-- Boundary walls so players stay in the arena.
function WorldBuilder.buildWalls()
	local walls = {}
	walls[1] = part("WallNorth", Vector3.new(70, 8, 2), Color3.fromRGB(60, 62, 78), Vector3.new(0, 4, 52), decoFolder)
	walls[2] = part("WallSouth", Vector3.new(70, 8, 2), Color3.fromRGB(60, 62, 78), Vector3.new(0, 4, -52), decoFolder)
	walls[3] = part("WallEast", Vector3.new(2, 8, 104), Color3.fromRGB(60, 62, 78), Vector3.new(34, 4, 0), decoFolder)
	walls[4] = part("WallWest", Vector3.new(2, 8, 104), Color3.fromRGB(60, 62, 78), Vector3.new(-34, 4, 0), decoFolder)
end

WorldBuilder.buildConveyor = buildConveyor
WorldBuilder.buildDecor = buildDecor
WorldBuilder.buildWalls = buildWalls

-- Build a blocky brainrot character: a head with a face decal, a body, and a
-- floating name label. def = { name, color, size }. Returns the Model.
function WorldBuilder.buildBrainrot(name, color, size)
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = beltFolder

	local body = Instance.new("Part")
	body.Name = "Body"
	body.Anchored = false
	body.CanCollide = true
	body.Size = Vector3.new(size, size, size)
	body.Color = color
	body.Position = Vector3.new(0, size / 2 + 0.5, 0)

	local head = Instance.new("Part")
	head.Name = "Head"
	head.Anchored = false
	head.CanCollide = true
	head.Size = Vector3.new(size * 1.2, size * 1.2, size * 1.2)
	head.Color = color
	head.Position = body.Position + Vector3.new(0, size, 0)

	local weldBody = Instance.new("Weld")
	weldBody.Part0 = head
	weldBody.Part1 = body
	weldBody.C0 = CFrame.new(0, -size / 2, 0)
	weldBody.Parent = head

	local label = Instance.new("BillboardGui")
	label.Name = "Label"
	label.AlwaysOnTop = true
	label.Size = UDim2.new(3, 0, 1.2, 0)
	label.StudsOffset = Vector3.new(0, size * 2.2, 0)
	label.Adornee = head

	local text = Instance.new("TextLabel")
	text.Name = "Text"
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.TextColor3 = Color3.new(1, 1, 1)
	text.TextStrokeTransparency = 0
	text.Font = Enum.Font.SourceSansBold
	text.TextSize = 14
	text.Text = name
	text.Parent = label

	body.Parent = model
	head.Parent = model
	label.Parent = model

	model:SetPrimaryPartCFrame(CFrame.new(0, 0, 0))
	return model, head
end

WorldBuilder.buildBrainrot = buildBrainrot

return WorldBuilder