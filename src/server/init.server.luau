local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WorldBuilder = require(script.Parent.WorldBuilder)
local GameState = require(script.Parent.GameState)
local Conveyor = require(script.Parent.Conveyor)
local Rival = require(script.Parent.Rival)
local Shop = require(script.Parent.Shop)

-- Server entry point: build the world, wire remote events, and start the
-- income loop plus the periodic events (Brainrot Rain, Golden Hour).

local INCOME_INTERVAL = 1.0 -- seconds per income tick
local EVENT_INTERVAL = 80 -- seconds between events
local GOLDEN_HOUR_EVERY = 300 -- seconds between golden hours
local GOLDEN_HOUR_DURATION = 60

local goldenHourUntil = 0
local nextEventAt = 0
local nextGoldenAt = 0

local function announceEvent(title, subtitle)
	local events = GameState.getRemoteEvents()
	local ev = events:FindFirstChild("EventBanner")
	if ev then
		ev:FireAllClients({
			title = title,
			subtitle = subtitle or "",
		})
	end
end

local function startIncomeLoop()
	while true do
		task.wait(INCOME_INTERVAL)
		for _, player in ipairs(Players:GetPlayers()) do
			local st = GameState.getState(player)
			if st then
				local income = GameState.totalIncome(player)
				local mult = 1
				if os.clock() < goldenHourUntil then
					mult = 2
				end
				GameState.addCash(player, income * mult)
			end
		end
	end
end

local function fireEvent()
	local r = math.random()
	local events = GameState.getRemoteEvents()
	local spawnEv = events:FindFirstChild("BrainrotSpawned")
	if r < 0.6 then
		-- Brainrot Rain: spawn an Epic+ brainrot on the belt with fanfare.
		announceEvent("BRAINROT RAIN!", "An Epic+ brainrot is rolling down the belt!")
		task.wait(0.8)
		Conveyor.spawnBrainrot(true)
	else
		announceEvent("DONATION WAVE", "The belt is running hot - more brainrots incoming!")
		Conveyor.spawnBrainrot(true)
	end
end

local function startEventLoop()
	while true do
		task.wait(EVENT_INTERVAL)
		fireEvent()
		if os.clock() >= nextGoldenAt then
			goldenHourUntil = os.clock() + GOLDEN_HOUR_DURATION
			nextGoldenAt = os.clock() + GOLDEN_HOUR_EVERY
			announceEvent("GOLDEN HOUR!", "All income x2 for 60 seconds!")
		end
	end
end

-- Connect a player: init their state and spawn them on their base.
local function onPlayerAdded(player)
	GameState.initState(player)
	player.CharacterAdded:Connect(function(char)
		local hrp = char:WaitForChild("HumanoidRootPart")
		hrp.CFrame = CFrame.new(WorldBuilder.PLAYER_BASE.center + Vector3.new(0, 4, 0))
	end)
	if not player.Character then
		player:LoadCharacter()
	end
end

local function onPlayerRemoving(player)
	GameState.removePlayer(player)
end

-- Build the world and start all systems.
WorldBuilder.setupLighting()
WorldBuilder.buildArena()
WorldBuilder.buildBase("PlayerBase", WorldBuilder.PLAYER_BASE, 4, Color3.fromRGB(70, 120, 220))
WorldBuilder.buildBase("RivalBase", WorldBuilder.RIVAL_BASE, 4, Color3.fromRGB(220, 70, 70))
WorldBuilder.buildConveyor()
Rival.buildModel()

Shop.init()

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

for _, existing in ipairs(Players:GetPlayers()) do
	onPlayerAdded(existing)
end

task.spawn(startIncomeLoop)
task.spawn(startEventLoop)
Conveyor.start(RunService)
Rival.start(RunService)

-- spawn a few brainrots right away so the belt is never empty
for _ = 1, 3 do
	task.spawn(function()
		task.wait(math.random() * 2)
		Conveyor.spawnBrainrot(false)
	end)
end