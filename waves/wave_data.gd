## One wave: which enemies, how many, and how fast they come out.
class_name WaveData
extends Resource

## Each entry is one enemy type and how many of it.
@export var groups : Array[EnemySpawn] = []
## Seconds between spawns (or between bursts, if burst_size is above 1).
@export var spawn_interval : float = 0.3
## How many enemies come out at once. 1 is a steady trickle.
@export_range(1, 20) var burst_size : int = 1
## Mix the types together instead of spawning each group in order.
@export var shuffle : bool = true
