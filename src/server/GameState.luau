-- GameState.luau
-- THE single source of truth for server-side state: player cash, owned brainrots,
-- pedestals, rebirths, locks, multipliers. All other server modules read/write
-- through this module so the income loop and the shop never disagree.

local GameState = {}

local BrainrotData = require(script.Parent.BrainrotData)

local PlayerData = {}
local CurrentLockTime = 0
local GoldenHourUntil = 0

local BASE_MAX_PEDESTALS = 8
local MAX_PEDESTALS_CAP = 12

-- ---------------------------------------------------------------------------
-- Player data lifecycle
-- ---------------------------------------------------------------------------
function GameState.Reset(player)
	PlayerData[player] = {
		cash = 120,
		rebirths = 0,
		pedestals = 3,
		owned = {},          -- array of { name, tier, mutation, baseMoney }
		conveyorSpeed = 1,   -- upgrade multiplier for spawn rate
		incomeMult = 1,      -- upgrade multiplier for $/s
		collected = {},      -- set of tier -> count, for the collection panel
	}
end

function GameState.Get(player)
	return PlayerData[player]
end

function GameState.Remove(player)
	PlayerData[player] = nil
end

-- ---------------------------------------------------------------------------
-- Cash
-- ---------------------------------------------------------------------------
function GameState.AddCash(player, amount)
	local data = PlayerData[player]
	if data then
		data.cash = data.cash + amount
	end
end

function GameState.GetCash(player)
	local data = PlayerData[player]
	return data and data.cash or 0
end

function GameState.Spend(player, amount)
	local data = PlayerData[player]
	if not data then
		return false
	end
	if data.cash < amount then
		return false
	end
	data.cash = data.cash - amount
	return true
end

-- ---------------------------------------------------------------------------
-- Income calculation
-- ---------------------------------------------------------------------------
-- Total dollars per second from all owned brainrots, applying mutation mult,
-- the income upgrade mult, the permanent rebirth mult, and Golden Hour.
function GameState.IncomePerSecond(player)
	local data = PlayerData[player]
	if not data then
		return 0
	end
	local perRebirth = 1 + data.rebirths * 0.5
	local perUpgrade = data.incomeMult
	local golden = 1
	if os.clock() < GoldenHourUntil then
		golden = 2
	end
	local total = 0
	for _, b in ipairs(data.owned) do
		local mut = BrainrotData.Mutations[b.mutation] or BrainrotData.Mutations.None
		total = total + b.baseMoney * mut.mult
	end
	return total * perRebirth * perUpgrade * golden
end

-- ---------------------------------------------------------------------------
-- Owned brainrots / pedestals
-- ---------------------------------------------------------------------------
function GameState.CountOwned(player)
	local data = PlayerData[player]
	return data and #data.owned or 0
end

function GameState.MaxPedestals(player)
	local data = PlayerData[player]
	if not data then
		return 0
	end
	return math.min(data.pedestals, MAX_PEDESTALS_CAP)
end

function GameState.HasFreePedestal(player)
	return GameState.CountOwned(player) < GameState.MaxPedestals(player)
end

function GameState.AddOwned(player, brainrot)
	local data = PlayerData[player]
	if not data then
		return false
	end
	if not GameState.HasFreePedestal(player) then
		return false
	end
	table.insert(data.owned, brainrot)
	data.collected[brainrot.tier] = (data.collected[brainrot.tier] or 0) + 1
	return true
end

function GameState.RemoveOwned(player, index)
	local data = PlayerData[player]
	if not data or not data.owned[index] then
		return false
	end
	local b = data.owned[index]
	table.remove(data.owned, index)
	if b then
		local c = (data.collected[b.tier] or 0) - 1
		if c <= 0 then
			data.collected[b.tier] = nil
		else
			data.collected[b.tier] = c
		end
	end
	return true
end

function GameState.GetOwned(player)
	local data = PlayerData[player]
	return data and data.owned or {}
end

function GameState.GetCollection(player)
	local data = PlayerData[player]
	return data and data.collected or {}
end

-- ---------------------------------------------------------------------------
-- Upgrades
-- ---------------------------------------------------------------------------
function GameState.PedestalCost(player)
	local data = PlayerData[player]
	local owned = data and #(data.owned) or 0
	local cur = data and data.pedestals or BASE_MAX_PEDESTALS
	return math.floor(150 * cur)
end

function GameState.AddPedestal(player)
	local data = PlayerData[player]
	if data and data.pedestals < MAX_PEDESTALS_CAP then
		data.pedestals = data.pedestals + 1
		return true
	end
	return false
end

function GameState.ConveyorSpeedCost(player)
	local data = PlayerData[player]
	local lvl = data and data.conveyorSpeed or 1
	return math.floor(200 * lvl)
end

function GameState.UpgradeConveyor(player)
	local data = PlayerData[player]
	if data then
		data.conveyorSpeed = data.conveyorSpeed + 1
		return true
	end
	return false
end

function GameState.GetConveyorSpeed(player)
	local data = PlayerData[player]
	return data and data.conveyorSpeed or 1
end

function GameState.IncomeUpgradeCost(player)
	local data = PlayerData[player]
	local lvl = data and data.incomeMult or 1
	return math.floor(250 * lvl)
end

function GameState.UpgradeIncome(player)
	local data = PlayerData[player]
	if data then
		data.incomeMult = data.incomeMult + 0.25
		return true
	end
	return false
end

function GameState.GetIncomeMult(player)
	local data = PlayerData[player]
	return data and data.incomeMult or 1
end

-- ---------------------------------------------------------------------------
-- Rebirths
-- ---------------------------------------------------------------------------
-- Spend cash + clear the base, gain +50% income per rebirth permanently.
function GameState.RebirthCost(player)
	local data = PlayerData[player]
	local n = data and data.rebirths or 0
	return math.floor(500 * (n + 1) * (n + 1))
end

function GameState.DoRebirth(player)
	local data = PlayerData[player]
	if not data then
		return nil
	end
	local cost = GameState.RebirthCost(player)
	if data.cash < cost then
		return nil
	end
	data.cash = data.cash - cost
	data.rebirths = data.rebirths + 1
	data.owned = {}
	data.conveyorSpeed = 1
	data.incomeMult = 1
	return data.rebirths
end

function GameState.GetRebirths(player)
	local data = PlayerData[player]
	return data and data.rebirths or 0
end

-- ---------------------------------------------------------------------------
-- Base lock (anti-theft)
-- ---------------------------------------------------------------------------
function GameState.SetLock(player, duration, cooldownEnd)
	CurrentLockTime = cooldownEnd or (os.clock() + duration)
end

function GameState.IsLocked()
	return os.clock() < CurrentLockTime
end

function GameState.LockSecondsLeft()
	return math.max(0, CurrentLockTime - os.clock())
end

function GameState.CanLock(player)
	-- Only one global lock window at a time is enough for a single-player rival
	-- scenario; cooldown is tracked by the shop using the last-lock timestamp.
	return not GameState.IsLocked()
end

-- ---------------------------------------------------------------------------
-- Golden Hour (global double income for 60s)
-- ---------------------------------------------------------------------------
function GameState.StartGoldenHour(duration)
	GoldenHourUntil = os.clock() + (duration or 60)
end

function GameState.GoldenHourLeft()
	return math.max(0, GoldenHourUntil - os.clock())
end

function GameState.IsGoldenHour()
	return os.clock() < GoldenHourUntil
end

return GameState