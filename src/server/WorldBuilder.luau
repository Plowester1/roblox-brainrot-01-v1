local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local BrainrotData = require(script.Parent.BrainrotData)
local WorldBuilder = {}

local worldFolder
local playerPedestals = {}
local rivalPedestals = {}
local rivalModel
local carriedModels = {}
local carriedConnections = {}

local function part(parent, name, size, position, partColor, material, canCollide)
	local item = Instance.new("Part")
	item.Name = name
	item.Size = size
	item.Position = position
	item.Color = partColor
	item.Anchored = true
	item.TopSurface = Enum.SurfaceType.Smooth
	item.BottomSurface = Enum.SurfaceType.Smooth
	item.Material = material or Enum.Material.SmoothPlastic
	if canCollide == false then
		item.CanCollide = false
	end
	item.Parent = parent
	return item
end

local function billboard(parent, size, offset)
	local gui = Instance.new("BillboardGui")
	gui.Name = "WorldLabel"
	gui.Size = size
	gui.StudsOffset = offset
	gui.AlwaysOnTop = true
	gui.MaxDistance = 180
	gui.Parent = parent
	return gui
end

local function buildBase(parent, center, baseColor, label, labelColor)
	local size = BrainrotData.World.baseSize
	part(parent, label .. "Platform", size, center, baseColor, Enum.Material.Concrete)
	local halfWidth = size.X / 2
	local halfDepth = size.Z / 2
	part(parent, label .. "FrontTrim", Vector3.new(size.X, 0.45, 0.6), center + Vector3.new(0, 2.2, halfDepth), labelColor, Enum.Material.Neon, false)
	part(parent, label .. "LeftTrim", Vector3.new(0.6, 0.45, size.Z), center + Vector3.new(-halfWidth, 2.2, 0), labelColor, Enum.Material.Neon, false)
	part(parent, label .. "RightTrim", Vector3.new(0.6, 0.45, size.Z), center + Vector3.new(halfWidth, 2.2, 0), labelColor, Enum.Material.Neon, false)
	part(parent, label .. "Step", Vector3.new(14, 1, 4), center + Vector3.new(0, -1.5, halfDepth + 2), labelColor, Enum.Material.Marble)
	local sign = part(parent, label .. "Sign", Vector3.new(18, 4, 1), center + Vector3.new(0, 8, halfDepth - 1), Color3.fromRGB(27, 30, 48), Enum.Material.SmoothPlastic, false)
	local gui = billboard(sign, UDim2.fromOffset(300, 70), Vector3.new(0, 3.5, 0))
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Text = label:upper() .. " BASE"
	text.TextColor3 = labelColor
	text.TextStrokeColor3 = Color3.fromRGB(16, 18, 30)
	text.TextStrokeTransparency = 0.2
	text.Font = Enum.Font.GothamBlack
	text.TextSize = 34
	text.Parent = gui
end

local function buildTree(parent, prop)
	part(parent, "TreeTrunk", Vector3.new(2, 8, 2), prop.position + Vector3.new(0, 4, 0), Color3.fromRGB(105, 65, 35), Enum.Material.Wood)
	part(parent, "TreeCrown", Vector3.new(8, 8, 8), prop.position + Vector3.new(0, 11, 0), prop.color, Enum.Material.Grass)
	part(parent, "TreeCrownTop", Vector3.new(5, 5, 5), prop.position + Vector3.new(0, 16, 0), Color3.fromRGB(64, 202, 77), Enum.Material.Grass)
end

local function buildSign(parent, prop)
	local sign = part(parent, prop.text .. "Sign", Vector3.new(13, 4, 1), prop.position, Color3.fromRGB(36, 40, 61), Enum.Material.SmoothPlastic, false)
	part(parent, prop.text .. "Post", Vector3.new(1, 5, 1), prop.position - Vector3.new(0, 3, 0), Color3.fromRGB(68, 61, 91), Enum.Material.Metal)
	local gui = billboard(sign, UDim2.fromOffset(230, 55), Vector3.new(0, 2.8, 0))
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Text = prop.text
	text.TextColor3 = Color3.fromRGB(255, 238, 93)
	text.TextStrokeTransparency = 0.25
	text.Font = Enum.Font.GothamBlack
	text.TextSize = 25
	text.Parent = gui
