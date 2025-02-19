extends BaseManager
class_name ObjectManager

var origin

signal object_spawned
signal object_despawned

var objects:Array[GameObject] = []
var objects_ids:Dictionary = {}
var objects_to_process:Array[GameObject]

var player:PlayerObject

func prepare(_game:GameScene):
	super.prepare(_game)

	for child in get_children():
		if child is ObjectRenderer:
			child.prepare()

	origin = game.origin
	player = game.player

	origin.set_physics_process(game.local_player)

	append_object(player,false)

func append_object(object:GameObject,parent:bool=true,include_children:bool=false):
	if objects_ids.keys().has(object.id): return false

	object.game = game
	object.manager = self

	object.set_physics_process(game.local_player)
	if !object.permanent: object.process_mode = Node.PROCESS_MODE_DISABLED
	object.process_priority = 4

	if object is HitObject:
		if player != null: object.connect(
			"on_hit_state_changed",
			Callable(player,"hit_object_state_changed").bind(object)
		)

	if parent: # Reparent to origin
		var current_parent = object.get_parent()
		if current_parent != origin:
			if current_parent != null:
				current_parent.remove_child(object)
			origin.add_child(object)

	if include_children: # Append children
		for child in object.get_children():
			if child is GameObject:
				append_object(child,false,true)

	objects.append(object)
	objects_ids[object.id] = object
	if !object.permanent: objects_to_process.append(object)

func _process(_delta):
	for object in objects_to_process.duplicate():
		if game.sync_manager.current_time < object.spawn_time: break
		if object.force_despawn or game.sync_manager.current_time > object.despawn_time:
			object.despawned.emit()
			object_despawned.emit(object)
			if object is HitObject and object.hit_state == HitObject.HitState.NONE:
				object.miss()
			object.process_mode = Node.PROCESS_MODE_DISABLED
			objects_to_process.erase(object)
			continue
		if object.process_mode != Node.PROCESS_MODE_INHERIT:
			object.spawned.emit()
			object_spawned.emit(object)
		object.process_mode = Node.PROCESS_MODE_INHERIT
