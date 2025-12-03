extends Control

@export var progress_preview : ColorRect

@export var color_picker_a : ColorPickerButton
@export var color_picker_b : ColorPickerButton

var color_a_default : Color = Color("40ff40")
var color_b_default : Color = Color("00ab00")

func _on_color_picker_1_color_changed(color: Color) -> void:
	progress_preview.material.set("shader_parameter/color_gap", color)

func _on_color_picker_2_color_changed(color: Color) -> void:
	progress_preview.material.set("shader_parameter/color_stripe", color)

func _on_reset_button_pressed() -> void:
	# Reset Progress Bar
	progress_preview.material.set("shader_parameter/color_gap", color_a_default)
	progress_preview.material.set("shader_parameter/color_stripe", color_b_default)
	
	# Reset Buttons
	color_picker_a.color = color_a_default
	color_picker_b.color = color_b_default
