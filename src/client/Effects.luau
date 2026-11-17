-- Effects.luau
-- Simple particles / sounds for buys, steals, slaps, rebirths, and events.
-- Kept light: a handful of Parts and ParticleEmitters.

local Effects = {}

local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

-- A tiny one-shot particle burst at a world position with a given color.
local function burst(position, color, count)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(color)
	emitter.Size = NumberSequence.new(1.5)
	emitter.Lifetime = NumberRange.new(0.5, 1)
	emitter.Speed = NumberRange.new(5, 12)
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Rate = 0
	local attachment = Instance.new("Attachment")
	attachment.Position = position
	attachment.Parent = workspace

	emitter.Parent = attachment
	emitter:Emit(count or 8)
	task.delay(1.5, function()
		emitter:Destroy()
		attachment:Destroy()
	end)
end

-- Play a short beep / pop sound.
local function beep(id)
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = 0.5
	sound.Parent = SoundService
	sound:Play()
	task.delay(1.5, function()
		sound:Destroy()
	end)
end

-- Confetti burst on a successful buy.
function Effects.Buy(position)
	burst(position, Color3.fromRGB(255, 220, 90), 14)
	burst(position + Vector3.new(0, 1, 0), Color3.fromRGB(120, 255, 120), 8)
end

-- Golden / sparkle burst on a steal.
function Effects.Steal(position)
	burst(position, Color3.fromRGB(255, 200, 60), 12)
end

-- Knockback flash when the rival is slapped.
function Effects.Slap(position)
	burst(position, Color3.fromRGB(255, 80, 80), 20)
end

-- Grand rebirth blast.
function Effects.Rebirth(position)
	burst(position, Color3.fromRGB(200, 140, 255), 30)
	burst(position + Vector3.new(0, 2, 0), Color3.fromRGB(255, 255, 120), 18)
end

-- Event fanfare: rainbow sparks across the conveyor.
function Effects.Rain(position)
	burst(position, Color3.fromRGB(120, 220, 255), 18)
	burst(position + Vector3.new(0, 1, 0), Color3.fromRGB(255, 180, 255), 14)
end

-- Golden hour aura.
function Effects.Golden(position)
	burst(position, Color3.fromRGB(255, 215, 0), 24)
	burst(position + Vector3.new(0, 2, 0), Color3.fromRGB(255, 240, 150), 16)
end

return Effects