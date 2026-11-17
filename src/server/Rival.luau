-- Rival.luau
-- The NPC rival bot: wanders the arena, picks a brainrot to steal from the
-- player's base, carries it back, can be slapped (drops it), and respects the
-- player's base lock.

local Rival = {}

local GameState = require(script.Parent.GameState)
local WorldBuilder = require(script.Parent.WorldBuilder)
local BrainrotData = require(script.Parent.BrainrotData)

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local LAYOUT = WorldBuilder.Layout

local rival = {
	model = nil,
	state = "idle",      -- idle | walking | stealing | carrying
	target = nil,        -- brainrot model being stolen
	targetIndex = nil,
	targetBase = nil,    -- "Player" | "Rival"
	path = nil,
	step = 0,
	speed = 3,
}

-- Build the rival's blocky body in the arena.
function Rival.Spawn()
	local model = Instance.new("Model")
	model.Name = "Rival"

	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = Vector3.new(2, 2.4, 2)
	body.Color = Color3.fromRGB(120, 60, 60)
	body.Anchored = true
	body.TopSurface = Enum.SurfaceType.Smooth
	body.BottomSurface = Enum.SurfaceType.Smooth
	body.Parent = model

	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = Vector3.new(1.8, 1.8, 1.8)
	head.Color = Color3.fromRGB(200, 140, 120)
	head.Anchored = true
	head.Parent = model

	local label = Instance.new("BillboardGui")
	label.Name = "Name"
	label.Size = UDim2.new(0, 120, 0, 30)
	label.StudsOffsetWorldSpace = Vector3.new(0, 3.4, 0)
	label.AlwaysOnTop = true
	local t = Instance.new("TextLabel")
	t.Name = "Text"
	t.Size = UDim2.new(1, 0, 1, 0)
	t.BackgroundTransparency = 1
	t.TextScaled = true
	t.Font = Enum.Font.FredokaOne
	t.TextColor3 = Color3.fromRGB(255, 255, 255)
	t.Text = "RIVAL BOT"
	t.TextStrokeTransparency = 0.2
	t.Parent = label
	label.Parent = model

	model.PrimaryPart = body
	model:SetPrimaryPartCFrame(CFrame.new(0, 2, LAYOUT.RivalBaseZ))
	model.Parent = workspace

	rival.model = model
	return model
end

-- Move the rival toward a target world position on the XZ plane.
local function moveToward(pos)
	local m = rival.model
	if not m or not m.PrimaryPart then
		return
	end
	local cf = m:GetPivot()
	local target = Vector3.new(pos.X, cf.Position.Y, pos.Z)
	local dir = (target - cf.Position)
	local dist = dir.Magnitude
	if dist > 0.1 then
		local step = rival.speed * 0.02
		local move = dir.Unit * math.min(step, dist)
		m:SetPrimaryPartCFrame(CFrame.new(cf.Position + move))
	end
	return dist <= 0.6
end

-- A friendly target a short distance in front of the rival's current heading.
local function aheadOf(cf, distance)
	return cf.Position + cf.LookVector * distance
end

-- Choose a brainrot to steal: prefer the player's highest-earning owned one.
local function pickPlayerTarget(player)
	local owned = GameState.GetOwned(player)
	if #owned == 0 then
		return nil
	end
	local best = nil
	local bestIndex = 0
	local bestVal = -1
	for i, b in ipairs(owned) do
		local mut = BrainrotData.Mutations[b.mutation] or BrainrotData.Mutations.None
		local val = b.baseMoney * mut.mult
		if val > bestVal then
			bestVal = val
			best = b
			bestIndex = i
		end
	end
	return best, bestIndex
end

local function tick(player)
	if not rival.model then
		return
	end
	if rival.state == "idle" then
		-- Wander a little, then decide to raid the player base.
		if math.random() < 0.5 then
			moveToward(Vector3.new(math.random(-10, 10), 0, math.random(-30, 30)))
		end
		if math.random() < 0.02 then
			if GameState.IsLocked() then
				return
			end
			local target, idx = pickPlayerTarget(player)
			if target then
				rival.state = "walking"
				rival.targetIndex = idx
				rival.targetBase = "Player"
			end
		end
	elseif rival.state == "walking" then
		local dest = Vector3.new(0, 0, LAYOUT.PlayerBaseZ)
		if moveToward(dest) then
			rival.state = "stealing"
		end
	elseif rival.state == "stealing" then
		-- Pick up the target brainrot (a model on the player base).
		local owned = GameState.GetOwned(player)
		local b = owned[rival.targetIndex]
		if not b then
			rival.state = "idle"
			return
		end
		rival.state = "carrying"
		rival.target = b
	elseif rival.state == "carrying" then
		local dest = Vector3.new(0, 0, LAYOUT.RivalBaseZ)
		if moveToward(dest) then
			-- Deposit the stolen brainrot on the rival base (it is gone for the
			-- player, plus a small cash reward for the rival-owned "NPC").
			if rival.target then
				GameState.RemoveOwned(player, rival.targetIndex)
			end
			rival.target = nil
			rival.targetIndex = nil
			rival.state = "idle"
		end
	end
end

-- Slap the rival: knock it back and make it drop what it carries.
function Rival.Slap(player)
	if not rival.model then
		return false
	end
	local cf = rival.model:GetPivot()
	local away = cf.LookVector * -6
	rival.model:SetPrimaryPartCFrame(CFrame.new(cf.Position + Vector3.new(away.X, 0, away.Z)))
	if rival.state == "carrying" then
		rival.target = nil
		rival.targetIndex = nil
		rival.state = "idle"
	end
	return true
end

function Rival.IsCarrying()
	return rival.state == "carrying"
end

local function startLoop()
	while true do
		RunService.Heartbeat:Wait()
		local player = Players:GetPlayers()[1]
		if player and GameState.Get(player) then
			tick(player)
		end
	end
end

function Rival.Start()
	task.spawn(startLoop)
end

return Rival