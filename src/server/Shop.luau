-- Shop: the server side of every player request. Each RemoteEvent handler
-- validates before it touches state (distance, cash, free pedestal, lock),
-- because the client can send anything. All state changes go through
-- GameState; all world changes go through WorldBuilder/Conveyor/Rival.
-- After every accepted request the server pushes a fresh state snapshot to
-- that player on the StateUpdate remote (cash, income, lock, upgrades...).

local BrainrotData = require(script.Parent.BrainrotData)
local Conveyor = require(script.Parent.Conveyor)
local GameState = require(script.Parent.GameState)
local Rival = require(script.Parent.Rival)
local WorldBuilder = require(script.Parent.WorldBuilder)

local Shop = {}

local remotes
local NORMAL_SPEED = 16
local CARRY_SPEED = 10
local INTERACT_RANGE = 12
local SLAP_RANGE = 14

local function getRoot(player)
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function setWalkSpeed(player, speed)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = speed
	end
end

local function fire(player, payload)
	if remotes and remotes.StateUpdate then
		remotes.StateUpdate:FireClient(player, payload)
	end
end

local function toast(player, text)
	fire(player, { type = "Toast", text = text })
end

local function effect(player, kind, position)
	fire(player, { type = "Effect", kind = kind, position = position })
end

-- The snapshot the HUD renders from. Sent after income ticks, events and
-- every accepted request, so the client never has to guess at server state.
function Shop.BuildStatePayload(player)
	local state = GameState.Get(player)
	if not state then
		return nil
	end
	local ownedIds = {}
	for _, owned in ipairs(state.owned) do
		table.insert(ownedIds, owned.id)
	end
	return {
		type = "State",
		cash = math.floor(state.cash),
		income = math.floor(GameState.GetTotalIncome(player)),
		baseIncome = math.floor(GameState.GetBaseIncome(player)),
		multiplier = GameState.GetIncomeMultiplier(player),
		rebirths = state.rebirths,
		title = GameState.GetTitle(player),
		pedestals = state.pedestals,
		ownedCount = #state.owned,
		ownedIds = ownedIds,
		carrying = state.carrying ~= nil,
		lockRemaining = math.floor(GameState.GetLockRemaining(player)),
		lockCooldown = math.floor(GameState.GetLockCooldownRemaining(player)),
		goldenRemaining = math.floor(GameState.GetGoldenRemaining(player)),
		upgradeCosts = {
			Pedestal = GameState.GetUpgradeCost(state, "Pedestal"),
			Conveyor = GameState.GetUpgradeCost(state, "Conveyor"),
			Income = GameState.GetUpgradeCost(state, "Income"),
		},
		upgradeLevels = {
			Pedestal = state.pedestals,
			Conveyor = state.conveyorLevel,
			Income = state.incomeUpgrade,
		},
		rebirthNeed = (function()
			local count, cash = GameState.GetRebirthRequirements(player)
			return { count = count, cash = cash }
		end)(),
	}
end

function Shop.SendState(player)
	local payload = Shop.BuildStatePayload(player)
	if payload then
		fire(player, payload)
	end
end

local function modelPosition(model)
	local root = model and model.PrimaryPart
	return root and root.Position
end

local function withinRange(player, position, range)
	local root = getRoot(player)
	if not root or not position then
		return false
	end
	return (root.Position - position).Magnitude <= range
end

local function onBuyBrainrot(player, model)
	local state = GameState.Get(player)
	if not state or typeof(model) ~= "Instance" or not Conveyor.IsSpawned(model) then
		return
	end
	local position = modelPosition(model)
	if not withinRange(player, position, INTERACT_RANGE) then
		toast(player, "Too far away!")
		return
	end
	local brainrot = BrainrotData.GetBrainrot(model:GetAttribute("BrainrotId"))
	if not brainrot then
		return
	end
	local price = model:GetAttribute("Price") or brainrot.price
	if state.cash < price then
		toast(player, ("Need $%d for %s"):format(price, brainrot.name))
		return
	end
	local slot = GameState.GetFreeSlot(player)
	if not slot then
		toast(player, "No free pedestal! Buy one in the Shop.")
		return
	end
	if not GameState.SpendCash(player, price) then
		return
	end
	Conveyor.Take(model)
	local mutation = model:GetAttribute("Mutation") or "None"
	local record = GameState.AddOwned(player, brainrot.id, mutation, model, slot)
	if not record then
		GameState.AddCash(player, price)
		return
	end
	WorldBuilder.PlaceOnPedestal(model, player, slot)
	effect(player, "Buy", position)
	toast(player, ("Bought %s for $%d!"):format(brainrot.name, price))
	Shop.SendState(player)
end

local function onStealBrainrot(player, model)
	local state = GameState.Get(player)
	if not state or typeof(model) ~= "Instance" then
		return
	end
	if state.carrying then
		toast(player, "Already carrying one! Bring it home first.")
		return
	end
	local position = modelPosition(model)
	if not withinRange(player, position, INTERACT_RANGE) then
		toast(player, "Too far away!")
		return
	end
	-- No free pedestal: refuse the steal BEFORE taking anything. The old
	-- code let the player pick up a brainrot they could never deliver, so
	-- they were stuck carrying it at speed 10 with no way out except
	-- rebirth or death.
	if not GameState.GetFreeSlot(player) then
		toast(player, "No free pedestal! Buy one in the Shop first.")
		return
	end
	local record
	if model:GetAttribute("CanCollect") then
		-- A brainrot dropped by a slap: free pickup, no owner to rob.
		local brainrot = BrainrotData.GetBrainrot(model:GetAttribute("BrainrotId"))
		if not brainrot then
			return
		end
		record = {
			id = brainrot.id,
			mutation = model:GetAttribute("Mutation") or "None",
			model = model,
			income = model:GetAttribute("Income") or brainrot.income,
		}
	else
		-- Steal from the rival's base: it must still be the rival's.
		record = GameState.RemoveRivalOwned(model)
		if not record then
			toast(player, "Too late - that one is gone!")
			return
		end
	end
	GameState.SetCarrying(player, record)
	WorldBuilder.AttachCarried(player, model)
	setWalkSpeed(player, CARRY_SPEED)
	effect(player, "Steal", position)
	toast(player, "Stolen! Run it back to YOUR base!")
	Shop.SendState(player)
