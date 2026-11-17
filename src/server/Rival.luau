-- Rival.luau
-- The NPC rival bot. It wanders the arena and periodically tries to steal the
-- player's highest-income brainrot, carrying it back to its own base. The
-- player can slap it to make it drop what it carries. It respects the player's
-- base lock.

local Players = game:GetService("Players")

local WorldBuilder = require(script.Parent.WorldBuilder)
local GameState = require(script.Parent.GameState)

local Rival = {}

local BOT_NAME = "Rival"
local model = nil
local carrying = nil -- { id, ownerUserId, def, mutation, income }
local targetId = nil
local animState = "idle" -- idle | toPlayerBase | steal | toRivalBase
local moveSpeed = 6
local STATE = {}

-- Where the bases are: set by init.server.
Rival.playerBase = CFrame.new(0, 0, -40)
Rival.rivalBase = CFrame.new(0, 0, 40)

Rival.STATE = STATE
Rival.carrying = nil
Rival.model = nil

-- Build the rival character (a big angry blocky bot).
function Rival.build()
	model = WorldBuilder.buildBrainrot(BOT_NAME, Color3.fromRGB(200, 40, 40), 3)
	model:PivotTo(Rival.rivalBase * CFrame.new(0, 1.8, -6))
	model:SetAttribute("IsRival", true)
	Rival.model = model
	Rival.carrying = carrying
	return model
end

-- Pick the player's highest-income brainrot currently on a pedestal.
local function pickHighestIncome()
	local best = nil
	local bestId = nil
	for _, p in ipairs(Players:GetPlayers()) do
		local userId = p.UserId
		local state = GameState.get(userId)
		if state then
			GameState.forEachOwned(userId, function(id, owner)
				local income = Rival.incomeOf and Rival.incomeOf(id) or 0
				if not best or income > best then
					best = income
					bestId = id
				end
			end)
		end
	end
	return bestId
end

Rival.pickHighestIncome = pickHighestIncome
Rival.STATE = STATE

-- Register the caller-provided hooks: incomeOf(id), takeFromPlayer(id, userId),
-- onKept(id), and a way to know whether the player base is locked.
function Rival.registerHooks(hooks)
	Rival.incomeOf = hooks.incomeOf
	Rival.takeFromPlayer = hooks.takeFromPlayer
	Rival.onKept = hooks.onKept
	Rival.isLocked = hooks.isLocked
end

-- Move the rival toward a target CFrame. Returns true when close enough.
local function walkToward(target, dt, stopDist)
	local c = model:GetPivot()
	local dir = target.Position - c.Position
	local dist = dir.Magnitude
	if dist < stopDist then
		return true
	end
	local step = dir.Unit * (moveSpeed * dt)
	model:PivotTo(c * CFrame.new(step))
	return false
end

-- The carried brainrot model sits on the rival's head.
local carriedModel = nil
local carriedAdornee = nil

-- Lift the picked brainrot model up onto the rival.
local function liftCarried(id, def, mutation)
	if not def then
		return
	end
	carriedModel, carriedAdornee = WorldBuilder.buildBrainrot(def.name, def.color, 1.6)
	carriedModel.Parent = model
	local offset = CFrame.new(0, 5.5, 0)
	local c = model:GetPivot()
	carriedModel:PivotTo(c * offset)
	carrying = { id = id, def = def, mutation = mutation, income = def.income * GameState.getMultiplier(0) or def.income }
	Rival.carrying = carrying
	STATE.carrying = true
end

-- Attempt a steal: choose the highest-income brainrot and transition to the
-- "toPlayerBase" state. Returns true when a steal started.
local function attemptSteal()
	local id = pickHighestIncome()
	if not id then
		return false
	end
	targetId = id
	animState = "toPlayerBase"
	return true
end

-- Complete the theft: remove the brainrot from the player, lift it, and head
-- back to the rival base. Every steal path ends cleanly here.
local function doTheft()
	if not targetId then
		animState = "idle"
		return
	end
	local entry = Rival.incomeOf and Rival.incomeOf(targetId)
	if not entry then
		targetId = nil
		animState = "idle"
		return
	end
	local owner = GameState.ownerOf(targetId)
	if owner and Rival.takeFromPlayer then
		Rival.takeFromPlayer(targetId, owner)
	end
	liftCarried(targetId, entry.def, entry.mutation)
	targetId = nil
	animState = "toRivalBase"
end

-- The rival reached its base with a carried brainrot: keep it (despawns).
local function keepCarried()
	if carrying and Rival.onKept then
		Rival.onKept(carrying.id)
	end
	if carriedModel then
		carriedModel:Destroy()
	end
	carriedModel = nil
	carrying = nil
	Rival.carrying = nil
	STATE.carrying = false
	animState = "idle"
end

-- Slap the rival: knock it back and make it drop what it carries.
function Rival.slap(fromPosition, force)
	local c = model:GetPivot()
	local away = (c.Position - fromPosition).Unit * (force or 6)
	model:PivotTo(c * CFrame.new(away))
	if carrying then
		if carriedModel then
			carriedModel:Destroy()
		end
		carriedModel = nil
		carrying = nil
		Rival.carrying = nil
		STATE.carrying = false
		animState = "idle"
	end
	return true
end

local stealTimer = 0
local thinkTimer = 0
local STEAL_INTERVAL = 9
local THINK_INTERVAL = 3

-- Advance the rival's AI: decide whether to start a steal.
local function think(dt)
	thinkTimer -= dt
	stealTimer -= dt
	if thinkTimer > 0 then
		return
	end
	thinkTimer = THINK_INTERVAL

	if animState == "idle" then
		-- Only start a steal when the player base is not locked.
		local locked = Rival.isLocked and Rival.isLocked() or false
		if not locked and stealTimer <= 0 and not carrying then
			if attemptSteal() then
				stealTimer = STEAL_INTERVAL
			end
		end
	end
end

-- Drive the walk states each frame.
local function update(dt)
	think(dt)
	if animState == "toPlayerBase" then
		local arrive = walkToward(Rival.playerBase, dt, 4)
		if arrive then
			doTheft()
		end
	elseif animState == "toRivalBase" then
		local arrive = walkToward(Rival.rivalBase, dt, 4)
		if arrive then
			keepCarried()
		end
	end
end

local isRunning = false

-- Start the rival's AI loop.
function Rival.start()
	if isRunning then
		return
	end
	isRunning = true
	game:GetService("RunService").Heartbeat:Connect(update)
end

function Rival.setState(s)
	animState = s
end

Rival.reset = function()
	carrying = nil
	Rival.carrying = nil
	STATE.carrying = false
	animState = "idle"
	if model then
		model:PivotTo(Rival.rivalBase * CFrame.new(0, 1.8, -6))
	end
end

return Rival