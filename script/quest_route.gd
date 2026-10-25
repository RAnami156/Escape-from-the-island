extends Node2D

const ROUTE_COLOR: Color = Color("efd085")
const OUTLINE_COLOR: Color = Color("253b32cc")
const HIGHLIGHT_COLOR: Color = Color("fff2c1")
const REPATH_INTERVAL: float = 0.2

var target: Node2D = null
var path: PackedVector2Array = PackedVector2Array()
var _navigation_polygon: NavigationPolygon
var _navigation_map: RID
var _navigation_region: RID
var _building_navigation: bool = false
var _repath_left: float = 0.0
var _flow: float = 0.0
var _target_id: int = 0


func _ready() -> void:
	z_index = 3
	light_mask = 0


func _process(delta: float) -> void:
	# The most recently spawned outstanding quest gets the guide. Older quests
	# become active again when that item is collected or removed.
	var next_target: Node2D = null
	for item: Node in get_tree().get_nodes_in_group("quest_items"):
		if item is Node2D and not item.is_queued_for_deletion() and not item.get("picked_up"):
			next_target = item as Node2D
	var next_id := next_target.get_instance_id() if next_target != null else 0
	if _target_id != next_id:
		target = next_target
		_target_id = next_id
		path.clear()
		_repath_left = 0.0
		queue_redraw()

	if not is_instance_valid(target) or not is_instance_valid(Global.player):
		return
	if not _navigation_map.is_valid() and not _building_navigation:
		_building_navigation = true
		_build_navigation.call_deferred()
	_flow = fmod(_flow + delta * 16.0, 18.0)
	queue_redraw()


func _physics_process(delta: float) -> void:
	if not is_instance_valid(target) or not is_instance_valid(Global.player):
		return
	if not _navigation_map.is_valid() or NavigationServer2D.map_get_iteration_id(_navigation_map) == 0:
		return
	_repath_left -= delta
	if _repath_left > 0.0:
		return
	_repath_left = REPATH_INTERVAL
	path = NavigationServer2D.map_get_path(
		_navigation_map, _player_feet(), target.global_position, true
	)


func _player_feet() -> Vector2:
	return Global.player.get_node("CollisionShape2D").global_position


func _build_navigation() -> void:
	if not is_instance_valid(Global.player) or not is_instance_valid(target):
		_building_navigation = false
		return
	var scene := get_tree().current_scene
	var geometry := Node2D.new()
	var bounds := Rect2(_player_feet(), Vector2.ONE).expand(target.global_position)
	for body: StaticBody2D in scene.find_children("*", "StaticBody2D", true, false):
		var copy := body.duplicate(0) as StaticBody2D
		geometry.add_child(copy)
		copy.transform = body.global_transform

	# Bake from separate copies in a separate physics world. Invalid atlas cells
	# are skipped in the copies only; the island and its collisions stay intact.
	for tile_map: TileMap in scene.find_children("*", "TileMap", true, false):
		var copy := tile_map.duplicate(0) as TileMap
		geometry.add_child(copy)
		copy.transform = tile_map.global_transform
		var used := tile_map.get_used_rect()
		for corner: Vector2i in [used.position, used.end, Vector2i(used.position.x, used.end.y), Vector2i(used.end.x, used.position.y)]:
			bounds = bounds.expand(tile_map.to_global(tile_map.map_to_local(corner)))
		for layer: int in copy.get_layers_count():
			for cell: Vector2i in copy.get_used_cells(layer):
				var source := copy.tile_set.get_source(copy.get_cell_source_id(layer, cell)) as TileSetAtlasSource
				if source != null and not source.has_tile(copy.get_cell_atlas_coords(layer, cell)):
					copy.erase_cell(layer, cell)

	bounds = bounds.grow(128.0)
	_navigation_polygon = NavigationPolygon.new()
	_navigation_polygon.agent_radius = 12.0
	_navigation_polygon.parsed_geometry_type = NavigationPolygon.PARSED_GEOMETRY_STATIC_COLLIDERS
	_navigation_polygon.parsed_collision_mask = Global.player.collision_mask
	_navigation_polygon.add_outline(PackedVector2Array([
		bounds.position, Vector2(bounds.end.x, bounds.position.y),
		bounds.end, Vector2(bounds.position.x, bounds.end.y),
	]))
	var viewport := SubViewport.new()
	viewport.size = Vector2i(2, 2)
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	viewport.world_2d = World2D.new()
	viewport.add_child(geometry)
	get_tree().root.add_child(viewport)
	var source_geometry := NavigationMeshSourceGeometryData2D.new()
	NavigationServer2D.parse_source_geometry_data(_navigation_polygon, source_geometry, geometry)
	viewport.free()
	NavigationServer2D.bake_from_source_geometry_data_async(
		_navigation_polygon, source_geometry, _on_navigation_baked
	)


