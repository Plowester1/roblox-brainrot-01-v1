local Players = game:GetService("Players")
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local HUD = require(script.Parent.HUD)
local Effects = require(script.Parent.Effects)

local player = Players.LocalPlayer
local hud = HUD
local events = ReplicatedStorage:WaitForChild("RemoteEvents")

local function fmtMoney(n)
	local s = tostring(math.floor(n))
	local out = ""
	local count = 0
	for i = #s, 1, -1 do
		out = string.sub(s, i, i) .. out
		count = count + 1
		if count % 3 == 0 and i > 1 then
			out = "," .. out
		end
	end
	return "$" .. out
end

local buyTargetId = nil

local function currentBeltBrainrotId()
	local char = player.Character
	if not char then
		return nil
	end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return nil
	end
	local best = nil
	local bestDist = 4
	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj:IsA("Model") and obj:GetAttribute("OnBelt") then
			local primary = obj.PrimaryPart
			if primary then
				local d = (primary.Position - hrp.Position).Magnitude
				if d < bestDist then
					bestDist = d
					best = obj:GetAttribute("BeltId")
				end
			end
		end
	end
	return best
end

ContextActionService:BindAction("BuyKey", function(_, state)
	if state == Enum.UserInputState.Begin then
		buyTargetId = currentBeltBrainrotId()
		if buyTargetId then
			events.BuyBrainrot:FireServer(buyTargetId)
		end
	end
	return Enum.ContextActionResult.Sink
end, false, Enum.KeyCode.E)

ContextActionService:BindAction("SlapKey", function(_, state)
	if state == Enum.UserInputState.Begin then
		events.SlapRival:FireServer()
	end
	return Enum.ContextActionResult.Sink
end, false, Enum.KeyCode.Q)

ContextActionService:BindAction("LockKey", function(_, state)
	if state == Enum.UserInputState.Begin then
		events.LockBase:FireServer()
	end
	return Enum.ContextActionResult.Sink
end, false, Enum.KeyCode.L)


local lastPayload = nil

local function updateHudState(payload)
	lastPayload = payload
	if payload.cash ~= nil then
		hud.cash.Text = fmtMoney(payload.cash)
	end
	local income = 0
	for _, b in pairs(payload.owned or {}) do
		income = income + (b.base or 0)
	end
	local mult = payload.incomeMult or 1
	hud.income.Text = fmtMoney(income * mult) .. "/s"
	hud.rebirth.Text = "Rebirths: " .. tostring(payload.rebirths or 0)
	if collection.Visible then
		updateCollection(payload)
	end
end

local function showBanner(title, subtitle)
	hud.banner.Text = title
	hud.banner.Visible = true
	task.delay(4, function()
		hud.banner.Visible = false
	end)
end

events.SyncState.OnClientEvent:Connect(updateHudState)

events.EventBanner.OnClientEvent:Connect(function(payload)
	showBanner(payload.title, payload.subtitle)
end)

events.EffectsPlay.OnClientEvent:Connect(function(payload)
	local pos = nil
	if payload.position then
		pos = Vector3.new(payload.position[1], payload.position[2], payload.position[3])
	end
	Effects.play(payload.kind, pos, payload.amount)
end)

-- ---- Collection panel (rarity ladder) ----

local collection = Instance.new("Frame")
collection.Size = UDim2.new(0, 340, 0, 420)
collection.Position = UDim2.new(0.5, -170, 0.5, -210)
collection.BackgroundColor3 = Color3.fromRGB(15, 15, 22)
collection.BackgroundTransparency = 0.1
collection.Visible = false
collection.ZIndex = 8
collection.Parent = hud.screenGui
local collStroke = Instance.new("UIStroke")
collStroke.Color = Color3.fromRGB(255, 220, 80)
collStroke.Thickness = 3
collStroke.Parent = collection

local collTitle = Instance.new("TextLabel")
collTitle.Size = UDim2.new(1, 0, 0, 34)
collTitle.BackgroundTransparency = 1
collTitle.Font = Enum.Font.GothamBold
collTitle.Text = "COLLECTION - RARITY LADDER"
collTitle.TextColor3 = Color3.fromRGB(255, 220, 80)
collTitle.TextSize = 20
collTitle.Parent = collection

