local Players = game:GetService("Players")

-- HUD: the ScreenGui overlay. Builds cash/income/rebirth counters, the Lock and
-- Shop buttons, a Collection (rarity ladder) panel, an event banner, and wires
-- it to the client entry points.

local HUD = {}

local player = Players.LocalPlayer

local function makeButton(parent, text, size, pos, color)
	local btn = Instance.new("TextButton")
	btn.Size = size
	btn.Position = pos
	btn.BackgroundColor3 = color or Color3.fromRGB(50, 90, 160)
	btn.BorderSizePixel = 0
	btn.Font = Enum.Font.GothamBold
	btn.Text = text
	btn.TextColor3 = Color3.fromRGB(255, 255, 255)
	btn.TextSize = 20
	btn.AutoButtonColor = true
	btn.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = btn
	return btn
end

local function makeLabel(parent, text, size, pos, fontSize, color)
	local lbl = Instance.new("TextLabel")
	lbl.Size = size
	lbl.Position = pos
	lbl.BackgroundTransparency = 1
	lbl.Font = Enum.Font.GothamBold
	lbl.Text = text
	lbl.TextColor3 = color or Color3.fromRGB(255, 255, 255)
	lbl.TextSize = fontSize
	lbl.TextStrokeTransparency = 0
	lbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	lbl.Parent = parent
	return lbl
end

local function addStroke(ui)
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(0, 0, 0)
	stroke.Thickness = 2
	stroke.Parent = ui
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "BrainrotHUD"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.Parent = player:WaitForChild("PlayerGui")

-- top-left info panel
local topLeft = Instance.new("Frame")
topLeft.Size = UDim2.new(0, 240, 0, 120)
topLeft.Position = UDim2.new(0, 12, 0, 12)
topLeft.BackgroundColor3 = Color3.fromRGB(10, 10, 15)
topLeft.BackgroundTransparency = 0.25
topLeft.BorderSizePixel = 0
topLeft.Parent = screenGui
addStroke(topLeft)
local tlc = Instance.new("UICorner")
tlc.CornerRadius = UDim.new(0, 10)
tlc.Parent = topLeft

local title = makeLabel(topLeft, "BRAINROT BASE WARS", UDim2.new(1, -16, 0, 24), UDim2.new(0, 8, 0, 6), 18, Color3.fromRGB(255, 220, 80))
title.TextXAlignment = Enum.TextXAlignment.Left
local cashLbl = makeLabel(topLeft, "$0", UDim2.new(1, -16, 0, 30), UDim2.new(0, 8, 0, 34), 28, Color3.fromRGB(120, 255, 140))
cashLbl.TextXAlignment = Enum.TextXAlignment.Left
local incomeLbl = makeLabel(topLeft, "$0/s", UDim2.new(1, -16, 0, 22), UDim2.new(0, 8, 0, 66), 18, Color3.fromRGB(160, 190, 255))
incomeLbl.TextXAlignment = Enum.TextXAlignment.Left
local rebirthLbl = makeLabel(topLeft, "Rebirths: 0", UDim2.new(1, -16, 0, 20), UDim2.new(0, 8, 0, 90), 15, Color3.fromRGB(255, 200, 200))
rebirthLbl.TextXAlignment = Enum.TextXAlignment.Left

-- right-side buttons
local lockBtn = makeButton(screenGui, "LOCK BASE (L)", UDim2.new(0, 150, 0, 42), UDim2.new(1, -165, 0, 12), Color3.fromRGB(40, 120, 80))
local lockCdLbl = makeLabel(screenGui, "", UDim2.new(0, 150, 0, 18), UDim2.new(1, -165, 0, 54), 13, Color3.fromRGB(255, 220, 120))
local shopBtn = makeButton(screenGui, "SHOP", UDim2.new(0, 96, 0, 40), UDim2.new(1, -105, 0, 70), Color3.fromRGB(120, 80, 40))
local collectBtn = makeButton(screenGui, "COLLECTION", UDim2.new(0, 140, 0, 40), UDim2.new(1, -152, 0, 118), Color3.fromRGB(80, 80, 130))

-- event banner (top center)
local banner = makeLabel(screenGui, "", UDim2.new(0, 480, 0, 44), UDim2.new(0.5, -240, 0, 60), 26, Color3.fromRGB(255, 255, 120))
banner.Visible = false
banner.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
banner.BackgroundTransparency = 0.2
banner.ZIndex = 5
addStroke(banner)

-- golden hour icon
local goldenLbl = makeLabel(screenGui, "GOLDEN HOUR x2", UDim2.new(0, 200, 0, 26), UDim2.new(0.5, -100, 0, 110), 18, Color3.fromRGB(255, 210, 80))
goldenLbl.Visible = false

return {
	screenGui = screenGui,
	topLeft = topLeft,
	cash = cashLbl,
	income = incomeLbl,
	rebirth = rebirthLbl,
	lockBtn = lockBtn,
	lockCd = lockCdLbl,
	shopBtn = shopBtn,
	collectBtn = collectBtn,
	banner = banner,
	golden = goldenLbl,
}