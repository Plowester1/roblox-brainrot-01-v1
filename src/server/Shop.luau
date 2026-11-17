-- Shop.luau
-- Handles buy/steal/lock/rebirth/upgrade requests from the client RemoteEvents,
-- validates them, and updates GameState. No steal soft-lock: every steal path
-- ends in a clean success or a clean cancel.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameState = require(script.Parent.GameState)
local BrainrotData = require(script.Parent.BrainrotData)
local WorldBuilder = require(script.Parent.WorldBuilder)
local Conveyor = require(script.Parent.Conveyor)

local Shop = {}

local REMOTE_FOLDER = "RemoteEvents"
local remotes = {}
local events

-- Called once by init.server with the game's configuration.
function Shop.configure(cfg, eventsTable)
	Shop.cfg = cfg
	events = eventsTable
	WorldBuilder.init()
end

local function getRemote(name)
	local r = remotes[name]
	if not r then
		r = ReplicatedStorage:WaitForChild(REMOTE_FOLDER):WaitForChild(name)
		remotes[name] = r
	end
	return r
end

Shop.getRemote = getRemote

-- Fire a client a HUD update (cash, income, etc.).
function Shop.pushHUD(userId)
	local ev = getRemote("HUDUpdate")
	local player = Players:GetPlayerByUserId(userId)
	if not ev or not player then
		return
	end
	local s = GameState.get(userId)
	if not s then
		return
	end
	local mult = GameState.getMultiplier(userId)
	local total = 0
	for id, e in pairs(OWNED) do
		if e.ownerUserId == userId then
			total += e.income
		end
	end
	total = total * mult
	ev:FireClient(player, s.cash, total, mult, s.rebirths, s.title, s.pedestals, s.lockUntil, s.lockReadyAt)
end

Shop.pushHUD = Shop.pushHUD

-- Registry of every owned brainrot model, id -> { model, def, mutation, income,
-- ownerUserId, pedestalIndex }. Used by the income loop, the rival, and stealing.
local OWNED = {} -- id -> entry
local REGISTRY_INDEX = {}

local worldPlayerBase = nil
local worldRivalBase = nil
local onIncomeChanged = nil
local onStealChanged = nil

Shop.OWNED = OWNED

-- Called after the world is built: remember the base models.
function Shop.setWorldBases(playerBase, rivalBase)
	worldPlayerBase = playerBase
	worldRivalBase = rivalBase
end

-- The rival/income loop asks for a model entry by id.
function Shop.entryOf(id)
	return OWNED[id]
end

-- incomeOf(id) for GameState.totalIncome and the rival.
function Shop.incomeOf(id)
	local e = OWNED[id]
	return e and e.income or 0
end

Shop.incomeOf = Shop.incomeOf

-- Count free pedestals for a player.
local function freePedestals(userId)
	local s = GameState.ensure(userId)
	return s.pedestals - Shop.countOwned(userId)
end

function Shop.countOwned(userId)
	local n = 0
	for id, e in pairs(OWNED) do
		if e.ownerUserId == userId then
			n += 1
		end
	end
	return n
end

Shop.countOwned = Shop.countOwned

-- Is a pedestal index occupied by any owned brainrot?
function Shop.pedestalFree(index)
	for id, e in pairs(OWNED) do
		if e.pedestalIndex == index then
			return false
		end
	end
	return true
end

-- Buy price for a brainrot: scaled from base income, rounded to nearest $100.
local function buyPrice(baseIncome, rebirths)
	local base = math.max(100, math.ceil(baseIncome * 20))
	local scale = 1 + rebirths * 0.75
	local raw = base * scale
	return math.round(raw / 100) * 100
end

Shop.buyPrice = buyPrice

-- Place an owned brainrot model onto a specific pedestal of the player's base.
local function placeOnPedestal(model, pedestalIndex)
	if not worldPlayerBase or not worldPlayerBase.pedestals then
		return
	end
	local ped = worldPlayerBase.pedestals[pedestalIndex]
	if not ped then
		return
	end
	model:PivotTo(ped.CFrame * CFrame.new(0, 2.4, 0))
end

Shop.placeOnPedestal = placeOnPedestal

-- Buy a brainrot currently on the belt. Returns (true) or (false, reason).
function Shop.buyBrainrot(player, beltId, pedestalIndex)
	local userId = player.UserId
	local s = GameState.ensure(userId)
	if freePedestals(userId) <= 0 then
		return false, "no pedestal"
	end
	local beltEntry = Conveyor.ACTIVE[beltId]
	if not beltEntry then
		return false, "not on belt"
	end
	local price = buyPrice(beltEntry.def.income, s.rebirths)
	if GameState.getCash(userId) < price then
		return false, "not enough cash"
	end
	-- Find a free pedestal index.
	local idx = pedestalIndex
	if not worldPlayerBase or not worldPlayerBase.pedestals[idx] then
		idx = nil
		for i = 1, s.pedestals do
			if Shop.pedestalFree(i) then
				idx = i
				break
			end
		end
	end
	if not idx then
		return false, "no pedestal"
	end
	GameState.addCash(userId, -price)
	local model = beltEntry.model
	Conveyor.remove(beltId)
	model.Parent = worldPlayerBase.model or model.Parent
	placeOnPedestal(model, idx)
	OWNED[beltId] = {
		model = model,
		def = beltEntry.def,
		mutation = beltEntry.mutation,
		income = beltEntry.income,
		ownerUserId = userId,
		pedestalIndex = idx,
	}
	GameState.claimBrainrot(beltId, userId)
	Shop.pushHUD(userId)
	return true
