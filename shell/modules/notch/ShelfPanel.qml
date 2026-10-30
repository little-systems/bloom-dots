import QtQuick
import qs.services

// The shelf panel: binds ShelfView to the shelf service.
ShelfView {
	theme: Theme
	items: ShelfState.items
	previews: ShelfState.previews
	newIds: ShelfState.newIds
	notice: ShelfState.notice

	onRemoveRequested: index => ShelfState.remove(index)
	onActivated: index => ShelfState.activate(index)
	onFilesDropped: paths => ShelfState.addFiles(paths)
	onTextDropped: text => ShelfState.addText(text)
}
