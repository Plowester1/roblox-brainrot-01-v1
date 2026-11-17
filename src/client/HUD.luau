-- HUD: the ScreenGui. The game itself is 3D; this module is ONLY the
-- interface over it: cash/income/rebirth stats, Lock/Shop/Collection/
-- Rebirth buttons, the event banner, toasts, the E-prompt and the
-- Collection + Shop panels. It never touches gameplay state directly:
-- Game.client feeds it server snapshots through SetState, and button clicks
-- fire the remotes the server validates.
-- NOTE: Roblox's own menu buttons cover the top-left corner, so the top
-- bar's stats start at x=210 and nothing important sits top-left.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local HUD = {}

local state = nil
local remotes = nil
local gui = nil
local labels = {}
local panels = {}
local rows = {}

local function formatMoney(amount)
	local text = tostring(math.floor(amount or 0))
	local reversed = text:reverse():gsub("(%d%d%d)", "%1,")
	return "$" .. reversed:reverse():gsub("^,", "")
end

local function makeLabel(parent, name, position, size, textSize, color, font)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Position = position
	label.Size = size
	label.BackgroundTransparency = 1
	label.Text = ""
	label.TextColor3 = color or Color3.fromRGB(240, 242, 255)
	label.TextSize = textSize
	label.Font = font or Enum.Font.GothamBold
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = parent
	return label
end

local function makeButton(parent, name, position, size, text, color)
	local button = Instance.new("TextButton")
	button.Name = name
	button.Position = position
	button.Size = size
	button.BackgroundColor3 = color
	button.BorderSizePixel = 0
	button.Text = text
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.TextSize = 14
	button.Font = Enum.Font.GothamBlack
	button.AutoButtonColor = true
	button.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = button
	return button
end

local function makePanel(parent, name, position, size)
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.Position = position
	frame.Size = size
	frame.BackgroundColor3 = Color3.fromRGB(22, 26, 51)
	frame.BorderSizePixel = 0
	frame.Visible = false
	frame.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = frame
	return frame
end

-- GameData.json (ReplicatedStorage.Shared) as a ModuleScript via Rojo.
-- Guarded: if the JSON transform is ever unavailable, the collection
-- panel falls back to the rarity ladder alone.
local gameData = nil
pcall(function()
	gameData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameData"))
end)

local function buildTopBar()
	local bar = Instance.new("Frame")
	bar.Name = "TopBar"
	bar.Position = UDim2.fromOffset(0, 0)
	bar.Size = UDim2.new(1, 0, 0, 64)
	bar.BackgroundColor3 = Color3.fromRGB(17, 22, 48)
	bar.BackgroundTransparency = 0.12
	bar.BorderSizePixel = 0
	bar.Parent = gui
	local accent = Instance.new("Frame")
	accent.Name = "Accent"
	accent.Position = UDim2.new(0, 0, 1, -3)
	accent.Size = UDim2.new(1, 0, 0, 3)
	accent.BackgroundColor3 = Color3.fromRGB(255, 205, 65)
	accent.BorderSizePixel = 0
	accent.Parent = bar

	local function statCard(x, title, icon, color)
		local card = Instance.new("Frame")
		card.Position = UDim2.fromOffset(x, 8)
		card.Size = UDim2.fromOffset(160, 48)
		card.BackgroundColor3 = Color3.fromRGB(26, 30, 59)
		card.BorderSizePixel = 0
		card.Parent = bar
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 10)
		corner.Parent = card
		local dot = Instance.new("Frame")
		dot.Position = UDim2.fromOffset(10, 15)
		dot.Size = UDim2.fromOffset(18, 18)
		dot.BackgroundColor3 = color
		dot.BorderSizePixel = 0
		dot.Parent = card
		local dotCorner = Instance.new("UICorner")
		dotCorner.CornerRadius = UDim.new(0, 9)
		dotCorner.Parent = dot
		makeLabel(card, "Icon", UDim2.fromOffset(14, 14), UDim2.fromOffset(12, 20), 11, Color3.fromRGB(18, 20, 35), Enum.Font.GothamBlack).Text = icon
		makeLabel(card, "Title", UDim2.fromOffset(36, 6), UDim2.fromOffset(120, 14), 9, Color3.fromRGB(166, 176, 213)).Text = title
		return makeLabel(card, "Value", UDim2.fromOffset(36, 22), UDim2.fromOffset(120, 20), 15, Color3.fromRGB(250, 252, 255))
	end

	labels.cash = statCard(210, "CASH", "$", Color3.fromRGB(255, 204, 55))
	labels.income = statCard(380, "INCOME / SEC", "+", Color3.fromRGB(70, 219, 173))
	labels.rebirth = statCard(550, "REBIRTHS", "R", Color3.fromRGB(225, 102, 255))
	labels.cash.Text = "$3,500"
	labels.income.Text = "$0/s"
	labels.rebirth.Text = "0  x1.0"

	labels.lockButton = makeButton(bar, "LockButton", UDim2.fromOffset(730, 10), UDim2.fromOffset(84, 44), "LOCK [L]", Color3.fromRGB(86, 132, 255))
	labels.shopButton = makeButton(bar, "ShopButton", UDim2.fromOffset(824, 10), UDim2.fromOffset(84, 44), "SHOP", Color3.fromRGB(255, 160, 53))
	labels.collectionButton = makeButton(bar, "CollectionButton", UDim2.fromOffset(918, 10), UDim2.fromOffset(128, 44), "COLLECTION [C]", Color3.fromRGB(203, 87, 255))
	labels.rebirthButton = makeButton(bar, "RebirthButton", UDim2.fromOffset(1056, 10), UDim2.fromOffset(150, 44), "REBIRTH", Color3.fromRGB(49, 211, 165))
	labels.title = makeLabel(bar, "Title", UDim2.new(1, -210, 0, 18), UDim2.fromOffset(200, 28), 13, Color3.fromRGB(255, 240, 126), Enum.Font.GothamBlack)
	labels.title.TextXAlignment = Enum.TextXAlignment.Right
	labels.title.Text = "BRAINROT BASE WARS"
