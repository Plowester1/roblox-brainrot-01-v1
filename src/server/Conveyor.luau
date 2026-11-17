local RunService = game:GetService("RunService")

local BrainrotData = require(script.Parent.BrainrotData)
local WorldBuilder = require(script.Parent.WorldBuilder)

local Conveyor = {}
local spawned = {}
local running = false
local heartbeatConnection = nil

local function fastestConveyorLevel()
	local fastest = 0
	for _, state in pairs(require(script.Parent.GameState).GetAll()) do
		fastest = math.max(fastest, state.conveyorLevel)
	end
	return fastest
end

local function getSpeed()
	return BrainrotData.World.conveyorSpeed + fastestConveyorLevel() * 0.65
end

local function getSpawnInterval()
	return math.max(2.1, 5.2 - fastestConveyorLevel() * 0.62)
end

local function removeFromList(model)
	for index, item in ipairs(spawned) do
		if item == model then
			table.remove(spawned, index)
			return true
		end
	end
	return false
end

local function spawnBrainrot(minimumRarityIndex, forcedMutation)
	local brainrot = BrainrotData.ChooseBrainrot(minimumRarityIndex)
	local mutation = forcedMutation or BrainrotData.ChooseMutation().name
	local model = WorldBuilder.CreateBrainrot(brainrot, mutation, "Conveyor")
	local lane = BrainrotData.World.conveyorStart
	-- Spread spawns across most of the 12-wide belt (was a 4.8-stud
	-- cluster in the middle, so the belt always looked the same).
	local x = lane.X + math.random() * 9 - 4.5
	model:PivotTo(CFrame.new(x, lane.Y, lane.Z))
	model:SetAttribute("WalkPhase", math.random() * math.pi * 2)
	table.insert(spawned, model)
	return model
end

function Conveyor.Spawn(minimumRarityIndex, forcedMutation)
	return spawnBrainrot(minimumRarityIndex or 1, forcedMutation)
end

function Conveyor.GetSpawned()
	return spawned
end

function Conveyor.IsSpawned(model)
	for _, item in ipairs(spawned) do
		if item == model then
			return true
		end
	end
	return false
end

function Conveyor.Take(model)
	if not Conveyor.IsSpawned(model) then
		return false
	end
	removeFromList(model)
	return true
end

function Conveyor.Remove(model)
	removeFromList(model)
	if model then
		model:Destroy()
	end
end

function Conveyor.FindNear(position, radius)
	local nearest
	local nearestDistance = radius
	for _, model in ipairs(spawned) do
		local root = model.PrimaryPart
		if root then
			local distance = (root.Position - position).Magnitude
			if distance <= nearestDistance then
				nearest = model
				nearestDistance = distance
			end
		end
	end
	return nearest
end

function Conveyor.Start()
	if running then
		return
	end
	running = true
	local lane = BrainrotData.World.conveyorStart
	local laneEnd = BrainrotData.World.conveyorEnd
	task.spawn(function()
		while running do
			task.wait(getSpawnInterval())
			if running then
				spawnBrainrot(1)
			end
		end
	end)
	-- The Heartbeat connection is stored so Stop() can disconnect it. The old
	-- code never disconnected: Start() after Stop() connected a second
	-- Heartbeat and every brainrot then moved at double speed.
	heartbeatConnection = RunService.Heartbeat:Connect(function(deltaTime)
		if not running then
			return
		end
		local speed = getSpeed()
		for index = #spawned, 1, -1 do
			local model = spawned[index]
			local root = model.PrimaryPart
			if root then
				local phase = (model:GetAttribute("WalkPhase") or 0) + deltaTime * 10
				model:SetAttribute("WalkPhase", phase)
				local nextZ = root.Position.Z + speed * deltaTime
				if nextZ >= laneEnd.Z then
					removeFromList(model)
					model:Destroy()
				else
					local bob = math.abs(math.sin(phase)) * 0.08
					model:PivotTo(CFrame.new(root.Position.X, lane.Y + bob, nextZ) * CFrame.Angles(0, math.rad(180), 0))
				end
			else
				-- PrimaryPart gone (model destroyed out from under us):
				-- drop it from the list instead of tracking a dead model.
				removeFromList(model)
				model:Destroy()
			end
		end
	end)
end

function Conveyor.Stop()
	running = false
	if heartbeatConnection then
		heartbeatConnection:Disconnect()
		heartbeatConnection = nil
	end
	for _, model in ipairs(spawned) do
		model:Destroy()
	end
	table.clear(spawned)
end

return Conveyor
