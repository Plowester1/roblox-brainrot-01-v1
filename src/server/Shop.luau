-- Shop.luau
-- Handles buy/steal/lock/rebirth/upgrade requests from RemoteEvents, validates
-- them (cash, pedestal free, lock state), and updates GameState.

local Shop = {}

local GameState = require(script.Parent.GameState)
local BrainrotData = require(script.Parent.BrainrotData)
local WorldBuilder = require(script.Parent.WorldBuilder)
local Conveyor = require(script.Parent.Conveyor)
local Rival = require(script.Parent.Rival)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LOCK_DURATION = 30
local LOCK_COOLDOWN = 60
local lastLockAt = 0

-- Buy a brainrot off the conveyor and place it on a free pedestal.
function Shop.Buy(player, model)
	local data = GameState.Get(player)
	if not data then
		return false, "Not ready"
	end
	local lane = Conveyor.Consume(model)
	if not lane then
		return false, "Already taken"
	end
	local cost = lane.entry.baseMoney
	if not GameState.Spend(player, cost) then
		-- refund the lane brainrot
		lane.walking = true
		return false, "Not enough cash"
	end
	if not GameState.HasFreePedestal(player) then
		lane.walking = true
		GameState.AddCash(player, cost)
		return false, "No free pedestal"
	end
	local entry = { name = lane.entry.name, tier = lane.entry.tier, mutation = lane.mutation, baseMoney = lane.entry.baseMoney }
	GameState.AddOwned(player, entry)
	return true, entry
end

-- Steal a brainrot from the rival base and carry it back to the player's base.
function Shop.StealFromRival(player, model)
	local data = GameState.Get(player)
	if not data then
		return false, "Not ready"
	end
	if not GameState.HasFreePedestal(player) then
		return false, "No free pedestal"
	end
	-- For simplicity a stolen rival brainrot is a random Epic; the reward is the
	-- free brainrot and some cash.
	local cost = 0
	local entry = { name = BrainrotData.PickName("Epic"), tier = "Epic", mutation = BrainrotData.PickMutation(), baseMoney = 20 }
	GameState.AddOwned(player, entry)
	GameState.AddCash(player, 25)
	if model then
		model:Destroy()
	end
	return true, entry
end

-- Lock the base against the rival for 30s, then a 60s cooldown.
function Shop.LockBase(player)
	local now = os.clock()
	if now < lastLockAt + LOCK_COOLDOWN then
		return false, "On cooldown"
	end
	GameState.SetLock(player, LOCK_DURATION, now + LOCK_DURATION)
	lastLockAt = now
	return true, LOCK_DURATION
end

-- Slap the rival bot, knocking it back and dropping what it carries.
function Shop.SlapRival(player)
	return Rival.Slap(player)
end

-- Rebirth: spend cash to reset cash/base and gain +50% income permanently.
function Shop.Rebirth(player)
	local count = GameState.DoRebirth(player)
	if not count then
		return false, "Not enough cash"
	end
	return true, count
end

-- Upgrades: more pedestals, faster conveyor, bigger income multiplier.
function Shop.BuyUpgrade(player, upgrade)
	local data = GameState.Get(player)
	if not data then
		return false, "Not ready"
	end
	if upgrade == "pedestal" then
		local cost = GameState.PedestalCost(player)
		if not GameState.Spend(player, cost) then
			return false, "Not enough cash"
		end
		if not GameState.AddPedestal(player) then
			GameState.AddCash(player, cost)
			return false, "Max pedestals"
		end
		return true, { pedestals = GameState.MaxPedestals(player) }
	elseif upgrade == "conveyor" then
		local cost = GameState.ConveyorSpeedCost(player)
		if not GameState.Spend(player, cost) then
			return false, "Not enough cash"
		end
		GameState.UpgradeConveyor(player)
		return true, { conveyor = GameState.GetConveyorSpeed(player) }
	elseif upgrade == "income" then
		local cost = GameState.IncomeUpgradeCost(player)
		if not GameState.Spend(player, cost) then
			return false, "Not enough cash"
		end
		GameState.UpgradeIncome(player)
		return true, { income = GameState.GetIncomeMult(player) }
	end
	return false, "Unknown upgrade"
end

return Shop