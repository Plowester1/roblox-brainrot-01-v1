local Players = game:GetService("Players")

local WorldBuilder = require(script.Parent.WorldBuilder)
local GameState = require(script.Parent.GameState)

-- The rival: an NPC that wanders between the two bases, steals a brainrot from
-- the player's base and carries it home, and can be slapped (which makes it
-- drop what it carries). It respects the player's base lock.

local Rival = {}

local pb = WorldBuilder.PLAYER_BASE
local rb = WorldBuilder.RIVAL_BASE

local state = {
	model = nil,
	body = nil,
	pos = rb.center + Vector3.new(0, 1.4, 0),
	home = rb.center,
	target = pb.center,
	carryingId = nil,
	slappedUntil = 0,
	wanderPhase = 0,
}

function Rival.buildModel()
	local model = Instance.new("Model")
	model.Name = "RivalBot"
	model.Parent = workspace

	local body = Instance.new("Part")
	body.Name = "RivalBody"
	body.Size = Vector3.new(2.2, 3.2, 1.8)
	body.Color = Color3.fromRGB(40, 40, 120)
	body.Material = Enum.Material.SmoothPlastic
	body.Anchored = true
	body.Parent = model

	local head = Instance.new("Part")
	head.Name = "RivalHead"
	head.Size = Vector3.new(1.6, 1.6, 1.6)
	head.Color = Color3.fromRGB(90, 60, 200)
	head.Material = Enum.Material.SmoothPlastic
	head.Anchored = true
	head.Parent = model

	local face = Instance.new("Decal")
	face.Texture = "rbxassetid://10611106203"
	face.Face = Enum.NormalId.Front
	face.Parent = head

	local nameTag = Instance.new("BillboardGui")
	nameTag.Name = "NameTag"
	nameTag.Size = UDim2.new(4, 0, 0, 0)
	nameTag.SizeOffset = Vector2.new(0, 30)
	nameTag.AlwaysOnTop = true
	nameTag.StudsOffsetWorldSpace = Vector3.new(0, 2.8, 0)
	nameTag.Parent = model

	local tag = Instance.new("TextLabel")
	tag.Size = UDim2.new(1, 0, 1, 0)
	tag.BackgroundTransparency = 1
	tag.Font = Enum.Font.GothamBold
	tag.TextScaled = true
	tag.TextColor3 = Color3.fromRGB(255, 120, 120)
	tag.Text = "RIVAL"
	tag.Parent = nameTag

	model.PrimaryPart = body
	model:PivotTo(CFrame.new(rb.center.x, 1.4, rb.center.z))

	state.model = model
	state.body = body
	return model
end

-- Move the rival toward a point on the arena floor.
function Rival.moveToward(targetPos, dt, speed)
	local dir = targetPos - state.pos
	dir = Vector3.new(dir.X, 0, dir.Z)
	if dir.Magnitude < 0.3 then
		return
	end
	local move = dir.Unit * speed * dt
	state.pos += move
	if state.model then
		state.model:PivotTo(CFrame.new(state.pos + Vector3.new(0, 0, 0), state.pos + move * 10))
		local head = state.model:FindFirstChild("RivalHead")
		if head then
			head.Position = state.pos + Vector3.new(0, 1.2, 0)
		end
	end
end

-- Drop whatever the rival is carrying (it lands on the arena where the rival is).
function Rival.dropCarried()
	local id = state.carryingId
	state.carryingId = nil
	if not id then
		return
	end
	-- The model stays registered; it can be picked up again by the player.
end

function Rival.isSlapped()
	return os.clock() < state.slappedUntil
end

function Rival.slap()
	state.slappedUntil = os.clock() + 2.5
	Rival.dropCarried()
	-- knock the rival back toward its own base
	state.pos += Vector3.new(6, 0, 0)
end

function Rival.getCarrying()
	return state.carryingId
end

-- Main loop: wander to the player base, steal a brainrot, carry it home, repeat.
function Rival.start(runService)
	runService.Heartbeat:Connect(function(dt)
		Rival.tick(dt)
	end)
end

function Rival.tick(dt)
	if Rival.isSlapped() then
		return
	end

	-- Find the first player
	local player = nil
	for _, p in ipairs(Players:GetPlayers()) do
		player = p
		break
	end
	if not player then
		return
	end

	local st = GameState.getState(player)
	if not st then
		return
	end

	if state.carryingId then
		-- carry it home
		Rival.moveToward(state.home + Vector3.new(0, 1.4, 0), dt, 5)
		local dist = (state.home - state.pos).Magnitude
		if dist < 2.5 then
			Rival.dropCarried()
			state.pos = state.home
		end
		return
	end

	-- at player base, look for a brainrot to steal
	local distToBase = (pb.center - state.pos).Magnitude
	if distToBase < 6 then
		if os.clock() > st.lockUntil then
			local target = Rival.pickStealTarget(player)
			if target then
				state.carryingId = target
				Rival.stealFromPedestal(player, target)
				return
			end
		end
		-- go home and wait
		Rival.moveToward(state.home + Vector3.new(0, 1.4, 0), dt, 7)
	else
		-- walk toward the player base
		Rival.moveToward(pb.center + Vector3.new(0, 1.4, 0), dt, 6)
	end
end

function Rival.pickStealTarget(player)
	local st = GameState.getState(player)
	local bestId = nil
	local bestIncome = -1
	for id, b in pairs(st.owned) do
		if not GameState.getCarrying(player) then
			local inc = GameState.brainrotIncome(player, b)
			if inc > bestIncome then
				bestIncome = inc
				bestId = id
			end
		end
	end
	return bestId
end

-- Remove a brainrot from the player's pedestal (it is now "carried" by the rival).
function Rival.stealFromPedestal(player, brainrotId)
	local st = GameState.getState(player)
	st.owned[brainrotId] = nil
	local pedestal = GameState.getPedestalFor(player, brainrotId)
	if pedestal then
		GameState.releasePedestal(player, pedestal)
	end
	-- keep the model registered so the player can reclaim it from the rival base
	local model = GameState.getBrainrotModel(brainrotId)
	if model and model.model then
		model.model:PivotTo(CFrame.new(state.pos))
	end
	GameState.sync(player)
end

return Rival