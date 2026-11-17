-- HUD.luau
-- Builds the on-screen HUD (cash, income, rebirth, lock/shop/collection buttons,
-- and the event banner). The HUD is only the interface overlay: the game itself
-- is 3D. This module exposes functions the client script calls.

local HUD = {}

local gui
local cashLabel, incomeLabel, rebirthLabel, banner, lockButton, lockText
local shopButton, collectionButton, collectionFrame
local lastBannerText = ""

local function label(name, size, color, pos, parent, text)
	local l = Instance.new("TextLabel")
	l.Name = name
	l.Size = size
	l.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
	l.BackgroundTransparency = 0.2
	l.BorderSizePixel = 0
	l.TextColor3 = color
	l.Font = Enum.Font.SourceSansBold
	l.TextSize = 22
	l.Text = text
	l.Position = pos
	l.Parent = parent
	return l
end

-- Build the full HUD into a ScreenGui. Returns a table of named elements.
function HUD.build(screenGui)
	gui = screenGui

	local top = Instance.new("Frame")
	top.Name = "TopBar"
	top.Size = UDim2.new(0.5, 0, 0, 70)
	top.Position = UDim2.new(0.5, 0, 0, 12)
	top.AnchorPoint = Vector2.new(0.5, 0)
	top.BackgroundColor3 = Color3.fromRGB(16, 16, 26)
	top.BackgroundTransparency = 0.25
	top.BorderSizePixel = 0
	top.Parent = gui

	cashLabel = label("Cash", UDim2.fromScale(0.33, 0.5), Color3.fromRGB(120, 255, 120), UDim2.fromScale(0, 0), top, "$0")
	cashLabel.BackgroundTransparency = 1
	cashLabel.TextScaled = false
	cashLabel.TextSize = 26

	incomeLabel = label("Income", UDim2.fromScale(0.33, 0.5), Color3.fromRGB(255, 230, 120), UDim2.fromScale(0.33, 0), top, "$0/s")
	incomeLabel.BackgroundTransparency = 1
	incomeLabel.TextSize = 22

	rebirthLabel = label("Rebirth", UDim2.fromScale(0.34, 0.5), Color3.fromRGB(160, 200, 255), UDim2.fromScale(0.66, 0), top, "Noob")
	rebirthLabel.BackgroundTransparency = 1
	rebirthLabel.TextSize = 22

	-- Event banner (top center, slides in and fades).
	banner = Instance.new("TextLabel")
	banner.Name = "Banner"
	banner.Size = UDim2.fromScale(0.7, 0)
	banner.Size = UDim2.fromOffset(640, 60)
	banner.Position = UDim2.new(0.5, 0, 0, 120)
	banner.AnchorPoint = Vector2.new(0.5, 0)
	banner.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
	banner.BackgroundTransparency = 0.2
	banner.TextColor3 = Color3.fromRGB(255, 255, 255)
	banner.Font = Enum.Font.SourceSansBold
	banner.TextSize = 30
	banner.Text = ""
	banner.Visible = false
	banner.Parent = gui

	HUD.cashLabel = cashLabel
	HUD.incomeLabel = incomeLabel
	HUD.rebirthLabel = rebirthLabel
	HUD.banner = banner
	return top
end

-- ------------------------------------------------------------------ updates

local function money(v)
	return "$" .. tostring(math.floor(v))
end

function HUD.updateCash(v)
	if cashLabel then
		cashLabel.Text = money(v)
	end
end

function HUD.updateIncome(v, mult)
	if incomeLabel then
		incomeLabel.Text = money(v) .. "/s x" .. tostring(mult)
	end
end

function HUD.updateRebirth(count, title)
	if rebirthLabel then
		rebirthLabel.Text = "Rebirth " .. tostring(count) .. " - " .. tostring(title)
	end
end

-- Show the event banner, fading it out after a few seconds.
function HUD.showBanner(text)
	if not banner then
		return
	end
	lastBannerText = text
	banner.Text = text
	banner.Visible = true
	banner.BackgroundTransparency = 0.2
	spawn(function()
		task.wait(4)
		if lastBannerText == text then
			banner.Visible = false
		end
	end)
end

-- ---------------------------------------------------------------- buttons

local callbacks = {}
HUD.callbacks = callbacks

local function makeButton(name, text, pos, color)
	local b = Instance.new("TextButton")
	b.Name = name
	b.Size = UDim2.new(0.14, 0, 0, 44)
	b.Position = pos
	b.BackgroundColor3 = color
	b.BorderSizePixel = 0
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Font = Enum.Font.SourceSansBold
	b.TextSize = 18
	b.Text = text
	b.Parent = gui
	return b
