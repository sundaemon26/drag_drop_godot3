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

extends Container

class_name DragDropContainer, "DragDropContainer.svg"


signal item_selected()
signal item_deselected()
signal item_swapped(container)


const DRAG_DROP_CONTAINER_GROUP := "_drag_drop_containers"


export(float, 0, 1) var drag_weight = 0.3
export(Vector2) var selected_offset
export(bool) var apply_pivot_offset = true
export(bool) var disabled
export(bool) var swappeable = true
export(int, FLAGS, "0", "1", "2", "3", "4", "5", "6", "7") var mask = 1

var _selected: bool setget, is_selected
var _target_position: Vector2


static func _reset_child_position_on_swap(child: Control, pos: Vector2):
	child.rect_global_position = pos


func _swap_children(container: DragDropContainer):
	var children = self.get_children()
	var container_children := container.get_children()
	var positions: PoolVector2Array
	var container_positions: PoolVector2Array
	
	for child in children:
		if not child is Control:
			continue
		positions.push_back(child.rect_global_position)
		self.remove_child(child)
	
	for child in container_children:
		if not child is Control:
			continue
		container_positions.push_back(child.rect_global_position)
		container.remove_child(child)
	
	var count: int
	
	count = 0
	for child in children:
		if not child is Control:
			continue
		container.add_child(child)
		child.rect_global_position = positions[count]
		count += 1
	
	count = 0
	for child in container_children:
		if not child is Control:
			continue
		self.add_child(child)
		child.rect_global_position = container_positions[count]
	
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
	self.connect("gui_input", self, "_on_gui_input")
	self.add_to_group(DRAG_DROP_CONTAINER_GROUP)
	_target_position = self.rect_global_position


func _process(_delta):
	for child in self.get_children():
		if not child is Control:
			continue
		
		var final_position := _target_position
		if _selected:
			if apply_pivot_offset:
				final_position -= child.rect_pivot_offset
		
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
