-- Numeric configuration stays engine-independent so the simulation can be tested offline.
-- Every duration is expressed in simulation ticks (1 tick = 1/60 s) unless named "Seconds".
return table.freeze({
	Version = "0.2.0",
	TickRate = 60,
	SnapshotRate = 30,
	MaxCatchUpSteps = 8,
	InputTimeout = 0.5,

	-- Movement
	WalkSpeed = 17,
	AirSpeed = 14,
	JumpVelocity = 43,
	Gravity = 115,
	DashSpeed = 38,
	DashTicks = 9,
	DashCooldownTicks = 30,
	ArenaMinX = -28,
	ArenaMaxX = 28,
	SpawnX = 7,
	PushWidth = 3.0,
	PushHeight = 4.8,
	RootHeight = 3.0,
	PlaneZ = 0,

	-- Hurtboxes, measured from the feet (state.y) of the fighter
	HurtHalfWidth = 1.1,
	HurtHeight = 5.8,
	CrouchHurtHeight = 4.0,

	-- Combat
	MaxHealth = 1000,
	MaxGuard = 100,
	BlockDamageRatio = 0.15, -- the guard reduces damage, it does not cancel it
	GuardRegenDelayTicks = 50,
	GuardRegenPerTick = 0.6,
	GuardBreakTicks = 55,
	BufferTicks = 8,
	ComboScaling = 0.9, -- each hit already taken in the combo multiplies damage by this
	MinComboScaling = 0.4,
	MaxJuggleHits = 3, -- airborne hits allowed before the target becomes untouchable until landing
	JugglePop = 18,
	PushbackDecay = 0.82,
	CornerPushRatio = 0.75,
	CornerMargin = 0.75,
	KnockdownTicks = 40,
	GetUpTicks = 14,
	KOPop = 26,
	KOHitstop = 26,

	-- Match
	RoundSeconds = 99,
	RoundsToWin = 2,
	IntroTicks = 130,
	KOTicks = 200,
	MatchEndTicks = 260,
	TrainingRefillTicks = 70,

	-- Presentation (client only)
	CameraFOV = 38,
	CameraMinDistance = 26,
	CameraMargin = 8,
	ModelYaw = 22, -- degrees the rig turns toward the camera, like 2D fighters drawn in 3/4 view
	PoseRate = 15,
})