end

local function buildBannerToastPrompt()
	local banner = Instance.new("Frame")
	banner.Name = "EventBanner"
	banner.AnchorPoint = Vector2.new(0.5, 0)
	banner.Position = UDim2.new(0.5, 0, 0, 76)
	banner.Size = UDim2.fromOffset(560, 44)
	banner.BackgroundColor3 = Color3.fromRGB(78, 35, 96)
	banner.BorderSizePixel = 0
	banner.Visible = false
	banner.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = banner
	labels.bannerText = makeLabel(banner, "Text", UDim2.fromOffset(16, 0), UDim2.new(1, -32, 1, 0), 15, Color3.fromRGB(255, 245, 189), Enum.Font.GothamBlack)
	labels.bannerText.TextXAlignment = Enum.TextXAlignment.Center
	labels.banner = banner

	local toast = makeLabel(gui, "Toast", UDim2.new(0.5, -300, 1, -150), UDim2.fromOffset(600, 30), 16, Color3.fromRGB(255, 255, 255), Enum.Font.GothamBold)
	toast.TextXAlignment = Enum.TextXAlignment.Center
	toast.TextStrokeColor3 = Color3.fromRGB(10, 10, 20)
	toast.TextStrokeTransparency = 0.2
	labels.toast = toast

	local prompt = makeLabel(gui, "Prompt", UDim2.new(0.5, -300, 1, -110), UDim2.fromOffset(600, 30), 16, Color3.fromRGB(255, 242, 135), Enum.Font.GothamBlack)
	prompt.TextXAlignment = Enum.TextXAlignment.Center
	prompt.TextStrokeColor3 = Color3.fromRGB(10, 10, 20)
	prompt.TextStrokeTransparency = 0.2
	labels.prompt = prompt

	local hint = makeLabel(gui, "Hint", UDim2.new(0, 16, 1, -34), UDim2.fromOffset(560, 22), 12, Color3.fromRGB(220, 226, 245))
	hint.Text = "WASD move - E interact - Q slap rival - L lock base - C collection"
	hint.TextStrokeColor3 = Color3.fromRGB(10, 10, 20)
	hint.TextStrokeTransparency = 0.3
end

local function rarityColor(name)
	if gameData then
		for _, rarity in ipairs(gameData.rarities) do
			if rarity.name == name then
				local c = rarity.color
				return Color3.new(c[1], c[2], c[3])
			end
		end
	end
	return Color3.fromRGB(200, 200, 200)
end

