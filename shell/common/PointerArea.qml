import QtQuick

// A clickable area with Bloom's cursor (`cursor: pointer`) and its hover and
// press state. Disabling it (or an ancestor) drops the taps and the hover, and
// the cursor falls back to the default, as Bloom's `:disabled` rules do.
// A tap takes the pointer on press and fires on a release inside, like a
// browser click with stopPropagation: a control inside another (a tile's
// chevron) doesn't also click the one beneath it.
Item {
	id: root

	property int cursorShape: Qt.PointingHandCursor
	readonly property bool hovered: hover.hovered
	readonly property bool pressed: leftTap.pressed

	signal clicked()
	signal rightClicked()

	HoverHandler {
		id: hover
		cursorShape: root.cursorShape
	}

	TapHandler {
		id: leftTap
		acceptedButtons: Qt.LeftButton
		gesturePolicy: TapHandler.ReleaseWithinBounds
		onTapped: root.clicked()
	}

	TapHandler {
		acceptedButtons: Qt.RightButton
		gesturePolicy: TapHandler.ReleaseWithinBounds
		onTapped: root.rightClicked()
	}
}
