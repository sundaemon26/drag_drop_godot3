# MIT Licence
# Copyright © 2023 sundaemon26
#
# Permission is hereby granted, free of charge, to any person obtaining a copy of
# this software and associated documentation files (the “Software”), to deal in the
# Software without restriction, including without limitation the rights to use,
# copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the
# Software, and to permit persons to whom the Software is furnished to do so,
# subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
# INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
# PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
# HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
# SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

extends MarginContainer

class_name DragDropContainer


signal item_selected()
signal item_deselected()
signal item_swapped(container)


const DRAG_DROP_CONTAINER_GROUP := "_drag_drop_containers"


export(float, 0, 1) var drag_weight = 0.3
export(Vector2) var selected_offset
export(bool) var apply_pivot_offset = true
export(bool) var disabled
export(bool) var swappeable
export(int, FLAGS, "0", "1", "2", "3", "4", "5", "6", "7") var mask = 1

var _selected: bool setget, is_selected
var _swapping: bool
var _target_position: Vector2


static func _reset_child_position_on_swap(child: Control, pos: Vector2):
	child.rect_global_position = pos


func _swap_children(container: DragDropContainer):
	var container_children := container.get_children()
	var position: Vector2
	_swapping = true
	
	for child in self.get_children():
		if not child is Control:
			continue
		position = child.rect_global_position
		self.remove_child(child)
		container.add_child(child)
		child.rect_global_position = position
	
	for child in container_children:
		if not child is Control:
			continue
		position = child.rect_global_position
		container.remove_child(child)
		self.add_child(child)
		child.rect_global_position = position
	
	self.emit_signal("item_swapped", container)
	container.emit_signal("item_swapped", self)


func _try_swap(container: DragDropContainer) -> bool:
	assert(self != container)
	for child in self.get_children():
		if not child is Control:
			continue
		if container.get_global_rect().intersects(child.get_global_rect()):
			_swap_children(container)
			return true
	return false


func _handle_swap():
	if not swappeable or disabled:
		return
	for container in get_tree().get_nodes_in_group(DRAG_DROP_CONTAINER_GROUP):
		if self == container or not mask & container.mask:
			continue
		
		if container.swappeable and not container.disabled:
			if _try_swap(container):
				break


func _input(event: InputEvent):
	if event is InputEventMouseButton and not event.pressed and _selected:
		_selected = false
		_target_position = self.rect_global_position
		self.emit_signal("item_deselected")
		_handle_swap()
	elif event is InputEventMouseMotion and _selected:
		_target_position = get_viewport().get_mouse_position() + selected_offset


func _ready():
	self.add_to_group(DRAG_DROP_CONTAINER_GROUP)
	_target_position = self.rect_global_position


func _sort_children():
	if not _swapping:
		._sort_children()
	else:
		_swapping = false


func _process(_delta):
	for child in self.get_children():
		if not child is Control:
			continue
		
		var final_position := _target_position
		if _selected:
			if apply_pivot_offset:
				final_position -= child.rect_pivot_offset
		else:
			final_position.x += self.get_constant("margin_left")
			final_position.y += self.get_constant("margin_top")
		
		child.rect_global_position = lerp(child.rect_global_position, final_position, drag_weight)


func _on_gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.pressed and not _selected:
		if disabled:
			return
		_selected = true
		_target_position = get_viewport().get_mouse_position() + selected_offset
		self.emit_signal("item_selected")


func is_selected() -> bool:
	return _selected
