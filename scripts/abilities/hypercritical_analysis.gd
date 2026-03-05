extends AbilityBase
class_name HypercriticalAnalysisAbility

## Hypercritical Analysis - Reveals weak points for guaranteed critical hits


func _ready() -> void:
	ability_name = "Hypercritical Analysis"
	cooldown = 15.0
	duration = 5.0


func _perform_ability(player: PlayerController) -> void:
	"""Activate critical hit mode for duration."""
	player.crit_active = true
	player.crit_multiplier = 3.0

	print("[Hypercritical Analysis] All attacks deal 3x damage for %.1f seconds!" % duration)

	# Deactivate after duration
	await get_tree().create_timer(duration).timeout
	player.crit_active = false

	ability_used.emit()
