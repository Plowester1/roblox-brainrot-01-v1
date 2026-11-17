-- Effects.luau
-- Lightweight client-side effects: particle bursts and simple sounds for buys,
-- steals, slaps, rebirths, and event fanfares.

local Effects = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

-- A short sound played through the SoundService.
local function playSound(id, parent)
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = 0.6
	sound.Parent = parent or SoundService
	sound:Play()
	sound.Ended:Connect(function()
		sound:Destroy()
	end)
end

-- A quick colored particle burst at a position.
local function burst(position, color, count)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.Size = Vector3.new(1, 1, 1)
	part.Transparency = 1
	part.Parent = workspace
	part.CFrame = CFrame.new(position)

	local attach = Instance.new("Attachment")
	attach.Position = Vector3.new(0, 0, 0)
	attach.Parent = part

	local particle = Instance.new("ParticleEmitter")
	particle.Rate = 0
	particle.Speed = NumberRange.new(3, 8)
	particle.SpreadAngle = Vector2.new(360, 360)
	particle.Lifetime = NumberRange.new(0.4, 0.8)
	particle.Size = NumberSequence.new(0.5, 0)
	particle.Color = ColorSequence.new(color)
	particle.Parent = attach
	particle:Emit(count or 10)

	task.delay(1.5, function()
		part:Destroy()
	end)
end

Effects.burst = burst

-- Played when a brainrot is bought.
function Effects.buy(position, color)
	burst(position, color, 12)
	playSound("rbxassetid://91161262508")
end

-- Played when the rival is slapped.
function Effects.slap(position)
	burst(position, Color3.new(1, 1, 1), 16)
	playSound("rbxassetid://91251675971")
end

-- Played on a rebirth.
function Effects.rebirth(position)
	for i = 1, 6 do
		task.delay(i * 0.08, function()
			burst(position + Vector3.new(math.random(-4, 4), math.random(0, 6), math.random(-4, 4)), Color3.new(1, 1, 0.4), 20)
		end)
	end
	playSound("rbxassetid://91190725453")
end

-- Event fanfare.
function Effects.fanfare(position)
	burst(position, Color3.new(0.4, 1, 0.8), 30)
	playSound("rbxassetid://91227725074")
end

return Effects