end

-- Rival-owned brainrots sitting on the rival base (stealable by the player).
local RIVAL_OWNED = {} -- rivalId -> { model, def, mutation, income }

Shop.RIVAL_OWNED = RIVAL_OWNED
Shop.rivalNextId = 0

-- When the rival keeps a stolen player brainrot, it lands on the rival base.
function Shop.rivalKept(id)
	local e = OWNED[id]
	if not e then
		return
	end
	-- Move the model off the player's pedestal and onto the rival base.
	local rivalId = "R" .. tostring(Shop.rivalNextId)
	Shop.rivalNextId += 1
	RIVAL_OWNED[rivalId] = {
		model = e.model,
		def = e.def,
		mutation = e.mutation,
		income = e.income,
	}
	OWNED[id] = nil
	GameState.releaseBrainrot(id)
	local model = RIVAL_OWNED[rivalId].model
	model:SetAttribute("BrainrotId", rivalId)
	model.Parent = worldRivalBase and worldRivalBase.model or WorldBuilder.bases
	if worldRivalBase then
		local ped = worldRivalBase.pedestals and worldRivalBase.pedestals[1]
		if ped then
			model:PivotTo(ped.CFrame * CFrame.new(0, 2.4, 0))
		end
	end
	-- Notify all players of the steal so the HUD updates.
	for _, p in ipairs(Players:GetPlayers()) do
		Shop.pushHUD(p.UserId)
	end
end

-- Player-side carrying state: a player is carrying a rival brainrot back home.
local PLAYER_CARRY = {} -- userId -> { model, rivalId, def, mutation, income }

Shop.PLAYER_CARRY = PLAYER_CARRY

-- Steal a brainrot off the rival base. Validates the player is not already
-- carrying and the target exists. Returns (true) or (false, reason).
function Shop.stealBrainrot(player, rivalId)
	local userId = player.UserId
	if PLAYER_CARRY[userId] then
		return false, "already carrying"
	end
	local rivalEntry = RIVAL_OWNED[rivalId]
	if not rivalEntry then
		return false, "not there"
	end
	-- Physically attach the model to the player's character (carried overhead).
	local char = player.Character
	local carryModel = rivalEntry.model
	RIVAL_OWNED[rivalId] = nil
	PLAYER_CARRY[userId] = {
		model = carryModel,
		rivalId = rivalId,
		def = rivalEntry.def,
		mutation = rivalEntry.mutation,
		income = rivalEntry.income,
	}
	if char and carryModel then
		local head = char:FindFirstChild("Head")
		carryModel.Parent = char
		carryModel:PivotTo((head or char:GetPivot()).CFrame * CFrame.new(0, 2, 0))
	end
	Shop.pushHUD(userId)
	if onStealChanged then
		onStealChanged(userId, true)
	end
	return true
end

-- Complete the steal: place the carried brainrot on a free player pedestal.
-- Returns true on success. Called by the client when the player reaches home.
function Shop.completeSteal(player)
	local userId = player.UserId
	local carry = PLAYER_CARRY[userId]
	if not carry then
		return false
	end
	if freePedestals(userId) <= 0 then
		return false
	end
	local idx = nil
	for i = 1, GameState.get(userId).pedestals do
		if Shop.pedestalFree(i) then
			idx = i
			break
		end
	end
	if not idx then
		return false
	end
	-- Adopt the carried model as an owned brainrot.
	PLAYER_CARRY[userId] = nil
	local model = carry.model
	if model then
		model.Parent = worldPlayerBase.model
		placeOnPedestal(model, idx)
	end
	local newId = carry.rivalId
	OWNED[newId] = {
		model = model,
		def = carry.def,
		mutation = carry.mutation,
		income = carry.income,
		ownerUserId = userId,
		pedestalIndex = idx,
	}
	GameState.claimBrainrot(newId, userId)
	if onStealChanged then
		onStealChanged(userId, false)
	end
	Shop.pushHUD(userId)
	return true
end

