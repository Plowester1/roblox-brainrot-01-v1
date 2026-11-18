local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local BrainrotData = require(script.Parent.BrainrotData)
local GameState = require(script.Parent.GameState)
local WorldBuilder = require(script.Parent.WorldBuilder)
local Conveyor = require(script.Parent.Conveyor)

-- Shop handles every buy/steal/lock/rebirth/upgrade request from the RemoteEvents,
-- validates it against GameState, and updates the world via WorldBuilder + GameState.

local Shop = {}

local playerBaseInfo = WorldBuilder.PLAYER_BASE

local REBIRTH_TITLES = {
	"Brainrot Noob",
	"Tung Turner",
	"Tralalero Master",
	"Bombardiro Champ",
	"Ballerina Legend",
	"Giraffa Celeste",
	"Pot Hotspot God",
	"Sfinge Pinguino King",
}

local function emitEffects(kind, position, amount)
	local events = GameState.getRemoteEvents()
	local ev = events:FindFirstChild("EffectsPlay")
	if ev then
		ev:FireAllClients({
			kind = kind,
			position = position and { position.X, position.Y, position.Z } or nil,
			amount = amount or 0,
		})
	end
end

function Shop.init()
	local events = GameState.getRemoteEvents()

	events.BuyBrainrot.OnServerEvent:Connect(function(player, id)
		Shop.buyBrainrot(player, id)
	end)

	events.StealBrainrot.OnServerEvent:Connect(function(player, id)
		Shop.stealBrainrot(player, id)
	end)

	events.SlapRival.OnServerEvent:Connect(function(player)
		Shop.slapRival(player)
	end)

	events.LockBase.OnServerEvent:Connect(function(player)
		Shop.lockBase(player)
	end)

	events.Rebirth.OnServerEvent:Connect(function(player)
		Shop.rebirth(player)
	end)

	events.BuyUpgrade.OnServerEvent:Connect(function(player, upgradeType)
		Shop.buyUpgrade(player, upgradeType)
	end)
end

-- Buy a brainrot off the belt for the player.
function Shop.buyBrainrot(player, beltId)
	local st = GameState.getState(player)
	if not st then
		return
	end
	local record = Conveyor.getBeltBrainrot(beltId)
	if not record then
		return
	end
	if not GameState.anyPedestalFree(player) then
		return
	end
	if not GameState.trySpend(player, record.price) then
		return
	end

	Conveyor.takeBeltBrainrot(beltId)

	local brainrotId = "p" .. tostring(player.UserId) .. "_" .. tostring(os.clock())
	local ownedEntry = {
		defId = record.defId,
		name = record.name,
		rarity = record.rarity,
		base = record.base,
		mutation = record.mutation,
	}
	st.owned[brainrotId] = ownedEntry

	local pedestal = GameState.findFreePedestal(player)
	GameState.assignPedestal(player, pedestal, brainrotId)

	-- move the model onto the pedestal
	local model = record.model
	if model then
		local slotPos = WorldBuilder.pedestalPosition(playerBaseInfo, pedestal)
		model:PivotTo(CFrame.new(slotPos))
		GameState.registerBrainrotModel(brainrotId, { model = model })
	end

	emitEffects("buy", record.model and record.model:GetPivot().Position or nil, record.price)
	GameState.sync(player)
end

-- Player steals a brainrot from the rival's base (walk over, press E).
function Shop.stealBrainrot(player, beltId)
	local st = GameState.getState(player)
	if not st then
		return
	end
	if GameState.getCarrying(player) then
		return -- already carrying one
	end
	if not GameState.anyPedestalFree(player) then
		return
	end

	-- The rival carries a stolen brainrot; reclaim it onto our base.
	local rival = require(script.Parent.Rival)
	local carriedId = rival.getCarrying()
	if not carriedId then
		return
	end
	local model = GameState.getBrainrotModel(carriedId)
	if not model then
		return
	end

	local pedestal = GameState.findFreePedestal(player)
	GameState.assignPedestal(player, pedestal, carriedId)
	local slotPos = WorldBuilder.pedestalPosition(playerBaseInfo, pedestal)
	model.model:PivotTo(CFrame.new(slotPos))
	rival.dropCarried()
	emitEffects("steal", slotPos, 0)
	GameState.sync(player)
