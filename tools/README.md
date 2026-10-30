# Shoreline distance data

The surf uses a small baked distance map, so there is no map-generation work at game startup. After painting a new coastline or moving/scaling the island, regenerate it from the project root:

```sh
godot --headless --path . --script res://tools/export_shore_distance.gd
python tools/rebuild_shore_distance.py
```

Use the installed Godot executable if `godot` is not on PATH. The offline Python step requires Pillow and NumPy; the game itself does not use Python. Reopen Godot to import the updated texture. The baker also updates both water materials' world bounds.
