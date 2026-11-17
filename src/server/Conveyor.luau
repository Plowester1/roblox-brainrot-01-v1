-- Conveyor.luau
-- Spawns brainrots on the belt on a timer, walks them down the lane, and
-- despawns any that reach the end un-bought. Cleans up dead models.

local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")

local BrainrotData = require(script.Parent.BrainrotData)
local WorldBuilder = require(script.Parent.WorldBuilder)

local Conveyor = {}

local ACTIVE = {} -- id -> { model, head, income, alive, z, speed, def, rarity, mutation }
local nextId = 0
local spawnTimer = 0
local beltLength = 80
local beltSpeed = 4.5
local spawnGap = 9
local lastZ = beltLength / 2
local onBuy = nil

Conveyor.ACTIVE = ACTIVE

local function newId()
	nextId = nextId + 1
	return "B" .. tostring(nextId)
end

-- Place the model on the belt at the given z.
local function place(model, z)
	local pivot = CFrame.new(0, 1.8, z)
	model:SetPrimaryPartCFrame(pivot)
end

-- Spawn a brainrot. def = { name, income, color }, rarity, mutation, speed.
function Conveyor.spawn(def, rarity, mutation, speed)
	local model, head = WorldBuilder.buildBrainrot(def.name, def.color, 2)
	local id = newId()
	local mut = mutation or "Normal"
	local mult = BrainrotData.totalMutationMult(mut)
	place(model, lastZ)
	ACTIVE[id] = {
		model = model,
		head = head,
		income = def.income * mult,
		alive = true,
		z = lastZ,
		speed = speed or beltSpeed,
		def = def,
		rarity = rarity,
		mutation = mut,
	}
	model:SetAttribute("BrainrotId", id)
	lastZ = lastZ - spawnGap
	return id, ACTIVE[id]
end

-- Remove a brainrot from the belt (bought, stolen, or despawned).
function Conveyor.remove(id)
	local entry = ACTIVE[id]
	if not entry then
		return
	end
	entry.alive = false
	ACTIVE[id] = nil
	if entry.model and entry.model.Parent then
		entry.model:Destroy()
	end
end

-- Despawn any brainrot that walked past the end of the belt.
local function despawnEnd()
	local toRemove = {}
	for id, e in pairs(ACTIVE) do
		if e.alive and e.z < -beltLength / 2 - 4 then
			table.insert(toRemove, id)
		end
	end
	for _, id in ipairs(toRemove) do
		Conveyor.remove(id)
	end
end

-- Move brainrots down the lane each frame. Spreads the walking speed so the
-- gaps between spawns roughly hold (~spawnGap studs).
local function moveBrainrots(dt)
	for id, e in pairs(ACTIVE) do
		if e.alive then
			e.z = e.z - e.speed * dt
			if e.model then
				place(e.model, e.z)
			end
		end
	end
end

-- Configure the conveyor (called once by init.server).
function Conveyor.configure(opts)
	if opts.beltLength then
		beltLength = opts.beltLength
		lastZ = beltLength / 2
	end
	if opts.speed then
		beltSpeed = opts.speed
	end
	if opts.gap then
		spawnGap = opts.gap
	end
	if opts.interval then
		spawnInterval = opts.interval
	end
end

local spawnInterval = 6.0
local firstSpawnDone = false

-- Spawn one brainrot with a random rarity/mutation from the catalog.
local function spawnRandom()
	local roll = BrainrotData.rollSpawn()
	if not roll.brainrot then
		return
	end
	local def = roll.brainrot
	Conveyor.spawn(def, roll.rarity, roll.mutation)
end

-- Start the conveyor: a spawn timer plus the walk/despawn loop.
function Conveyor.start()
	spawnTimer = 0.5
	RunService.Heartbeat:Connect(function(dt)
		spawnTimer -= dt
		if spawnTimer <= 0 then
			spawnRandom()
			spawnTimer = spawnInterval
		end
		moveBrainrots(dt)
		despawnEnd()
	end)
end

-- Let the rival or shop register a callback when a brainrot is taken by id.
function Conveyor.onTaken(fn)
	Conveyor.takenHook = fn
end

function Conveyor.notifyTaken(id)
	if Conveyor.takenHook then
		Conveyor.takenHook(id)
	end
end

return Conveyor