-- Cancel the steal cleanly: return the carried model to the rival base so
-- nothing is lost and the player is never left stuck carrying nothing.
function Shop.cancelSteal(player)
	local userId = player.UserId
	local carry = PLAYER_CARRY[userId]
	if not carry then
		return
	end
	PLAYER_CARRY[userId] = nil
	local model = carry.model
	if model then
		local rivalId = "R" .. tostring(Shop.rivalNextId)
		Shop.rivalNextId += 1
		model:SetAttribute("BrainrotId", rivalId)
		RIVAL_OWNED[rivalId] = {
			model = model,
			def = carry.def,
			mutation = carry.mutation,
			income = carry.income,
		}
		model.Parent = worldRivalBase and worldRivalBase.model or WorldBuilder.bases
		if worldRivalBase then
			local ped = worldRivalBase.pedestals and worldRivalBase.pedestals[1]
			if ped then
				model:PivotTo(ped.CFrame * CFrame.new(0, 2.4, 0))
			end
		end
	end
	if onStealChanged then
		onStealChanged(userId, false)
	end
end

Shop.isCarrying = function(userId)
	return PLAYER_CARRY[userId] ~= nil
end

-- Lock the player's base so the rival cannot steal. Respects cooldown.
function Shop.lockBase(player)
	local userId = player.UserId
	local s = GameState.ensure(userId)
	local now = os.clock()
	if now < s.lockReadyAt then
		return false, "cooldown"
	end
	s.lockUntil = now + Shop.cfg.lockDuration
	s.lockReadyAt = now + Shop.cfg.lockCooldown
	Shop.pushHUD(userId)
	return true
end

-- Is the player's base currently locked? (Used by the rival.)
function Shop.isLockedForRival()
	local now = os.clock()
	for _, p in ipairs(Players:GetPlayers()) do
		local s = GameState.get(p.UserId)
		if s and now < s.lockUntil then
			return true
		end
	end
	return false
end

-- Slap the rival. Validates the player is within range.
function Shop.slapRival(player)
	local char = player.Character
	if not char then
		return false, "no character"
	end
	local rivalModel = game.Workspace:FindFirstChild("World") and game.Workspace.World:FindFirstChild("Rival")
	if not rivalModel then
		return false, "no rival"
	end
	local dist = (char:GetPivot().Position - rivalModel:GetPivot().Position).Magnitude
	if dist > 12 then
		return false, "too far"
	end
	local Rival = require(script.Parent.Rival)
	Rival.slap(char:GetPivot().Position, 6)
	return true
end

-- Rebirth: spend cash plus owned brainrots to reset and gain +50% income.
function Shop.rebirth(player)
	local userId = player.UserId
	local s = GameState.ensure(userId)
	local ownedCount = Shop.countOwned(userId)
	if ownedCount <= 0 then
		return false, "need brainrots"
	end
	local cashCost = math.round(5000 * (1 + s.rebirths * 1.75))
	if GameState.getCash(userId) < cashCost then
		return false, "not enough cash"
	end
	GameState.setCash(userId, 0)
	-- Clear all owned brainrots (despawn models).
	for id, e in pairs(OWNED) do
		if e.ownerUserId == userId then
			if e.model then
				e.model:Destroy()
			end
			OWNED[id] = nil
			GameState.releaseBrainrot(id)
		end
	end
	s.rebirths += 1
	local titles = BrainrotData.titles
	s.title = titles[math.min(s.rebirths + 1, #titles)]
	Shop.pushHUD(userId)
	return true
end

-- Buy an upgrade: "pedestal" | "conveyor" | "income".
function Shop.buyUpgrade(player, kind)
	local userId = player.UserId
	local s = GameState.ensure(userId)
	local cfg = Shop.cfg
	local cost = 0
	if kind == "pedestal" then
		if s.pedestals >= cfg.pedestalMax then
			return false, "max"
		end
		cost = math.round((s.pedestals) * cfg.pedestalCostStep / 100) * 100
		if GameState.getCash(userId) < cost then
			return false, "not enough cash"
		end
		GameState.addCash(userId, -cost)
		s.pedestals += 1
	elseif kind == "conveyor" then
		cost = math.round((s.conveyorLevel) * 500 / 100) * 100
		if GameState.getCash(userId) < cost then
			return false, "not enough cash"
		end
		GameState.addCash(userId, -cost)
		s.conveyorLevel += 1
		Conveyor.configure({ interval = math.max(2, cfg.spawnInterval * (0.9 ^ (s.conveyorLevel - 1))) })
	elseif kind == "income" then
		cost = math.round((s.incomeLevel) * 300 / 100) * 100
		if GameState.getCash(userId) < cost then
			return false, "not enough cash"
		end
		GameState.addCash(userId, -cost)
		s.incomeLevel += 1
	else
		return false, "unknown"
	end
	Shop.pushHUD(userId)
	return true, cost
end

-- Let init.server register callbacks for income/steal changes.
function Shop.registerCallbacks(cbs)
	onIncomeChanged = cbs.onIncomeChanged
	onStealChanged = cbs.onStealChanged
end

return Shop