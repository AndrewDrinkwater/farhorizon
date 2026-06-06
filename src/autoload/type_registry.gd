extends Node
## TypeRegistry — loads and hands out authored .tres Resources (ADR 0002).
##
## Read-only cache of immutable authored data (hulls, systems, bodies, tuning).
## Runtime state references these by id; this resolves id -> Resource. Never
## mutate a returned Resource.
##
## SCAFFOLD STUB — directory scanning + typed getters land alongside the data
## types in build-order steps 4-5.

var _cache: Dictionary = {}


func get_resource(id: String) -> Resource:
	# TODO(step 4): resolve id -> loaded .tres from the cache.
	return _cache.get(id, null)


func has(id: String) -> bool:
	return _cache.has(id)
