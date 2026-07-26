extends Resource
class_name ZombieData

# ── Zombie variant definitions & constants ──
# Mirrors the original game.js spawnZombie & related systems

# Base zombie colors — the green-tinged dead
const ZOMBIE_COLORS: Array[Color] = [
	Color("5a6348"),
	Color("6b7355"),
	Color("7a8260"),
	Color("4a5538"),
	Color("8a9268"),
]

# Variant colors
const GREEN_COLOR: Color = Color("39b83a")
const RED_COLOR: Color = Color("d43a3a")
const PURPLE_COLOR: Color = Color("9b4dff")

# Boss livery
const BOSS_PURPLE: Color = Color("8a2be2")
const BOSS_CRIMSON: Color = Color("c22626")
const BOSS_INFECTED: Color = Color("2f9e34")
const BOSS_ROTTEN: Color = Color("77a12c")
const CRIMSON_HANDS: Color = Color("6e1414")
const INFECTED_HANDS: Color = Color("145414")
const ROTTEN_HANDS: Color = Color("3f5a14")

# Gore colors
const BLOOD: Color = Color("7a0f0f")
const ROT_PINK: Color = Color("e89aa8")
const ROT_HEART: Color = Color("7a0f0f")
const ROT_RIB: Color = Color("d8cfc0")
const ROT_SOCKET: Color = Color("1c0e10")
const ROT_CAV: Color = Color("c76b80")
const ROT_FLESH: Color = Color("d77a8e")

# Zombie body part colors
const ZOMBIE_HAND: Color = Color("8aa85a")
const ZOMBIE_KNUCKLE: Color = Color("789748")
const ZOMBIE_LEG: Color = Color("39432a")
const ZOMBIE_FOOT: Color = Color("2c331f")
const ZOMBIE_MOUTH: Color = Color("4a1414")
const ZOMBIE_BROW: Color = Color("2f4020")
const BLIND_EYE: Color = Color("e2e6e2")
const BLIND_PUPIL: Color = Color("bfc3c6")
const ZOMBIE_PUPIL: Color = Color("7a1010")

# ── Zombie states ──
enum State {
	EMERGE,     # Clawing out of the dirt
	SLEEP,      # Lying sprawled on the pavement
	CORPSE,     # Dead carcass, never gets up (unless Rotten One wakes it)
	WAKE,       # Getting up from sleep
	CHASE,      # Active pursuit
	DYING,      # Falling over, sinking
	DORMANT,    # Boss only — asleep until approached
}

# ── Spawn modes ──
enum SpawnMode {
	GRAVE,      # Claws up out of the dirt
	SLEEPER,    # Lies on the ground until you're close
	RUNNER,     # Spawns far out and sprints in
	POP,        # Just appears (boss waves)
	CORPSE,     # Already dead carcass
}

# ── Variant type ──
enum Variant {
	NONE,
	PURPLE,     # Boss-swarm variant: purple, 33% faster
	RED,        # Crimson One's church swarm: red, quick, harder bite
	GREEN,      # Infected One's lot: green, 10% bigger
	GORE_HORN,  # Gore-horde extra: green horned brute, free walker
}

# ── Limb hitbox spec (local to zombie facing frame) ──
# [kind, idx, localX, localY, localZ, radius]
const LIMB_SPECS: Array[Dictionary] = [
	{ kind = "arm", idx = 0, local_x = -0.5, local_y = 0.80, local_z = 0.18, radius = 0.30 },
	{ kind = "arm", idx = 1, local_x =  0.5, local_y = 0.80, local_z = 0.18, radius = 0.30 },
	{ kind = "leg", idx = 0, local_x = -0.2, local_y = 0.28, local_z = 0.02, radius = 0.24 },
	{ kind = "leg", idx = 1, local_x =  0.2, local_y = 0.28, local_z = 0.02, radius = 0.24 },
]

# ── Spawner constants ──
const SPAWNER_BASE_MAX: int = 4
const SPAWNER_MAX_PER_TIME: int = 22           # +1 per ~22s of game time
const SPAWNER_MAX_PER_KILL: int = 7            # +1 per 7 kills
const SPAWNER_HARD_CAP: int = 28
const SPAWNER_BASE_INTERVAL: float = 4.2
const SPAWNER_INTERVAL_DECAY: float = 80.0     # interval = (4.2 - time/80) / spawnRate
const SPAWNER_MIN_INTERVAL: float = 0.42
const SPAWNER_GORE_HORDE_MULT: float = 1.2     # Extra Gore multiplies capacity & rate
const GRAVE_SPAWN_RANGE_NEAR: float = 14.0     # Don't spawn right under their feet
const GRAVE_SPAWN_RANGE_FAR: float = 60.0      # Don't spawn too far to matter
const SPAWN_FOG_PADDING: float = 6.0           # Runners spawn past the fog line
const SPAWN_FOG_SPREAD: float = 28.0
const SPAWN_NEAR_MIN: float = 32.0
const SPAWN_NEAR_MAX: float = 54.0
const SPAWN_RUNNER_CHANCE: float = 0.22
const SPAWN_GRAVE_CHANCE: float = 0.3
const SPAWN_ROAD_SLEEPER_CHANCE: float = 0.35
const SPAWN_GORE_HORN_CHANCE: float = 0.2      # Fraction of horde spawns that are gore-horn brutes

