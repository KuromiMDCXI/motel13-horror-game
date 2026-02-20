local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local AtmosphereService = {}
AtmosphereService.__index = AtmosphereService

function AtmosphereService.new(playerStateService)
	local self = setmetatable({}, AtmosphereService)
	self._playerStateService = playerStateService
	self._running = false
	self._thread = nil
	return self
end

function AtmosphereService:StartRound()
	self._running = true
	self._thread = task.spawn(function()
		while self._running do
			self:_flickerRandomLight()
			task.wait(math.random(2, 5))
		end
	end)
end

function AtmosphereService:StopRound()
	self._running = false
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
		chosen.Enabled = true
		task.wait(0.05)
		chosen.Enabled = false
		task.wait(0.12)
		chosen.Enabled = previous
	elseif chosen:IsA("BasePart") then
		local original = chosen.Color
		chosen.Color = Color3.fromRGB(12, 12, 12)
		task.wait(0.1)
		chosen.Color = original
	end
end

return AtmosphereService
