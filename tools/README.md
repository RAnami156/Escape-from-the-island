# Shoreline distance data

The surf uses a small baked distance map, so there is no map-generation work at game startup. After painting a new coastline or moving/scaling the island, regenerate it from the project root:

```sh
godot --headless --path . --script res://tools/export_shore_distance.gd
python tools/rebuild_shore_distance.py
```

Use the installed Godot executable if `godot` is not on PATH. The offline Python step requires Pillow and NumPy; the game itself does not use Python. Reopen Godot to import the updated texture. The baker also updates both water materials' world bounds.

## NPC dialogue

Czech Kong, Panda and Flycatcher use [Gemma 3 4B](https://ollama.com/library/gemma3:4b) locally. Install it before starting the Czech game:

```sh
ollama pull gemma3:4b
```

The Czech model is configured in `script/npc_czech_dialogue.gd`. Russian NPCs and Michael retain `qwen3:8b`. Speech generation produces a short intent and a free reply; a separate request evaluates the player's behavior and relationship changes. The existing NPC handlers still control quest progression, item spawns and rewards. Saved dialogue from older speech profiles remains visible, but is excluded from the model's speaking examples; explicitly learned player names are retained.

Offline checks cover the two requests, malformed assessments, neutral versus hostile behavior, history migration and the original quest routes:

```sh
godot --headless --path . --script res://tests/npc_czech_dialogue_test.gd
godot --headless --path . --script res://tests/npc_fast_dialogue_test.gd
```

With Ollama running, check conversational meaning and the complete quest exchanges:

```sh
godot --headless --path . --script res://tests/npc_czech_dialogue_quality_live_test.gd -- --report=/tmp/island-dialogue-quality.json
godot --headless --path . --script res://tests/npc_czech_dialogue_live_test.gd -- --report=/tmp/island-dialogue-quests.json
```

Quality checks examine greetings, informal Czech, player names, clarification, sadness, unavailable actions and directions. Inspect the recorded replies as well as the checks: passing a keyword check alone does not establish natural Czech. The quality runner accepts `--npc=bong` (also `panda` or `flycatcher`) and `--model=...` for focused comparisons. Live tests use isolated save paths.
