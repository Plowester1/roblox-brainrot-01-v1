-- BrainrotData.luau
-- The catalog of every brainrot, rarity tier, mutation, and spawn weight.
-- Loads the shared GameData.json (a Rojo ModuleScript) and exposes lookups.

local GameData = require(script.Parent.Parent.Shared.GameData)

local BrainrotData = {}

BrainrotData.game = GameData.game
BrainrotData.mutations = GameData.mutations
BrainrotData.rarities = GameData.rarities
BrainrotData.brainrots = GameData.brainrots
BrainrotData.titles = GameData.titles

-- Indexes by name for fast lookups.
local brainrotByName = {}
for _, b in ipairs(BrainrotData.brainrots) do
	brainrotByName[b.name] = b
end

local rarityByName = {}
for _, r in ipairs(BrainrotData.rarities) do
	rarityByName[r.name] = r
end

local mutationByName = {}
for _, m in ipairs(BrainrotData.mutations) do
	mutationByName[m.name] = m
end

function BrainrotData.getBrainrot(name)
	return brainrotByName[name]
end

function BrainrotData.getRarity(name)
	return rarityByName[name]
end

function BrainrotData.getMutation(name)
	return mutationByName[name]
end

-- Weighted random rarity roll (returns a rarity name).
function BrainrotData.rollRarity()
	local total = 0
	for _, r in ipairs(BrainrotData.rarities) do
		total += r.weight
	end
	local roll = math.random() * total
	local acc = 0
	for _, r in ipairs(BrainrotData.rarities) do
		acc += r.weight
		if roll <= acc then
			return r.name
		end
	end
	return BrainrotData.rarities[#BrainrotData.rarities].name
end

-- Weighted random mutation roll (returns a mutation name).
function BrainrotData.rollMutation()
	local total = 0
	for _, m in ipairs(BrainrotData.mutations) do
		total += m.chance
	end
	local roll = math.random() * total
	local acc = 0
	for _, m in ipairs(BrainrotData.mutations) do
		acc += m.chance
		if roll <= acc then
			return m.name
		end
	end
	return "Normal"
end

-- Pick a random brainrot of a given rarity (weighted evenly among them).
function BrainrotData.pickOfRarity(rarityName)
	local pool = {}
	for _, b in ipairs(BrainrotData.brainrots) do
		if b.rarity == rarityName then
			table.insert(pool, b)
		end
	end
	if #pool == 0 then
		return nil
	end
	return pool[math.random(#pool)]
end

-- A full spawn: rarity, brainrot def, mutation. Returns a table of choices.
function BrainrotData.rollSpawn(forcedRarity)
	local rarity = forcedRarity or BrainrotData.rollRarity()
	local brainrot = BrainrotData.pickOfRarity(rarity)
	local mutation = BrainrotData.rollMutation()
	return {
		rarity = rarity,
		brainrot = brainrot,
		mutation = mutation,
	}
end

function BrainrotData.totalMutationMult(mutationName)
	return mutationByName[mutationName] and mutationByName[mutationName].mult or 1
end

-- Effective income per second for a given brainrot name + mutation.
function BrainrotData.effectiveIncome(brainrotName, mutationName)
	local b = brainrotByName[brainrotName]
	local m = mutationByName[mutationName or "Normal"]
	if not b or not m then
		return 0
	end
	return b.income * m.mult
end

return BrainrotData