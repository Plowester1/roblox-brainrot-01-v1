local Players = game:GetService("Players")

local BrainrotData = require(script.Parent.BrainrotData)
local WorldBuilder = require(script.Parent.WorldBuilder)
local GameState = require(script.Parent.GameState)

-- Conveyor spawns brainrots on the belt on a timer, moves them toward the
-- player's side, and despawns them at the far end if nobody buys them.

local Conveyor = {}

local c = WorldBuilder.CONVEYOR
-- brainrots currently walking the belt: modelId -> { model, spec, id }
local beltBrainrots = {}
local nextId = 1

local BASE_INTERVAL = 5.0

-- Spawn one brainrot on the belt (start of the belt). Returns its record or nil.
function Conveyor.spawnBrainrot(epicOrBetter)
	local rarity = BrainrotData.rollRarity(epicOrBetter)
	local def = BrainrotData.rollBrainrot(rarity.name)
	local mutation = BrainrotData.rollMutation()
	local mutColor = mutation ~= "None" and BrainrotData.getMutationColor(mutation) or def.color

	local id = "belt" .. tostring(nextId)
	nextId += 1

	local spec = {
		name = def.name,
		rarity = rarity.name,
		rarityColor = rarity.color,
		color = def.color,
		mutationColor = mutColor,
		size = def.size,
		mutation = mutation,
		income = def.base,
		base = def.base,
		defId = def.id,
	}

	local built = WorldBuilder.buildBrainrotModel(spec)
	local model = built.model
	model.Parent = workspace
	model.PrimaryPart = built.body
	model:SetAttribute("BeltId", id)
	model:SetAttribute("OnBelt", true)
	model:SetPrimaryPartCFrame(CFrame.new(c.startX, c.y, c.z))

	local record = {
		id = id,
		defId = def.id,
		name = def.name,
		rarity = rarity.name,
		base = def.base,
		mutation = mutation,
		price = Conveyor.priceFor(def, rarity, mutation),
		model = model,
		spec = spec,
		x = c.startX,
	}
	beltBrainrots[id] = record

	-- tell clients a brainrot is on the belt (for HUD cue / fanfare)
	local events = GameState.getRemoteEvents()
	local spawnEv = events:FindFirstChild("BrainrotSpawned")
	if spawnEv then
		spawnEv:FireAllClients({
			name = def.name,
			rarity = rarity.name,
			mutation = mutation,
			price = record.price,
		})
	end

	return record
end

function Conveyor.priceFor(def, rarity, mutation)
	local mutMult = BrainrotData.getMutationMultiplier(mutation)
	local tier = BrainrotData.getRarity(rarity)
	local tierMult = (tier and tier.index or 1)
	return math.floor(20 * (def.base or 2) * mutMult * (1 + tierMult * 0.5))
end

-- Buy a brainrot off the belt. Returns the record or nil if it was already bought.
function Conveyor.takeBeltBrainrot(id)
	local record = beltBrainrots[id]
	if not record then
		return nil
	end
	beltBrainrots[id] = nil
	return record
end

function Conveyor.getBeltBrainrot(id)
	return beltBrainrots[id]
end

function Conveyor.getBeltList()
	return beltBrainrots
end

-- Per-heartbeat step: move every belt brainrot along x toward the player base.
-- Despawn any that pass the far end.
local function step(dt)
	local speed = WorldBuilder.CONVEYOR_SPEED or 2.5
	for id, record in pairs(beltBrainrots) do
		record.x -= speed * dt
		local model = record.model
		if model then
			model:PivotTo(CFrame.new(record.x, c.y, c.z))
		end
		if record.x < c.startX - 1.5 then
			model:Destroy()
			beltBrainrots[id] = nil
		end
	end
end

function Conveyor.start(runService)
	runService.Heartbeat:Connect(function(dt)
		step(dt)
	end)
end

return Conveyor