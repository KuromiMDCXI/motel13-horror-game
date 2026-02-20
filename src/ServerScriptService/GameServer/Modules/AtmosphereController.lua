-- Explorer Path: ServerScriptService/GameServer/Modules/AtmosphereController
--!strict

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local AtmosphereController = {}
AtmosphereController.__index = AtmosphereController

function AtmosphereController.new(config, remotes)
	local self = setmetatable({}, AtmosphereController)
	self._config = config
	self._remotes = remotes
	self._enabled = false
	self:_startLoop()
	return self
end

function AtmosphereController:SetRoundActive(active: boolean)
	self._enabled = active
end

function AtmosphereController:_startLoop()
	local timer = 0
	RunService.Heartbeat:Connect(function(dt)
		if not self._enabled then
			return
		end
		timer += dt
		if timer < 3 then
			return
		end
		timer = 0
		self:_flickerRandomLight()
		self:_sendAmbientCue()
	end)
end

function AtmosphereController:_flickerRandomLight()
	local tagged = CollectionService:GetTagged("LightFlicker")
	if #tagged == 0 then
		return
	end
	local target = tagged[math.random(1, #tagged)]

	local lights = {}
	for _, descendant in ipairs(target:GetDescendants()) do
		if descendant:IsA("PointLight") or descendant:IsA("SpotLight") or descendant:IsA("SurfaceLight") then
			table.insert(lights, descendant)
		end
	end
	if #lights == 0 then
		return
	end

	for _, light in ipairs(lights) do
		light.Enabled = false
	end
	self._remotes:WaitForChild("AtmosphereCue"):FireAllClients("flicker")
	task.delay(0.12, function()
		for _, light in ipairs(lights) do
			if light.Parent then
				light.Enabled = true
			end
		end
	end)
end

function AtmosphereController:_sendAmbientCue()
	if math.random() < 0.55 then
		return
	end
	local cueType = math.random() < 0.5 and "knock" or "breathing"
	self._remotes:WaitForChild("AtmosphereCue"):FireAllClients(cueType)
end

return AtmosphereController
