-- GameState.luau
-- The single source of truth for every player's runtime state: cash, owned
-- brainrots, pedestals, rebirths, base lock, income multiplier, and title.
-- All other server modules read and write through this module.

local Players = game:GetService("Players")

local GameState = {}

GameState.PREFIX = "Brainrot_"
GameState.RIVAL_PREFIX = "RivalBrainrot_"
GameState.PLAYER_BASE = "PlayerBase"
GameState.RIVAL_BASE = "RivalBase"
GameState.BASES = "Bases"

-- playerState[userId] = { cash, pedestals, rebirths, lockUntil, ... }
local playerState = {}
local brainrotOwners = {}

local function newState()
	return {
		cash = 100,
		pedestals = 1,
		rebirths = 0,
		title = "Noob",
		lockUntil = 0,
		lockReadyAt = 0,
		incomeLevel = 1,
		conveyorLevel = 1,
	}
end

-- Ensure a state exists for a userId, creating a fresh one on first access.
function GameState.ensure(userId)
	local s = playerState[userId]
	if not s then
		s = newState()
		playerState[userId] = s
	end
	return s
end

function GameState.get(userId)
	return playerState[userId]
end

-- Remove all state for a leaving player (also clears owned brainrot models).
function GameState.remove(userId)
	for id, owner in pairs(brainrotOwners) do
		if owner == userId then
			brainrotOwners[id] = nil
		end
	end
	playerState[userId] = nil
end

-- Track/untrack who owns a brainrot model (by its unique id).
function GameState.claimBrainrot(id, userId)
	brainrotOwners[id] = userId
end

function GameState.releaseBrainrot(id)
	brainrotOwners[id] = nil
end

function GameState.ownerOf(id)
	return brainrotOwners[id]
end

-- Income multiplier: +50% per rebirth, plus a stacking upgrade bonus.
function GameState.getMultiplier(userId)
	local s = playerState[userId]
	if not s then
		return 1
	end
	local rebirthMult = 1 + s.rebirths * 0.5
	local upgradeMult = 1 + (s.incomeLevel - 1) * 0.15
	return rebirthMult * upgradeMult
end

-- Cash getters/setters (all go through GameState so income logic is central).
function GameState.getCash(userId)
	local s = playerState[userId]
	return s and s.cash or 0
end

function GameState.addCash(userId, amount)
	local s = GameState.ensure(userId)
	s.cash += amount
	return s.cash
end

function GameState.setCash(userId, amount)
	local s = GameState.ensure(userId)
	s.cash = amount
	return s.cash
end

-- Iterate all brainrot model ids owned by a userId. Calls fn(id, userId).
function GameState.forEachOwned(userId, fn)
	for id, owner in pairs(brainrotOwners) do
		if owner == userId then
			fn(id, owner)
		end
	end
end

-- Total income/sec for a player's owned brainrots, given a lookup of
-- income-per-id provided by the caller (keeps GameState decoupled from models).
function GameState.totalIncome(userId, incomeOf)
	local s = playerState[userId]
	if not s then
		return 0
	end
	local total = 0
	for id, owner in pairs(brainrotOwners) do
		if owner == userId then
			total += incomeOf(id) or 0
		end
	end
	return total * GameState.getMultiplier(userId)
end

return GameState