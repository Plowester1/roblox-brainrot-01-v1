local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local BrainrotData = require(script.Parent.BrainrotData)
local GameState = require(script.Parent.GameState)
local WorldBuilder = require(script.Parent.WorldBuilder)

local Rival = {}
local phase = "Wander"
local targetPlayer
local targetModel
local destination
local nextDecisionAt = 0
local walkPhase = 0
local knockback = Vector3.zero
local started = false

local function now()
	return os.clock()
end

local function rivalPosition()
	local model = WorldBuilder.GetRivalModel()
	local root = model and model.PrimaryPart
	return root and root.Position or Vector3.new(0, 3, 28)
end

local function findFreeRivalSlot()
	local occupied = {}
	for _, owned in ipairs(GameState.GetRivalOwned()) do
		occupied[owned.slot] = true
	end
	for slot = 1, #BrainrotData.World.rivalSlots do
		if not occupied[slot] then
			return slot
		end
	end
	return nil
end

local function chooseWanderDestination()
	local points = {
		Vector3.new(-28, 3, 18), Vector3.new(28, 3, 18), Vector3.new(-28, 3, -18),
		Vector3.new(28, 3, -18), Vector3.new(0, 3, 0), Vector3.new(-38, 3, 48),
		Vector3.new(38, 3, -48),
	}
	return points[math.random(1, #points)]
end

local function chooseVictim()
	local candidates = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local state = GameState.Get(player)
		if state and #state.owned > 0 and not GameState.IsLocked(player) then
			table.insert(candidates, player)
		end
	end
	if #candidates == 0 then
		return
	end
	targetPlayer = candidates[math.random(1, #candidates)]
	local owned = targetPlayer and GameState.Get(targetPlayer).owned
	if not owned or #owned == 0 then
		targetPlayer = nil
		return
	end
	-- The rival hunts the highest-income brainrot, not a random one:
	-- protecting your best earner (lock / slap) is now a real decision
	-- instead of the rival mostly grabbing a cheap Common.
	local record = owned[1]
	for _, candidate in ipairs(owned) do
		if (candidate.income or 0) > (record.income or 0) then
			record = candidate
		end
	end
	targetModel = record.model
	if targetModel and targetModel.PrimaryPart then
		destination = targetModel.PrimaryPart.Position
		phase = "Hunt"
		nextDecisionAt = now() + 12
	else
		targetPlayer = nil
		targetModel = nil
		phase = "Wander"
	end
end

local function animateWalk(model, deltaTime)
	walkPhase += deltaTime * 10
	local swing = math.sin(walkPhase)
	local root = model.PrimaryPart
	if not root then
		return
	end
	-- Set absolute limb angles from the root's current CFrame each frame.
	-- The old code multiplied each limb's CFrame by a rotation every frame,
	-- so the swing accumulated and the legs spun round instead of swinging.
	-- Each limb swings around its hip/shoulder: translate up to the joint,
	-- rotate, translate back down.
	local function swingLimb(limb, offset, angle)
		if not limb then
			return
		end
		local rest = root.CFrame * CFrame.new(offset.X, offset.Y, offset.Z)
		limb.CFrame = rest * CFrame.new(0, limb.Size.Y / 2, 0)
			* CFrame.Angles(angle, 0, 0)
			* CFrame.new(0, -limb.Size.Y / 2, 0)
	end
	swingLimb(model:FindFirstChild("RivalLeftLeg"), Vector3.new(-0.8, -1, 0), swing * 0.45)
	swingLimb(model:FindFirstChild("RivalRightLeg"), Vector3.new(0.8, -1, 0), -swing * 0.45)
	swingLimb(model:FindFirstChild("RivalLeftArm"), Vector3.new(-2, 3.3, 0), -swing * 0.35)
	swingLimb(model:FindFirstChild("RivalRightArm"), Vector3.new(2, 3.3, 0), swing * 0.35)
end

local function moveToward(model, target, speed, deltaTime)
	local root = model and model.PrimaryPart
	if not root then
		return true
	end
	local offset = target - root.Position
	offset = Vector3.new(offset.X, 0, offset.Z)
	local distance = offset.Magnitude
	if distance < 0.5 then
		return true
	end
	local direction = offset.Unit
	local step = math.min(speed * deltaTime, distance)
	local nextPosition = root.Position + direction * step
	model:PivotTo(CFrame.lookAt(nextPosition, nextPosition + direction))
	animateWalk(model, deltaTime)
	return distance <= step + 0.5
end

local function seedRivalBase()
	if #GameState.GetRivalOwned() > 0 then
		return
	end
	local seeds = {"tralalero", "lirili", "trippi"}
	for slot, id in ipairs(seeds) do
		local brainrot = BrainrotData.GetBrainrot(id)
		local model = WorldBuilder.CreateBrainrot(brainrot, "None", "RivalOwned")
		local record = {
			id = id,
			mutation = "None",
			slot = slot,
			model = model,
			income = BrainrotData.GetEffectiveIncome(brainrot, "None"),
		}
		GameState.AddRivalOwned(record)
		WorldBuilder.PlaceOnRivalPedestal(model, slot)
	end
end

local function tryStealTarget()
	if not targetPlayer or not targetModel then
		return false
	end
	if GameState.IsLocked(targetPlayer) then
		targetPlayer = nil
		targetModel = nil
		phase = "Wander"
		return false
	end
	local record = GameState.RemoveOwned(targetPlayer, targetModel)
	if not record then
		targetPlayer = nil
		targetModel = nil
		phase = "Wander"
		return false
	end
	record.model:SetAttribute("Kind", "RivalCarried")
	WorldBuilder.UpdateLabel(record.model, "Carried")
	GameState.SetRivalCarrying(record)
	targetPlayer = nil
	targetModel = nil
	phase = "Carry"
	return true
end

local function completeRivalSteal()
	local rival = GameState.GetRival()
	local record = rival.carrying
	local slot = findFreeRivalSlot()
	if not record then
		phase = "Wander"
		nextDecisionAt = now() + 4
		return
	end
	if not slot then
		-- Rival base full: the old code just returned and the rival stayed
		-- in Carry phase forever, hugging its base with a stolen brainrot.
		-- Drop it as a pickup in front of the rival base instead so a
		-- player can grab it back.
		local dropAt = BrainrotData.World.rivalBase + Vector3.new(0, 1, 12)
		if record.model then
			record.model:Destroy()
		end
		WorldBuilder.CreateDropped(record, dropAt)
		GameState.ClearRivalCarrying()
		phase = "Wander"
		nextDecisionAt = now() + 4
		return
	end
	record.slot = slot
	GameState.AddRivalOwned(record)
	GameState.ClearRivalCarrying()
	WorldBuilder.PlaceOnRivalPedestal(record.model, slot)
	phase = "Wander"
	nextDecisionAt = now() + 4
end

function Rival.Start()
	if started then
		return
	end
	started = true
	WorldBuilder.BuildRival()
	WorldBuilder.InitializeRivalPedestals()
	seedRivalBase()
	destination = chooseWanderDestination()
	RunService.Heartbeat:Connect(function(deltaTime)
		local model = WorldBuilder.GetRivalModel()
		if not model or not model.PrimaryPart then
			return
		end
		local rival = GameState.GetRival()
		if now() < rival.stunnedUntil then
			if knockback.Magnitude > 0.01 then
				local nextPosition = model.PrimaryPart.Position + knockback * deltaTime
				model:PivotTo(CFrame.new(nextPosition))
				knockback = knockback * 0.93
			end
			return
		end
		if phase == "Wander" then
			local reached = destination and moveToward(model, destination, 11, deltaTime)
			if reached or now() >= nextDecisionAt then
				chooseVictim()
				if phase == "Wander" then
					destination = chooseWanderDestination()
					nextDecisionAt = now() + 3
				end
			end
		elseif phase == "Hunt" then
			if not targetPlayer or not targetModel or not targetModel.Parent then
				targetPlayer = nil
				targetModel = nil
				phase = "Wander"
				destination = chooseWanderDestination()
			elseif GameState.IsLocked(targetPlayer) then
				targetPlayer = nil
				targetModel = nil
				phase = "Wander"
				destination = chooseWanderDestination()
			else
				local targetPosition = targetModel.PrimaryPart and targetModel.PrimaryPart.Position
				if targetPosition and moveToward(model, targetPosition, 13, deltaTime) then
					tryStealTarget()
				end
			end
		elseif phase == "Carry" then
			local record = rival.carrying
			if record and record.model then
				record.model:PivotTo(model.PrimaryPart.CFrame * CFrame.new(0, 2, -3.5))
			end
			local basePosition = BrainrotData.World.rivalBase + Vector3.new(0, 1, 9)
			if moveToward(model, basePosition, 12, deltaTime) then
				completeRivalSteal()
			end
		end
	end)
end

function Rival.Slap(player)
	local rival = GameState.GetRival()
	if now() < rival.slapCooldownUntil then
		return false, "Rival is still recovering"
	end
	local model = WorldBuilder.GetRivalModel()
	if not model or not model.PrimaryPart then
		return false, "Rival not ready"
	end
	local dropPosition
	local record = rival.carrying
	if record then
		dropPosition = model.PrimaryPart.Position + Vector3.new(0, 0.3, 0)
		if record.model then
			record.model:Destroy()
		end
		WorldBuilder.CreateDropped(record, dropPosition)
		GameState.ClearRivalCarrying()
	end
	local playerRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if playerRoot then
		local away = model.PrimaryPart.Position - playerRoot.Position
		away = Vector3.new(away.X, 0, away.Z)
		if away.Magnitude > 0 then
			knockback = away.Unit * 28
		end
	end
	rival.stunnedUntil = now() + 1.5
	rival.slapCooldownUntil = now() + 2
	phase = "Wander"
	targetPlayer = nil
	targetModel = nil
	destination = chooseWanderDestination()
	return true, dropPosition
end

function Rival.GetDistanceTo(player)
	local model = WorldBuilder.GetRivalModel()
	local root = model and model.PrimaryPart
	local playerRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root or not playerRoot then
		return math.huge
	end
	return (root.Position - playerRoot.Position).Magnitude
end
