local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

-- Effects: light visual + audio feedback for buys, steals, slaps, rebirths
-- and events. Simple Part/Sound instances, kept light on purpose.

local Effects = {}

local function playSound(id, volume)
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume or 0.6
	s.Parent = SoundService
	s:Play()
	task.delay(3, function()
		s:Destroy()
	end)
end

local function spawnParticles(position, color, count)
	if not position then
		return
	end
	for i = 1, count or 8 do
		local part = Instance.new("Part")
		part.Shape = Enum.PartType.Ball
		part.Size = Vector3.new(0.4, 0.4, 0.4)
		part.Color = color or Color3.fromRGB(255, 220, 80)
		part.Material = Enum.Material.Neon
		part.Anchored = true
		part.CanCollide = false
		part.Position = position + Vector3.new(math.random(-40, 40) / 100, math.random(0, 30) / 100, math.random(-40, 40) / 100)
		part.Parent = workspace

		local velocity = Instance.new("VectorForce")
		velocity.Force = Vector3.new(math.random(-60, 60) / 10, 40, math.random(-60, 60) / 10)
		velocity.RelativeTo = Enum.ActuatorRelativeTo.World
		velocity.Parent = part

		task.delay(0.8, function()
			part:Destroy()
		end)
	end
end

-- Draw a brief ring flash at a position.
local function spawnRing(position, color)
	if not position then
		return
	end
	local ring = Instance.new("Part")
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(4, 0.2, 4)
	ring.Color = color or Color3.fromRGB(80, 220, 255)
	ring.Material = Enum.Material.Neon
	ring.Anchored = true
	ring.CanCollide = false
	ring.Transparency = 0.3
	ring.CFrame = CFrame.new(position + Vector3.new(0, 0.2, 0))
	ring.Parent = workspace

	local t = 0
	local conn = nil
	conn = RunService.Heartbeat:Connect(function(dt)
		t += dt
		local k = 1 + t
		ring.Size = Vector3.new(4 * k, 0.2, 4 * k)
		ring.Transparency = 0.3 + t * 0.5
		if t > 1 then
			ring:Destroy()
			conn:Disconnect()
		end
	end)
end

local soundMap = {
	buy = { "rbxassetid://9110412196", 0.5 },
	steal = { "rbxassetid://9110412196", 0.4 },
	slap = { "rbxassetid://9110412196", 0.7 },
	lock = { "rbxassetid://9110412196", 0.5 },
	rebirth = { "rbxassetid://9110412196", 0.8 },
	upgrade = { "rbxassetid://9110412196", 0.6 },
}

local colorMap = {
	buy = Color3.fromRGB(80, 220, 255),
	steal = Color3.fromRGB(255, 120, 120),
	slap = Color3.fromRGB(255, 200, 80),
	lock = Color3.fromRGB(120, 120, 255),
	rebirth = Color3.fromRGB(255, 220, 80),
	upgrade = Color3.fromRGB(120, 255, 120),
}

function Effects.play(kind, position, amount)
	local snd = soundMap[kind]
	if snd then
		playSound(snd[1], snd[2])
	end
	local col = colorMap[kind] or Color3.fromRGB(255, 255, 255)
	if kind == "slap" then
		spawnRing(position, col)
	else
		spawnParticles(position, col, 10)
	end
	if kind == "rebirth" then
		spawnRing(position, Color3.fromRGB(255, 220, 80))
		spawnParticles(position, Color3.fromRGB(255, 255, 255), 24)
	end
end

return Effects