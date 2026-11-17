local GameState = {}

local BrainrotData = require(script.Parent.BrainrotData)

local playerStates = {}
local rivalState = {
	owned = {},
	carrying = nil,
	stunnedUntil = 0,
	slapCooldownUntil = 0,
}

local titles = {
	"Brainrot Rookie",
	"Certified Nonsense",
	"Tralalero Tycoon",
	"Pastafarian CEO",
	"Garlic Brain Baron",
	"Cosmic Cappuccino",
	"Quantum Menace",
	"Supreme Brainrot",
}

local function now()
	return os.clock()
end

local function createPlayerState()
	return {
		cash = 3500,
		owned = {},
		pedestals = 6,
		rebirths = 0,
		incomeUpgrade = 1,
		conveyorLevel = 0,
		lockUntil = 0,
		lockCooldownUntil = 0,
		goldenUntil = 0,
		carrying = nil,
	}
end

function GameState.Setup(player)
	local state = createPlayerState()
	playerStates[player.UserId] = state
	return state
end

function GameState.Get(player)
	return playerStates[player.UserId]
end

function GameState.GetAll()
	return playerStates
end

function GameState.GetRival()
	return rivalState
end

function GameState.AddCash(player, amount)
	local state = GameState.Get(player)
	if not state then
		return 0
	end
	state.cash += amount
	return state.cash
end

function GameState.SpendCash(player, amount)
	local state = GameState.Get(player)
	if not state or amount < 0 or state.cash < amount then
		return false
	end
	state.cash -= amount
	return true
end

function GameState.GetFreeSlot(player)
	local state = GameState.Get(player)
	if not state then
		return nil
	end
	local occupied = {}
	for _, owned in ipairs(state.owned) do
		occupied[owned.slot] = true
	end
	for slot = 1, state.pedestals do
		if not occupied[slot] then
			return slot
		end
	end
	return nil
end

function GameState.AddOwned(player, brainrotId, mutationName, model, requestedSlot)
	local state = GameState.Get(player)
	local brainrot = BrainrotData.GetBrainrot(brainrotId)
	if not state or not brainrot then
		return nil
	end
	local slot = requestedSlot or GameState.GetFreeSlot(player)
	if not slot or slot < 1 or slot > state.pedestals then
		return nil
	end
	for _, owned in ipairs(state.owned) do
		if owned.slot == slot then
			return nil
		end
	end
	local record = {
		id = brainrotId,
		mutation = mutationName or "None",
		slot = slot,
		model = model,
		income = BrainrotData.GetEffectiveIncome(brainrot, mutationName or "None"),
	}
	table.insert(state.owned, record)
	return record
end

function GameState.RemoveOwned(player, model)
	local state = GameState.Get(player)
	if not state then
		return nil
	end
	for index, owned in ipairs(state.owned) do
		if owned.model == model then
			table.remove(state.owned, index)
			return owned
		end
	end
	return nil
end

function GameState.GetOwnedByModel(player, model)
	local state = GameState.Get(player)
	if not state then
		return nil
	end
	for _, owned in ipairs(state.owned) do
		if owned.model == model then
			return owned
		end
	end
	return nil
end

function GameState.SetCarrying(player, record)
	local state = GameState.Get(player)
	if not state then
		return false
	end
	state.carrying = record
	return true
end

function GameState.ClearCarrying(player)
	local state = GameState.Get(player)
	if state then
		state.carrying = nil
	end
end

function GameState.AddRivalOwned(record)
	table.insert(rivalState.owned, record)
	return record
end

function GameState.RemoveRivalOwned(model)
	for index, owned in ipairs(rivalState.owned) do
		if owned.model == model then
			table.remove(rivalState.owned, index)
			return owned
		end
	end
	return nil
end

function GameState.GetRivalOwned()
	return rivalState.owned
end

function GameState.SetRivalCarrying(record)
	rivalState.carrying = record
end

function GameState.ClearRivalCarrying()
	rivalState.carrying = nil
end

