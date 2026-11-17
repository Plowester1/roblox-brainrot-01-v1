-- init.server.luau
-- Server entry: builds the 3D world, wires the RemoteEvents, starts the income
-- loop and the events (Brainrot Rain, Golden Hour).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local BrainrotData = require(script.BrainrotData)
local GameState = require(script.GameState)
local WorldBuilder = require(script.WorldBuilder)
local Conveyor = require(script.Conveyor)
local Rival = require(script.Rival)
local Shop = require(script.Shop)

local cfg = BrainrotData.game

-- ---------------------------------------------------------------- world build

local function buildWorld()
	WorldBuilder.init()

	local playerBase = WorldBuilder.buildBase("PlayerBase", Vector3.new(0, 0, -44), Color3.fromRGB(46, 160, 220))
	local rivalBase = WorldBuilder.buildBase("RivalBase", Vector3.new(0, 0, 44), Color3.fromRGB(220, 60, 60))

	-- Pull the pedestal Parts off the bases' models into a plain array.
	local function collectPedestals(baseModel)
		local list = {}
		for _, child in ipairs(baseModel:GetDescendants()) do
			if child:IsA("Part") and child.Name:match("Pedestal_") then
				local n = child.Name:match("Pedestal_(%d+)")
				if n then
					list[tonumber(n)] = child
				end
			end
		end
		return list
	end

	playerBase.pedestals = collectPedestals(playerBase.model)
	rivalBase.pedestals = collectPedestals(rivalBase.model)

	WorldBuilder.buildConveyor(cfg.conveyorLength)
	WorldBuilder.buildDecor()
	WorldBuilder.buildWalls()

	-- Spawn locations: the player spawns at their base, near the pedestals.
	local playerSpawn = Instance.new("SpawnLocation")
	playerSpawn.Name = "PlayerSpawn"
	playerSpawn.Anchored = true
	playerSpawn.CanCollide = false
	playerSpawn.Size = Vector3.new(6, 1, 6)
	playerSpawn.Position = Vector3.new(0, 4, -34)
	playerSpawn.Neutral = true
	playerSpawn.Parent = workspace

	local rivalSpawn = Instance.new("SpawnLocation")
	rivalSpawn.Name = "RivalSpawn"
	rivalSpawn.Anchored = true
	rivalSpawn.CanCollide = false
	rivalSpawn.Size = Vector3.new(6, 1, 6)
	rivalSpawn.Position = Vector3.new(0, 4, 34)
	rivalSpawn.Neutral = true
	rivalSpawn.Parent = workspace

	Shop.setWorldBases(playerBase, rivalBase)
	Rival.playerBase = CFrame.new(0, 0, -44)
	Rival.rivalBase = CFrame.new(0, 0, 44)
	Rival.build()
	return playerBase, rivalBase
end

local playerBase, rivalBase = buildWorld()

-- ---------------------------------------------------------------- hooks

Shop.configure(cfg, {})
Conveyor.configure({
	beltLength = cfg.conveyorLength,
	speed = cfg.conveyorSpeed,
	gap = cfg.spawnGap,
	interval = cfg.spawnInterval,
})

-- Wire the rival's stealing to Shop: it steals the highest-income brainrot,
-- then "keeps" it on its own base (which the player can re-steal).
Rival.registerHooks({
	incomeOf = Shop.incomeOf,
	takeFromPlayer = function(id, owner)
		Shop.rivalKept(id)
	end,
	onKept = function(id)
		-- The kept brainrot already became a rival-owned model in rivalKept.
	end,
	isLocked = Shop.isLockedForRival,
})

-- ---------------------------------------------------------------- remote events

local resultRemote = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("ActionResult")
Shop.resultRemote = resultRemote

local function wire(name, fn)
	local ev = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild(name)
	ev.OnServerEvent:Connect(function(player, ...)
		local ok, result, detail = pcall(fn, player, ...)
		local success = ok and result == true
		if resultRemote then
			resultRemote:FireClient(player, name, success, detail)
		end
	end)
end

wire("BuyBrainrot", function(player, beltId, pedestalIndex)
	Shop.buyBrainrot(player, beltId, pedestalIndex)
end)

wire("StealBrainrot", function(player, rivalId)
	Shop.stealBrainrot(player, rivalId)
end)