end

-- Build the bottom-left control buttons.
function HUD.buildButtons()
	lockButton = makeButton("LockButton", "[L] Lock Base", UDim2.new(0.02, 0, 108, 0), Color3.fromRGB(60, 120, 200))
	lockText = lockButton
	shopButton = makeButton("ShopButton", "Shop", UDim2.new(0.02, 0, 160, 0), Color3.fromRGB(180, 140, 40))
	collectionButton = makeButton("CollectionButton", "Collection", UDim2.new(0.02, 0, 212, 0), Color3.fromRGB(120, 90, 200))

	lockButton.Activated:Connect(function()
		if callbacks.onLock then
			callbacks.onLock()
		end
	end)
	shopButton.Activated:Connect(function()
		if callbacks.onShop then
			callbacks.onShop()
		end
	end)
	collectionButton.Activated:Connect(function()
		if callbacks.onCollection then
			callbacks.onCollection()
		end
	end)
end

-- Set the lock button's cooldown text and enabled state.
function HUD.updateLock(secondsLeft, ready)
	if lockButton then
		if ready then
			lockButton.Text = "[L] Lock Base"
			lockButton.BackgroundColor3 = Color3.fromRGB(60, 120, 200)
		else
			lockButton.Text = "Lock (" .. tostring(math.ceil(secondsLeft)) .. "s)"
			lockButton.BackgroundColor3 = Color3.fromRGB(70, 70, 80)
		end
	end
end

HUD.lockButton = lockButton

-- ---------------------------------------------------------------- collection

-- Build the collection panel: the rarity ladder and which brainrots are owned.
function HUD.buildCollection(rarities, brainrots)
	collectionFrame = Instance.new("Frame")
	collectionFrame.Name = "CollectionFrame"
	collectionFrame.Size = UDim2.new(0.3, 0, 0.8, 0)
	collectionFrame.Position = UDim2.new(0.34, 0, 0.1, 0)
	collectionFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 24)
	collectionFrame.BackgroundTransparency = 0.15
	collectionFrame.BorderSizePixel = 0
	collectionFrame.Visible = false
	collectionFrame.Parent = gui

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 40)
	title.BackgroundTransparency = 1
	title.Text = "COLLECTION"
	title.TextColor3 = Color3.new(1, 1, 1)
	title.Font = Enum.Font.SourceSansBold
	title.TextSize = 24
	title.Parent = collectionFrame

	local list = Instance.new("Frame")
	list.Name = "List"
	list.Size = UDim2.new(1, 0, 1, -40)
	list.Position = UDim2.new(0, 0, 0, 40)
	list.BackgroundTransparency = 1
	list.Parent = collectionFrame

	-- Rows: one per rarity tier, listing its brainrots.
	local y = 0
	local owned = HUD.owned or {}
	for _, r in ipairs(rarities) do
		local row = Instance.new("TextLabel")
		row.Name = "Rarity_" .. r.name
		row.Size = UDim2.new(1, 0, 0, 26)
		row.Position = UDim2.new(0, 0, 0, y)
		row.BackgroundColor3 = Color3.fromRGB(r.color[1], r.color[2], r.color[3])
		row.BorderSizePixel = 0
		row.TextColor3 = Color3.new(0, 0, 0)
		row.Font = Enum.Font.SourceSansBold
		row.TextSize = 18
		row.Text = r.name .. " (x" .. tostring(r.weight) .. ")"
		row.Parent = list
		y += 26
		for _, b in ipairs(brainrots) do
			if b.rarity == r.name then
				local ownedMark = owned[b.name] and "  [OWNED]" or ""
				local item = Instance.new("TextLabel")
				item.Name = "Item_" .. b.name
				item.Size = UDim2.new(1, 0, 0, 20)
				item.Position = UDim2.new(0.1, 0, 0, y)
				item.BackgroundTransparency = 1
				item.TextColor3 = owned[b.name] and Color3.new(0.4, 1, 0.4) or Color3.new(0.7, 0.7, 0.7)
				item.Font = Enum.Font.SourceSans
				item.TextSize = 15
				item.Text = b.name .. "  $" .. tostring(b.income) .. "/s" .. ownedMark
				item.Parent = list
				y += 20
			end
		end
	end
	HUD.collectionFrame = collectionFrame
	return collectionFrame
end

-- Toggle the collection panel.
function HUD.toggleCollection()
	if collectionFrame then
		collectionFrame.Visible = not collectionFrame.Visible
	end
end

-- Update which brainrots the player owns (for the collection panel).
function HUD.setOwned(names)
	HUD.owned = names or {}
end

return HUD