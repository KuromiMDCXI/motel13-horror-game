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
	self._state = "Patrol"
	self._target = nil
	self._investigatePos = nil
	self._lastKnownPos = nil
	self._searchUntil = 0
	self._lastPathCompute = 0
	self._lastAttackAt = 0
	self._patrolIndex = 1
	return self
end

function EnemyController:StartRound()
	self._running = true
	self._state = "Patrol"
	self._target = nil
	self._investigatePos = nil
	self._lastKnownPos = nil
	self._searchUntil = 0
	self._waypoints = CollectionService:GetTagged(Config.Tags.EnemyWaypoint)
	table.sort(self._waypoints, function(a, b)
		return (a:GetAttribute("PatrolIndex") or 0) < (b:GetAttribute("PatrolIndex") or 0)
	end)
	self._heartbeat = RunService.Heartbeat:Connect(function()
		self:_tick()
	end)
end

function EnemyController:StopRound()
	self._running = false
	if self._heartbeat then
		self._heartbeat:Disconnect()
		self._heartbeat = nil
	end
end

function EnemyController:_tick()
	if not self._running then
		return
	end
	local seenTarget, heardPos = self:_sensePlayers()
	if seenTarget then
		self._state = "Chase"
		self._target = seenTarget
		self._lastKnownPos = self:_getPlayerPos(seenTarget)
	elseif self._state ~= "Chase" and heardPos then
		self._state = "Investigate"
		self._investigatePos = heardPos
	elseif self._state == "Chase" and not self._target then
		self._state = "Search"
		self._searchUntil = os.clock() + Config.Enemy.SearchSeconds
	end

	if self._state == "Chase" then
		self:_runChase()
	elseif self._state == "Investigate" then
		self:_runInvestigate()
	elseif self._state == "Search" then
		self:_runSearch()
	else
		self:_runPatrol()
	end
end

function EnemyController:_sensePlayers(): (Player?, Vector3?)
	local bestTarget = nil
	local heardPos = nil
	local bestDist = math.huge
	for _, player in ipairs(Players:GetPlayers()) do
		if self._playerStateService:IsDowned(player) then
			continue
		end
		local pos = self:_getPlayerPos(player)
		if not pos then
			continue
		end
		local dist = (pos - self._root.Position).Magnitude
		local hidden = self._playerStateService:IsHidden(player)
		local canSee = dist <= Config.Enemy.SpotRange and self:_hasLineOfSight(pos, player.Character)
		if hidden and dist > Config.Enemy.HiddenSpotRange then
			canSee = false
		end
		if canSee and dist < bestDist then
			bestDist = dist
			bestTarget = player
			if dist < 16 then
				self._jumpscareRemote:FireClient(player)
			end
		end
		if self._playerStateService:IsPlayerRunning(player) and dist <= Config.Enemy.HearRange then
			heardPos = pos
		end
	end
	return bestTarget, heardPos
end

function EnemyController:_runPatrol()
	self._humanoid.WalkSpeed = Config.Enemy.PatrolSpeed
	if #self._waypoints == 0 then
		return
	end
	local node = self._waypoints[self._patrolIndex]
	if node and node:IsA("BasePart") then
		self._humanoid:MoveTo(node.Position)
		if (node.Position - self._root.Position).Magnitude < 5 then
			self._patrolIndex = (self._patrolIndex % #self._waypoints) + 1
		end
	end
end

function EnemyController:_runInvestigate()
	if not self._investigatePos then
		self._state = "Patrol"
		return
	end
	self._humanoid.WalkSpeed = Config.Enemy.InvestigateSpeed
	self:_pathMoveTo(self._investigatePos)
	if (self._investigatePos - self._root.Position).Magnitude < 6 then
		self._state = "Search"
		self._searchUntil = os.clock() + Config.Enemy.SearchSeconds
	end
end

function EnemyController:_runChase()
	if not self._target then
		self._state = "Search"
		self._searchUntil = os.clock() + Config.Enemy.SearchSeconds
		return
	end
	local pos = self:_getPlayerPos(self._target)
	if not pos then
		self._target = nil
		self._state = "Search"
		self._searchUntil = os.clock() + Config.Enemy.SearchSeconds
		return
	end
	self._humanoid.WalkSpeed = Config.Enemy.ChaseSpeed
	self._lastKnownPos = pos
	self:_pathMoveTo(pos)
	self:_attemptAttack(self._target)
end

function EnemyController:_runSearch()
	self._humanoid.WalkSpeed = Config.Enemy.SearchSpeed
	if self._lastKnownPos then
		self:_pathMoveTo(self._lastKnownPos)
	end
	if os.clock() >= self._searchUntil then
		self._state = "Patrol"
		self._target = nil
	end
end

function EnemyController:_pathMoveTo(destination: Vector3)
	if os.clock() - self._lastPathCompute < Config.Enemy.PathRecomputeSeconds then
		return
	end
	self._lastPathCompute = os.clock()
	local path = PathfindingService:CreatePath({ AgentRadius = 2, AgentHeight = 5, AgentCanJump = true })
	path:ComputeAsync(self._root.Position, destination)
	if path.Status ~= Enum.PathStatus.Success then
		self._humanoid:MoveTo(destination)
		return
	end
	local points = path:GetWaypoints()
	if #points >= 2 then
		self._humanoid:MoveTo(points[2].Position)
	else
		self._humanoid:MoveTo(destination)
	end
end

function EnemyController:_attemptAttack(player: Player)
	if os.clock() - self._lastAttackAt < Config.Enemy.AttackCooldown then
		return
	end
	local pos = self:_getPlayerPos(player)
	if not pos then
		return
	end
	if (pos - self._root.Position).Magnitude <= Config.Enemy.AttackRange then
		self._lastAttackAt = os.clock()
		self._playerStateService:DownPlayer(player)
		self._target = nil
		self._state = "Search"
		self._searchUntil = os.clock() + Config.Enemy.SearchSeconds
	end
end

function EnemyController:_getPlayerPos(player: Player): Vector3?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root.Position
	end
	return nil
end

function EnemyController:_hasLineOfSight(targetPos: Vector3, targetCharacter: Model?): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { self._enemyModel }
	local result = Workspace:Raycast(self._root.Position, targetPos - self._root.Position, params)
	if not result then
		return true
	end
	return targetCharacter ~= nil and result.Instance:IsDescendantOf(targetCharacter)
end

return EnemyController
