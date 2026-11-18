local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BrainrotData = require(script.Parent.BrainrotData)

-- GameState is THE single source of truth. Server modules read/write state here,
-- and every change to player-facing numbers is pushed to the owning client.

local GameState = {}

local BASE_CASH = 150
local BASE_PEDESTALS = 4
local MAX_PEDESTALS = 12
local INCOME_PER_REBIRTH = 0.5 -- +50% per rebirth
local UPGRADE_COST_BASE = 250

-- Player -> state record
local states = {}
-- id -> pedestal mapping (which owned brainrot sits on which pedestal)
local pedestalUsage = {} -- key "playerId:pedestal" -> brainrotId
local ownedBrainrotModels = {} -- brainrotId -> { model, label, ownerId }

function GameState.initState(player)
	states[player.UserId] = {
		userId = player.UserId,
		cash = BASE_CASH,
		incomeMult = 1,
		rebirths = 0,
		pedestals = BASE_PEDESTALS,
		owned = {}, -- brainrotId -> { defId, name, rarity, base, mutation, income }
		lockUntil = 0,
		lockCooldownUntil = 0,
		title = "Brainrot Noob",
		carryingId = nil,
	}
	GameState.sync(player)
	return states[player.UserId]
end

function GameState.getState(player)
	return states[player.UserId]
end

function GameState.removePlayer(player)
	states[player.UserId] = nil
end

function GameState.getRemoteEvents()
	return ReplicatedStorage:WaitForChild("RemoteEvents")
end

function GameState.sync(player)
	local st = states[player.UserId]
	if not st then
		return
	end
	local events = GameState.getRemoteEvents()
	local ev = events:FindFirstChild("SyncState")
	if ev then
		local payload = {
			cash = math.floor(st.cash),
			incomeMult = st.incomeMult,
			rebirths = st.rebirths,
			pedestals = st.pedestals,
			maxPedestals = MAX_PEDESTALS,
			owned = st.owned,
			title = st.title,
			lockUntil = st.lockUntil,
			lockCooldownUntil = st.lockCooldownUntil,
		}
		ev:FireClient(player, payload)
	end
end

function GameState.broadcastAll()
	for _, plr in ipairs(Players:GetPlayers()) do
		GameState.sync(plr)
	end
end

function GameState.addCash(player, amount)
	local st = states[player.UserId]
	if not st then
		return
	end
	st.cash += amount
	GameState.sync(player)
	return st.cash
end

function GameState.trySpend(player, amount)
	local st = states[player.UserId]
	if not st then
		return false
	end
	if st.cash < amount then
		return false
	end
	st.cash -= amount
	return true
end

-- Income of one owned brainrot after rarity mult? Income = base * mutationMult * player incomeMult.
function GameState.brainrotIncome(player, brainrot)
	local st = states[player.UserId]
	local data = BrainrotData.getBrainrotById(brainrot.defId)
	local mult = BrainrotData.getMutationMultiplier(brainrot.mutation)
	return (data and data.base or 0) * mult * (st.incomeMult or 1)
end

function GameState.totalIncome(player)
	local st = states[player.UserId]
	if not st then
		return 0
	end
	local total = 0
	for _, b in pairs(st.owned) do
		total += GameState.brainrotIncome(player, b)
	end
	return total
end

-- Count the player's owned brainrots across rarities (used by Rebirth).
function GameState.countByRarity(player)
	local st = states[player.UserId]
	local counts = {}
	for _, b in pairs(st.owned) do
		counts[b.rarity] = (counts[b.rarity] or 0) + 1
	end
	return counts
end

function GameState.findFreePedestal(player)
	local st = states[player.UserId]
	for p = 1, st.pedestals do
		if not pedestalUsage[player.UserId .. ":" .. p] then
			return p
		end
	end
	return nil
end

function GameState.assignPedestal(player, pedestal, brainrotId)
	pedestalUsage[player.UserId .. ":" .. pedestal] = brainrotId
end

function GameState.releasePedestal(player, pedestal)
	pedestalUsage[player.UserId .. ":" .. pedestal] = nil
end

function GameState.getPedestalFor(player, brainrotId)
	for p, id in pairs(pedestalUsage) do
		if id == brainrotId then
			local key = tostring(player.UserId) .. ":"
			local s, e = string.find(p, key)
			if s == 1 then
				return tonumber(string.sub(p, e + 1))
			end
		end
	end
	return nil
end

function GameState.isPedestalFree(player, pedestal)
	return pedestalUsage[player.UserId .. ":" .. pedestal] == nil
end

function GameState.anyPedestalFree(player)
	return GameState.findFreePedestal(player) ~= nil
end

-- Record an owned brainrot model so WorldBuilder can move/recolor it.
function GameState.registerBrainrotModel(brainrotId, model)
	ownedBrainrotModels[brainrotId] = model
end

function GameState.getBrainrotModel(brainrotId)
	return ownedBrainrotModels[brainrotId]
end

function GameState.unregisterBrainrotModel(brainrotId)
	ownedBrainrotModels[brainrotId] = nil
end

function GameState.getMaxPedestals()
	return MAX_PEDESTALS
end

function GameState.getPedestalUpgradeCost(player, nextCount)
	local st = states[player.UserId]
	local n = nextCount or (st.pedestals + 1)
	return math.floor(UPGRADE_COST_BASE * n * (1 + st.rebirths * 0.5))
end

function GameState.getIncomeMult(player)
	return states[player.UserId].incomeMult
end

function GameState.setCarrying(player, brainrotId)
	states[player.UserId].carryingId = brainrotId
end

function GameState.getCarrying(player)
	return states[player.UserId].carryingId
end

return GameState