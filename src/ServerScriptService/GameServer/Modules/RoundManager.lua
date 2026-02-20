-- Explorer Path: ServerScriptService/GameServer/Modules/RoundManager
--!strict

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local RoundManager = {}
RoundManager.__index = RoundManager

function RoundManager.new(config, remotes, services)
	local self = setmetatable({}, RoundManager)
	self._config = config
	self._remotes = remotes
	self._services = services
	self._state = "Lobby"
	self._stateEndsAt = 0
	self._running = false
	return self
end

function RoundManager:StartLoop()
	if self._running then
		return
	end
	self._running = true
	task.spawn(function()
		while self._running do
			self:_runLobby()
			self:_runIntermission()
			self:_runRound()
			self:_runEndRound()
		end
	end)
end

function RoundManager:_setState(stateName: string, duration: number, reason: string?)
	self._state = stateName
	self._stateEndsAt = os.time() + duration
	self._remotes:WaitForChild("RoundState"):FireAllClients({
		state = stateName,
		timeLeft = duration,
		reason = reason,
	})
end

function RoundManager:_runLobby()
	while #Players:GetPlayers() < self._config.Round.MinimumPlayers do
		self:_setState("Lobby", 1, "Waiting for players")
		self:_teleportToTag("LobbySpawn", Players:GetPlayers())
		task.wait(1)
	end
end

function RoundManager:_runIntermission()
	self:_setState("Intermission", self._config.Round.IntermissionDuration)
	self:_teleportToTag("LobbySpawn", Players:GetPlayers())
	for i = self._config.Round.IntermissionDuration, 1, -1 do
		self._remotes:WaitForChild("RoundState"):FireAllClients({ state = "Intermission", timeLeft = i })
		task.wait(1)
	end
end

function RoundManager:_runRound()
	local playersList = Players:GetPlayers()
	if #playersList == 0 then
		return
	end

	self:_setState("InRound", self._config.Round.RoundDuration)
	self:_teleportToTag("PlayerSpawn", playersList)
	self._services.PlayerState:ResetForRound(playersList)
	self._services.Objectives:SpawnObjectives()
	self._services.Enemy:ResetForRound()
	self._services.Atmosphere:SetRoundActive(true)

	for t = self._config.Round.RoundDuration, 1, -1 do
		self._remotes:WaitForChild("RoundState"):FireAllClients({ state = "InRound", timeLeft = t })
		self._services.Objectives:PushObjectiveUpdate()

		local activePlayers = Players:GetPlayers()
		if self._services.PlayerState:AreAllPlayersDownedOrEscaped(activePlayers) then
			self:_setState("EndRound", self._config.Round.EndDuration, "All players incapacitated")
			break
		end

		if self._services.Objectives:IsGateUnlocked() then
			local allEscapedOrDowned = self._services.PlayerState:AreAllPlayersDownedOrEscaped(activePlayers)
			if allEscapedOrDowned then
				self:_setState("EndRound", self._config.Round.EndDuration, "Escape complete")
				break
			end
		end

		task.wait(1)
	end

	self._services.Enemy:Stop()
	self._services.Atmosphere:SetRoundActive(false)
end

function RoundManager:_runEndRound()
	if self._state ~= "EndRound" then
		self:_setState("EndRound", self._config.Round.EndDuration, "Round complete")
	end
	for i = self._config.Round.EndDuration, 1, -1 do
		self._remotes:WaitForChild("RoundState"):FireAllClients({ state = "EndRound", timeLeft = i })
		task.wait(1)
	end
	self:_teleportToTag("LobbySpawn", Players:GetPlayers())
end

function RoundManager:_teleportToTag(tagName: string, playersList: {Player})
	local spawns = CollectionService:GetTagged(tagName)
	if #spawns == 0 then
		warn("No spawns tagged", tagName)
		return
	end
	for index, player in ipairs(playersList) do
		local character = player.Character
		if not character then
			continue
		end
		local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root then
			continue
		end
		local spawn = spawns[((index - 1) % #spawns) + 1]
		if spawn:IsA("BasePart") then
			root.CFrame = spawn.CFrame + Vector3.new(0, 3, 0)
		end
	end
end

return RoundManager
