-- HUD.luau
-- Builds the ScreenGui HUD (cash, income, buttons, collection panel, event
-- banner). Clear, readable, colorful. It is ONLY the HUD — the game is 3D.

local HUD = {}

local Players = game:GetService("Players")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local gui = nil

-- Main button creator helper.
local function makeButton(parent, text, size, pos, color, onClick)
	local btn = Instance.new("TextButton")
	btn.Size = size
	btn.Position = pos
	btn.BackgroundColor3 = color
	btn.TextColor3 = Color3.fromRGB(255, 255, 255)
	btn.Text = text
	btn.Font = Enum.Font.FredokaOne
	btn.TextScaled = true
	btn.BorderSizePixel = 2
	btn.BorderColor3 = Color3.fromRGB(40, 40, 40)
	btn.Parent = parent
	if onClick then
		btn.MouseButton1Click:Connect(onClick)
	end
	return btn
end

-- Label creator helper.
local function makeLabel(parent, text, size, pos, color, font)
	local lbl = Instance.new("TextLabel")
	lbl.Size = size
	lbl.Position = pos
	lbl.BackgroundTransparency = 1
	lbl.TextColor3 = color or Color3.fromRGB(255, 255, 255)
	lbl.Text = text
	lbl.Font = font or Enum.Font.FredokaOne
	lbl.TextScaled = true
	lbl.TextStrokeTransparency = 0.2
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.Parent = parent
	return lbl
end

-- The main HUD surface. Created once, kept in a table of references.
function HUD.Build()
	if gui then
		return gui
	end
	gui = Instance.new("ScreenGui")
	gui.Name = "BrainrotHUD"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = playerGui

	local frame = Instance.new("Frame")
	frame.Name = "HUD"
	frame.Size = UDim2.new(1, 0, 1, 0)
	frame.BackgroundTransparency = 1
	frame.Parent = gui

	local topLeft = Instance.new("Frame")
	topLeft.Name = "TopLeft"
	topLeft.Size = UDim2.new(0, 240, 0, 130)
	topLeft.Position = UDim2.new(0, 16, 0, 16)
	topLeft.BackgroundColor3 = Color3.fromRGB(20, 24, 30)
	topLeft.BackgroundTransparency = 0.2
	topLeft.BorderSizePixel = 2
	topLeft.BorderColor3 = Color3.fromRGB(70, 70, 70)
	topLeft.Parent = frame

	local title = makeLabel(topLeft, "BRAINROT BASE WARS", UDim2.new(1, -12, 0, 22),
		UDim2.new(0, 6, 0, 4), Color3.fromRGB(255, 220, 90), Enum.Font.FredokaOne)
	title.TextScaled = true

	-- References to update later.
	HUD.refs = {
		cash = makeLabel(topLeft, "$0", UDim2.new(1, -12, 0, 30),
			UDim2.new(0, 6, 0, 30), Color3.fromRGB(120, 255, 120)),
		income = makeLabel(topLeft, "$0/s", UDim2.new(1, -12, 0, 26),
			UDim2.new(0, 6, 0, 62), Color3.fromRGB(255, 200, 120)),
		rebirth = makeLabel(topLeft, "Rebirths: 0 (x1.0)", UDim2.new(1, -12, 0, 24),
			UDim2.new(0, 6, 0, 92), Color3.fromRGB(200, 180, 255)),
	}

	-- Buttons row under the top-left panel.
	HUD.refs.lockBtn = makeButton(frame, "LOCK", UDim2.new(0, 150, 0, 40),
		UDim2.new(0, 16, 0, 156), Color3.fromRGB(220, 80, 90))
	HUD.refs.shopBtn = makeButton(frame, "SHOP", UDim2.new(0, 130, 0, 40),
		UDim2.new(0, 176, 0, 156), Color3.fromRGB(90, 140, 220))
	HUD.refs.shopBtn.MouseButton1Click:Connect(function()
		HUD.OpenShop()
	end)
	HUD.refs.collectBtn = makeButton(frame, "COLLECTION", UDim2.new(0, 150, 0, 40),
		UDim2.new(0, 316, 0, 156), Color3.fromRGB(150, 100, 220))
	HUD.refs.collectBtn.MouseButton1Click:Connect(function()
		HUD.OpenCollection()
	end)

	-- Event banner (top center).
	local banner = makeLabel(frame, "", UDim2.new(0, 420, 0, 40),
		UDim2.new(0.5, -210, 0, 14), Color3.fromRGB(255, 240, 120), Enum.Font.FredokaOne)
	banner.TextXAlignment = Enum.TextXAlignment.Center
	banner.BackgroundColor3 = Color3.fromRGB(30, 34, 40)
	banner.BackgroundTransparency = 0.3
	banner.BorderSizePixel = 2
	banner.Visible = false
	HUD.refs.banner = banner
	HUD.refs.bannerText = banner

	-- Help hint bottom-right.
	local hint = makeLabel(frame,
		"WASD move | E buy/steal | Q slap rival | L lock base",
		UDim2.new(0, 380, 0, 22), UDim2.new(1, -396, 1, -30),
		Color3.fromRGB(220, 220, 220), Enum.Font.FredokaOne)

	-- Build the shop panel (hidden by default).
	HUD.refs.shopPanel = HUD.BuildShopPanel()
	HUD.refs.shopPanel.Parent = frame
	-- Build the collection panel (hidden by default).
	HUD.refs.collectPanel = HUD.BuildCollectionPanel()
	HUD.refs.collectPanel.Parent = frame

	return HUD.refs
