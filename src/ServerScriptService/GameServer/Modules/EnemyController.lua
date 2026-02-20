-- Explorer Path: ServerScriptService/GameServer/Modules/EnemyController
--!strict

local CollectionService = game:GetService("CollectionService")
local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local EnemyController = {}
EnemyController.__index = EnemyController

function EnemyController.new(config, remotes, playerState)
	local self = setmetatable({}, EnemyController)
	self._config = config
	self._remotes = remotes
	self._playerState = playerState
	self._enemyModel = nil
	self._humanoid = nil
	self._rootPart = nil
	self._waypoints = {}
	self._state = "Idle"
	self._target = nil
	self._lastAttackTime = 0
	self._lastPathTime = 0
	self._pathPoints = {}
	self._pathIndex = 1
	self._patrolIndex = 1
	self._jumpscareCooldown = {}
	self._enabled = false
	self:_cacheWaypoints()
	self:_bindEnemy()
	self:_startLoop()
	return self
end

function EnemyController:_cacheWaypoints()
	self._waypoints = CollectionService:GetTagged("EnemyWaypoint")
	table.sort(self._waypoints, function(a, b)
		return (a:GetAttribute("PatrolIndex") or 0) < (b:GetAttribute("PatrolIndex") or 0)
	end)
end

function EnemyController:_bindEnemy()
	for _, model in ipairs(CollectionService:GetTagged("Enemy")) do
		if model:IsA("Model") then
			self._enemyModel = model
			self._humanoid = model:FindFirstChildOfClass("Humanoid")
			self._rootPart = model:FindFirstChild("HumanoidRootPart") :: BasePart?
			break
		end
	end
	if not self._enemyModel then
		warn("No enemy model tagged with 'Enemy'.")
	end
end

function EnemyController:ResetForRound()
	self:_cacheWaypoints()
	self:_bindEnemy()
	self._state = "Patrol"
	self._target = nil
	self._pathPoints = {}
	self._pathIndex = 1
	self._lastAttackTime = 0
	self._enabled = true
	if self._humanoid then
		self._humanoid.WalkSpeed = self._config.Enemy.PatrolSpeed
	end
end

function EnemyController:Stop()
	self._enabled = false
	self._state = "Idle"
	self._target = nil
end

function EnemyController:_startLoop()
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		if not self._enabled then
			return
		end
		accumulator += dt
		if accumulator < 0.2 then
			return
		end
		self:_tick(accumulator)
		accumulator = 0
	end)
end

function EnemyController:_tick(_dt)
	if not self._enemyModel or not self._humanoid or not self._rootPart then
		return
	end

	local sensedTarget = self:_senseTarget()
	if sensedTarget then
		self._target = sensedTarget
		self._state = "Chase"
	elseif self._state == "Chase" then
		self._state = "Patrol"
		self._target = nil
	end

	if self._state == "Chase" and self._target then
		self:_chaseTarget(self._target)
	else
		self:_patrol()
	end
end

function EnemyController:_senseTarget(): Player?
	local root = self._rootPart
	if not root then
		return nil
	end

	local bestTarget = nil
	local bestDistance = math.huge
	for _, player in ipairs(Players:GetPlayers()) do
		if not self._playerState:IsAlive(player) then
			continue
		end
		local character = player.Character
		if not character then
			continue
		end
		local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not hrp then
			continue
		end

		local offset = hrp.Position - root.Position
		local distance = offset.Magnitude
		if distance < bestDistance then
			local heard = self._playerState:IsRunning(player) and distance <= self._config.Enemy.HearingDistance
			local seen = self:_hasLineOfSight(hrp, distance)
			if heard or seen then
				bestTarget = player
				bestDistance = distance
				if distance <= self._config.Enemy.JumpscareDistance then
					self:_triggerJumpscare(player)
				end
			end
		end
	end

	return bestTarget
end

function EnemyController:_hasLineOfSight(targetPart: BasePart, distance: number): boolean
	if distance > self._config.Enemy.SightDistance then
		return false
	end
	if not self._rootPart then
		return false
	end

	local direction = (targetPart.Position - self._rootPart.Position).Unit
	if self._rootPart.CFrame.LookVector:Dot(direction) < self._config.Enemy.SightFovDot then
		return false
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { self._enemyModel }
	local result = Workspace:Raycast(self._rootPart.Position, targetPart.Position - self._rootPart.Position, params)
	if not result then
		return true
	end
	return result.Instance:IsDescendantOf(targetPart.Parent)
end

function EnemyController:_patrol()
	if not self._humanoid or #self._waypoints == 0 then
		return
	end
	self._humanoid.WalkSpeed = self._config.Enemy.PatrolSpeed
	local waypoint = self._waypoints[self._patrolIndex]
	if waypoint and waypoint:IsA("BasePart") then
		self._humanoid:MoveTo(waypoint.Position)
		if self._rootPart and (self._rootPart.Position - waypoint.Position).Magnitude <= 4 then
			self._patrolIndex += 1
			if self._patrolIndex > #self._waypoints then
				self._patrolIndex = 1
			end
		end
	end
end

function EnemyController:_chaseTarget(target: Player)
	if not self._humanoid or not self._rootPart then
		return
	end
	local character = target.Character
	if not character then
		return
	end
	local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then
		return
	end

	self._humanoid.WalkSpeed = self._config.Enemy.ChaseSpeed
	local distance = (self._rootPart.Position - hrp.Position).Magnitude
	if distance <= self._config.Enemy.AttackDistance then
		self:_attack(target)
		return
	end

	if os.clock() - self._lastPathTime >= self._config.Enemy.RepathInterval then
		self._lastPathTime = os.clock()
		self:_buildPath(hrp.Position)
	end

	local waypoint = self._pathPoints[self._pathIndex]
	if waypoint then
		self._humanoid:MoveTo(waypoint)
		if (self._rootPart.Position - waypoint).Magnitude <= 4 then
			self._pathIndex += 1
		end
	else
		self._humanoid:MoveTo(hrp.Position)
	end
end

function EnemyController:_buildPath(targetPosition: Vector3)
	if not self._rootPart then
		return
	end
	local path = PathfindingService:CreatePath({
		AgentRadius = 2,
		AgentHeight = 5,
		AgentCanJump = true,
	})
	path:ComputeAsync(self._rootPart.Position, targetPosition)
	if path.Status ~= Enum.PathStatus.Success then
		self._pathPoints = {}
		self._pathIndex = 1
		return
	end

	self._pathPoints = {}
	self._pathIndex = 1
	for _, waypoint in ipairs(path:GetWaypoints()) do
		table.insert(self._pathPoints, waypoint.Position)
	end
end

function EnemyController:_attack(player: Player)
	if os.clock() - self._lastAttackTime < self._config.Enemy.AttackCooldown then
		return
	end
	self._lastAttackTime = os.clock()
	self._playerState:DownPlayer(player)
end

function EnemyController:_triggerJumpscare(player: Player)
	local last = self._jumpscareCooldown[player] or 0
	if os.clock() - last < 8 then
		return
	end
	self._jumpscareCooldown[player] = os.clock()
	self._remotes:WaitForChild("Jumpscare"):FireClient(player, {
		intensity = 1,
		soundId = self._config.Audio.JumpscareSoundId,
	})
end

return EnemyController
