-- Numeric configuration stays engine-independent so the simulation can be tested offline.
-- Every duration is expressed in simulation ticks (1 tick = 1/60 s) unless named "Seconds".
return table.freeze({
	Version = "0.23.26",
	TickRate = 60,
	SnapshotRate = 30,
	MaxCatchUpSteps = 8,
	InputTimeout = 0.8, -- held inputs drop after this long without a packet (tolerates lag spikes)

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
	MaxHealth = 1550, -- KAI's health (each kit has its own, see MoveData.Kits[kit].Stats)
	MaxGuard = 100,
	BackBlock = true, -- holding back (away from the opponent) guards, like every fighting game
	ProximityGuardRange = 3, -- walking back stops into the guard when an attack's reach + this is close (studs)
	BlockDamageRatio = 0.08, -- the guard reduces damage, it does not cancel it
	-- COUNTER HIT: a blow that lands while the target is still starting its own attack
	-- (outside a combo) hits harder, stuns longer and freezes longer: reading the opponent pays.
	-- (only slow blows thrown fresh can be caught: a jab traded against a jab is not a read,
	-- and the next blow of a string is never a counter hit)
	CounterDamage = 1.15, CounterHitstun = 6, CounterHitstop = 3, CounterMinStartup = 10,
	GuardRegenDelayTicks = 12,
	GuardRegenPerTick = 0.6,
	CrouchGuardWear = 1.5, -- a crouching guard wears 1.5x as fast (the low guard is not a fortress)
	LightGuardWear = 0.5, -- light chain hits (guard damage 12 or less) wear the guard at half rate
	GuardCancelTicks = 8, -- after guarding, for this long a jab comes out faster...
	GuardCancelStartup = 3, -- ...in this many frames of wind-up
	GuardBreakTicks = 55,
	BufferTicks = 10, -- lifetime of a queued press (frozen during hitstop and while a hit lands)
	BufferSize = 3, -- presses kept ahead: enough for rhythm, not to type a whole route
	LateCancelTicks = 6, -- a press this late after a connected move still links (latency)
	MaxLatencyTicks = 12, -- latency compensation cap (200 ms one way): late links, QTE judged as seen
	ReversalBufferTicks = 4, -- while stunned / getting up, only presses this close to recovery count
	ComboScaling = 0.9, -- each hit already taken in the combo multiplies damage by this
	MinComboScaling = 0.4,
	MaxJuggleHits = 6, -- airborne hits allowed before the target becomes untouchable until landing
	JugglePop = 18,
	RelaunchVelocity = 20, -- a launcher on a target already in the air only keeps it up (one launch per combo)
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
	WakeInvulnTicks = 15, -- untouchable for this long once back on its feet (0.25 s)
	KOPop = 26,
	KOHitstop = 26,

	-- Ki meter (3 bars of 100) and ultimate
	MaxMeter = 300,
	-- COUP FATAL (C): only below this share of one's own health, once per match (MoveData.Fatal).
	FatalHealth = 0.3,
	-- ... and the blow that lands heals the striker by this share of his maximum health.
	FatalHeal = 0.2,
	SlipMeter = 8, -- ki for slipping an attack (boxer weave, see CombatSimulation slips)
	SlipAdvantageTicks = 18, -- the slipped attacker stays frozen this much longer: the boxer takes the lead
	SlipFreezeTicks = 14, -- slow-down on both fighters when the boxer slips an attack (black and white)
	StanceCooldownTicks = 30, -- between two stance switches (TARO: CLASSIQUE / ESQUIVE)
	-- Ultimate cinematics play in slow motion (share of real time), slower still around the
	-- final blow; the round timer is paused meanwhile. CinematicGap: distance the attacker
	-- stands from the target when the cinematic starts (both put on the ground, face to face).
	CinematicTimeScale = 0.6,
	CinematicImpactScale = 0.3,
	CinematicImpactTicks = { -4, 16 }, -- around the final blow
	CinematicGap = 2.6,
	MeterBar = 100,
	MeterOnHit = 0.18, -- fractions of the damage dealt / received
	MeterOnBlock = 0.15,
	MeterWhenHit = 0.1,
	MeterWhenBlocking = 0.12,
	SuperFlashTicks = 40,
	UltimateLaunch = 34,
	UltimatePush = 48,

	-- Match
	RoundSeconds = 99,
	RoundsToWin = 2,
	TeamHealOnKO = 0.2, -- teams (relay): the fighter who stays in gets back this share of its health
	IntroTicks = 130,
	KOTicks = 200,
	MatchEndTicks = 260,
	TrainingRefillTicks = 70,

	-- Presentation (client only)
	CameraFOV = 38,
	CameraMinDistance = 26,
	CameraMargin = 8,
	ModelYaw = 22, -- degrees the rig turns toward the camera, like 2D fighters drawn in 3/4 view
	-- Poses per second: 60 = FLUIDE (the default since 0.11.0: the steps of 12/15/24 only
	-- interpolate between a few key poses, which looks jerky on these bodies; the anime timing
	-- comes from the holds, smears and impact frames instead). The HUD button POSES cycles.
	PoseRate = 60,
})
