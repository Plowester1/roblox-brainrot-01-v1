-- Game.client.luau
-- Client entry: builds the HUD, binds keys (E buy/steal, Q slap, L lock) via
-- ContextActionService, and handles the server's RemoteEvents. WASD + Space is
-- default Roblox movement; the camera stays default third-person.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

local HUD = require(script.HUD)
local Effects = require(script.Effects)

local REMOTE_FOLDER = ReplicatedStorage:WaitForChild("RemoteEvents")

local function remote(name)
	return REMOTE_FOLDER:WaitForChild(name)
end

local buyRemote = remote("BuyBrainrot")
local stealRemote = remote("StealBrainrot")
local slapRemote = remote("SlapRival")
local lockRemote = remote("LockBase")
local rebirthRemote = remote("Rebirth")
local upgradeRemote = remote("BuyUpgrade")
local hudRemote = remote("HUDUpdate")
local bannerRemote = remote("EventBanner")
local resultRemote = remote("ActionResult")

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "HUD"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = player:WaitForChild("PlayerGui")

-- Shared brainrot catalog (for the collection panel).
local GameData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameData"))

-- Pick the nearest brainrot of a given folder.
local function nearestModel(folder, predicate)
	local best = nil
	local bestDist = math.huge
	local origin = player.Character and player.Character:GetPivot().Position or Vector3.new()
	for _, model in ipairs(folder:GetChildren()) do
		if predicate(model) then
			local dist = (model:GetPivot().Position - origin).Magnitude
			if dist < bestDist then
				bestDist = dist
				best = model
			end
		end
	end
	return best, bestDist
end

-- Build the HUD (top bar + buttons + collection panel).
HUD.build(ScreenGui)
HUD.buildButtons()
HUD.buildCollection(GameData.rarities, GameData.brainrots)

local World = workspace:WaitForChild("World")
local BeltFolder = World:WaitForChild("Conveyor")
local BasesFolder = World:WaitForChild("Bases")

-- Track whether the player is currently carrying a stolen brainrot.
local carrying = false

local function beltBrainrot(model)
	return model:FindFirstChild("Head") ~= nil and not model:GetAttribute("IsRival") and not model:GetAttribute("Carried")
end

-- The nearest belt brainrot within buy range.
local function findBeltTarget(range)
	local model, dist = nearestModel(BeltFolder, beltBrainrot)
	if dist <= range then
		return model
	end
	return nil
end

-- The nearest rival-base brainrot within steal range.
local function findRivalTarget(range)
	local base = BasesFolder:FindFirstChild("RivalBase")
	if not base then
		return nil
	end
	local model, dist = nearestModel(base, beltBrainrot)
	if dist <= range then
		return model, dist
	end
	return nil
end

-- Press E: buy a nearby belt brainrot, or steal one from the rival base.
local function onE()
	local char = player.Character
	if not char then
		return
	end
	local target = findBeltTarget(8)
	if target then
		local id = target:GetAttribute("BrainrotId")
		if id then
			buyRemote:FireServer(id, 1)
			Effects.buy(target:GetPivot().Position, target.Head.Color)
		end
		return
	end
	local rivalModel, dist = findRivalTarget(8)
	if rivalModel and not carrying then
		local id = rivalModel:GetAttribute("BrainrotId")
		if id then
			stealRemote:FireServer(id)
		end
	end
end

-- Press Q: slap the rival.
local function onQ()
	slapRemote:FireServer()
end

-- Press L: lock the base.
local function onL()
	lockRemote:FireServer()
end

ContextActionService:BindAction("BuyOrSteal", function(_, state)
	if state == Enum.UserInputState.Begin then
		onE()
	end
	return Enum.ContextActionResult.Sink
end, false, Enum.KeyCode.E)

ContextActionService:BindAction("Slap", function(_, state)
	if state == Enum.UserInputState.Begin then
		onQ()
	end
	return Enum.ContextActionResult.Sink
end, false, Enum.KeyCode.Q)

ContextActionService:BindAction("Lock", function(_, state)
	if state == Enum.UserInputState.Begin then
		onL()
	end
	return Enum.ContextActionResult.Sink
end, false, Enum.KeyCode.L)

HUD.callbacks.onLock = onL

-- ---------------------------------------------------------------- server events

-- Local snapshot of the HUD state pushed by the server.
local hudState = { cash = 0, income = 0, mult = 1, rebirths = 0, title = "Noob", lockReadyAt = 0, lockUntil = 0 }

hudRemote.OnClientEvent:Connect(function(cash, income, mult, rebirths, title, pedestals, lockUntil, lockReadyAt)
	hudState.cash = cash
	hudState.income = income
	hudState.mult = mult
	hudState.rebirths = rebirths
	hudState.title = title or hudState.title
	hudState.lockUntil = lockUntil or 0
	hudState.lockReadyAt = lockReadyAt or 0
	HUD.updateCash(cash)
	HUD.updateIncome(income, mult)
	HUD.updateRebirth(rebirths, title or hudState.title)
end)

bannerRemote.OnClientEvent:Connect(function(text)
	HUD.showBanner(text)
	Effects.fanfare(player.Character and player.Character:GetPivot().Position or Vector3.new())
end)

-- ActionResult: let the player know a request failed.
resultRemote.OnClientEvent:Connect(function(actionName, success, detail)
	if not success and detail then
		HUD.showBanner(actionName .. ": " .. tostring(detail))
	end
end)

-- Tick the lock button's cooldown each frame.
RunService.Heartbeat:Connect(function()
	local lockReady = os.clock() >= (hudState.lockReadyAt or 0)
	HUD.updateLock(hudState.lockReadyAt - os.clock(), lockReady)
end)

return { }