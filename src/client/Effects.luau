-- Effects: client-side juice. Particle bursts + a short sound for buys,
-- steals, slaps, rebirths and events. Everything is created locally and
-- cleaned up with Debris, so a burst can never leak parts into the world.
-- Sounds use engine-bundled rbxasset:// clips (no uploaded assets needed);
-- a clip that fails to load just stays silent, the burst still shows.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")

local player = Players.LocalPlayer
local Effects = {}

local PRESETS = {
	Buy = { color = Color3.fromRGB(255, 210, 63), count = 26, size = 0.55, sound = "rbxasset://sounds/electronicpingshort.wav", volume = 0.5 },
	Steal = { color = Color3.fromRGB(183, 73, 255), count = 30, size = 0.6, sound = "rbxasset://sounds/electronicpingshort.wav", volume = 0.5 },
	Slap = { color = Color3.fromRGB(255, 92, 60), count = 40, size = 0.8, sound = "rbxasset://sounds/impact_water.mp3", volume = 0.7 },
	Rebirth = { color = Color3.fromRGB(255, 215, 90), count = 80, size = 0.7, sound = "rbxasset://sounds/electronicpingshort.wav", volume = 0.8 },
	Rain = { color = Color3.fromRGB(92, 220, 255), count = 50, size = 0.6, sound = "rbxasset://sounds/electronicpingshort.wav", volume = 0.6 },
	Golden = { color = Color3.fromRGB(255, 236, 120), count = 60, size = 0.7, sound = "rbxasset://sounds/electronicpingshort.wav", volume = 0.7 },
}

local function playSound(preset)
	local sound = Instance.new("Sound")
	sound.SoundId = preset.sound
	sound.Volume = preset.volume or 0.5
	sound.Parent = SoundService
	pcall(function()
		sound:Play()
	end)
	Debris:AddItem(sound, 3)
end

-- Burst of particles at a world position (or above the player's head when
-- the server sent no position, e.g. for world-wide events).
function Effects.Burst(kind, position)
	local preset = PRESETS[kind] or PRESETS.Buy
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local at = position or (root and root.Position + Vector3.new(0, 3, 0)) or Vector3.zero
	local anchor = Instance.new("Part")
	anchor.Name = "EffectAnchor"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.5, 0.5, 0.5)
	anchor.CFrame = CFrame.new(at)
	anchor.Parent = workspace
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(preset.color)
	emitter.Size = NumberSequence.new(preset.size)
	emitter.Speed = NumberRange.new(8, 18)
	emitter.Lifetime = NumberRange.new(0.4, 0.9)
	emitter.Rate = 0
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Parent = anchor
	emitter:Emit(preset.count)
	Debris:AddItem(anchor, 2)
	playSound(preset)
end

-- A golden flash across the whole screen for Golden Hour (a full-screen
-- Frame that fades out), so the event reads even when the player is
-- looking away from the world.
function Effects.GoldenFlash(gui)
	local flash = Instance.new("Frame")
	flash.Name = "GoldenFlash"
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = Color3.fromRGB(255, 220, 90)
	flash.BackgroundTransparency = 0.85
	flash.BorderSizePixel = 0
	flash.ZIndex = 5
	flash.Parent = gui
	task.spawn(function()
		for step = 1, 20 do
			flash.BackgroundTransparency = 0.85 + (step / 20) * 0.15
			task.wait(0.05)
		end
		flash:Destroy()
	end)
end

return Effects