end

-- Build the Shop panel with the three upgrade buttons.
function HUD.BuildShopPanel()
	local panel = Instance.new("Frame")
	panel.Name = "ShopPanel"
	panel.Size = UDim2.new(0, 260, 0, 260)
	panel.Position = UDim2.new(0.5, -130, 0.5, -130)
	panel.BackgroundColor3 = Color3.fromRGB(24, 28, 36)
	panel.BackgroundTransparency = 0.15
	panel.BorderSizePixel = 3
	panel.BorderColor3 = Color3.fromRGB(90, 90, 90)
	panel.Visible = false

	makeLabel(panel, "SHOP", UDim2.new(1, -12, 0, 26),
		UDim2.new(0, 6, 0, 4), Color3.fromRGB(255, 220, 90), Enum.Font.FredokaOne)

	local upgrades = {
		{ key = "pedestal", label = "Pedestal +1", cost = 150 },
		{ key = "conveyor", label = "Conveyor +", cost = 200 },
		{ key = "income", label = "Income x1.25", cost = 250 },
	}
	for i, u in ipairs(upgrades) do
		local btn = makeButton(panel, u.label .. "  [$" .. tostring(u.cost) .. "]", UDim2.new(1, -16, 0, 40),
			UDim2.new(0, 8, 0, 36 + (i - 1) * 50), Color3.fromRGB(70, 120, 90))
		btn.MouseButton1Click:Connect(function()
			if HUD.onUpgrade then
				HUD.onUpgrade(u.key)
			end
		end)
	end

	makeLabel(panel, "Rebirth: resets cash/base for x2 income.",
		UDim2.new(1, -16, 0, 40), UDim2.new(0, 8, 0, 196),
		Color3.fromRGB(200, 200, 200), Enum.Font.FredokaOne)

	local close = makeButton(panel, "CLOSE", UDim2.new(1, -16, 0, 28),
		UDim2.new(0, 8, 0, 226), Color3.fromRGB(150, 60, 60))
	close.MouseButton1Click:Connect(function()
		panel.Visible = false
	end)

	return panel
end

