class_name LoadingScreen
extends Control

#region Exported Variables
@export var progress_bar: ProgressBar
@export var loading_label: Label
#endregion

#region Private Variables
var _dots: int = 0
var _timer: Timer
#endregion

func _ready() -> void:
	if GameManager.is_instance_valid(GameManager):
		GameManager.game_state = 3 # Ensure GameManager knows we are loading
	
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	_timer = Timer.new()
	add_child(_timer)
	_timer.wait_time = 0.5
	_timer.autostart = true
	_timer.timeout.connect(Callable(self, "_update_dots"))
	
	# Simulate loading time
	var load_delay_timer: Timer = Timer.new()
	add_child(load_delay_timer)
	load_delay_timer.one_shot = true
	load_delay_timer.wait_time = 3.0 # Simulate 3 seconds of loading
	load_delay_timer.timeout.connect(Callable(self, "_on_loading_complete"))
	load_delay_timer.start()
	
	if is_instance_valid(progress_bar):
		progress_bar.max_value = load_delay_timer.wait_time
		progress_bar.value = 0
	
	print("LoadingScreen: Started loading.")

func _process(delta: float) -> void:
	if is_instance_valid(progress_bar):
		progress_bar.value += delta

func _update_dots() -> void:
	_dots = (_dots + 1) % 4
	var dot_string: String = "." * _dots
	if is_instance_valid(loading_label):
		loading_label.text = "Loading" + dot_string

func _on_loading_complete() -> void:
	print("LoadingScreen: Loading complete, transitioning to GameWorld.")
	if GameManager.is_instance_valid(GameManager):
		GameManager.load_game_world()