# ── Zombie stats ──
const HP_BASE_MIN: float = 9.0
const HP_BASE_MAX: float = 15.0
const HP_CORPSE_MIN: float = 3.0
const HP_CORPSE_MAX: float = 6.0
const HP_VARIANT_MULT: float = 1.2
const SPEED_MIN: float = 1.5
const SPEED_MAX: float = 2.9
const SPEED_PURPLE_MULT: float = 1.33
const SPEED_RED_GREEN_MULT: float = 1.25
const SPEED_RUNNER_MULT: float = 1.5
const SCALE_MIN: float = 0.85
const SCALE_MAX: float = 1.35
const SCALE_GREEN_MULT: float = 1.1
const POWER_SCALE_SPEED: float = 0.1
const POWER_SCALE_TIME: float = 240.0          # Time divisor for power scaling

# ── Attack ──
const BITE_RANGE: float = 1.7
const BITE_V_REACH: float = 1.25
const BOSS_BITE_RANGE: float = 3.4
const BOSS_BITE_V_REACH: float = 2.4
const BITE_DAMAGE_MIN: float = 9.0
const BITE_DAMAGE_MAX: float = 15.0
const BOSS_BITE_DAMAGE_MIN: float = 26.0
const BOSS_BITE_DAMAGE_MAX: float = 38.0
const BITE_MULT_RED_GREEN: float = 1.35
const ATTACK_COOLDOWN: float = 0.9
const BOSS_ATTACK_COOLDOWN: float = 1.1
const PUNCH_CHANCE: float = 0.05              # Rare haymaker instead of bite
const PUNCH_DAMAGE_MIN: float = 8.0
const PUNCH_DAMAGE_MAX: float = 13.0
const STOP_DIST: float = 1.5                  # Pull up at bite range
const SURROUND_STOP_DIST: float = 0.6         # Ringing a rooftop — close right up

# ── Wake / emerge ──
const EMERGE_DURATION: float = 1.7
const WAKE_DURATION: float = 0.9
const WAKE_DISTANCE: float = 24.0             # Any player walking up wakes it
const CORPSE_WAKE_DISTANCE: float = 24.0

# ── Death ──
const CORPSE_SINK_TIME: float = 2.4
const CORPSE_SINK_START: float = 1.2
const CORPSE_SINK_SPEED: float = 0.8

# ── Blind behavior ──
const BLIND_CHANCE: float = 0.16
const BLIND_SHOT_HEAR_RANGE: float = 14.0     # Seconds a gunshot stays audible
const BLIND_SHOT_CLOSE: float = 2.2           # Reached the source — shrug, wander
const BLIND_WANDER_RANGE: float = 6.0
const BLIND_WANDER_TIME_MIN: float = 2.5
const BLIND_WANDER_TIME_MAX: float = 6.5

# ── Knockback ──
const KNOCKBACK_IMPULSE_MULT: float = 0.5
const KNOCKBACK_POS_MULT: float = 0.12
const KNOCKBACK_DECAY: float = 6.0            # exp(-6*dt) per frame
const KNOCKBACK_MIN: float = 0.08
const BOSS_KNOCKBACK_MULT: float = 0.05

# ── Groan / step sounds ──
const GROAN_INTERVAL_MIN: float = 4.0
const GROAN_INTERVAL_MAX: float = 11.0
const GROAN_HEAR_RANGE: float = 26.0
const STEP_INTERVAL: float = 0.55
const STEP_HEAR_RANGE: float = 22.0

# ── Walk animation ──
const WALK_PHASE_SPEED: float = 3.2
const LEG_SWING_AMP: float = 0.7
const ARM_SWING_BASE: float = -1.4
const ARM_SWING_AMP: float = 0.25
const CLAW_ARM_RAISE: float = -2.5
const CLAW_ARM_SWING: float = 0.55
const CLAW_SPEED: float = 6.0
const CLAW_FADE_SPEED: float = 4.0
const LUNGE_AMOUNT: float = 0.9

# ── Head animation pool ──
const HEAD_ANIM_CHANCE: float = 0.7
const HEAD_ANIM_ENGAGING_MIN: float = 0.45
const HEAD_ANIM_ENGAGING_MAX: float = 1.05
const HEAD_ANIM_BLEEDING_MIN: float = 1.0
const HEAD_ANIM_BLEEDING_MAX: float = 3.0
const HEAD_ANIM_IDLE_MIN: float = 2.0
const HEAD_ANIM_IDLE_MAX: float = 4.0
const HEAD_ANIM_BOSS4_MIN: float = 0.2
const HEAD_ANIM_BOSS4_MAX: float = 0.65

