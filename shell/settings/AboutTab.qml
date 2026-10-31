import QtQuick
import "../common"
import "../common/render"
import "../common/tokens.js" as Tokens

// Bloom's AboutTab, without Software Updates: pacman owns those here.
Column {
	id: root
	property QtObject theme
	property string version: ""
	property string exportLabel: "Export Settings"
	property string importLabel: "Import Settings"
	signal exportRequested()
	signal importRequested()

	x: Tokens.settings.about.padding[1]
	width: parent.width - 2 * Tokens.settings.about.padding[1]
	topPadding: Tokens.settings.about.padding[0]

	Column {
		width: parent.width
		topPadding: Tokens.settings.about.top
		bottomPadding: Tokens.settings.about.bottom

		Image {
			objectName: "logo"
			x: (parent.width - width) / 2
			width: Tokens.settings.about.logo
			height: width
			sourceSize: Qt.size(width * 2, height * 2)
			source: Qt.resolvedUrl("../assets/bloom.png")
			RotationAnimation on rotation {
				id: spin
				running: false
				from: 0
				to: 360
				duration: 700
				easing.type: Easing.BezierSpline
				easing.bezierCurve: [0.22, 1, 0.36, 1, 1, 1]
			}
			HoverHandler { onHoveredChanged: if (hovered) spin.restart() }
		}
		Item { width: 1; height: Tokens.settings.about.logoGap }
		Text {
			objectName: "aboutTitle"
			width: parent.width
			horizontalAlignment: Text.AlignHCenter
			text: "Bloom"
			color: root.theme.text
			font.family: Fonts.syne
			font.pixelSize: Tokens.settings.about.title
			font.weight: Font.ExtraBold
			font.letterSpacing: -0.035 * Tokens.settings.about.title
		}
		Item { width: 1; height: 12 }
		Rectangle {
			x: (parent.width - width) / 2
			width: versionText.implicitWidth + 18
			height: versionText.implicitHeight + 5
			radius: height / 2
			color: root.theme.groupBg
			Text {
				id: versionText
				objectName: "version"
				anchors.centerIn: parent
				text: "Version " + root.version
				color: root.theme.textMuted
				font.family: Fonts.familyFor(Font.DemiBold)
				font.pixelSize: Tokens.settings.about.version
				font.weight: Font.DemiBold
				font.letterSpacing: 0.08 * Tokens.settings.about.version
				font.capitalization: Font.AllUppercase
			}
		}
	}

	SGroupLabel { theme: root.theme; text: "Data"; above: 0 }
	SGroup {
		theme: root.theme
		SRow { objectName: "export"; theme: root.theme; icon: "file-down"; label: root.exportLabel; desc: "Save settings to a file"; action: true; onClicked: root.exportRequested() }
		SRow { objectName: "import"; theme: root.theme; icon: "upload"; label: root.importLabel; desc: "Load settings from a file"; action: true; divider: false; onClicked: root.importRequested() }
	}
}
