extends Resource
class_name AbilityEligibilityRule


func is_satisfied(_context: Dictionary) -> bool:
	return true


func get_failure_reason(_context: Dictionary) -> String:
	return ""
