-- Game.client: the client entry point. The 3D world is the game (default
-- Roblox third-person camera, WASD to move); this script only builds the
-- HUD, binds the keys, finds what the player can interact with nearby, and
-- talks to the server through the BrainrotRemotes. The server validates
-- every request — the client never decides a purchase, a steal or a slap.
-- Keys are bound with ContextActionService (Roblox's camera eats raw
-- arrow-key input; E/Q/L/C are free).

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local Effects = require(script.Parent.Effects)
local HUD = require(script.Parent.HUD)

local remotes = ReplicatedStorage:WaitForChild("BrainrotRemotes")
HUD.Build(remotes)

local INTERACT_RANGE = 12
local SLAP_RANGE = 14

local lastState = nil
local currentTarget = nil -- { kind = "Buy" | "Steal", model = Instance }

local function getRoot()
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

remotes.StateUpdate.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then
		return
	end
	if payload.type == "State" then
		lastState = payload
		HUD.SetState(payload)
	elseif payload.type == "Toast" then
		HUD.ShowToast(payload.text)
	elseif payload.type == "Banner" then
		HUD.ShowBanner(payload.text, payload.duration)
	elseif payload.type == "Effect" then
		Effects.Burst(payload.kind, payload.position)
		if payload.kind == "Golden" then
			Effects.GoldenFlash(HUD.GetGui())
		end
	end
end)

local function nearestModel(root, kinds)
	local world = Workspace:FindFirstChild("BrainrotWorld")
	if not world then
		return nil
	end
	local nearest = nil
	local nearestDistance = INTERACT_RANGE
	for _, child in ipairs(world:GetChildren()) do
		if child:IsA("Model") and kinds[child:GetAttribute("Kind")] then
			local part = child.PrimaryPart
			if part then
				local distance = (part.Position - root.Position).Magnitude
				if distance <= nearestDistance then
					nearest = child
					nearestDistance = distance
				end
			end
		end
	end
	return nearest
end

local function refreshPrompt()
	local root = getRoot()
	if not root then
		HUD.SetPrompt("")
		currentTarget = nil
		return
	end
	if lastState and lastState.carrying then
		local free = (lastState.pedestals or 0) - (lastState.ownedCount or 0)
		if free > 0 then
			HUD.SetPrompt("Carrying a brainrot - run onto YOUR base to deliver it!")
		else
			HUD.SetPrompt("Carrying - but no free pedestal! Buy one in the Shop.")
		end
		currentTarget = nil
		return
	end
	local buyTarget = nearestModel(root, { Conveyor = true })
	if buyTarget then
		currentTarget = { kind = "Buy", model = buyTarget }
		local name = buyTarget:GetAttribute("BrainrotName") or "Brainrot"
		local price = buyTarget:GetAttribute("Price") or 0
		local rarity = buyTarget:GetAttribute("Rarity") or ""
		HUD.SetPrompt(("Press E to buy %s - $%d (%s)"):format(name, price, rarity))
		return
	end
	local stealTarget = nearestModel(root, { RivalOwned = true, Dropped = true })
	if stealTarget then
		currentTarget = { kind = "Steal", model = stealTarget }
		local name = stealTarget:GetAttribute("BrainrotName") or "Brainrot"
		if stealTarget:GetAttribute("CanCollect") then
			HUD.SetPrompt(("Press E to pick up %s!"):format(name))
		else
			HUD.SetPrompt(("Press E to STEAL %s from the rival!"):format(name))
		end
		return
	end
	currentTarget = nil
	local rival = Workspace:FindFirstChild("BrainrotWorld") and Workspace.BrainrotWorld:FindFirstChild("RivalBot")
	local rivalRoot = rival and rival.PrimaryPart
	if rivalRoot and (rivalRoot.Position - root.Position).Magnitude <= SLAP_RANGE then
		HUD.SetPrompt("Press Q to SLAP the rival!")
		return
	end
	HUD.SetPrompt("")
end

task.spawn(function()
	while true do
		task.wait(0.2)
		pcall(refreshPrompt)
	end
end)

local function onInteract(_, inputState)
	if inputState ~= Enum.UserInputState.Begin then
		return
	end
	if not currentTarget then
		return
	end
	if currentTarget.kind == "Buy" then
		remotes.BuyBrainrot:FireServer(currentTarget.model)
	elseif currentTarget.kind == "Steal" then
		remotes.StealBrainrot:FireServer(currentTarget.model)
	end
end

local function onSlap(_, inputState)
	if inputState ~= Enum.UserInputState.Begin then
		return
	end
	remotes.SlapRival:FireServer()
end

local function onLock(_, inputState)
	if inputState ~= Enum.UserInputState.Begin then
		return
	end
	remotes.LockBase:FireServer()
end

local function onCollection(_, inputState)
	if inputState ~= Enum.UserInputState.Begin then
		return
	end
	HUD.ToggleCollection()
end

ContextActionService:BindAction("BrainrotInteract", onInteract, false, Enum.KeyCode.E)
ContextActionService:BindAction("BrainrotSlap", onSlap, false, Enum.KeyCode.Q)
ContextActionService:BindAction("BrainrotLock", onLock, false, Enum.KeyCode.L)
ContextActionService:BindAction("BrainrotCollection", onCollection, false, Enum.KeyCode.C)

-- Clicking anywhere (not on a HUD button) also slaps when the rival is in
-- range, so mouse players get the same defence as keyboard players.
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 then
		return
	end
	local root = getRoot()
	if not root then
		return
	end
	local world = Workspace:FindFirstChild("BrainrotWorld")
	local rival = world and world:FindFirstChild("RivalBot")
	local rivalRoot = rival and rival.PrimaryPart
	if rivalRoot and (rivalRoot.Position - root.Position).Magnitude <= SLAP_RANGE then
		remotes.SlapRival:FireServer()
	end
end)

print("[Brainrot Base Wars] client ready - E interact, Q slap, L lock, C collection")
