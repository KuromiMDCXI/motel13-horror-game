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
	ReviveDuration = 4,
	MaxRevivesPerRound = 1,
}

Config.Enemy = {
	PatrolSpeed = 9,
	InvestigateSpeed = 11,
	ChaseSpeed = 16,
	SearchSpeed = 10,
	AttackRange = 5,
	SpotRange = 80,
	HearRange = 55,
	HiddenSpotRange = 14,
	LoseTargetSeconds = 6,
	SearchSeconds = 6,
	PathRecomputeSeconds = 0.8,
	AttackCooldown = 2.0,
}

Config.Atmosphere = {
	EventMinSeconds = 30,
	EventMaxSeconds = 90,
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
	HideSpot = "HideSpot",
	LockedDoor = "LockedDoor",
	PowerLight = "PowerLight",
	EmergencyLight = "EmergencyLight",
	SoundEmitter = "SoundEmitter",
}

return Config
