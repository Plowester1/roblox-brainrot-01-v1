-- Game.client.luau
-- Client entry: builds the HUD, binds keys (ContextActionService), handles the
-- RemoteEvents (cash updates, event banners), and the E buy/steal interaction.

local HUD = require(script.HUD)
local Effects = require(script.Effects)

local Players = game:GetService("Players")
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")

-- ---------------------------------------------------------------------------
-- World lookups
-- ---------------------------------------------------------------------------
local function char()
	return player.Character
end

local function charPos()
	local c = char()
	if c and c.PrimaryPart then
		return c.PrimaryPart.Position
	end
	return Vector3.new()
end

-- Find the nearest conveyor brainrot within range.
local function nearestConveyor()
	local best, bestDist
	for _, obj in ipairs(Workspace:GetChildren()) do
		if obj:IsA("Model") and obj.Name:sub(1, 8) == "Brainrot_" then
			local pos = obj.PrimaryPart and obj.PrimaryPart.Position
			if pos then
				local d = (pos - charPos()).Magnitude
				if d < 18 and (not bestDist or d < bestDist) then
					best = obj
					bestDist = d
				end
			end
		end
	end
	return best
end

-- Is the player near the rival base (to steal from it)?
local function nearRivalBase()
	local pos = charPos()
	return (pos - Vector3.new(0, 0, -56)).Magnitude < 16
end

-- Is the player near their own base?
local function nearOwnBase()
	local pos = charPos()
	return (pos - Vector3.new(0, 0, 56)).Magnitude < 16
end

-- ---------------------------------------------------------------------------
-- Interactions
-- ---------------------------------------------------------------------------
local function tryBuy()
	local model = nearestConveyor()
	if model then
		remotes.BuyBrainrot:FireServer(model)
		Effects.Buy(model.PrimaryPart and model.PrimaryPart.Position or charPos())
		return
	end
	-- Steal from the rival base.
	if nearRivalBase() then
		remotes.StealBrainrot:FireServer()
		Effects.Steal(charPos() + Vector3.new(0, 2, 0))
	end
end

local function trySlap()
	remotes.SlapRival:FireServer()
	local rival = Workspace:FindFirstChild("Rival")
	if rival then
		Effects.Slap(rival.PrimaryPart and rival.PrimaryPart.Position or charPos())
	end
end

local function tryLock()
	remotes.LockBase:FireServer()
end

-- ---------------------------------------------------------------------------
-- Key bindings via ContextActionService (not raw arrow keys).
-- ---------------------------------------------------------------------------
local function onAction(action, state, input)
	if state ~= Enum.UserInputState.Begin then
		return
	end
	if action == "Buy" then
		tryBuy()
	elseif action == "Slap" then
		trySlap()
	elseif action == "Lock" then
		tryLock()
	end
end

local function bindKeys()
	ContextActionService:BindAction("Buy", onAction, false, Enum.KeyCode.E)
	ContextActionService:BindAction("Slap", onAction, false, Enum.KeyCode.Q)
	ContextActionService:BindAction("Lock", onAction, false, Enum.KeyCode.L)
end

-- ---------------------------------------------------------------------------
-- Remote event handling
-- ---------------------------------------------------------------------------
local function wireRemotes()
	remotes.SyncState.OnClientEvent:Connect(function(state)
		HUD.ApplyState(state)
	end)
	remotes.Event.OnClientEvent:Connect(function(kind)
		if kind == "rain" then
			HUD.ShowBanner("BRAINROT RAIN! An Epic+ brainrot is coming!", 4)
		elseif kind == "golden" then
			HUD.ShowBanner("GOLDEN HOUR! Double income for 60s!", 4)
		end
	end)
end

-- ---------------------------------------------------------------------------
-- Wire the shop upgrade buttons.
-- ---------------------------------------------------------------------------
local function wireUpgrades()
	HUD.SetOnUpgrade(function(key)
		remotes.BuyUpgrade:FireServer(key)
	end)
	HUD.refs.lockBtn.MouseButton1Click:Connect(tryLock)
end

-- ---------------------------------------------------------------------------
-- Boot
-- ---------------------------------------------------------------------------
HUD.Build()
bindKeys()
wireRemotes()
wireUpgrades()

print("Brainrot Base Wars client ready.")