local function makeRarityRow(rarity, has)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, -20, 0, 40)
	row.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
	row.Parent = collection
	local rowLabel = Instance.new("TextLabel")
	rowLabel.Size = UDim2.new(1, 0, 1, 0)
	rowLabel.BackgroundTransparency = 1
	rowLabel.Font = Enum.Font.GothamBold
	rowLabel.Text = rarity .. (has and "  [OWNED]" or "")
	rowLabel.TextColor3 = has and Color3.fromRGB(120, 255, 140) or Color3.fromRGB(200, 200, 210)
	rowLabel.TextSize = 18
	rowLabel.Parent = row
	return row
end

local rarityRows = {}

function updateCollection(payload)
	local ownedNames = {}
	for _, b in pairs(payload.owned or {}) do
		ownedNames[b.rarity] = true
	end
	local tiers = { "Common", "Rare", "Epic", "Legendary", "Mythic", "Brainrot God", "Secret" }
	for _, row in ipairs(rarityRows) do
		row:Destroy()
	end
	rarityRows = {}
	local y = 40
	for _, t in ipairs(tiers) do
		local row = makeRarityRow(t, ownedNames[t] == true)
		row.Position = UDim2.new(0, 10, 0, y)
		rarityRows[#rarityRows + 1] = row
		y = y + 46
	end
end

hud.collectBtn.Activated:Connect(function()
	collection.Visible = not collection.Visible
	if lastPayload then
		updateCollection(lastPayload)
	end
end)

updateCollection({})

-- ---- Shop panel ----

local shop = Instance.new("Frame")
shop.Size = UDim2.new(0, 320, 0, 300)
shop.Position = UDim2.new(0.5, -160, 0.5, -150)
shop.BackgroundColor3 = Color3.fromRGB(15, 22, 15)
shop.BackgroundTransparency = 0.1
shop.Visible = false
shop.ZIndex = 8
shop.Parent = hud.screenGui
local shopStroke = Instance.new("UIStroke")
shopStroke.Color = Color3.fromRGB(120, 255, 120)
shopStroke.Thickness = 3
shopStroke.Parent = shop

local shopTitle = Instance.new("TextLabel")
shopTitle.Size = UDim2.new(1, 0, 0, 34)
shopTitle.BackgroundTransparency = 1
shopTitle.Font = Enum.Font.GothamBold
shopTitle.Text = "SHOP - UPGRADES"
shopTitle.TextColor3 = Color3.fromRGB(120, 255, 120)
shopTitle.TextSize = 20
shopTitle.Parent = shop

local function shopButton(text, pos, kind)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1, -20, 0, 52)
	btn.Position = pos
	btn.BackgroundColor3 = Color3.fromRGB(60, 120, 70)
	btn.BorderSizePixel = 0
	btn.Font = Enum.Font.GothamBold
	btn.Text = text
	btn.TextColor3 = Color3.fromRGB(255, 255, 255)
	btn.TextSize = 18
	btn.Parent = shop
	btn.Activated:Connect(function()
		events.BuyUpgrade:FireServer(kind)
	end)
	return btn
end

shopButton("+ Pedestal Slot", UDim2.new(0, 10, 0, 40), "pedestal")
shopButton("+ Conveyor Speed", UDim2.new(0, 10, 0, 98), "conveyor")
shopButton("+ Income Multiplier", UDim2.new(0, 10, 0, 156), "multiplier")

local rebirthBtn = Instance.new("TextButton")
rebirthBtn.Size = UDim2.new(1, -20, 0, 52)
rebirthBtn.Position = UDim2.new(0, 10, 0, 214)
rebirthBtn.BackgroundColor3 = Color3.fromRGB(160, 120, 30)
rebirthBtn.BorderSizePixel = 0
rebirthBtn.Font = Enum.Font.GothamBold
rebirthBtn.Text = "REBIRTH (+50% income)"
rebirthBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
rebirthBtn.TextSize = 18
rebirthBtn.Parent = shop
rebirthBtn.Activated:Connect(function()
	events.Rebirth:FireServer()
end)

hud.shopBtn.Activated:Connect(function()
	shop.Visible = not shop.Visible
end)

-- Lock button uses the same RemoteEvent as the L key.
hud.lockBtn.Activated:Connect(function()
	events.LockBase:FireServer()
end)

print("Brainrot Base Wars client ready")
