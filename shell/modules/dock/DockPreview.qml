import QtQuick
import "../../common/tokens.js" as Tokens

// Window cards are created only after the dock's hover dwell. Each visible
// card owns its own capture stream; closing the card destroys the stream.
Item {
	id: root
	property var candidates: []
	property bool opened: false
	property bool captureEnabled: false
	property color background: Qt.rgba(0.1, 0.1, 0.12, 0.95)
	property color foreground: "white"
	readonly property bool hovered: hover.hovered
	readonly property Item boxItem: frame
	signal focusRequested(string address)
	signal closeRequested(string address)

	width: Math.min(Tokens.dock.preview.maxVisible, candidates.length) * Tokens.dock.preview.width
		+ Math.max(0, Math.min(Tokens.dock.preview.maxVisible, candidates.length) - 1) * Tokens.dock.preview.gap
	height: 166
	visible: opened && candidates.length > 0
	opacity: visible ? 1 : 0
	Behavior on opacity { NumberAnimation { duration: Tokens.dock.preview.motionMs } }
	HoverHandler { id: hover }

	Rectangle {
		id: frame
		anchors.fill: parent
		color: "transparent"
		clip: true
		Flickable {
			id: scroller
			anchors.fill: parent
			clip: true
			contentWidth: root.candidates.length * Tokens.dock.preview.width
				+ Math.max(0, root.candidates.length - 1) * Tokens.dock.preview.gap
			contentHeight: height
			boundsBehavior: Flickable.StopAtBounds
			flickableDirection: Flickable.HorizontalFlick

			Repeater {
				model: root.candidates
				delegate: Rectangle {
					id: card
					required property int index
					required property var modelData
					readonly property var candidate: modelData
					readonly property bool inViewport: x + width > scroller.contentX && x < scroller.contentX + scroller.width
					objectName: "preview-card-" + candidate.address
					x: index * (Tokens.dock.preview.width + Tokens.dock.preview.gap)
					width: Tokens.dock.preview.width
					height: root.height
					radius: 10
					color: root.background
					clip: true
					MouseArea {
						anchors.fill: parent
						onClicked: root.focusRequested(card.candidate.address)
					}

					Rectangle {
						id: imageBox
						x: 0; y: 0
						width: parent.width
						height: Tokens.dock.preview.imageHeight
						color: Qt.rgba(0, 0, 0, 0.2)
						clip: true
						Loader {
							id: capture
							anchors.fill: parent
							active: root.captureEnabled && root.opened && card.inViewport && !!card.candidate.toplevel
							source: "DockCapture.qml"
							onLoaded: {
								capture.item.captureSource = card.candidate.toplevel;
								capture.item.streamLive = Qt.binding(() => root.opened && card.inViewport);
							}
						}
						Text {
							objectName: "preview-fallback-" + card.candidate.address
							anchors.centerIn: parent
							visible: !capture.item || !capture.item.hasContent
							text: card.candidate.title || "Window preview unavailable"
							color: root.foreground
							font.pixelSize: 12
							elide: Text.ElideRight
							width: parent.width - 20
							horizontalAlignment: Text.AlignHCenter
						}
					}

					Text {
						objectName: "preview-title-" + card.candidate.address
						x: 10; y: Tokens.dock.preview.imageHeight + 10
						width: card.width - 44
						text: card.candidate.title
						color: root.foreground
						font.pixelSize: 12
						elide: Text.ElideRight
					}
					Rectangle {
						id: closeButton
						objectName: "preview-close-" + card.candidate.address
						x: card.width - width - 5
						y: Tokens.dock.preview.imageHeight + 4
						width: 30; height: 30
						radius: 5
						color: closeTap.containsMouse ? Qt.rgba(1, 1, 1, 0.18) : "transparent"
						Text { anchors.centerIn: parent; text: "×"; color: root.foreground; font.pixelSize: 18 }
						MouseArea {
							id: closeTap
							anchors.fill: parent
							hoverEnabled: true
							onClicked: root.closeRequested(card.candidate.address)
						}
					}
				}
			}
		}
	}
}