# ── Engaging / reaching ──
const ENGAGE_DIST: float = 2.2
const ENGAGE_ATTACK_THRESH: float = 0.55
const REACH_ATTACK_THRESH: float = 0.5
const REACH_MAX_DIST: float = 7.0
const REACH_MIN_DIST: float = 1.6
const REACH_FAR_DIST: float = 1.9

# ── Chunk / despawn ──
const DESPAWN_FOG_OFFSET: float = 26.0
const DESPAWN_FARBORN_OFFSET: float = 46.0

# ── Leash / clamp speed ──
const SPEED_CLOSE_MULT: float = 1.25
const SPEED_CLOSE_DIST: float = 3.0
const SPEED_WANDER_MULT: float = 0.45

# ── Collision ──
const ZOMBIE_RADIUS: float = 0.4
const ZOMBIE_SEPARATION: float = 0.85
const ZOMBIE_SEP_FORCE: float = 0.5
const BLOCKED_THRESHOLD: float = 0.34
const STEP_UP: float = 0.55
const GRAVITY: float = 20.0

# ── Dismember / spawn visuals ──
const BRAIN_EXPOSED_CHANCE: float = 0.12
const BRAIN_CORPSE_CHANCE: float = 0.4
const DROOPY_CHANCE: float = 0.3
const ARM_GONE_CHANCE: float = 0.1
const ARM_GONE_CORPSE_CHANCE: float = 0.35
const WOUNDED_EXTRA_GORE_CHANCE: float = 0.35

# ── Rot / Rotten One sickness ──
const ROT_EYE_CHANCE: float = 0.28
const ROT_EYE_CORPSE_CHANCE: float = 0.5
const ROT_CHEST_CHANCE: float = 0.26
const ROT_CHEST_CORPSE_CHANCE: float = 0.5
const ROT_BELLY_CHANCE: float = 0.3
const ROT_BELLY_CORPSE_CHANCE: float = 0.55

# ── Headshot damage ──
const BRAIN_EXPOSED_DAMAGE_MULT: float = 2.5


static func random_zombie_color(rng: RandomNumberGenerator = null) -> Color:
	if rng:
		return ZOMBIE_COLORS[rng.randi_range(0, ZOMBIE_COLORS.size() - 1)]
	return ZOMBIE_COLORS[randi() % ZOMBIE_COLORS.size()]


static func variant_color(variant: Variant) -> Color:
	match variant:
		Variant.GREEN, Variant.GORE_HORN:
			return GREEN_COLOR
		Variant.RED:
			return RED_COLOR
		Variant.PURPLE:
			return PURPLE_COLOR
	return ZOMBIE_COLORS[0]


static func variant_hands(variant: Variant) -> Color:
	match variant:
		Variant.GREEN, Variant.GORE_HORN:
			return Color("145414")
		Variant.RED:
			return CRIMSON_HANDS
		Variant.PURPLE:
			return Color("4a1a7a")
	return Color(0, 0, 0, 0)  # transparent = use default


static func random_scale(rng: RandomNumberGenerator, green: bool) -> float:
	var s: float
	if rng:
		s = SCALE_MIN + rng.randf() * (SCALE_MAX - SCALE_MIN)
	else:
		s = SCALE_MIN + randf() * (SCALE_MAX - SCALE_MIN)
	if green:
		s *= SCALE_GREEN_MULT
	return s


static func random_hp(rng: RandomNumberGenerator, scale: float, power_scale: float, variant_mult: bool) -> float:
	if rng:
		return (HP_BASE_MIN + rng.randf() * (HP_BASE_MAX - HP_BASE_MIN)) * scale * power_scale * (HP_VARIANT_MULT if variant_mult else 1.0)
	return (HP_BASE_MIN + randf() * (HP_BASE_MAX - HP_BASE_MIN)) * scale * power_scale * (HP_VARIANT_MULT if variant_mult else 1.0)


static func random_speed(rng: RandomNumberGenerator, power_scale: float, variant: Variant, is_runner: bool) -> float:
	var s: float
	if rng:
		s = SPEED_MIN + rng.randf() * (SPEED_MAX - SPEED_MIN)
	else:
		s = SPEED_MIN + randf() * (SPEED_MAX - SPEED_MIN)
	s *= 0.9 + power_scale * POWER_SCALE_SPEED
	match variant:
		Variant.PURPLE:
			s *= SPEED_PURPLE_MULT
		Variant.RED, Variant.GREEN, Variant.GORE_HORN:
			s *= SPEED_RED_GREEN_MULT
	if is_runner:
		s *= SPEED_RUNNER_MULT
	return s


static func corpse_hp(rng: RandomNumberGenerator, scale: float) -> float:
	if rng:
		return (HP_CORPSE_MIN + rng.randf() * (HP_CORPSE_MAX - HP_CORPSE_MIN)) * scale
	return (HP_CORPSE_MIN + randf() * (HP_CORPSE_MAX - HP_CORPSE_MIN)) * scale
