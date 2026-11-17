local BrainrotData = {}

local rarities = {
	{name = "Common", color = Color3.fromRGB(173, 181, 190), weight = 50, income = 1},
	{name = "Rare", color = Color3.fromRGB(54, 145, 255), weight = 25, income = 4},
	{name = "Epic", color = Color3.fromRGB(183, 73, 255), weight = 13, income = 12},
	{name = "Legendary", color = Color3.fromRGB(255, 169, 38), weight = 7, income = 40},
	{name = "Mythic", color = Color3.fromRGB(255, 55, 153), weight = 3.5, income = 140},
	{name = "Brainrot God", color = Color3.fromRGB(45, 244, 232), weight = 1.4, income = 520},
	{name = "Secret", color = Color3.fromRGB(83, 54, 128), weight = 0.1, income = 2200},
}

local mutations = {
	{name = "None", multiplier = 1, color = Color3.fromRGB(255, 255, 255), weight = 1000},
	{name = "Golden", multiplier = 2, color = Color3.fromRGB(255, 191, 39), weight = 12},
	{name = "Diamond", multiplier = 5, color = Color3.fromRGB(74, 224, 255), weight = 5},
	{name = "Rainbow", multiplier = 10, color = Color3.fromRGB(238, 70, 255), weight = 1.5},
	{name = "Bloodrot", multiplier = 25, color = Color3.fromRGB(178, 12, 25), weight = 0.35},
}

local brainrots = {
	{id = "tung", name = "Tung Tung Tung Sahur", rarity = "Common", income = 2, price = 250, color = Color3.fromRGB(232, 187, 104), size = Vector3.new(2.2, 3.8, 2.2), weight = 15},
	{id = "tralalero", name = "Tralalero Tralala", rarity = "Common", income = 3, price = 350, color = Color3.fromRGB(58, 145, 235), size = Vector3.new(2.6, 3.2, 2.2), weight = 15},
	{id = "ballerina", name = "Ballerina Cappuccina", rarity = "Common", income = 4, price = 500, color = Color3.fromRGB(244, 119, 181), size = Vector3.new(2.1, 3.5, 2.1), weight = 15},
	{id = "bombardiro", name = "Bombardiro Crocodilo", rarity = "Rare", income = 8, price = 900, color = Color3.fromRGB(71, 184, 89), size = Vector3.new(3.2, 2.7, 2.6), weight = 12},
	{id = "lirili", name = "Lirili Larila", rarity = "Rare", income = 10, price = 1100, color = Color3.fromRGB(224, 199, 81), size = Vector3.new(2.2, 4.0, 2.2), weight = 12},
	{id = "chimpanzini", name = "Chimpanzini Bananini", rarity = "Rare", income = 12, price = 1300, color = Color3.fromRGB(158, 97, 46), size = Vector3.new(2.4, 3.4, 2.4), weight = 12},
	{id = "lavaca", name = "La Vaca Saturno Saturnita", rarity = "Epic", income = 25, price = 2600, color = Color3.fromRGB(191, 46, 215), size = Vector3.new(2.8, 3.8, 2.5), weight = 8},
	{id = "frigo", name = "Frigo Camelo", rarity = "Epic", income = 30, price = 3000, color = Color3.fromRGB(89, 209, 235), size = Vector3.new(2.5, 4.0, 2.5), weight = 8},
	{id = "trippi", name = "Trippi Troppi", rarity = "Epic", income = 35, price = 3500, color = Color3.fromRGB(250, 117, 25), size = Vector3.new(2.2, 3.6, 2.2), weight = 8},
	{id = "assassino", name = "Cappuccino Assassino", rarity = "Legendary", income = 80, price = 7000, color = Color3.fromRGB(56, 43, 33), size = Vector3.new(2.2, 3.9, 2.2), weight = 6},
	{id = "giraffa", name = "Giraffa Celeste", rarity = "Legendary", income = 95, price = 8000, color = Color3.fromRGB(92, 209, 255), size = Vector3.new(2.0, 4.8, 2.0), weight = 6},
	{id = "pot", name = "Pot Hotspot", rarity = "Legendary", income = 110, price = 9000, color = Color3.fromRGB(242, 64, 20), size = Vector3.new(2.7, 3.0, 2.7), weight = 6},
	{id = "tralaleritos", name = "Los Tralaleritos", rarity = "Mythic", income = 250, price = 18000, color = Color3.fromRGB(250, 31, 184), size = Vector3.new(2.8, 4.2, 2.8), weight = 4},
	{id = "bobrito", name = "Bobrito Bandito", rarity = "Mythic", income = 300, price = 21000, color = Color3.fromRGB(140, 64, 31), size = Vector3.new(2.5, 3.4, 2.5), weight = 4},
	{id = "cocco", name = "Cocco Ninja", rarity = "Mythic", income = 360, price = 24000, color = Color3.fromRGB(36, 36, 46), size = Vector3.new(2.3, 3.8, 2.3), weight = 4},
	{id = "trololo", name = "Grande Trololo", rarity = "Brainrot God", income = 1000, price = 60000, color = Color3.fromRGB(20, 242, 232), size = Vector3.new(3.3, 4.8, 3.3), weight = 2},
	{id = "brr", name = "Brr Brr Patapim", rarity = "Brainrot God", income = 1200, price = 70000, color = Color3.fromRGB(199, 122, 61), size = Vector3.new(3.0, 4.3, 3.0), weight = 2},
	{id = "sahurgod", name = "Tung Tung Tung Sahur God", rarity = "Brainrot God", income = 1500, price = 85000, color = Color3.fromRGB(31, 234, 219), size = Vector3.new(2.7, 5.2, 2.7), weight = 2},
	{id = "bombordini", name = "Los Bombordini Cryptini", rarity = "Secret", income = 5000, price = 300000, color = Color3.fromRGB(26, 10, 41), size = Vector3.new(3.5, 4.5, 3.2), weight = 1},
	{id = "quantum", name = "La Cucaracha Quantum", rarity = "Secret", income = 6000, price = 350000, color = Color3.fromRGB(77, 20, 102), size = Vector3.new(3.0, 4.0, 3.0), weight = 1},
	{id = "ultimate", name = "Tralalero Tralalero Tung Tung", rarity = "Secret", income = 8000, price = 450000, color = Color3.fromRGB(10, 7, 20), size = Vector3.new(3.2, 4.8, 3.2), weight = 1},
}