end

local function buildCoin(parent, prop)
	local coin = part(parent, "GoldenCoin", Vector3.new(3, 3, 0.7), prop.position, prop.color, Enum.Material.Neon, false)
	coin.Shape = Enum.PartType.Cylinder
	coin.CFrame = CFrame.new(coin.Position) * CFrame.Angles(0, 0, math.rad(90))
end

function WorldBuilder.Build()
	if worldFolder then
		return worldFolder
	end
	worldFolder = Instance.new("Folder")
	worldFolder.Name = "BrainrotWorld"
	worldFolder.Parent = Workspace
	local world = BrainrotData.World
	local arena = world.arenaSize
	part(worldFolder, "ArenaFloor", arena, Vector3.new(0, -0.5, 0), Color3.fromRGB(51, 199, 122), Enum.Material.Grass)
	buildBase(worldFolder, world.playerBase, world.playerBaseColor, "Player", Color3.fromRGB(92, 220, 255))
	buildBase(worldFolder, world.rivalBase, world.rivalBaseColor, "Rival", Color3.fromRGB(255, 198, 62))
	local belt = world.conveyorStart
	local beltEnd = world.conveyorEnd
	local beltLength = beltEnd.Z - belt.Z
	local beltCenter = (belt.Z + beltEnd.Z) / 2
	part(worldFolder, "ConveyorBelt", Vector3.new(world.conveyorWidth, 1, beltLength), Vector3.new(belt.X, belt.Y - 0.6, beltCenter), Color3.fromRGB(43, 48, 65), Enum.Material.Metal)
	for _, side in ipairs({-1, 1}) do
		part(worldFolder, "ConveyorRail", Vector3.new(0.7, 1.5, beltLength), Vector3.new(belt.X + side * world.conveyorWidth / 2, belt.Y - 0.6, beltCenter), Color3.fromRGB(255, 207, 42), Enum.Material.Neon, false)
	end
	for index = 0, 13 do
		local z = belt.Z + index * beltLength / 14
		part(worldFolder, "BeltArrow", Vector3.new(world.conveyorWidth - 2, 0.12, 0.7), Vector3.new(belt.X, belt.Y - 0.03, z), Color3.fromRGB(255, 236, 88), Enum.Material.Neon, false)
	end
	for index = 0, 8 do
		local z = belt.Z + index * beltLength / 8
		part(worldFolder, "BeltSupport", Vector3.new(14, 2, 2), Vector3.new(belt.X, 1, z), Color3.fromRGB(92, 96, 119), Enum.Material.Metal)
	end
	part(worldFolder, "WestWall", Vector3.new(2, 8, 198), Vector3.new(-99, 3.5, 0), Color3.fromRGB(75, 65, 120), Enum.Material.Rock)
	part(worldFolder, "EastWall", Vector3.new(2, 8, 198), Vector3.new(99, 3.5, 0), Color3.fromRGB(75, 65, 120), Enum.Material.Rock)
	part(worldFolder, "NorthWall", Vector3.new(198, 8, 2), Vector3.new(0, 3.5, -99), Color3.fromRGB(75, 65, 120), Enum.Material.Rock)
	part(worldFolder, "SouthWall", Vector3.new(198, 8, 2), Vector3.new(0, 3.5, 99), Color3.fromRGB(75, 65, 120), Enum.Material.Rock)
	for _, prop in ipairs(world.props) do
		if prop.type == "tree" then
			buildTree(worldFolder, prop)
		elseif prop.type == "sign" then
			buildSign(worldFolder, prop)
		elseif prop.type == "coin" then
			buildCoin(worldFolder, prop)
		end
	end
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "PlayerSpawn"
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.Position = world.spawnPosition - Vector3.new(0, 0.5, 0)
	spawn.Color = Color3.fromRGB(61, 219, 255)
	spawn.Material = Enum.Material.Neon
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = worldFolder
	Lighting.ClockTime = 14.2
	Lighting.Brightness = 2.5
	Lighting.Ambient = Color3.fromRGB(89, 102, 132)
	Lighting.Outlines = false
	local atmosphere = Lighting:FindFirstChild("BrainrotSky")
	if not atmosphere then
		atmosphere = Instance.new("Atmosphere")
		atmosphere.Name = "BrainrotSky"
		atmosphere.Density = 0.18
		atmosphere.Offset = 0.1
		atmosphere.Color = Color3.fromRGB(205, 225, 255)
		atmosphere.Decay = Color3.fromRGB(112, 88, 180)
		atmosphere.Glare = 0.15
		atmosphere.Haze = 1.1
		atmosphere.Parent = Lighting
	end
	local sky = Lighting:FindFirstChild("ColorfulSky")
	if not sky then
		sky = Instance.new("Sky")
		sky.Name = "ColorfulSky"
		sky.SkyboxBk = "rbxassetid://1262421302"
		sky.SkyboxDn = "rbxassetid://1262422175"
		sky.SkyboxFt = "rbxassetid://1262422164"
		sky.SkyboxLf = "rbxassetid://1262422202"
		sky.SkyboxRt = "rbxassetid://1262422285"
		sky.SkyboxUp = "rbxassetid://1262422350"
		sky.Parent = Lighting
	end
	return worldFolder
