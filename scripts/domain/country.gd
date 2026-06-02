class_name Country
extends RefCounted

enum Code { SA = 0, AUS = 1 }

static func to_key(c: int) -> String:
	match c:
		Code.SA: return "SA"
		Code.AUS: return "AUS"
		_: return ""

static func display_name(c: int) -> String:
	match c:
		Code.SA: return "SOUTH AFRICA"
		Code.AUS: return "AUSTRALIA"
		_: return ""