local world = {
	arenaSize = Vector3.new(200, 1, 200),
	baseSize = Vector3.new(52, 4, 50),
	playerBase = Vector3.new(0, 2, 70),
	rivalBase = Vector3.new(0, 2, -70),
	playerBaseColor = Color3.fromRGB(50, 112, 242),
	rivalBaseColor = Color3.fromRGB(220, 60, 76),
	conveyorStart = Vector3.new(0, 3.35, -42),
	conveyorEnd = Vector3.new(0, 3.35, 43),
	conveyorWidth = 12,
	conveyorSpeed = 4.2,
	spawnPosition = Vector3.new(0, 6, 64),
	playerSlots = {
		Vector3.new(-18, 5, 58), Vector3.new(-9, 5, 58), Vector3.new(0, 5, 58), Vector3.new(9, 5, 58), Vector3.new(18, 5, 58),
		Vector3.new(-18, 5, 70), Vector3.new(-9, 5, 70), Vector3.new(0, 5, 70), Vector3.new(9, 5, 70), Vector3.new(18, 5, 70),
		Vector3.new(-12, 5, 84), Vector3.new(12, 5, 84),
	},
	rivalSlots = {
		Vector3.new(-15, 5, -70), Vector3.new(0, 5, -70), Vector3.new(15, 5, -70),
		Vector3.new(-15, 5, -82), Vector3.new(0, 5, -82), Vector3.new(15, 5, -82),
	},
	props = {
		{type = "tree", position = Vector3.new(-65, 0, -55), color = Color3.fromRGB(31, 140, 56)},
		{type = "tree", position = Vector3.new(62, 0, 48), color = Color3.fromRGB(31, 140, 56)},
		{type = "tree", position = Vector3.new(-58, 0, 62), color = Color3.fromRGB(38, 158, 64)},
		{type = "tree", position = Vector3.new(60, 0, -67), color = Color3.fromRGB(38, 158, 64)},
		{type = "tree", position = Vector3.new(-66, 0, 40), color = Color3.fromRGB(44, 126, 72)},
		{type = "tree", position = Vector3.new(67, 0, -42), color = Color3.fromRGB(44, 126, 72)},
		{type = "sign", position = Vector3.new(-25, 4, 35), text = "YOUR BASE"},
		{type = "sign", position = Vector3.new(25, 4, 35), text = "RIVAL BASE"},
		{type = "coin", position = Vector3.new(-38, 5, 10), color = Color3.fromRGB(255, 209, 20)},
		{type = "coin", position = Vector3.new(38, 5, -10), color = Color3.fromRGB(255, 209, 20)},
	},
}

local rarityByName = {}
local brainrotById = {}
local mutationByName = {}
for _, rarity in ipairs(rarities) do
	rarityByName[rarity.name] = rarity
end
for _, brainrot in ipairs(brainrots) do
	brainrotById[brainrot.id] = brainrot
end
for _, mutation in ipairs(mutations) do
	mutationByName[mutation.name] = mutation
end

local random = Random.new()

local function chooseWeighted(items)
	local total = 0
	for _, item in ipairs(items) do
		total += item.weight
	end
	local roll = random:NextNumber(0, total)
	for _, item in ipairs(items) do
		roll -= item.weight
		if roll <= 0 then
			return item
		end
	end
	return items[#items]
end

local function chooseBrainrot(minimumRarityIndex)
	-- Clamp: an out-of-range minimum used to leave eligibleRarities empty,
	-- and chooseWeighted({}) then returned nil, crashing the spawn.
	minimumRarityIndex = math.clamp(minimumRarityIndex or 1, 1, #rarities)
	local eligibleRarities = {}
	for index, rarity in ipairs(rarities) do
		if index >= minimumRarityIndex then
			table.insert(eligibleRarities, rarity)
		end
	end
	local rarity = chooseWeighted(eligibleRarities)
	local candidates = {}
	for _, brainrot in ipairs(brainrots) do
		if brainrot.rarity == rarity.name then
			table.insert(candidates, brainrot)
		end
	end
	return chooseWeighted(candidates)
end

local function chooseMutation()
	return chooseWeighted(mutations)
end

local function getBrainrot(id)
	return brainrotById[id]
end

local function getRarity(name)
	return rarityByName[name]
end

local function getMutation(name)
	return mutationByName[name] or mutationByName.None
end

local function getEffectiveIncome(brainrot, mutationName)
	return brainrot.income * getMutation(mutationName).multiplier
end

BrainrotData.Data = {world = world, rarities = rarities, mutations = mutations, brainrots = brainrots}
BrainrotData.Rarities = rarities
BrainrotData.Mutations = mutations
BrainrotData.Brainrots = brainrots
BrainrotData.World = world
BrainrotData.ChooseBrainrot = chooseBrainrot
BrainrotData.ChooseMutation = chooseMutation
BrainrotData.GetBrainrot = getBrainrot
BrainrotData.GetRarity = getRarity
BrainrotData.GetMutation = getMutation
BrainrotData.GetEffectiveIncome = getEffectiveIncome

return BrainrotData