end

function WorldBuilder.BuildRival()
	if rivalModel then
		return rivalModel
	end
	local model = Instance.new("Model")
	model.Name = "RivalBot"
	model:SetAttribute("RivalBot", true)
	local root = part(model, "Root", Vector3.new(1, 1, 1), Vector3.zero, Color3.fromRGB(255, 255, 255), Enum.Material.SmoothPlastic, false)
	root.Transparency = 1
	local body = part(model, "RivalBody", Vector3.new(3, 4, 2), Vector3.new(0, 3, 0), Color3.fromRGB(224, 47, 70), Enum.Material.SmoothPlastic)
	local head = part(model, "RivalHead", Vector3.new(2.8, 2.8, 2.8), Vector3.new(0, 6.5, 0), Color3.fromRGB(255, 197, 80), Enum.Material.SmoothPlastic)
	part(model, "RivalHat", Vector3.new(3.3, 0.7, 3.3), Vector3.new(0, 8.2, 0), Color3.fromRGB(91, 34, 151), Enum.Material.Fabric)
	part(model, "RivalLeftArm", Vector3.new(1.2, 4, 1.2), Vector3.new(-2, 3.3, 0), Color3.fromRGB(224, 47, 70), Enum.Material.SmoothPlastic)
	part(model, "RivalRightArm", Vector3.new(1.2, 4, 1.2), Vector3.new(2, 3.3, 0), Color3.fromRGB(224, 47, 70), Enum.Material.SmoothPlastic)
	part(model, "RivalLeftLeg", Vector3.new(1.4, 4, 1.4), Vector3.new(-0.8, -1, 0), Color3.fromRGB(40, 38, 55), Enum.Material.SmoothPlastic)
	part(model, "RivalRightLeg", Vector3.new(1.4, 4, 1.4), Vector3.new(0.8, -1, 0), Color3.fromRGB(40, 38, 55), Enum.Material.SmoothPlastic)
	local gui = billboard(head, UDim2.fromOffset(235, 62), Vector3.new(0, 3.2, 0))
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "RIVAL BOT\nQ / CLICK: SLAP"
	label.TextColor3 = Color3.fromRGB(255, 235, 95)
	label.TextStrokeColor3 = Color3.fromRGB(35, 10, 20)
	label.TextStrokeTransparency = 0.15
	label.Font = Enum.Font.GothamBlack
	label.TextSize = 18
	label.Parent = gui
	model.PrimaryPart = root
	model.Parent = worldFolder
	model:PivotTo(CFrame.new(0, 3, 28))
	rivalModel = model
	return model