function GameState.GetTitle(player)
	local state = GameState.Get(player)
	local index = math.min((state and state.rebirths or 0) + 1, #titles)
	return titles[index]
end

function GameState.GetRebirthMultiplier(player)
	local state = GameState.Get(player)
	return 1 + (state and state.rebirths or 0) * 0.5
end

function GameState.GetIncomeMultiplier(player)
	local state = GameState.Get(player)
	if not state then
		return 1
	end
	local goldenMultiplier = state.goldenUntil > now() and 2 or 1
	return GameState.GetRebirthMultiplier(player) * state.incomeUpgrade * goldenMultiplier
end

function GameState.GetBaseIncome(player)
	local state = GameState.Get(player)
	if not state then
		return 0
	end
	local total = 0
	for _, owned in ipairs(state.owned) do
		total += owned.income or 0
	end
	return total
end

function GameState.GetTotalIncome(player)
	return GameState.GetBaseIncome(player) * GameState.GetIncomeMultiplier(player)
end

function GameState.GetLockRemaining(player)
	local state = GameState.Get(player)
	if not state then
		return 0
	end
	return math.max(0, state.lockUntil - now())
end

function GameState.IsLocked(player)
	return GameState.GetLockRemaining(player) > 0
end

function GameState.GetLockCooldownRemaining(player)
	local state = GameState.Get(player)
	if not state or state.lockUntil > now() then
		return 0
	end
	return math.max(0, state.lockCooldownUntil - now())
end

function GameState.CanLock(player)
	local state = GameState.Get(player)
	return state ~= nil and state.lockUntil <= now() and state.lockCooldownUntil <= now()
end

function GameState.ActivateLock(player)
	local state = GameState.Get(player)
	if not GameState.CanLock(player) then
		return false
	end
	state.lockUntil = now() + 30
	state.lockCooldownUntil = now() + 90
	return true
end

function GameState.SetGoldenUntil(player, untilTime)
	local state = GameState.Get(player)
	if state then
		state.goldenUntil = untilTime
	end
end

function GameState.GetGoldenRemaining(player)
	local state = GameState.Get(player)
	if not state then
		return 0
	end
	return math.max(0, state.goldenUntil - now())
end

function GameState.GetUpgradeCost(state, upgradeType)
	if upgradeType == "Pedestal" then
		if state.pedestals >= 12 then
			return nil
		end
		return math.floor(3000 * (2 ^ (state.pedestals - 6)))
	elseif upgradeType == "Conveyor" then
		if state.conveyorLevel >= 5 then
			return nil
		end
		return math.floor(5000 * (2 ^ state.conveyorLevel))
	elseif upgradeType == "Income" then
		if state.incomeUpgrade >= 2.25 then
			return nil
		end
		-- Round to the nearest $100: the raw 2^(x-1) curve lands on odd
		-- figures ($9,514, $11,313...) that read as bugs in the HUD.
		local raw = 8000 * (2 ^ (state.incomeUpgrade - 1))
		return math.floor(raw / 100 + 0.5) * 100
	end
	return nil
end

function GameState.BuyUpgrade(player, upgradeType)
	local state = GameState.Get(player)
	if not state then
		return false, "No player state"
	end
	local cost = GameState.GetUpgradeCost(state, upgradeType)
	if not cost then
		return false, "Upgrade maxed"
	end
	if not GameState.SpendCash(player, cost) then
		return false, "Not enough cash"
	end
	if upgradeType == "Pedestal" then
		state.pedestals += 1
	elseif upgradeType == "Conveyor" then
		state.conveyorLevel += 1
	elseif upgradeType == "Income" then
		state.incomeUpgrade += 0.25
	else
		state.cash += cost
		return false, "Unknown upgrade"
	end
	return true, cost
end

function GameState.GetRebirthRequirements(player)
	local state = GameState.Get(player)
	local rebirths = state and state.rebirths or 0
	-- Cash need grows 1.75x per rebirth (was 2x): income only grows 1.5x
	-- per rebirth, so the old curve made each rebirth strictly harder
	-- than the last and priced late rebirths out of reach.
	return 3 + rebirths, math.floor(25000 * (1.75 ^ rebirths))
end

function GameState.CanRebirth(player)
	local state = GameState.Get(player)
	if not state then
		return false, "No player state"
	end
	local count, cash = GameState.GetRebirthRequirements(player)
	if #state.owned < count then
		return false, ("Need %d brainrots"):format(count)
	end
	if state.cash < cash then
		return false, ("Need $%s"):format(tostring(cash))
	end
	return true
end

function GameState.Rebirth(player)
	local state = GameState.Get(player)
	local allowed, reason = GameState.CanRebirth(player)
	if not allowed then
		return false, reason
	end
	local count, cash = GameState.GetRebirthRequirements(player)
	state.cash -= cash
	-- Hand the cleared records back so the caller (Shop) can destroy the
	-- brainrot models still standing on the pedestals. Clearing state.owned
	-- alone would leave orphan models floating on the base forever.
	local removed = state.owned
	state.owned = {}
	state.rebirths += 1
	state.carrying = nil
	return true, count, removed
end

function GameState.Remove(player)
	playerStates[player.UserId] = nil
end

return GameState
