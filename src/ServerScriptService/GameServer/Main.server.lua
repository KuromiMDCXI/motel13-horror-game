-- Explorer Path: ServerScriptService/GameServer/Main
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local shared = ReplicatedStorage:WaitForChild("Shared")
local remotes = ReplicatedStorage:WaitForChild("Remotes")

local config = require(shared:WaitForChild("GameConfig"))
local modulesFolder = ServerScriptService:WaitForChild("GameServer"):WaitForChild("Modules")

local PlayerStateManager = require(modulesFolder:WaitForChild("PlayerStateManager"))
local ObjectiveManager = require(modulesFolder:WaitForChild("ObjectiveManager"))
local EnemyController = require(modulesFolder:WaitForChild("EnemyController"))
local AtmosphereController = require(modulesFolder:WaitForChild("AtmosphereController"))
local RoundManager = require(modulesFolder:WaitForChild("RoundManager"))

local playerState = PlayerStateManager.new(config, remotes)
local objectives = ObjectiveManager.new(config, remotes, playerState)
local enemy = EnemyController.new(config, remotes, playerState)
local atmosphere = AtmosphereController.new(config, remotes)

local round = RoundManager.new(config, remotes, {
	PlayerState = playerState,
	Objectives = objectives,
	Enemy = enemy,
	Atmosphere = atmosphere,
})

round:StartLoop()
