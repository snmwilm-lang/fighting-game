-- Numeric configuration stays engine-independent so the simulation can be tested offline.
-- Every duration is expressed in simulation ticks (1 tick = 1/60 s) unless named "Seconds".
return table.freeze({
	Version = "0.8.0",
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
	MaxHealth = 1500, -- a full 6-press route takes ~20-27 %, KAIEN RUSH ~28 %
	MaxGuard = 100,
	BlockDamageRatio = 0.15, -- the guard reduces damage, it does not cancel it
	GuardRegenDelayTicks = 50,
	GuardRegenPerTick = 0.6,
	GuardBreakTicks = 55,
	BufferTicks = 12, -- lifetime of the next queued press (frozen during hitstop)
	BufferSize = 6, -- a whole 6-press route can be typed ahead
	LateCancelTicks = 6, -- a press this late after a connected move still links (latency)
	ReversalBufferTicks = 4, -- while stunned / getting up, only presses this close to recovery count
	ComboScaling = 0.9, -- each hit already taken in the combo multiplies damage by this
	MinComboScaling = 0.4,
	MaxJuggleHits = 6, -- airborne hits allowed before the target becomes untouchable until landing
	JugglePop = 18,
	SuperJumpVelocity = 50, -- jump cancel after a launcher
	GroundBounceVelocity = 30,
	SpikeVelocity = 30,
	WallBounceVelocity = 26,
	CrumpleTicks = 52,
	PushbackDecay = 0.82,
	AirPushDecay = 0.96,
	CornerPushRatio = 0.75,
	CornerMargin = 0.75,
	KnockdownTicks = 40,
	GetUpTicks = 14,
	KOPop = 26,
	KOHitstop = 26,

	-- Ki meter (3 bars of 100) and ultimate
	MaxMeter = 300,
	MeterBar = 100,
	MeterOnHit = 0.5, -- fractions of the damage dealt / received
	MeterOnBlock = 0.25,
	MeterWhenHit = 0.3,
	MeterWhenBlocking = 0.2,
	SuperFlashTicks = 40,
	UltimateLaunch = 34,
	UltimatePush = 48,

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
