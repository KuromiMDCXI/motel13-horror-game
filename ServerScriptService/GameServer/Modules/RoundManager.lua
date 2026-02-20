local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local RoundManager = {}
RoundManager.__index = RoundManager

function RoundManager.new(objectiveManager, playerStateService, enemyController, atmosphereService)
	local self = setmetatable({}, RoundManager)
	self._objectiveManager = objectiveManager
	self._playerStateService = playerStateService
	self._enemyController = enemyController
	self._atmosphereService = atmosphereService
	self._roundRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("RoundStateChanged")
	self._state = "Lobby"
	self._roundEndRequested = false
	return self
end

function RoundManager:Start()
	task.spawn(function()
		while true do
			self:_setState("Lobby", 0)
			self:_teleportPlayersToTag(Config.Tags.LobbySpawn)
			self:_waitForMinPlayers()
			self:_runIntermission()
			self:_runRound()
			self:_runEndRound()
		end
	end)
end

function RoundManager:_setState(state: string, timeRemaining: number)
	self._state = state
	self._roundRemote:FireAllClients({ state = state, timeRemaining = timeRemaining })
end

function RoundManager:_waitForMinPlayers()
	while #Players:GetPlayers() < Config.Round.MinimumPlayers do
		task.wait(1)
	end
end

function RoundManager:_runIntermission()
	for t = Config.Round.IntermissionDuration, 0, -1 do
		self:_setState("Intermission", t)
		task.wait(1)
	end
end

function RoundManager:_runRound()
	self._roundEndRequested = false
	self._playerStateService:SetRoundActive(true)
	self._playerStateService:ResetForRound()
	self:_teleportPlayersToTag(Config.Tags.PlayerSpawn)
	self._objectiveManager:StartRound(function()
		self._roundEndRequested = true
	end)
	self._enemyController:StartRound()
	self._atmosphereService:StartRound()

	for t = Config.Round.RoundDuration, 0, -1 do
		self:_setState("InRound", t)
		if self._roundEndRequested then
			break
		end
		if self._playerStateService:IsAllPlayersDowned() then
			break
		end
		task.wait(1)
	end

	self._enemyController:StopRound()
	self._atmosphereService:StopRound()
	self._objectiveManager:ResetRound()
	self._playerStateService:SetRoundActive(false)
end

function RoundManager:_runEndRound()
	for t = 10, 0, -1 do
		self:_setState("EndRound", t)
		task.wait(1)
	end
end

function RoundManager:_teleportPlayersToTag(tagName: string)
	local points = CollectionService:GetTagged(tagName)
	if #points == 0 then
		warn("[RoundManager] No spawn points tagged:", tagName)
		return
	end
	for i, player in ipairs(Players:GetPlayers()) do
		local point = points[((i - 1) % #points) + 1]
		local character = player.Character
		if character then
			local hrp = character:FindFirstChild("HumanoidRootPart")
			if hrp and point:IsA("BasePart") then
				hrp.CFrame = point.CFrame + Vector3.new(0, 4, 0)
			end
		end
	end
end

return RoundManager