end

local function labelText(model, kind)
	local name = model:GetAttribute("BrainrotName") or "Brainrot"
	local rarity = model:GetAttribute("Rarity") or "Common"
	local mutation = model:GetAttribute("Mutation") or "None"
	local income = model:GetAttribute("Income") or 0
	local price = model:GetAttribute("Price") or 0
	local rarityInfo = BrainrotData.GetRarity(rarity)
	local text = name .. "\n" .. rarity
	if mutation ~= "None" then
		text ..= " • " .. mutation
	end
	if kind == "Conveyor" then
		text ..= ("\n$%s/s  •  BUY $%s"):format(tostring(income), tostring(price))
	elseif kind == "RivalOwned" then
		text ..= ("\nRIVAL • $%s/s"):format(tostring(income))
	elseif kind == "Dropped" then
		text ..= ("\nPICK UP • $%s/s"):format(tostring(income))
	elseif kind == "Carried" then
		text ..= ("\nCARRYING • $%s/s"):format(tostring(income))
	else
		text ..= ("\n$%s/s"):format(tostring(income))
	end
	local label = model:FindFirstChild("BrainrotLabel")
	local textLabel = label and label:FindFirstChild("Text")
	if textLabel then
		textLabel.Text = text
		textLabel.TextColor3 = rarityInfo and rarityInfo.color or Color3.new(1, 1, 1)
	end
end

function WorldBuilder.CreateBrainrot(brainrot, mutationName, kind)
	local mutation = BrainrotData.GetMutation(mutationName)
	local rarity = BrainrotData.GetRarity(brainrot.rarity)
	local model = Instance.new("Model")
	model.Name = brainrot.name
	local root = part(model, "Root", Vector3.new(1, 1, 1), Vector3.zero, Color3.fromRGB(255, 255, 255), Enum.Material.SmoothPlastic, false)
	root.Transparency = 1
	local width, height, depth = brainrot.size.X, brainrot.size.Y, brainrot.size.Z
	local bodyColor = mutationName == "None" and brainrot.color or mutation.color
	local body = part(model, "Body", Vector3.new(width, height * 0.48, depth), Vector3.new(0, height * 0.3, 0), bodyColor, Enum.Material.SmoothPlastic)
	local head = part(model, "Head", Vector3.new(width * 0.78, width * 0.78, depth * 0.72), Vector3.new(0, height * 0.72, 0), bodyColor, Enum.Material.SmoothPlastic)
	part(model, "LeftArm", Vector3.new(width * 0.28, height * 0.46, width * 0.28), Vector3.new(-width * 0.62, height * 0.3, 0), bodyColor, Enum.Material.SmoothPlastic)
	part(model, "RightArm", Vector3.new(width * 0.28, height * 0.46, width * 0.28), Vector3.new(width * 0.62, height * 0.3, 0), bodyColor, Enum.Material.SmoothPlastic)
	part(model, "LeftLeg", Vector3.new(width * 0.36, height * 0.28, depth * 0.42), Vector3.new(-width * 0.26, height * 0.13, 0), bodyColor, Enum.Material.SmoothPlastic)
	part(model, "RightLeg", Vector3.new(width * 0.36, height * 0.28, depth * 0.42), Vector3.new(width * 0.26, height * 0.13, 0), bodyColor, Enum.Material.SmoothPlastic)
	part(model, "LeftEye", Vector3.new(0.24, 0.32, 0.12), Vector3.new(-width * 0.16, height * 0.76, -depth * 0.37), Color3.fromRGB(18, 18, 25), Enum.Material.SmoothPlastic, false)
	part(model, "RightEye", Vector3.new(0.24, 0.32, 0.12), Vector3.new(width * 0.16, height * 0.76, -depth * 0.37), Color3.fromRGB(18, 18, 25), Enum.Material.SmoothPlastic, false)
	if mutationName ~= "None" then
		body.Material = Enum.Material.Neon
		head.Material = Enum.Material.Neon
	end
	local decal = Instance.new("Decal")
	decal.Name = "Face"
	decal.Face = Enum.NormalId.Front
	decal.Texture = "rbxasset://textures/face.png"
	decal.Parent = head
	local gui = billboard(head, UDim2.fromOffset(245, 78), Vector3.new(0, height * 0.55 + 1.2, 0))
	gui.Name = "BrainrotLabel"
	local text = Instance.new("TextLabel")
	text.Name = "Text"
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundColor3 = Color3.fromRGB(24, 24, 34)
	text.BackgroundTransparency = 0.12
	text.TextColor3 = rarity and rarity.color or Color3.new(1, 1, 1)
	text.TextStrokeColor3 = Color3.fromRGB(8, 8, 12)
	text.TextStrokeTransparency = 0.15
	text.Font = Enum.Font.GothamBold
	text.TextSize = 16
	text.TextWrapped = true
	text.Parent = gui
	model.PrimaryPart = root
	model.Parent = worldFolder
	model:SetAttribute("BrainrotId", brainrot.id)
	model:SetAttribute("BrainrotName", brainrot.name)
	model:SetAttribute("Mutation", mutationName)
	model:SetAttribute("Rarity", brainrot.rarity)
	model:SetAttribute("Income", BrainrotData.GetEffectiveIncome(brainrot, mutationName))
	model:SetAttribute("Price", brainrot.price)
	model:SetAttribute("Kind", kind or "Conveyor")
	labelText(model, kind or "Conveyor")
	return model