local function buildCollectionPanel()
	local panel = makePanel(gui, "CollectionPanel", UDim2.new(0.5, -360, 0.5, -240), UDim2.fromOffset(720, 480))
	panels.collection = panel
	makeLabel(panel, "Header", UDim2.fromOffset(20, 14), UDim2.fromOffset(500, 28), 20, Color3.fromRGB(248, 249, 255), Enum.Font.GothamBlack).Text = "BRAINROT COLLECTION"
	labels.collectionCount = makeLabel(panel, "Count", UDim2.fromOffset(20, 44), UDim2.fromOffset(500, 18), 12, Color3.fromRGB(148, 161, 201))
	labels.collectionCount.Text = "0 OWNED"
	local close = makeButton(panel, "Close", UDim2.fromOffset(660, 12), UDim2.fromOffset(44, 32), "X", Color3.fromRGB(220, 60, 76))
	close.TextSize = 16
	close.MouseButton1Click:Connect(function()
		panel.Visible = false
	end)

	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "List"
	scroll.Position = UDim2.fromOffset(16, 72)
	scroll.Size = UDim2.new(1, -32, 1, -88)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 6
	scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.Parent = scroll

	if gameData then
		for _, brainrot in ipairs(gameData.brainrots) do
			local color = Color3.new(brainrot.color[1], brainrot.color[2], brainrot.color[3])
			local row = Instance.new("Frame")
			row.Name = brainrot.id
			row.Size = UDim2.new(1, 0, 0, 44)
			row.BackgroundColor3 = Color3.fromRGB(30, 35, 66)
			row.BorderSizePixel = 0
			row.Parent = scroll
			local rowCorner = Instance.new("UICorner")
			rowCorner.CornerRadius = UDim.new(0, 9)
			rowCorner.Parent = row
			local chip = Instance.new("Frame")
			chip.Position = UDim2.fromOffset(8, 7)
			chip.Size = UDim2.fromOffset(30, 30)
			chip.BackgroundColor3 = color
			chip.BorderSizePixel = 0
			chip.Parent = row
			local chipCorner = Instance.new("UICorner")
			chipCorner.CornerRadius = UDim.new(0, 7)
			chipCorner.Parent = chip
			makeLabel(row, "Name", UDim2.fromOffset(48, 5), UDim2.fromOffset(280, 18), 13, Color3.fromRGB(240, 242, 255)).Text = brainrot.name
			local rarityLabel = makeLabel(row, "Rarity", UDim2.fromOffset(48, 24), UDim2.fromOffset(180, 14), 11, rarityColor(brainrot.rarity))
			rarityLabel.Text = brainrot.rarity:upper()
			makeLabel(row, "Income", UDim2.new(1, -220, 0, 12), UDim2.fromOffset(100, 18), 13, Color3.fromRGB(103, 235, 165)).Text = ("+$%d/s"):format(brainrot.income)
			local ownedLabel = makeLabel(row, "Owned", UDim2.new(1, -110, 0, 12), UDim2.fromOffset(100, 18), 12, Color3.fromRGB(238, 224, 144))
			ownedLabel.TextXAlignment = Enum.TextXAlignment.Right
			ownedLabel.Text = formatMoney(brainrot.price)
			rows[brainrot.id] = ownedLabel
		end
	end

	-- Rarity ladder under the list: every tier, its weight and base income.
	local ladder = makeLabel(panel, "Ladder", UDim2.fromOffset(20, 0), UDim2.fromOffset(680, 16), 11, Color3.fromRGB(148, 161, 201))
	ladder.Position = UDim2.new(0, 20, 1, -24)
	if gameData then
		local parts = {}
		for _, rarity in ipairs(gameData.rarities) do
			-- Weights sum to 100, so each weight IS its spawn percent.
			local weightText = rarity.weight == math.floor(rarity.weight)
				and tostring(rarity.weight)
				or ("%.1f"):format(rarity.weight)
			table.insert(parts, ("%s %s%%"):format(rarity.name, weightText))
		end
		ladder.Text = "Rarity weights (of spawns): " .. table.concat(parts, "  -  ")
	else
		ladder.Text = "Rarities: Common - Rare - Epic - Legendary - Mythic - Brainrot God - Secret"
	end
end

local function buildShopPanel()
	local panel = makePanel(gui, "ShopPanel", UDim2.new(0.5, -220, 0.5, -190), UDim2.fromOffset(440, 380))
	panels.shop = panel
	makeLabel(panel, "Header", UDim2.fromOffset(20, 14), UDim2.fromOffset(300, 28), 20, Color3.fromRGB(248, 249, 255), Enum.Font.GothamBlack).Text = "UPGRADES"
	local close = makeButton(panel, "Close", UDim2.fromOffset(380, 12), UDim2.fromOffset(44, 32), "X", Color3.fromRGB(220, 60, 76))
	close.TextSize = 16
	close.MouseButton1Click:Connect(function()
		panel.Visible = false
	end)

	local upgrades = {
		{ key = "Pedestal", title = "Extra Pedestal", desc = "One more base slot (max 12)" },
		{ key = "Conveyor", title = "Faster Conveyor", desc = "Brainrots spawn more often" },
		{ key = "Income", title = "Income Boost", desc = "+25% income multiplier" },
	}
	labels.upgradeButtons = {}
	for index, upgrade in ipairs(upgrades) do
		local y = 60 + (index - 1) * 96
		local row = Instance.new("Frame")
		row.Position = UDim2.fromOffset(16, y)
		row.Size = UDim2.new(1, -32, 0, 84)
		row.BackgroundColor3 = Color3.fromRGB(30, 35, 66)
		row.BorderSizePixel = 0
		row.Parent = panel
		local rowCorner = Instance.new("UICorner")
		rowCorner.CornerRadius = UDim.new(0, 10)
		rowCorner.Parent = row
		makeLabel(row, "Title", UDim2.fromOffset(14, 10), UDim2.fromOffset(240, 20), 15, Color3.fromRGB(240, 242, 255)).Text = upgrade.title
		makeLabel(row, "Desc", UDim2.fromOffset(14, 34), UDim2.fromOffset(240, 34), 12, Color3.fromRGB(148, 161, 201)).Text = upgrade.desc
		local buy = makeButton(row, "Buy", UDim2.new(1, -130, 0, 20), UDim2.fromOffset(116, 44), "BUY", Color3.fromRGB(49, 211, 165))
		buy.MouseButton1Click:Connect(function()
			if remotes and remotes.BuyUpgrade then
				remotes.BuyUpgrade:FireServer(upgrade.key)
			end
		end)
		labels.upgradeButtons[upgrade.key] = buy
	end