-- Build the Collection panel showing the rarity ladder.
function HUD.BuildCollectionPanel(getCollection)
	local panel = Instance.new("Frame")
	panel.Name = "CollectionPanel"
	panel.Size = UDim2.new(0, 300, 0, 340)
	panel.Position = UDim2.new(0.5, -150, 0.5, -170)
	panel.BackgroundColor3 = Color3.fromRGB(24, 28, 36)
	panel.BackgroundTransparency = 0.15
	panel.BorderSizePixel = 3
	panel.BorderColor3 = Color3.fromRGB(90, 90, 90)
	panel.Visible = false

	makeLabel(panel, "COLLECTION", UDim2.new(1, -12, 0, 26),
		UDim2.new(0, 6, 0, 4), Color3.fromRGB(255, 220, 90), Enum.Font.FredokaOne)

	-- Rarity rows.
	local rarityColors = {
		Common = Color3.fromRGB(176, 220, 160),
		Rare = Color3.fromRGB(120, 190, 255),
		Epic = Color3.fromRGB(190, 120, 255),
		Legendary = Color3.fromRGB(255, 200, 90),
		Mythic = Color3.fromRGB(255, 120, 190),
		["Brainrot God"] = Color3.fromRGB(255, 220, 60),
		Secret = Color3.fromRGB(255, 80, 90),
	}
	local order = { "Common", "Rare", "Epic", "Legendary", "Mythic", "Brainrot God", "Secret" }
	HUD.refs.collectionRows = {}
	for i, tier in ipairs(order) do
		local row = makeLabel(panel, tier .. ": 0", UDim2.new(1, -16, 0, 30),
			UDim2.new(0, 8, 0, 34 + (i - 1) * 32), rarityColors[tier])
		row.TextXAlignment = Enum.TextXAlignment.Left
		HUD.refs.collectionRows[i] = { tier = tier, label = row }
	end

	local close = makeButton(panel, "CLOSE", UDim2.new(1, -16, 0, 28),
		UDim2.new(0, 8, 0, 304), Color3.fromRGB(150, 60, 60))
	close.MouseButton1Click:Connect(function()
		panel.Visible = false
	end)

	return panel
end

-- Setter helpers used by Game.client.luau.
function HUD.SetOnUpgrade(cb)
	HUD.onUpgrade = cb
end

function HUD.SetCash(amount)
	if HUD.refs and HUD.refs.cash then
		HUD.refs.cash.Text = "$" .. tostring(math.floor(amount))
	end
end

function HUD.SetIncome(income)
	if HUD.refs and HUD.refs.income then
		HUD.refs.income.Text = "$" .. tostring(math.floor(income)) .. "/s"
	end
end

function HUD.SetRebirths(count)
	if HUD.refs and HUD.refs.rebirth then
		HUD.refs.rebirth.Text = "Rebirths: " .. tostring(count) .. " (x" .. tostring(1 + count * 0.5) .. ")"
	end
end

function HUD.SetLock(left)
	if HUD.refs and HUD.refs.lockBtn then
		if left and left > 0 then
			HUD.refs.lockBtn.Text = "LOCKED " .. tostring(math.ceil(left))
		else
			HUD.refs.lockBtn.Text = "LOCK"
		end
	end
end

function HUD.ShowBanner(text, duration)
	if HUD.refs and HUD.refs.banner then
		HUD.refs.banner.Text = text
		HUD.refs.banner.Visible = true
		task.delay(duration or 3, function()
			HUD.refs.banner.Visible = false
		end)
	end
end

function HUD.SetCollection(collection)
	if not HUD.refs or not HUD.refs.collectionRows then
		return
	end
	for _, row in ipairs(HUD.refs.collectionRows) do
		local count = collection and collection[row.tier] or 0
		row.label.Text = row.tier .. ": " .. tostring(count)
	end
end

function HUD.OpenShop()
	if HUD.refs and HUD.refs.shopPanel then
		HUD.refs.shopPanel.Visible = not HUD.refs.shopPanel.Visible
	end
end

function HUD.OpenCollection()
	if HUD.refs and HUD.refs.collectPanel then
		HUD.refs.collectPanel.Visible = not HUD.refs.collectPanel.Visible
	end
end

function HUD.ApplyState(state)
	if not state then
		return
	end
	HUD.SetCash(state.cash)
	HUD.SetIncome(state.income)
	HUD.SetRebirths(state.rebirths)
	HUD.SetLock(state.lockLeft)
	HUD.SetCollection(state.collection)
end

return HUD