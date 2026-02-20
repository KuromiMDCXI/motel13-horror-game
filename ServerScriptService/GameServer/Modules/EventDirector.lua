local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local EventDirector = {}
EventDirector.__index = EventDirector

function EventDirector.new()
	local self = setmetatable({}, EventDirector)
	self._running = false
	self._eventRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("AtmosphereEvent")
	return self
end

function EventDirector:StartRound()
	if self._running then
		return
	end
	self._running = true
	task.spawn(function()
		while self._running do
			task.wait(math.random(Config.Atmosphere.EventMinSeconds, Config.Atmosphere.EventMaxSeconds))
			if not self._running then
				break
			end
			self:_runEvent()
		end
	end)
end

function EventDirector:StopRound()
	self._running = false
end

function EventDirector:_runEvent()
	local emitters = CollectionService:GetTagged(Config.Tags.SoundEmitter)
	local eventType = math.random(1, 4)
	if eventType == 1 and #emitters > 0 then
		local emitter = emitters[math.random(1, #emitters)]
		self._eventRemote:FireAllClients("EmitterSfx", emitter.Position, "Knock")
	elseif eventType == 2 and #emitters > 0 then
		local emitter = emitters[math.random(1, #emitters)]
		self._eventRemote:FireAllClients("EmitterSfx", emitter.Position, "Whisper")
	elseif eventType == 3 then
		self._eventRemote:FireAllClients("StaticBurst")
	else
		self._eventRemote:FireAllClients("DistantScream")
	end
end

return EventDirector