func _on_navigation_baked() -> void:
	if not is_inside_tree():
		return
	# A private map keeps quest guidance independent of gameplay navigation.
	_navigation_map = NavigationServer2D.map_create()
	NavigationServer2D.map_set_active(_navigation_map, true)
	# Preserve the short baked coastline edges instead of merging nearby edges.
	NavigationServer2D.map_set_merge_rasterizer_cell_scale(_navigation_map, 0.001)
	NavigationServer2D.map_set_use_async_iterations(_navigation_map, false)
	_navigation_region = NavigationServer2D.region_create()
	NavigationServer2D.region_set_use_async_iterations(_navigation_region, false)
	NavigationServer2D.region_set_map(_navigation_region, _navigation_map)
	NavigationServer2D.region_set_navigation_polygon(_navigation_region, _navigation_polygon)
	NavigationServer2D.map_force_update(_navigation_map)
	_building_navigation = false
	_repath_left = 0.0


func _draw() -> void:
	if not is_instance_valid(target) or not is_instance_valid(Global.player):
		return
	var start := to_local(_player_feet())
	var finish := to_local(target.global_position)
	var points := PackedVector2Array()
	for point: Vector2 in path:
		points.append(to_local(point))
	if points.size() >= 2:
		points[0] = start
		draw_polyline(points, OUTLINE_COLOR, 3.2, true)
		draw_polyline(points, ROUTE_COLOR, 1.4, true)
		_draw_flow(points)
		# Keep the item's exact spawn point, even if it lies off the walkable mesh.
		if points[-1].distance_to(finish) > 1.0:
			draw_dashed_line(points[-1], finish, ROUTE_COLOR, 1.2, 3.0, true, true)
	else:
		# Show the direction immediately while the navigation mesh is baking.
		draw_dashed_line(start, finish, OUTLINE_COLOR, 2.6, 4.0, true, true)
		draw_dashed_line(start, finish, ROUTE_COLOR, 1.2, 4.0, true, true)
	draw_arc(finish, 7.0, 0.0, TAU, 24, OUTLINE_COLOR, 3.2, true)
	draw_arc(finish, 7.0, 0.0, TAU, 24, ROUTE_COLOR, 1.4, true)


func _draw_flow(points: PackedVector2Array) -> void:
	var distance: float = _flow
	var visible_rect := get_viewport_rect().grow(16.0)
	var canvas_transform := get_global_transform_with_canvas()
	for index: int in range(1, points.size()):
		var segment_length := points[index - 1].distance_to(points[index])
		while distance < segment_length:
			var position_on_line := points[index - 1].move_toward(points[index], distance)
			if visible_rect.has_point(canvas_transform * position_on_line):
				draw_circle(position_on_line, 1.0, HIGHLIGHT_COLOR, true, -1.0, true)
			distance += 18.0
		distance -= segment_length


func _exit_tree() -> void:
	if _navigation_region.is_valid():
		NavigationServer2D.free_rid(_navigation_region)
	if _navigation_map.is_valid():
		NavigationServer2D.free_rid(_navigation_map)
