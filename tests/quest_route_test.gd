extends SceneTree

# Run with Godot: --headless --path . --script res://tests/quest_route_test.gd

var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)


func _settle() -> void:
	await physics_frame
	await process_frame
	await process_frame


func _wait_for_route(guide: Node) -> void:
	var deadline := Time.get_ticks_msec() + 6000
	while guide.path.size() < 2 and Time.get_ticks_msec() < deadline:
		await create_timer(0.05).timeout
	_check(guide.path.size() >= 2, "Navigation path must be available")


func _run() -> void:
	var global: Node = root.get_node("Global")
	var cases := {
		"bong": ["spawn_whiskey", "whiskey_instance", "whiskey", ["whiskey_spawn_bamboo_forest", "whiskey_spawn_west_beach_baobab", "whiskey_spawn_plane_wreck"]],
		"flycather": ["spawn_fly", "fly_instance", "fly", ["fly_spawn_swamp_forest", "fly_spawn_east_crash_beach", "fly_spawn_west_coast"]],
		"panda": ["spawn_book", "book_instance", "book", ["book_spawn_temple", "book_spawn_plane_beach"]],
	}
	for language: String in ["ru", "cz"]:
		global.language = language
		change_scene_to_file("res://scene/main.tscn")
		await scene_changed
		await _settle()
		var guide: Node = current_scene.get_node("QuestRoute")
		_check(guide.target == null and guide.path.is_empty(), "No route before a quest item spawns")
		for npc_name: String in cases:
			var npc: Node2D = current_scene.get_node(npc_name)
			var settings: Array = cases[npc_name]
			for location: int in settings[3].size():
				global.set(settings[2], false)
				global.player_position = npc.global_position + Vector2(0, 80)
				npc.quest_location_type = location
				var expected: Vector2 = npc.get(settings[3][location])
				npc.call(settings[0])
				var item: Node2D = npc.get(settings[1])
				_check(item.global_position == expected, "Spawn coordinates must not change")
				await _settle()
				_check(guide.target == item, "Route must target spawned item")
				await _wait_for_route(guide)
				_check(item.global_position == expected, "Navigation must not move the item")
				if not guide.path.is_empty():
					_check(guide.path[-1].distance_to(expected) < 64.0, "Path must reach the item vicinity")
				var blocked_segments: int = 0
				for index: int in range(1, guide.path.size()):
					var query := PhysicsRayQueryParameters2D.create(guide.path[index - 1], guide.path[index], global.player.collision_mask, [global.player.get_rid(), npc.get_rid()])
					if not global.player.get_world_2d().direct_space_state.intersect_ray(query).is_empty():
						blocked_segments += 1
				_check(blocked_segments == 0, "Path crosses obstacles: " + npc_name + " / " + str(location) + " segments=" + str(blocked_segments))
				print("ROUTE ", language, " ", npc_name, " / ", location, " points=", guide.path.size(), " endpoint=", guide.path[-1] if not guide.path.is_empty() else Vector2.ZERO)
				item.pick_up()
				await _settle()
				_check(guide.target == null and guide.path.is_empty(), "Route must disappear after pickup")
		# Concurrent quests choose the newest item, then restore the older route.
		var bong: Node2D = current_scene.get_node("bong")
		var flycatcher: Node2D = current_scene.get_node("flycather")
		global.whiskey = false
		global.fly = false
		bong.quest_location_type = 0
		flycatcher.quest_location_type = 0
		bong.spawn_whiskey()
		flycatcher.spawn_fly()
		await _settle()
		await _wait_for_route(guide)
		_check(guide.target == flycatcher.fly_instance, "Newest quest must get the guide")
		var old_start: Vector2 = guide.path[0]
		global.player_position = current_scene.get_node("ship").global_position + Vector2(-100, 0)
		await create_timer(0.3).timeout
		_check(guide.path[0].distance_to(old_start) > 100.0, "Route must update when the player moves or teleports")
		flycatcher.fly_instance.pick_up()
		await _settle()
		_check(guide.target == bong.whiskey_instance, "Earlier quest must resume after latest pickup")
		var bottle: Node2D = bong.whiskey_instance
		bottle.player = global.player
		bottle.pick_up()
		await _settle()
		_check(is_instance_valid(bottle), "Pickup tween should still be running")
		_check(guide.target == null and guide.path.is_empty(), "Route must hide at pickup start, before the tween finishes")
		print("PASS language: ", language)
	# Leaving the island while the asynchronous bake is running must be safe.
	change_scene_to_file("res://scene/main.tscn")
	await scene_changed
	global.whiskey = false
	current_scene.get_node("bong").spawn_whiskey()
	await _settle()
	_check(current_scene.get_node("QuestRoute")._building_navigation, "Navigation should be baking asynchronously")
	change_scene_to_file("res://scene/menu.tscn")
	await scene_changed
	await create_timer(1.5).timeout
	_check(current_scene.scene_file_path == "res://scene/menu.tscn", "Exiting during navigation bake must stay in menu")
	print("QUEST_ROUTE_TEST failures=", failures)
	quit(0 if failures == 0 else 1)