end

local function onSlapRival(player)
	local state = GameState.Get(player)
	if not state then
		return
	end
	if Rival.GetDistanceTo(player) > SLAP_RANGE then
		toast(player, "Too far to slap the rival!")
		return
	end
	local ok, result = Rival.Slap(player)
	if not ok then
		toast(player, tostring(result))
		return
	end
	local rivalModel = WorldBuilder.GetRivalModel()
	local position = rivalModel and rivalModel.PrimaryPart and rivalModel.PrimaryPart.Position
	effect(player, "Slap", position)
	toast(player, "SLAPPED! The rival dropped its loot!")
	Shop.SendState(player)
end

local function onLockBase(player)
	if GameState.ActivateLock(player) then
		toast(player, "Base LOCKED for 30s - the rival can't steal!")
	else
		local cooldown = GameState.GetLockCooldownRemaining(player)
		toast(player, ("Lock recharging: %ds"):format(cooldown))
	end
	Shop.SendState(player)
end

local function onRebirth(player)
	local state = GameState.Get(player)
	if not state then
		return
	end
	local carrying = state.carrying
	local ok, result, removed = GameState.Rebirth(player)
	if not ok then
		toast(player, tostring(result))
		return
	end
	-- Destroy every model the rebirth cleared, plus anything carried:
	-- GameState only clears its tables, the 3D models stay in the world.
	for _, record in ipairs(removed or {}) do
		WorldBuilder.DestroyBrainrot(record.model)
	end
	if carrying and carrying.model then
		WorldBuilder.DestroyBrainrot(carrying.model)
	end
	WorldBuilder.ClearCarried(player)
	setWalkSpeed(player, NORMAL_SPEED)
	local position = getRoot(player) and getRoot(player).Position
	effect(player, "Rebirth", position)
	toast(player, ("REBIRTH #%d! Income x%.1f forever!"):format(state.rebirths, GameState.GetRebirthMultiplier(player)))
	Shop.SendState(player)
end

local function onBuyUpgrade(player, upgradeType)
	if upgradeType ~= "Pedestal" and upgradeType ~= "Conveyor" and upgradeType ~= "Income" then
		return
	end
	local state = GameState.Get(player)
	if not state then
		return
	end
	local ok, result = GameState.BuyUpgrade(player, upgradeType)
	if not ok then
		toast(player, tostring(result))
		return
	end
	if upgradeType == "Pedestal" then
		WorldBuilder.SetPedestalCount(player, state.pedestals)
	end
	toast(player, ("%s upgraded! (-$%d)"):format(upgradeType, result))
	Shop.SendState(player)
end

-- Called by init's heartbeat: a carrying player standing on their own base
-- delivers the brainrot onto a free pedestal. Server-side, so the client
-- can't fake a delivery from across the map.
function Shop.TryDeliver(player)
	local state = GameState.Get(player)
	if not state or not state.carrying then
		return false
	end
	local root = getRoot(player)
	if not root then
		return false
	end
	local baseCenter = BrainrotData.World.playerBase
	local offset = root.Position - baseCenter
	if math.abs(offset.X) > BrainrotData.World.baseSize.X / 2 or math.abs(offset.Z) > BrainrotData.World.baseSize.Z / 2 then
		return false
	end
	local slot = GameState.GetFreeSlot(player)
	if not slot then
		-- Keep carrying: clearing here would orphan the attached model.
		-- The HUD shows "no free pedestal" from ownedCount vs pedestals.
		return false
	end
	local record = state.carrying
	GameState.ClearCarrying(player)
	WorldBuilder.ClearCarried(player)
	local placed = GameState.AddOwned(player, record.id, record.mutation, record.model, slot)
	if not placed then
		return false
	end
	WorldBuilder.PlaceOnPedestal(record.model, player, slot)
	setWalkSpeed(player, NORMAL_SPEED)
	effect(player, "Buy", root.Position)
	local delivered = BrainrotData.GetBrainrot(record.id)
	toast(player, ("Delivered %s to your base!"):format(delivered and delivered.name or "brainrot"))
	Shop.SendState(player)
	return true
end

function Shop.ResetWalkSpeed(player)
	setWalkSpeed(player, NORMAL_SPEED)
end

function Shop.Init(remotesFolder)
	remotes = remotesFolder
	remotes.BuyBrainrot.OnServerEvent:Connect(onBuyBrainrot)
	remotes.StealBrainrot.OnServerEvent:Connect(onStealBrainrot)
	remotes.SlapRival.OnServerEvent:Connect(onSlapRival)
	remotes.LockBase.OnServerEvent:Connect(onLockBase)
	remotes.Rebirth.OnServerEvent:Connect(onRebirth)
	remotes.BuyUpgrade.OnServerEvent:Connect(onBuyUpgrade)
end

return Shop
