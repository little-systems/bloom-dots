import QtQuick
import "../common"
import "../common/render"
import "../common/tokens.js" as Tokens

// Bloom's AboutTab, without Software Updates: pacman owns those here.
Column {
	id: root
	property QtObject theme
	property string version: ""
	property var osInfo: ({})
	property string distroLogo: ""
	property string kernel: ""
	property string architecture: ""
	readonly property var systemRows: [
		{ label: "Distribution ID", value: root.osInfo.id || "", icon: "info" },
		{ label: "Edition", value: root.osInfo.variant || "", icon: "info" },
		{ label: "Architecture", value: root.architecture, icon: "cpu" },
		{ label: "Kernel", value: root.kernel, icon: "cpu" }
	].filter(row => row.value !== "")
	property string exportLabel: "Export Settings"
	property string importLabel: "Import Settings"
	signal exportRequested()
	signal importRequested()

	x: Tokens.settings.about.padding[1]
	width: parent.width - 2 * Tokens.settings.about.padding[1]
	topPadding: Tokens.settings.about.padding[0]

	Flow {
		id: identity
		width: parent.width
		topPadding: Tokens.settings.about.top
		bottomPadding: Tokens.settings.about.bottom
		spacing: 24
		readonly property bool paired: !!root.osInfo.name && width >= 600
		readonly property real columnWidth: paired ? (width - spacing) / 2 : width

		Column {
			width: identity.columnWidth

			Image {
				objectName: "logo"
				x: (parent.width - width) / 2
				width: Tokens.settings.about.logo
				height: width
				sourceSize: Qt.size(width * 2, height * 2)
				source: Qt.resolvedUrl("../assets/bloom.png")
			}
			Item { width: 1; height: Tokens.settings.about.logoGap }
			Text {
				objectName: "aboutTitle"
				width: parent.width
				horizontalAlignment: Text.AlignHCenter
				text: "Bloom"
				color: root.theme.text
				font.family: Fonts.syne
				font.pixelSize: Fonts.px(Tokens.settings.about.title)
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
					font.family: Fonts.uiFor(Font.DemiBold)
					font.pixelSize: Fonts.px(Tokens.settings.about.version)
					font.weight: Font.DemiBold
					font.letterSpacing: 0.08 * Tokens.settings.about.version
					font.capitalization: Font.AllUppercase
				}
			}
		}

		Column {
			objectName: "distributionIdentity"
			visible: !!root.osInfo.name
			width: identity.columnWidth
			Item {
				width: parent.width
				height: Tokens.settings.about.logo
				Image {
					objectName: "distributionLogo"
					anchors.centerIn: parent
					width: Tokens.settings.about.logo; height: width
					fillMode: Image.PreserveAspectFit
					sourceSize: Qt.size(width * 2, height * 2)
					source: root.distroLogo
					visible: source.toString() !== ""
					Accessible.name: root.osInfo.name + " logo"
				}
			}
			Item { width: 1; height: Tokens.settings.about.logoGap }
			Text {
				objectName: "systemValue:Distribution"
				width: parent.width; height: Fonts.px(Tokens.settings.about.title) * 1.2
				verticalAlignment: Text.AlignVCenter
				horizontalAlignment: Text.AlignHCenter
				text: root.osInfo.name || ""
				textFormat: Text.PlainText; elide: Text.ElideRight
				color: root.theme.text
				font.family: Fonts.uiFor(Font.DemiBold)
				font.pixelSize: Fonts.px(30)
				font.weight: Font.DemiBold
			}
			Item { width: 1; height: 12 }
			Rectangle {
				x: (parent.width - width) / 2
				width: release.implicitWidth + 18; height: release.implicitHeight + 5
				radius: height / 2; color: root.theme.groupBg
				visible: !!root.osInfo.release
				Text {
					id: release; objectName: "systemValue:Release"
					anchors.centerIn: parent
					text: root.osInfo.release || ""; textFormat: Text.PlainText
					color: root.theme.textMuted
					font.family: Fonts.uiFor(Font.DemiBold)
					font.pixelSize: Fonts.px(Tokens.settings.about.version)
					font.weight: Font.DemiBold
					font.capitalization: Font.AllUppercase
					font.letterSpacing: 0.08 * Tokens.settings.about.version
				}
			}
		}
	}

	SGroupLabel { theme: root.theme; text: "System"; above: 0; visible: root.systemRows.length > 0 }
	SGroup {
		theme: root.theme
		visible: root.systemRows.length > 0
		Repeater {
			model: root.systemRows
			delegate: SRow {
				required property var modelData
				required property int index
				objectName: "aboutSystem:" + modelData.label
				theme: root.theme
				icon: modelData.icon
				label: modelData.label
				divider: index < root.systemRows.length - 1
				Accessible.description: modelData.value
				Text {
					objectName: "systemValue:" + modelData.label
					text: modelData.value
					textFormat: Text.PlainText
					width: Math.min(implicitWidth, root.width * 0.55)
					elide: Text.ElideRight
					color: root.theme.textMuted
					font.family: Fonts.ui
					font.pixelSize: Fonts.px(14)
				}
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