end

function WorldBuilder.InitializePlayerPedestals(player, count)
	if playerPedestals[player] then
		WorldBuilder.SetPedestalCount(player, count)
		return
	end
	local pedestals = {}
	for index = 1, count do
		local position = BrainrotData.World.playerSlots[index]
		local pedestal = part(worldFolder, "PlayerPedestal_" .. index, Vector3.new(5, 1.5, 5), position - Vector3.new(0, 0.75, 0), Color3.fromRGB(231, 236, 255), Enum.Material.Marble)
		pedestal:SetAttribute("PedestalIndex", index)
		pedestal:SetAttribute("PedestalPosition", position)
		pedestals[index] = pedestal
	end
	playerPedestals[player] = pedestals
end

function WorldBuilder.SetPedestalCount(player, count)
	local pedestals = playerPedestals[player]
	if not pedestals then
		WorldBuilder.InitializePlayerPedestals(player, count)
		return
	end
	for index = count + 1, #pedestals do
		pedestals[index]:Destroy()
		pedestals[index] = nil
	end
	for index = #pedestals + 1, count do
		local position = BrainrotData.World.playerSlots[index]
		-- playerSlots only holds 12 entries: a count past that used to index
		-- nil and error on `position - Vector3...`. Cap at the table.
		if not position then
			break
		end
		local pedestal = part(worldFolder, "PlayerPedestal_" .. index, Vector3.new(5, 1.5, 5), position - Vector3.new(0, 0.75, 0), Color3.fromRGB(255, 238, 118), Enum.Material.Marble)
		pedestal:SetAttribute("PedestalIndex", index)
		pedestal:SetAttribute("PedestalPosition", position)
		pedestals[index] = pedestal
	end
end

