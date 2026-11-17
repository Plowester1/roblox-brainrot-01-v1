-- BrainrotData.luau
-- The catalog: every brainrot, rarity tiers, mutation multipliers, spawn weights.
-- Single source of truth for what exists in the game. Read by GameState, the
-- conveyor (spawning), the shop (buy/pedestal), and the client (labels/collection).

local BrainrotData = {}

-- The 7 rarity tiers, ordered from common to rarest.
-- Each tier has: name, color (BrickColor-ish rgb), base dollars-per-second,
-- spawn weight (how often it appears on the conveyor), pedestal slot index that
-- the pedestal display uses.
local TIER_ORDER = { "Common", "Rare", "Epic", "Legendary", "Mythic", "Brainrot God", "Secret" }

BrainrotData.TierOrder = TIER_ORDER

BrainrotData.Tiers = {
	Common = {
		rank = 1,
		color = Color3.fromRGB(176, 220, 160),
		baseMoney = 2,
		weight = 58,
	},
	Rare = {
		rank = 2,
		color = Color3.fromRGB(120, 190, 255),
		baseMoney = 6,
		weight = 27,
	},
	Epic = {
		rank = 3,
		color = Color3.fromRGB(190, 120, 255),
		baseMoney = 15,
		weight = 10,
	},
	Legendary = {
		rank = 4,
		color = Color3.fromRGB(255, 200, 90),
		baseMoney = 35,
		weight = 5,
	},
	Mythic = {
		rank = 5,
		color = Color3.fromRGB(255, 120, 190),
		baseMoney = 80,
		weight = 1.8,
	},
	["Brainrot God"] = {
		rank = 6,
		color = Color3.fromRGB(255, 220, 60),
		baseMoney = 180,
		weight = 0.35,
	},
	Secret = {
		rank = 7,
		color = Color3.fromRGB(255, 80, 90),
		baseMoney = 420,
		weight = 0.06,
	},
}

-- The absurd Italian-brainrot names. Each entry: name, tier, base dollars/sec.
-- Higher rarity names sit higher up the ladderhouse.
BrainrotData.Catalog = {
	{ name = "Frigo Camelo", tier = "Common", baseMoney = 2 },
	{ name = "Giraffa Celeste", tier = "Common", baseMoney = 3 },
	{ name = "Trippi Troppi", tier = "Common", baseMoney = 4 },
	{ name = "Chimpanzini Bananini", tier = "Rare", baseMoney = 6 },
	{ name = "Pot Hotspot", tier = "Rare", baseMoney = 7 },
	{ name = "Cappuccino Assassino", tier = "Rare", baseMoney = 9 },
	{ name = "Lirili Larila", tier = "Epic", baseMoney = 15 },
	{ name = "Tralalero Tralala", tier = "Epic", baseMoney = 18 },
	{ name = "Tung Tung Tung Sahur", tier = "Legendary", baseMoney = 35 },
	{ name = "Bombardiro Crocodilo", tier = "Legendary", baseMoney = 42 },
	{ name = "Ballerina Cappuccina", tier = "Mythic", baseMoney = 80 },
	{ name = "La Vaca Saturno Saturnita", tier = "Mythic", baseMoney = 96 },
	{ name = "Lirili Larila Supreme", tier = "Brainrot God", baseMoney = 180 },
	{ name = "??? Sahur", tier = "Secret", baseMoney = 420 },
}

-- Mutation multipliers, applied on top of the base dollars/sec.
-- Mutations also tint the model and show up in the floating label.
BrainrotData.Mutations = {
	None = { mult = 1, color = Color3.fromRGB(255, 255, 255), label = "" },
	Golden = { mult = 2, color = Color3.fromRGB(255, 215, 0), label = "Golden" },
	Diamond = { mult = 5, color = Color3.fromRGB(180, 240, 255), label = "Diamond" },
	Rainbow = { mult = 10, color = Color3.fromRGB(255, 140, 255), label = "Rainbow" },
	Bloodrot = { mult = 25, color = Color3.fromRGB(200, 40, 40), label = "Bloodrot" },
}

-- The chance each spawned brainrot is mutated (otherwise None).
BrainrotData.MutationChance = {
	Golden = 0.06,
	Diamond = 0.025,
	Rainbow = 0.012,
	Bloodrot = 0.004,
}

-- Cost to buy a brainrot off the conveyor, before any upgrade multiplier.
-- Roughly (10 + tier * 15) base, scaled by the player's owned count a touch.
function BrainrotData.BuyCost(tier)
	local rank = BrainrotData.Tiers[tier] and BrainrotData.Tiers[tier].rank or 1
	return math.floor(12 + rank * rank * 6)
end

-- Pick a tier at random weighted by each tier's spawn weight.
function BrainrotData.PickTier()
	local total = 0
	for _, tier in ipairs(TIER_ORDER) do
		total = total + BrainrotData.Tiers[tier].weight
	end
	local roll = math.random() * total
	local acc = 0
	for _, tier in ipairs(TIER_ORDER) do
		acc = acc + BrainrotData.Tiers[tier].weight
		if roll <= acc then
			return tier
		end
	end
	return "Common"
end

-- Pick a random brainrot name belonging to a tier.
function BrainrotData.PickName(tier)
	local pool = {}
	for _, entry in ipairs(BrainrotData.Catalog) do
		if entry.tier == tier then
			table.insert(pool, entry.name)
		end
	end
	if #pool == 0 then
		return "Frigo Camelo"
	end
	return pool[math.random(1, #pool)]
end

-- Pick a mutation at random following the mutation chances.
function BrainrotData.PickMutation()
	local roll = math.random()
	local acc = 0
	for _, mut in ipairs({ "Golden", "Diamond", "Rainbow", "Bloodrot" }) do
		acc = acc + BrainrotData.MutationChance[mut]
		if roll <= acc then
			return mut
		end
	end
	return "None"
end

return BrainrotData