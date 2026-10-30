extends SceneTree

const OUTPUT := "res://.godot/"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var main: Node = load("res://scene/main.tscn").instantiate()
	var map: TileMap = main.get_node("TileMap")
	var ocean: TextureRect = map.get_node("TextureRect")
	var rows: Array = []
	var sources := {}
	var details := {}
	for layer in 2:
		for cell: Vector2i in map.get_used_cells(layer):
			var source_id := map.get_cell_source_id(layer, cell)
			var source: TileSetAtlasSource = map.tile_set.get_source(source_id)
			var coords := map.get_cell_atlas_coords(layer, cell)
			if not source.has_tile(coords):
				continue
			var tile: TileData = map.get_cell_tile_data(layer, cell)
			if tile == null:
				continue
			var region := source.get_tile_texture_region(coords)
			var center := map.map_to_local(cell)
			var position := center - Vector2(region.size) * 0.5 - Vector2(tile.texture_origin)
			var path: String = source.texture.resource_path
			sources[str(source_id)] = path
			rows.append([layer, source_id, position.x, position.y, region.position.x, region.position.y, region.size.x, region.size.y, tile.flip_h, tile.flip_v, tile.transpose])
			var key := "%d:%s:%d" % [source_id, coords, map.get_cell_alternative_tile(layer, cell)]
			details[key] = [region.size.x, region.size.y, tile.texture_origin.x, tile.texture_origin.y]
	var world_transform: Transform2D = main.transform * map.transform
	var origin: Vector2 = world_transform * ocean.position
	var extent: Vector2 = ocean.size * map.scale * main.scale
	var file := FileAccess.open(OUTPUT + "shoreline-source.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"sources": sources, "cells": rows, "details": details,
		"ocean_local": [ocean.position.x, ocean.position.y, ocean.size.x, ocean.size.y],
		"world_bounds": [origin.x, origin.y, extent.x, extent.y],
		"map_transform": [world_transform.x.x, world_transform.y.y, world_transform.origin.x, world_transform.origin.y]}, "\t"))
	file.close()
	main.free()
	print("SURF MAP EXPORT: cells=", rows.size(), " variants=", details.size(), " bounds=", origin, "/", extent)
	quit()
