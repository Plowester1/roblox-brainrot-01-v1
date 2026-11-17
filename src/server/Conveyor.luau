-- Conveyor.luau
-- Spawns brainrots on the belt on a timer (weighted by rarity), moves them down
-- the lane, and despawns them at the end if they are not bought.

local Conveyor = {}

local BrainrotData = require(script.Parent.BrainrotData)
local WorldBuilder = require(script.Parent.WorldBuilder)
local GameState = require(script.Parent.GameState)

local RunService = game:GetService("RunService")

-- The living conveyor brainrot models, keyed by the model itself.
local active = {}

local LAYOUT = WorldBuilder.Layout

-- Spawn a brainrot on the conveyor at the far (rival) end and let it walk toward
-- the player base. Returns the model.
function Conveyor.Spawn(owner, tier, forceMutation)
	tier = tier or BrainrotData.PickTier()
	local mutation = forceMutation or BrainrotData.PickMutation()
	local name = BrainrotData.PickName(tier)
	local entry = { name = name, tier = tier, baseMoney = BrainrotData.BuyCost(tier) }
	local model = WorldBuilder.BuildBrainrot(entry, mutation)
	model.Name = "Brainrot_" .. name
	model.PrimaryPart = model:FindFirstChild("Body")
	local startPos = Vector3.new(LAYOUT.ConveyorX, LAYOUT.ConveyorY + 1.1, LAYOUT.ConveyorZStart + 2)
	model:SetPrimaryPartCFrame(CFrame.new(startPos))
	model.Parent = workspace

	local data = {
		model = model,
		owner = owner,
		entry = entry,
		mutation = mutation,
		z = startPos.Z,
		walking = true,
	}
	active[model] = data
	return model
end

-- Force-spawn an Epic+ brainrot during a Brainrot Rain event.
function Conveyor.SpawnEvent(owner)
	local tier = nil
	local roll = math.random()
	if roll < 0.5 then
		tier = "Epic"
	elseif roll < 0.8 then
		tier = "Legendary"
	elseif roll < 0.95 then
		tier = "Mythic"
	else
		tier = "Brainrot God"
	end
	return Conveyor.Spawn(owner, tier, "None")
end

-- Called by Shop when a player buys a conveyor brainrot; remove it from the lane.
function Conveyor.Consume(model)
	local data = active[model]
	if not data then
		return nil
	end
	data.walking = false
	active[model] = nil
	return data
end

-- Move all conveyor brainrots toward the player base. Despawn those that reach
-- the end without being bought.
local function tick()
	local step = 0.35
	for model, data in pairs(active) do
		if data.walking then
			data.z = data.z + step
			if model.PrimaryPart then
				model:SetPrimaryPartCFrame(CFrame.new(LAYOUT.ConveyorX, LAYOUT.ConveyorY + 1.1, data.z))
			end
			if data.z >= LAYOUT.ConveyorZEnd then
				data.walking = false
				active[model] = nil
				model:Destroy()
			end
		end
	end
end

-- Every few seconds (scaled by the owner's conveyor speed upgrade) spawn a new
-- brainrot on the belt.
local function spawnLoop()
	local acc = 0
	while true do
		local players = game:GetService("Players"):GetPlayers()
		local owner = players[1]
		local speed = owner and GameState.GetConveyorSpeed(owner) or 1
		acc = acc + RunService.Heartbeat:Wait()
		local interval = 6 / math.max(1, speed)
		if acc >= interval then
			acc = 0
			if owner then
				Conveyor.Spawn(owner)
			end
		end
	end
end

function Conveyor.Start()
	task.spawn(spawnLoop)
	RunService.Heartbeat:Connect(tick)
end

return Conveyor