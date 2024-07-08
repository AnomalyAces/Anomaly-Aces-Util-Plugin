extends Node

## Find First Element of Array that me
static func findFirst( arr:Array, search_criteria: Callable) -> Variant: 
	for item in arr:
		if search_criteria.call(item):
			return item
	return null
