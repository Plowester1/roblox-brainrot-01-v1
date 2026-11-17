-- init.server.luau
-- Server entry: builds the world (via WorldBuilder), wires RemoteEvents, starts
-- the income loop and the event system.

local GameState = require(script.GameState)
local WorldBuilder = require(script.WorldBuilder)
local Conveyor = require(script.Conveyor)
local Rival = require(script.Rival)
local Shop = require(script.Shop)
local BrainrotData = require(script.BrainrotData)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- The RemoteEvents the client talks to. Declared in default.project.json; here we
-- just look them up and wire them.
local remotes = ReplicatedStorage.Remotes

local REMOTE_NAMES = { "BuyBrainrot", "StealBrainrot", "SlapRival", "LockBase", "Rebirth", "BuyUpgrade" }

-- Broadcast the current HUD state to a client (or all clients when nil).
local function packState(player)
	local data = GameState.Get(player)
	if not data then
		return nil
	end
	return {
		cash = math.floor(GameState.GetCash(player)),
		income = GameState.IncomePerSecond(player),
		rebirths = GameState.GetRebirths(player),
		pedestals = GameState.MaxPedestals(player),
		used = GameState.CountOwned(player),
		lockLeft = GameState.LockSecondsLeft(),
		golden = GameState.GoldenHourLeft(),
		collection = GameState.GetCollection(player),
	}
end

local function sync(player)
	if not remotes or not remotes.SyncState then
		return
	end
	local target = player or Players
	if player then
		remotes.SyncState:FireClient(player, packState(player))
	else
		for _, p in ipairs(Players:GetPlayers()) do
			remotes.SyncState:FireClient(p, packState(p))
		end
	end
end

-- Wire all RemoteEvents to the shop handlers.
local function wire()
	for _, name in ipairs(REMOTE_NAMES) do
		local ev = remotes:FindFirstChild(name)
		if not ev then
			continue
		end
		if name == "BuyBrainrot" then
			ev.OnServerEvent:Connect(function(player, model)
				local ok, res = Shop.Buy(player, model)
				if ok then
					sync(player)
				end
			end)
		elseif name == "StealBrainrot" then
			ev.OnServerEvent:Connect(function(player, model)
				local ok, res = Shop.StealFromRival(player, model)
				if ok then
					sync(player)
				end
			end)
		elseif name == "SlapRival" then
			ev.OnServerEvent:Connect(function(player)
				Shop.SlapRival(player)
			end)
		elseif name == "LockBase" then
			ev.OnServerEvent:Connect(function(player)
				local ok = Shop.LockBase(player)
				if ok then
					sync(player)
				end
			end)
		elseif name == "Rebirth" then
			ev.OnServerEvent:Connect(function(player)
				local ok = Shop.Rebirth(player)
				if ok then
					sync(player)
				end
			end)
		elseif name == "BuyUpgrade" then
			ev.OnServerEvent:Connect(function(player, upgrade)
				local ok = Shop.BuyUpgrade(player, upgrade)
				if ok then
					sync(player)
				end
			end)
		end
	end
end

-- Income loop: pay the player their dollars-per-second, ticking the HUD.
local function incomeLoop()
	while true do
		task.wait(1)
		for _, player in ipairs(Players:GetPlayers()) do
			if GameState.Get(player) then
				local income = GameState.IncomePerSecond(player)
				if income > 0 then
					GameState.AddCash(player, income)
				end
				sync(player)
			end
		end
	end
end

-- Event system: Brainrot Rain every ~90s, Golden Hour every ~5min.
local function eventLoop()
	local rainDelay = 75 + math.random(0, 30)
	local goldenDelay = 240 + math.random(0, 90)
	local rainAcc = rainDelay
	local goldenAcc = goldenDelay
	while true do
		task.wait(1)
		rainAcc = rainAcc - 1
		goldenAcc = goldenAcc - 1
		if rainAcc <= 0 then
			rainAcc = 75 + math.random(0, 30)
			local player = Players:GetPlayers()[1]
			if player and GameState.Get(player) then
				Conveyor.SpawnEvent(player)
				if remotes and remotes.Event then
					remotes.Event:FireAllClients("rain")
				end
			end
		end
		if goldenAcc <= 0 then
			goldenAcc = 240 + math.random(0, 90)
			GameState.StartGoldenHour(60)
			if remotes and remotes.Event then
				remotes.Event:FireAllClients("golden")
			end
		end
	end
end

-- Player lifecycle.
Players.PlayerAdded:Connect(function(player)
	GameState.Reset(player)
	task.wait(2)
	sync(player)
end)

Players.PlayerRemoving:Connect(function(player)
	GameState.Remove(player)
end)

-- Boot the world and the systems.
WorldBuilder.BuildWorld()
wire()
Conveyor.Start()
Rival.Start()
task.spawn(incomeLoop)
task.spawn(eventLoop)

print("Brainrot Base Wars server started.")