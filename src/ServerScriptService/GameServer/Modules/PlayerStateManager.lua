-- Explorer Path: ServerScriptService/GameServer/Modules/PlayerStateManager
--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local PlayerStateManager = {}
PlayerStateManager.__index = PlayerStateManager

export type PlayerData = {
	Stamina: number,
	Battery: number,
	Downed: boolean,
	Running: boolean,
	FlashlightOn: boolean,
	HeldFuses: number,
	Escaped: boolean,
	LastFlashlightToggle: number,
	LastFlashlightUse: number,
}

function PlayerStateManager.new(config, remotes)
	local self = setmetatable({}, PlayerStateManager)
	self._config = config
	self._remotes = remotes
	self._stateByPlayer = {} :: {[Player]: PlayerData}
	self._spectateIndex = {} :: {[Player]: number}
	self:_bind()
	return self
end

function PlayerStateManager:_bind()
	Players.PlayerAdded:Connect(function(player)
		self:_initPlayer(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		self._stateByPlayer[player] = nil
		self._spectateIndex[player] = nil
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		self:_initPlayer(player)
	end

	self._remotes:WaitForChild("SprintState").OnServerEvent:Connect(function(player, wantsSprint)
		self:SetRunning(player, wantsSprint == true)
	end)

	self._remotes:WaitForChild("FlashlightToggle").OnServerEvent:Connect(function(player)
		self:ToggleFlashlight(player)
	end)

	local spectateRemote = self._remotes:WaitForChild("RequestSpectateNext")
	if spectateRemote:IsA("RemoteFunction") then
		spectateRemote.OnServerInvoke = function(player)
			return self:GetNextSpectateTarget(player)
		end
	end

	local stepAccumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		stepAccumulator += dt
		if stepAccumulator < 0.25 then
			return
		end
		self:_tick(stepAccumulator)
		stepAccumulator = 0
	end)
end

function PlayerStateManager:_initPlayer(player: Player)
	self._stateByPlayer[player] = {
		Stamina = self._config.Player.StaminaMax,
		Battery = self._config.Player.FlashlightBatteryMax,
		Downed = false,
		Running = false,
		FlashlightOn = false,
		HeldFuses = 0,
		Escaped = false,
		LastFlashlightToggle = 0,
		LastFlashlightUse = os.clock(),
	}
	self:_applyMovement(player)
	self:_pushState(player)

	player.CharacterAdded:Connect(function()
		task.defer(function()
			self:_applyMovement(player)
			self:_pushState(player)
		end)
	end)
end

function PlayerStateManager:_tick(dt: number)
	for player, data in pairs(self._stateByPlayer) do
		if not player.Parent then
			continue
		end

		if data.Downed or data.Escaped then
			data.Running = false
		end

		if data.Running then
			data.Stamina = math.max(0, data.Stamina - self._config.Player.StaminaDrainPerSecond * dt)
			if data.Stamina <= 0 then
				data.Running = false
			end
		else
			data.Stamina = math.min(self._config.Player.StaminaMax, data.Stamina + self._config.Player.StaminaRegenPerSecond * dt)
		end

		if data.FlashlightOn and not data.Downed then
			data.Battery = math.max(0, data.Battery - self._config.Player.FlashlightDrainPerSecond * dt)
			data.LastFlashlightUse = os.clock()
			if data.Battery <= 0 then
				data.FlashlightOn = false
			end
		elseif os.clock() - data.LastFlashlightUse >= self._config.Player.FlashlightRegenDelay then
			data.Battery = math.min(self._config.Player.FlashlightBatteryMax, data.Battery + self._config.Player.FlashlightRegenPerSecond * dt)
		end

		self:_applyMovement(player)
		self:_pushState(player)
	end
end

function PlayerStateManager:_applyMovement(player: Player)
	local data = self._stateByPlayer[player]
	if not data then
		return
	end
	local character = player.Character
	if not character then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	if data.Downed or data.Escaped then
		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0
	else
		humanoid.WalkSpeed = data.Running and self._config.Player.SprintSpeed or self._config.Player.WalkSpeed
		humanoid.JumpPower = 50
	end
end

function PlayerStateManager:_pushState(player: Player)
	local data = self._stateByPlayer[player]
	if not data then
		return
	end
	self._remotes:WaitForChild("PlayerStateUpdate"):FireClient(player, {
		stamina = data.Stamina,
		battery = data.Battery,
		running = data.Running,
		downed = data.Downed,
		flashlightOn = data.FlashlightOn,
		heldFuses = data.HeldFuses,
		escaped = data.Escaped,
	})
end

function PlayerStateManager:SetRunning(player: Player, wantsSprint: boolean)
	local data = self._stateByPlayer[player]
	if not data then
		return
	end
	if data.Downed or data.Escaped then
		data.Running = false
	elseif wantsSprint and data.Stamina > 0 then
		data.Running = true
	else
		data.Running = false
	end
	self:_applyMovement(player)
	self:_pushState(player)
end

function PlayerStateManager:ToggleFlashlight(player: Player)
	local data = self._stateByPlayer[player]
	if not data then
		return
	end
	if data.Downed or data.Battery <= 0 then
		return
	end
	if os.clock() - data.LastFlashlightToggle < 0.2 then
		return
	end
	data.LastFlashlightToggle = os.clock()
	data.FlashlightOn = not data.FlashlightOn
	self:_pushState(player)
end

function PlayerStateManager:DownPlayer(player: Player)
	local data = self._stateByPlayer[player]
	if not data or data.Downed or data.Escaped then
		return
	end
	data.Downed = true
	data.Running = false
	data.FlashlightOn = false
	self:_applyMovement(player)
	self:_pushState(player)
	self:PushSpectateTargets(player)
end

function PlayerStateManager:ResetForRound(playersList: {Player})
	for _, player in ipairs(playersList) do
		local data = self._stateByPlayer[player]
		if data then
			data.Stamina = self._config.Player.StaminaMax
			data.Battery = self._config.Player.FlashlightBatteryMax
			data.Downed = false
			data.Running = false
			data.FlashlightOn = false
			data.HeldFuses = 0
			data.Escaped = false
			data.LastFlashlightUse = os.clock()
			self:_applyMovement(player)
			self:_pushState(player)
		end
	end
end

function PlayerStateManager:AddFuse(player: Player)
	local data = self._stateByPlayer[player]
	if not data then
		return
	end
	data.HeldFuses += 1
	self:_pushState(player)
end

function PlayerStateManager:ConsumeFuse(player: Player): boolean
	local data = self._stateByPlayer[player]
	if not data or data.HeldFuses <= 0 then
		return false
	end
	data.HeldFuses -= 1
	self:_pushState(player)
	return true
end

function PlayerStateManager:SetEscaped(player: Player)
	local data = self._stateByPlayer[player]
	if not data then
		return
	end
	data.Escaped = true
	data.Running = false
	data.FlashlightOn = false
	self:_applyMovement(player)
	self:_pushState(player)
end

function PlayerStateManager:IsAlive(player: Player): boolean
	local data = self._stateByPlayer[player]
	return data ~= nil and not data.Downed and not data.Escaped
end

function PlayerStateManager:IsRunning(player: Player): boolean
	local data = self._stateByPlayer[player]
	return data ~= nil and data.Running
end

function PlayerStateManager:GetAlivePlayers(): {Player}
	local alive = {}
	for player, _ in pairs(self._stateByPlayer) do
		if self:IsAlive(player) then
			table.insert(alive, player)
		end
	end
	return alive
end

function PlayerStateManager:GetActivePlayers(): {Player}
	local active = {}
	for player, data in pairs(self._stateByPlayer) do
		if data and not data.Escaped then
			table.insert(active, player)
		end
	end
	return active
end

function PlayerStateManager:AreAllPlayersDownedOrEscaped(playersList: {Player}): boolean
	for _, player in ipairs(playersList) do
		local data = self._stateByPlayer[player]
		if data and not data.Downed and not data.Escaped then
			return false
		end
	end
	return true
end

function PlayerStateManager:PushSpectateTargets(player: Player)
	local alive = self:GetAlivePlayers()
	local ids = {}
	for _, alivePlayer in ipairs(alive) do
		if alivePlayer ~= player then
			table.insert(ids, alivePlayer.UserId)
		end
	end
	self._remotes:WaitForChild("SpectateTargets"):FireClient(player, ids)
end

function PlayerStateManager:GetNextSpectateTarget(player: Player): number?
	local alive = self:GetAlivePlayers()
	local candidates = {}
	for _, target in ipairs(alive) do
		if target ~= player then
			table.insert(candidates, target)
		end
	end
	if #candidates == 0 then
		return nil
	end

	local index = (self._spectateIndex[player] or 0) + 1
	if index > #candidates then
		index = 1
	end
	self._spectateIndex[player] = index
	return candidates[index].UserId
end

return PlayerStateManager
