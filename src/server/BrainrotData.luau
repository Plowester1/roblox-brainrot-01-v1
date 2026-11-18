local BrainrotData = {}

-- Seven rarity tiers from Common to Secret. Higher index = rarer and richer.
local RARITY_TIERS = {
	{ name = "Common",        index = 1, weight = 44, color = Color3.fromRGB(127, 127, 127), baseIncome = 4 },
	{ name = "Rare",          index = 2, weight = 26, color = Color3.fromRGB(38, 140, 242),  baseIncome = 12 },
	{ name = "Epic",          index = 3, weight = 15, color = Color3.fromRGB(184, 77, 230),  baseIncome = 34 },
	{ name = "Legendary",     index = 4, weight = 8,  color = Color3.fromRGB(242, 179, 26),  baseIncome = 95 },
	{ name = "Mythic",        index = 5, weight = 4,  color = Color3.fromRGB(230, 51, 77),   baseIncome = 260 },
	{ name = "Brainrot God",  index = 6, weight = 2,  color = Color3.fromRGB(26, 230, 217),  baseIncome = 720 },
	{ name = "Secret",        index = 7, weight = 1,  color = Color3.fromRGB(255, 255, 255), baseIncome = 2400 },
}

local MUTATION_MULTIPLIERS = {
	None = 1,
	Golden = 2,
	Diamond = 5,
	Rainbow = 10,
	Bloodrot = 25,
}

local MUTATION_CHANCES = {
	Golden = 0.06,
	Diamond = 0.03,
	Rainbow = 0.01,
	Bloodrot = 0.005,
}

local MUTATION_COLORS = {
	Golden = Color3.fromRGB(255, 215, 0),
	Diamond = Color3.fromRGB(80, 220, 255),
	Rainbow = Color3.fromRGB(255, 105, 180),
	Bloodrot = Color3.fromRGB(160, 20, 25),
}

-- The absurd Italian-brainrot cast.
local BRAINROTS = {
	{ id = "tung",        name = "Tung Tung Tung Sahur",         rarity = "Common",       base = 2,   color = Color3.fromRGB(230, 179, 64),  size = 1 },
	{ id = "tralalero",   name = "Tralalero Tralala",            rarity = "Common",       base = 2,   color = Color3.fromRGB(191, 140, 242), size = 1 },
	{ id = "lirili",      name = "Lirili Larila",                rarity = "Common",       base = 3,   color = Color3.fromRGB(102, 204, 242), size = 1 },
	{ id = "bombardiro",  name = "Bombardiro Crocodilo",         rarity = "Rare",         base = 8,   color = Color3.fromRGB(26, 191, 77),   size = 1.1 },
	{ id = "ballerina",   name = "Ballerina Cappuccina",         rarity = "Rare",         base = 9,   color = Color3.fromRGB(242, 115, 191), size = 1.05 },
	{ id = "chimpanzini", name = "Chimpanzini Bananini",         rarity = "Epic",         base = 24,  color = Color3.fromRGB(250, 217, 89),  size = 1.15 },
	{ id = "frigo",       name = "Frigo Camelo",                 rarity = "Epic",         base = 27,  color = Color3.fromRGB(38, 204, 217),  size = 1.2 },
	{ id = "vaca",        name = "La Vaca Saturno Saturnita",    rarity = "Legendary",    base = 70,  color = Color3.fromRGB(102, 64, 153),  size = 1.3 },
	{ id = "trippi",      name = "Trippi Troppi",                rarity = "Legendary",    base = 76,  color = Color3.fromRGB(230, 51, 230),  size = 1.25 },
	{ id = "giraffa",     name = "Giraffa Celeste",              rarity = "Mythic",       base = 200, color = Color3.fromRGB(64, 191, 250),  size = 1.4 },
	{ id = "assassino",   name = "Cappuccino Assassino",         rarity = "Mythic",       base = 230, color = Color3.fromRGB(140, 89, 51),   size = 1.35 },
	{ id = "pot",         name = "Pot Hotspot",                  rarity = "Brainrot God", base = 660, color = Color3.fromRGB(89, 230, 89),   size = 1.45 },
	{ id = "sfinge",      name = "Sfinge Pinguino",              rarity = "Secret",       base = 2100, color = Color3.fromRGB(255, 128, 128), size = 1.7 },
}

local byId = {}
for _, b in ipairs(BRAINROTS) do
	byId[b.id] = b
end

local rarityByName = {}
for _, t in ipairs(RARITY_TIERS) do
	rarityByName[t.name] = t
end

local RARITY_MULT = {}
for _, t in ipairs(RARITY_TIERS) do
	RARITY_MULT[t.name] = t.index * t.index -- simple scaling for bonus packs
end

function BrainrotData.getBrainrots()
	return BRAINROTS
end

function BrainrotData.getBrainrotById(id)
	return byId[id]
end

function BrainrotData.getRarityTiers()
	return RARITY_TIERS
end

function BrainrotData.getRarity(name)
	return rarityByName[name]
end

function BrainrotData.getMutationMultipliers()
	return MUTATION_MULTIPLIERS
end

function BrainrotData.getMutationMultiplier(name)
	return MUTATION_MULTIPLIERS[name] or 1
end

function BrainrotData.getMutationChances()
	return MUTATION_CHANCES
end

function BrainrotData.getMutationColor(name)
	return MUTATION_COLORS[name]
end

-- Weighted rarity pick. Brainrot Rain forces Epic or better.
function BrainrotData.rollRarity(epicOrBetter)
	local pool = {}
	for _, t in ipairs(RARITY_TIERS) do
		if not epicOrBetter or t.index >= 3 then
			table.insert(pool, t)
		end
	end
	local total = 0
	for _, t in ipairs(pool) do
		total += t.weight
	end
	local r = math.random() * total
	for _, t in ipairs(pool) do
		r -= t.weight
		if r <= 0 then
			return t
		end
	end
	return pool[#pool]
end

-- Pick a random brainrot of a rarity (or any if nil).
function BrainrotData.rollBrainrot(rarityName)
	local pool = {}
	for _, b in ipairs(BRAINROTS) do
		if rarityName == nil or b.rarity == rarityName then
			table.insert(pool, b)
		end
	end
	if #pool == 0 then
		pool = BRAINROTS
	end
	return pool[math.random(1, #pool)]
end

-- Roll a mutation (may be None).
function BrainrotData.rollMutation()
	local total = 0
	for _, c in pairs(MUTATION_CHANCES) do
		total += c
	end
	local r = math.random() * total
	local acc = 0
	local names = { "Golden", "Diamond", "Rainbow", "Bloodrot" }
	for _, name in ipairs(names) do
		acc += MUTATION_CHANCES[name]
		if r <= acc then
			return name
		end
	end
	return "None"
end

return BrainrotData