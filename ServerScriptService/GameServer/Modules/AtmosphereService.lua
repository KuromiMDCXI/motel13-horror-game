local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local AtmosphereService = {}
AtmosphereService.__index = AtmosphereService

function AtmosphereService.new()
	local self = setmetatable({}, AtmosphereService)
	self._running = false
	self._powerOn = false
	self._eventRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("AtmosphereEvent")
	return self
end

function AtmosphereService:SetLobbyPreset()
	Lighting.ClockTime = 18.2
	Lighting.Brightness = 1.8
	Lighting.Ambient = Color3.fromRGB(55, 55, 70)
	Lighting.OutdoorAmbient = Color3.fromRGB(70, 70, 85)
	Lighting.FogStart = 70
	Lighting.FogEnd = 280
	self:_ensurePostEffects(Color3.fromRGB(225, 220, 210), 0.03)
end

function AtmosphereService:StartRound()
	self._running = true
	self._powerOn = false
	self:_applyNightPreset()
	self:_applyPowerState(false)
	task.spawn(function()
		while self._running do
			self:_flickerRandomLight()
			task.wait(math.random(2, 5))
		end
	end)
end

function AtmosphereService:StopRound()
	self._running = false
	self:SetLobbyPreset()
end

function AtmosphereService:SetPowerRestored(powerOn: boolean)
	self._powerOn = powerOn
	self:_applyPowerState(powerOn)
	if powerOn then
		self._eventRemote:FireAllClients("BreakerPop")
	end
end

function AtmosphereService:_applyNightPreset()
	Lighting.ClockTime = 1.2
	Lighting.Brightness = 0.8
	Lighting.Ambient = Color3.fromRGB(18, 22, 30)
	Lighting.OutdoorAmbient = Color3.fromRGB(8, 12, 20)
	Lighting.FogStart = 10
	Lighting.FogEnd = 120
	self:_ensurePostEffects(Color3.fromRGB(188, 210, 255), -0.06)
end

function AtmosphereService:_ensurePostEffects(tint: Color3, brightness: number)
	local color = Lighting:FindFirstChild("M13Color")
	if not color then
		color = Instance.new("ColorCorrectionEffect")
		color.Name = "M13Color"
		color.Parent = Lighting
	end
	color.TintColor = tint
	color.Brightness = brightness
	color.Contrast = 0.12
	color.Saturation = -0.2

	local bloom = Lighting:FindFirstChild("M13Bloom")
	if not bloom then
		bloom = Instance.new("BloomEffect")
		bloom.Name = "M13Bloom"
		bloom.Parent = Lighting
	end
	bloom.Intensity = 0.22
	bloom.Size = 22
	bloom.Threshold = 1.2
end

function AtmosphereService:_applyPowerState(powerOn: boolean)
	for _, inst in ipairs(CollectionService:GetTagged(Config.Tags.PowerLight)) do
		if inst:IsA("Light") then
			inst.Enabled = powerOn
		elseif inst:IsA("BasePart") then
			inst.Material = powerOn and Enum.Material.SmoothPlastic or Enum.Material.Metal
		end
	end
	for _, inst in ipairs(CollectionService:GetTagged(Config.Tags.EmergencyLight)) do
		if inst:IsA("Light") then
			inst.Enabled = not powerOn
			if not powerOn then
				inst.Color = Color3.fromRGB(255, 70, 70)
			end
		end
	end
end

function AtmosphereService:_flickerRandomLight()
	local lights = CollectionService:GetTagged(Config.Tags.LightFlicker)
	if #lights == 0 then
		return
	end
	local chosen = lights[math.random(1, #lights)]
	if chosen:IsA("Light") then
		local previous = chosen.Enabled
		chosen.Enabled = false
		task.wait(0.08)
		chosen.Enabled = previous
	elseif chosen:IsA("BasePart") then
		local original = chosen.Color
		chosen.Color = Color3.fromRGB(20, 20, 20)
		task.wait(0.1)
		chosen.Color = original
	end
end

return AtmosphereService