end

function HUD.SetState(payload)
	state = payload
	labels.cash.Text = formatMoney(payload.cash)
	labels.income.Text = ("$%d/s"):format(payload.income)
	labels.rebirth.Text = ("%d  x%.1f"):format(payload.rebirths, payload.multiplier)
	if payload.lockRemaining and payload.lockRemaining > 0 then
		labels.lockButton.Text = ("LOCKED %ds"):format(payload.lockRemaining)
		labels.lockButton.BackgroundColor3 = Color3.fromRGB(49, 211, 165)
	elseif payload.lockCooldown and payload.lockCooldown > 0 then
		labels.lockButton.Text = ("LOCK %ds"):format(payload.lockCooldown)
		labels.lockButton.BackgroundColor3 = Color3.fromRGB(120, 124, 150)
	else
		labels.lockButton.Text = "LOCK [L]"
		labels.lockButton.BackgroundColor3 = Color3.fromRGB(86, 132, 255)
	end
	if payload.rebirthNeed then
		labels.rebirthButton.Text = ("REBIRTH %d+%s"):format(payload.rebirthNeed.count, formatMoney(payload.rebirthNeed.cash))
	end
	if payload.upgradeCosts then
		for key, button in pairs(labels.upgradeButtons or {}) do
			local cost = payload.upgradeCosts[key]
			button.Text = cost and formatMoney(cost) or "MAX"
		end
	end
	if payload.ownedIds then
		local owned = {}
		for _, id in ipairs(payload.ownedIds) do
			owned[id] = true
		end
		for id, label in pairs(rows) do
			if owned[id] then
				label.Text = "OWNED"
				label.TextColor3 = Color3.fromRGB(103, 235, 165)
			end
		end
		labels.collectionCount.Text = ("%d OWNED  /  %d PEDESTALS"):format(payload.ownedCount or 0, payload.pedestals or 0)
	end
end

function HUD.ShowToast(text)
	labels.toast.Text = text
	task.delay(3, function()
		if labels.toast.Text == text then
			labels.toast.Text = ""
		end
	end)
end

function HUD.ShowBanner(text, duration)
	labels.bannerText.Text = text
	labels.banner.Visible = true
	task.delay(duration or 5, function()
		if labels.bannerText.Text == text then
			labels.banner.Visible = false
		end
	end)
end

function HUD.SetPrompt(text)
	labels.prompt.Text = text or ""
end

function HUD.ToggleCollection()
	panels.shop.Visible = false
	panels.collection.Visible = not panels.collection.Visible
end

function HUD.ToggleShop()
	panels.collection.Visible = false
	panels.shop.Visible = not panels.shop.Visible
end

function HUD.GetGui()
	return gui
end

function HUD.Build(remotesFolder)
	remotes = remotesFolder
	gui = Instance.new("ScreenGui")
	gui.Name = "BrainrotHUD"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 10
	buildTopBar()
	buildBannerToastPrompt()
	buildCollectionPanel()
	buildShopPanel()
	labels.lockButton.MouseButton1Click:Connect(function()
		if remotes and remotes.LockBase then
			remotes.LockBase:FireServer()
		end
	end)
	labels.shopButton.MouseButton1Click:Connect(HUD.ToggleShop)
	labels.collectionButton.MouseButton1Click:Connect(HUD.ToggleCollection)
	labels.rebirthButton.MouseButton1Click:Connect(function()
		if remotes and remotes.Rebirth then
			remotes.Rebirth:FireServer()
		end
	end)
	gui.Parent = player:WaitForChild("PlayerGui")
	return HUD
end

return HUD