end

-- Slap the rival: knock it back and make it drop what it carries.
function Shop.slapRival(player)
	local rival = require(script.Parent.Rival)
	rival.slap()
	emitEffects("slap", WorldBuilder.RIVAL_BASE.center + Vector3.new(0, 3, 0), 0)
end

function Shop.lockBase(player)
	local st = GameState.getState(player)
	if not st then
		return
	end
	local now = os.clock()
	if now < st.lockCooldownUntil then
		return
	end
	if now < st.lockUntil then
		return
	end
	st.lockUntil = now + 30
	st.lockCooldownUntil = now + 60
	emitEffects("lock", playerBaseInfo.center + Vector3.new(0, 3, 0), 0)
	GameState.sync(player)
end

-- Rebirth: reset cash + clear base for a permanent +50% income and a new title.
function Shop.rebirth(player)
	local st = GameState.getState(player)
	if not st then
		return
	end
	local count = GameState.countByRarity(player)
	local totalOwned = 0
	local cost = 500 * (st.rebirths + 1)
	for _, n in pairs(count) do
		totalOwned += n
	end
	if totalOwned < 3 then
		return
	end
	if not GameState.trySpend(player, cost) then
		return
	end

	-- clear owned brainrots from pedestals
	for id, entry in pairs(st.owned) do
		local model = GameState.getBrainrotModel(id)
		if model then
			model.model:Destroy()
		end
		GameState.unregisterBrainrotModel(id)
	end
	st.owned = {}
	-- release pedestals
	for p = 1, st.pedestals do
		GameState.releasePedestal(player, p)
	end

	st.rebirths += 1
	st.incomeMult = 1 + st.rebirths * 0.5
	st.cash = 0
	local title = REBIRTH_TITLES[math.min(st.rebirths, #REBIRTH_TITLES)]
	if title then
		st.title = title
	end

	emitEffects("rebirth", playerBaseInfo.center + Vector3.new(0, 2, 0), st.rebirths)
	GameState.sync(player)
end

-- Buy an upgrade: "pedestal" adds a slot, "conveyor" speeds spawns, "multiplier" boosts income.
function Shop.buyUpgrade(player, upgradeType)
	local st = GameState.getState(player)
	if not st then
		return
	end
	if upgradeType == "pedestal" then
		if st.pedestals >= GameState.getMaxPedestals() then
			return
		end
		local cost = GameState.getPedestalUpgradeCost(player, st.pedestals + 1)
		if not GameState.trySpend(player, cost) then
			return
		end
		st.pedestals += 1
		-- build the new pedestal
		local slotPos = WorldBuilder.pedestalPosition(playerBaseInfo, st.pedestals)
		WorldBuilder.buildPedestal(workspace:FindFirstChild("PlayerBase"), slotPos, Color3.fromRGB(220, 220, 60))
		emitEffects("upgrade", slotPos, cost)
	elseif upgradeType == "conveyor" then
		local cost = 400 * (st.rebirths + 1)
		if not GameState.trySpend(player, cost) then
			return
		end
		WorldBuilder.CONVEYOR_SPEED = (WorldBuilder.CONVEYOR_SPEED or 2.5) + 0.6
		emitEffects("upgrade", Vector3.new(0, 3, 0), cost)
	elseif upgradeType == "multiplier" then
		local cost = 500 * (st.rebirths + 1)
		if not GameState.trySpend(player, cost) then
			return
		end
		st.incomeMult += 0.5
		emitEffects("upgrade", playerBaseInfo.center + Vector3.new(0, 2, 0), cost)
	end
	GameState.sync(player)
end

return Shop