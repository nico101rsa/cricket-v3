class_name NamePair
extends Resource

@export var first_name: String = ""
@export var surname: String = ""

func display() -> String:
	return "%s %s" % [first_name, surname]

func display_caps() -> String:
	return display().to_upper()