wire("SlapRival", function(player)
	Shop.slapRival(player)
end)

wire("LockBase", function(player)
	Shop.lockBase(player)
end)

wire("Rebirth", function(player)
	Shop.rebirth(player)
end)

wire("BuyUpgrade", function(player, kind)
	Shop.buyUpgrade(player, kind)
end)

-- ---------------------------------------------------------------- income loop

local incomeTimer = 0

local function pushAll()
	for _, p in ipairs(Players:GetPlayers()) do
		Shop.pushHUD(p.UserId)
	end
end

-- Runs once a second: give each player their brainrot income (x multiplier),
-- and broadcast a HUD update so the client shows cash and income/sec.
RunService.Heartbeat:Connect(function(dt)
	incomeTimer += dt
	if incomeTimer >= cfg.incomeTick then
		incomeTimer = 0
		local golden = goldenUntil and os.clock() < goldenUntil
		for _, p in ipairs(Players:GetPlayers()) do
			local userId = p.UserId
			local income = GameState.totalIncome(userId, Shop.incomeOf)
			if golden then
				income = income * 2
			end
			if income > 0 then
				GameState.addCash(userId, income)
			end
		end
		pushAll()
	end
end)

-- ---------------------------------------------------------------- events

local goldenUntil = 0
local rainTimer = 0
local goldenTimer = 0

local function announce(text)
	local banner = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("EventBanner")
	banner:FireAllClients(text)
end

-- Brainrot Rain: spawns an Epic+ brainrot on the belt with a fanfare.
local function doRain()
	local roll = BrainrotData.rollSpawn("Epic")
	if roll.brainrot then
		Conveyor.spawn(roll.brainrot, roll.rarity, roll.mutation)
		announce("BRAINROT RAIN! An Epic+ brainrot fell on the belt!")
	end
end

-- Golden Hour: double all income for the duration.
local function doGolden()
	goldenUntil = os.clock() + cfg.goldenDuration
	announce("GOLDEN HOUR! All income is doubled for 60s!")
end

RunService.Heartbeat:Connect(function(dt)
	rainTimer += dt
	goldenTimer += dt
	if rainTimer >= cfg.rainEvery then
		rainTimer = 0
		doRain()
	end
	if goldenTimer >= cfg.goldenEvery then
		goldenTimer = 0
		doGolden()
	end
end)

-- ---------------------------------------------------------------- player lifecycle

Players.PlayerRemoving:Connect(function(player)
	-- Clean up owned brainrots and state when a player leaves.
	for id, e in pairs(Shop.OWNED) do
		if e.ownerUserId == player.UserId then
			if e.model then
				e.model:Destroy()
			end
			Shop.OWNED[id] = nil
			GameState.releaseBrainrot(id)
		end
	end
	if Shop.PLAYER_CARRY[player.UserId] then
		Shop.cancelSteal(player)
	end
	GameState.remove(player.UserId)
end)

-- Start the conveyor and the rival AI.
Conveyor.start()
Rival.start()

-- ---------------------------------------------------------------- steal completion

-- Resolve player steals: when a carrying player reaches their own base the steal
-- completes; if they stray too long or die, it cancels cleanly. Never leaves a
-- player stuck carrying nothing or a brainrot in a half-stolen state.
local carryTimer = {}
local CARRY_TIMEOUT = 25

RunService.Heartbeat:Connect(function(dt)
	for _, p in ipairs(Players:GetPlayers()) do
		local userId = p.UserId
		if Shop.PLAYER_CARRY[userId] then
			carryTimer[userId] = (carryTimer[userId] or 0) + dt
			local char = p.Character
			local humanoid = char and char:FindFirstChildOfClass("Humanoid")
			local dead = humanoid and humanoid.Health <= 0
			local pos = char and char:GetPivot().Position or Vector3.new()
			local atHome = pos.Z < -30
			local timedOut = carryTimer[userId] > CARRY_TIMEOUT
			if atHome then
				Shop.completeSteal(p)
				carryTimer[userId] = 0
			elseif dead or timedOut then
				Shop.cancelSteal(p)
				carryTimer[userId] = 0
			end
		else
			carryTimer[userId] = nil
		end
	end
end)