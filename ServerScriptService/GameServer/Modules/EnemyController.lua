local CollectionService = game:GetService("CollectionService")
local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local EnemyController = {}
EnemyController.__index = EnemyController

function EnemyController.new(playerStateService)
	local self = setmetatable({}, EnemyController)
	self._playerStateService = playerStateService
	self._jumpscareRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Jumpscare")
	self._enemyModel = Workspace:WaitForChild("Enemy")
	self._humanoid = self._enemyModel:WaitForChild("Humanoid")
	self._root = self._enemyModel:WaitForChild("HumanoidRootPart")
	self._waypoints = {}
	self._heartbeat = nil
	self._running = false
	self._lastPathCompute = 0
	self._currentTarget = nil
	self._chaseLostAt = 0
	self._lastAttackAt = 0
	self._patrolIndex = 1
	return self
end

function EnemyController:StartRound()
	self._running = true
	self._waypoints = CollectionService:GetTagged(Config.Tags.EnemyWaypoint)
	table.sort(self._waypoints, function(a, b)
		return (a:GetAttribute("PatrolIndex") or 0) < (b:GetAttribute("PatrolIndex") or 0)
	end)
	self._currentTarget = nil
	self._lastPathCompute = 0
	self._heartbeat = RunService.Heartbeat:Connect(function(_dt)
		self:_tick()
	end)
end

function EnemyController:StopRound()
	self._running = false
	if self._heartbeat then
		self._heartbeat:Disconnect()
		self._heartbeat = nil
	end
	self._currentTarget = nil
end

function EnemyController:_tick()
	if not self._running then
		return
	end

	local target = self:_findTarget()
	if target then
		self._currentTarget = target
		self._chaseLostAt = tick()
		self._humanoid.WalkSpeed = Config.Enemy.ChaseSpeed
		self:_moveToTarget(target)
		self:_attemptAttack(target)
	else
		if self._currentTarget and (tick() - self._chaseLostAt) <= Config.Enemy.LoseTargetSeconds then
			self._humanoid.WalkSpeed = Config.Enemy.ChaseSpeed
			self:_moveToLastKnown(self._currentTarget)
		else
			self._currentTarget = nil
			self._humanoid.WalkSpeed = Config.Enemy.PatrolSpeed
			self:_patrol()
		end
	end
end

function EnemyController:_findTarget(): Player?
	local bestTarget = nil
	local bestDistance = math.huge
	for _, player in ipairs(Players:GetPlayers()) do
		if player:GetAttribute("Downed") then
			continue
		end
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if not hrp then
			continue
		end
		local distance = (hrp.Position - self._root.Position).Magnitude
		local canSee = distance <= Config.Enemy.SpotRange and self:_hasLineOfSight(hrp.Position, char)
		local canHear = distance <= Config.Enemy.HearRange and self._playerStateService:IsPlayerRunning(player)
		if (canSee or canHear) and distance < bestDistance then
			bestDistance = distance
			bestTarget = player
			if distance < 16 then
				self._jumpscareRemote:FireClient(player)
			end
		end
	end
	return bestTarget
end

function EnemyController:_hasLineOfSight(targetPos: Vector3, targetCharacter: Model): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { self._enemyModel }
	local direction = targetPos - self._root.Position
	local result = Workspace:Raycast(self._root.Position, direction, params)
	if not result then
		return true
	end
	return targetCharacter and result.Instance:IsDescendantOf(targetCharacter)
end

function EnemyController:_moveToTarget(player: Player)
	local char = player.Character
	if not char then
		return
	end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return
	end
	self:_pathMoveTo(hrp.Position)
end

function EnemyController:_moveToLastKnown(player: Player)
	local char = player.Character
	if not char then
		return
	end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if hrp then
		self:_pathMoveTo(hrp.Position)
	end
end

function EnemyController:_pathMoveTo(destination: Vector3)
	if tick() - self._lastPathCompute < Config.Enemy.PathRecomputeSeconds then
		return
	end
	self._lastPathCompute = tick()

	local path = PathfindingService:CreatePath({
		AgentRadius = 2,
		AgentHeight = 5,
		AgentCanJump = true,
	})
	path:ComputeAsync(self._root.Position, destination)
	if path.Status ~= Enum.PathStatus.Success then
		self._humanoid:MoveTo(destination)
		return
	end
	local waypoints = path:GetWaypoints()
	if #waypoints > 1 then
		self._humanoid:MoveTo(waypoints[2].Position)
	else
		self._humanoid:MoveTo(destination)
	end
end

function EnemyController:_patrol()
	if #self._waypoints == 0 then
		return
	end
	local node = self._waypoints[self._patrolIndex]
	if node and node:IsA("BasePart") then
		self._humanoid:MoveTo(node.Position)
		if (node.Position - self._root.Position).Magnitude < 6 then
			self._patrolIndex = (self._patrolIndex % #self._waypoints) + 1
		end
	end
end

function EnemyController:_attemptAttack(player: Player)
	if tick() - self._lastAttackAt < Config.Enemy.AttackCooldown then
		return
	end
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return
	end
	if (hrp.Position - self._root.Position).Magnitude > Config.Enemy.AttackRange then
		return
	end
	self._lastAttackAt = tick()
	self._playerStateService:DownPlayer(player)
end

return EnemyController