function WorldBuilder.RemovePlayerPedestals(player)
	-- A leaving player's pedestals used to stay in the world forever:
	-- PlayerRemoving destroyed their brainrots but never these parts, so
	-- every departed player left 6-12 marble slabs on their base.
	local pedestals = playerPedestals[player]
	if not pedestals then
		return
	end
	for _, pedestal in pairs(pedestals) do
		if pedestal then
			pedestal:Destroy()
		end
	end
	playerPedestals[player] = nil
end

function WorldBuilder.GetPedestalPosition(player, slot)
	return BrainrotData.World.playerSlots[slot]
end

function WorldBuilder.PlaceOnPedestal(model, player, slot)
	local position = WorldBuilder.GetPedestalPosition(player, slot)
	if position and model then
		model:SetAttribute("Kind", "Owned")
		model:PivotTo(CFrame.new(position))
		labelText(model, "Owned")
	end
end

function WorldBuilder.InitializeRivalPedestals()
	if #rivalPedestals > 0 then
		return rivalPedestals
	end
	for index, position in ipairs(BrainrotData.World.rivalSlots) do
		local pedestal = part(worldFolder, "RivalPedestal_" .. index, Vector3.new(5, 1.5, 5), position - Vector3.new(0, 0.75, 0), Color3.fromRGB(255, 218, 224), Enum.Material.Marble)
		pedestal:SetAttribute("PedestalIndex", index)
		pedestal:SetAttribute("PedestalPosition", position)
		rivalPedestals[index] = pedestal
	end
	return rivalPedestals
end

function WorldBuilder.PlaceOnRivalPedestal(model, slot)
	local position = BrainrotData.World.rivalSlots[slot]
	if position and model then
		model:SetAttribute("Kind", "RivalOwned")
		model:PivotTo(CFrame.new(position))
		labelText(model, "RivalOwned")
	end
end

function WorldBuilder.AttachCarried(player, model)
	WorldBuilder.ClearCarried(player)
	if not model then
		return
	end
	carriedModels[player] = model
	model:SetAttribute("Kind", "Carried")
	labelText(model, "Carried")
	carriedConnections[player] = RunService.Heartbeat:Connect(function()
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		-- The carried model can be destroyed out from under us (rebirth,
		-- rival slap, player leaving). PivotTo on a destroyed model errors,
		-- so bail out and clear the carry instead of crashing Heartbeat.
		if not model.Parent then
			WorldBuilder.ClearCarried(player)
			return
		end
		if root and carriedModels[player] == model then
			model:PivotTo(root.CFrame * CFrame.new(0, 2.2, -3.2))
		end
	end)
end

function WorldBuilder.ClearCarried(player)
	if carriedConnections[player] then
		carriedConnections[player]:Disconnect()
		carriedConnections[player] = nil
	end
	carriedModels[player] = nil
end

function WorldBuilder.DestroyCarried(player)
	local model = carriedModels[player]
	WorldBuilder.ClearCarried(player)
	if model then
		model:Destroy()
	end
end

function WorldBuilder.CreateDropped(record, position)
	local brainrot = BrainrotData.GetBrainrot(record.id)
	if not brainrot then
		return nil
	end
	local model = WorldBuilder.CreateBrainrot(brainrot, record.mutation, "Dropped")
	model:SetAttribute("CanCollect", true)
	model:PivotTo(CFrame.new(position))
	-- A dropped brainrot nobody picks up used to sit in the world forever
	-- (slap drops, full-rival-base drops). Despawn after 60s so the arena
	-- never fills with stale pickups.
	task.delay(60, function()
		if model.Parent and model:GetAttribute("CanCollect") then
			model:Destroy()
		end
	end)
	return model
end

function WorldBuilder.DestroyBrainrot(model)
	if model then
		model:Destroy()
	end
end

function WorldBuilder.GetRivalModel()
	return rivalModel
end

function WorldBuilder.GetWorld()
	return worldFolder
end

function WorldBuilder.UpdateLabel(model, kind)
	labelText(model, kind or model:GetAttribute("Kind") or "Owned")
end

return WorldBuilder
