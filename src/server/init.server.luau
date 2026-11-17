-- init.server: the server entry point. Builds the world, wires the remotes,
-- starts the conveyor, the rival and the income/event loops. Gameplay state
-- lives only in GameState; this file only orchestrates the modules.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Conveyor = require(script.Parent.Conveyor)
local GameState = require(script.Parent.GameState)
local Rival = require(script.Parent.Rival)
local Shop = require(script.Parent.Shop)
local WorldBuilder = require(script.Parent.WorldBuilder)

local remotes = ReplicatedStorage:WaitForChild("BrainrotRemotes")
local NORMAL_SPEED = 16

WorldBuilder.Build()
WorldBuilder.InitializeRivalPedestals()
Shop.Init(remotes)
Rival.Start()
Conveyor.Start()

local function setupPlayer(player)
	GameState.Setup(player)
	WorldBuilder.InitializePlayerPedestals(player, 6)
	player.CharacterAdded:Connect(function(character)
		local humanoid = character:WaitForChild("Humanoid")
		humanoid.WalkSpeed = NORMAL_SPEED
		-- Dying drops the run: anything carried is lost with the life.
		WorldBuilder.DestroyCarried(player)
		GameState.ClearCarrying(player)
	end)
end

Players.PlayerAdded:Connect(setupPlayer)
for _, player in ipairs(Players:GetPlayers()) do
	setupPlayer(player)
end

Players.PlayerRemoving:Connect(function(player)
	local state = GameState.Get(player)
	if state then
		for _, record in ipairs(state.owned) do
			WorldBuilder.DestroyBrainrot(record.model)
		end
		if state.carrying and state.carrying.model then
			WorldBuilder.DestroyBrainrot(state.carrying.model)
		end
	end
	WorldBuilder.ClearCarried(player)
	GameState.Remove(player)
	WorldBuilder.RemovePlayerPedestals(player)
end)

-- Income loop: every second each player earns their total $/s, gets a fresh
-- state snapshot for the HUD, and a carrying player standing on their own
-- base delivers the brainrot automatically.
task.spawn(function()
	while true do
		task.wait(1)
		for _, player in ipairs(Players:GetPlayers()) do
			local state = GameState.Get(player)
			if state then
				GameState.AddCash(player, GameState.GetTotalIncome(player))
				Shop.SendState(player)
				Shop.TryDeliver(player)
			end
		end
	end
end)

print("[Brainrot Base Wars] server ready - world built, conveyor running, rival loose")

-- Events loop: Brainrot Rain every ~90s (an Epic-or-rarer brainrot joins the
-- conveyor with a fanfare) and Golden Hour every ~5 min (all income x2
-- for 60s). Announced to every player through the StateUpdate banner.
local RAIN_INTERVAL = 90
local RAIN_MIN_RARITY = 3 -- Epic
local GOLDEN_INTERVAL = 300
local GOLDEN_DURATION = 60

local function broadcast(payload)
	for _, player in ipairs(Players:GetPlayers()) do
		remotes.StateUpdate:FireClient(player, payload)
	end
end

task.spawn(function()
	local nextRainAt = os.clock() + RAIN_INTERVAL
	local nextGoldenAt = os.clock() + GOLDEN_INTERVAL
	while true do
		task.wait(1)
		local now = os.clock()
		if now >= nextRainAt then
			nextRainAt = now + RAIN_INTERVAL
			Conveyor.Spawn(RAIN_MIN_RARITY)
			broadcast({ type = "Banner", text = "BRAINROT RAIN! A rare brainrot hit the conveyor!", duration = 6 })
			broadcast({ type = "Effect", kind = "Rain" })
		end
		if now >= nextGoldenAt then
			nextGoldenAt = now + GOLDEN_INTERVAL
			for _, player in ipairs(Players:GetPlayers()) do
				GameState.SetGoldenUntil(player, now + GOLDEN_DURATION)
			end
			broadcast({ type = "Banner", text = "GOLDEN HOUR! All income DOUBLED for 60s!", duration = 6 })
			broadcast({ type = "Effect", kind = "Golden" })
		end
	end
end)
