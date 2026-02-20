local Config = {}

Config.Round = {
	IntermissionDuration = 15,
	RoundDuration = 10 * 60,
	MinimumPlayers = 1,
}

Config.Objectives = {
	RequiredKeys = 6,
	RequiredFuses = 3,
}

Config.Player = {
	MaxStamina = 100,
	StaminaDrainPerSecond = 22,
	StaminaRegenPerSecond = 18,
	WalkSpeed = 10,
	SprintSpeed = 18,
	FlashlightBatteryMax = 100,
	FlashlightDrainPerSecond = 5,
	FlashlightRegenPerSecond = 1,
	DownedWalkSpeed = 0,
}

Config.Enemy = {
	PatrolSpeed = 9,
	ChaseSpeed = 16,
	AttackRange = 5,
	SpotRange = 80,
	HearRange = 55,
	LoseTargetSeconds = 7,
	PathRecomputeSeconds = 1.0,
	AttackCooldown = 2.0,
}

Config.Tags = {
	KeySpawn = "KeySpawn",
	FuseSpawn = "FuseSpawn",
	EnemyWaypoint = "EnemyWaypoint",
	LightFlicker = "LightFlicker",
	PlayerSpawn = "PlayerSpawn",
	LobbySpawn = "LobbySpawn",
	ExitGate = "ExitGate",
	PowerBox = "PowerBox",
}

return Config
