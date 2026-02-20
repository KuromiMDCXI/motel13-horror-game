-- Explorer Path: ReplicatedStorage/Shared/GameConfig
--!strict

export type RoundState = "Lobby" | "Intermission" | "InRound" | "EndRound"

local GameConfig = {
	Round = {
		IntermissionDuration = 15,
		RoundDuration = 600,
		EndDuration = 12,
		MinimumPlayers = 1,
	},
	Objectives = {
		RequiredKeys = 6,
		RequiredFuses = 3,
		InteractDistance = 12,
	},
	Player = {
		WalkSpeed = 10,
		SprintSpeed = 17,
		StaminaMax = 100,
		StaminaDrainPerSecond = 20,
		StaminaRegenPerSecond = 14,
		FlashlightBatteryMax = 100,
		FlashlightDrainPerSecond = 6,
		FlashlightRegenPerSecond = 2,
		FlashlightRegenDelay = 5,
	},
	Enemy = {
		PatrolSpeed = 10,
		ChaseSpeed = 16,
		HearingDistance = 45,
		SightDistance = 80,
		SightFovDot = 0.25,
		AttackDistance = 5,
		AttackCooldown = 2,
		RepathInterval = 1.2,
		StuckRepathDistance = 6,
		JumpscareDistance = 20,
	},
	Audio = {
		DistantKnockSoundId = "rbxassetid://9125807754",
		JumpscareSoundId = "rbxassetid://9118823107",
		ChaseMusicSoundId = "rbxassetid://1837467336",
		BreathingSoundId = "rbxassetid://9114245359",
	},
}

return GameConfig
