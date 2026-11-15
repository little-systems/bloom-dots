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
	property string hostname: ""
	property string cpu: ""
	property string memory: ""
	// The one place for this machine's details (there is no separate Device page).
	readonly property var systemRows: [
		{ label: "Device Name", value: root.hostname, icon: "monitor" },
		{ label: "Processor", value: root.cpu, icon: "cpu" },
		{ label: "Memory", value: root.memory, icon: "memory-stick" },
		{ label: "Distribution ID", value: root.osInfo.id || "", icon: "info" },
		{ label: "Edition", value: root.osInfo.variant || "", icon: "info" },
		{ label: "Architecture", value: root.architecture, icon: "cpu" },
		{ label: "Kernel", value: root.kernel, icon: "cpu" }
	].filter(row => row.value !== "")
	property string exportLabel: "Export Settings"
	property string importLabel: "Import Settings"
	signal exportRequested()
	signal importRequested()
	signal linkRequested(url link)

	// Bloom .about-author: a GitHub pill that turns the accent colour on hover.
	component AuthorPill: Rectangle {
		id: pill
		required property string author
		required property url link
		readonly property color ink: pillHover.hovered ? (root.theme.accent ?? "#0a84ff") : root.theme.text
		anchors.verticalCenter: parent.verticalCenter
		width: pillContent.implicitWidth + 14
		height: pillContent.implicitHeight + 4
		radius: height / 2
		color: pillHover.hovered ? root.theme.border : root.theme.groupBg
		Behavior on color { ColorAnimation { duration: 150 } }
		Accessible.role: Accessible.Link
		Accessible.name: pill.author + " on GitHub"
		Row {
			id: pillContent
			anchors.centerIn: parent
			spacing: 4
			SvgIcon {
				anchors.verticalCenter: parent.verticalCenter
				name: "bloom-github"
				size: 12
				color: pill.ink
				opacity: pillHover.hovered ? 1 : 0.65
				Behavior on opacity { NumberAnimation { duration: 150 } }
			}
			Text {
				anchors.verticalCenter: parent.verticalCenter
				text: pill.author
				color: pill.ink
				font.family: Fonts.uiFor(Font.DemiBold)
				font.pixelSize: Fonts.px(Tokens.settings.about.credit)
				font.weight: Font.DemiBold
			}
		}
		HoverHandler { id: pillHover; cursorShape: Qt.PointingHandCursor }
		TapHandler { onTapped: root.linkRequested(pill.link) }
	}

	component CreditText: Text {
		anchors.verticalCenter: parent.verticalCenter
		color: root.theme.textMuted
		font.family: Fonts.ui
		font.pixelSize: Fonts.px(Tokens.settings.about.credit)
		font.letterSpacing: 0.01 * Tokens.settings.about.credit
	}

	x: Tokens.settings.about.padding[1]
	width: parent.width - 2 * Tokens.settings.about.padding[1]
	topPadding: Tokens.settings.about.padding[0]

	Flow {
		id: identity
		width: parent.width
		topPadding: Tokens.settings.about.top
		bottomPadding: 14
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

	// Bloom .about-credit: "Made with ❤️ by" and the authors' GitHub pills,
	// centred under both identities.
	Row {
		objectName: "credit"
		x: (parent.width - width) / 2
		height: dhanush.height
		spacing: 5
		CreditText { text: "Made with" }
		// Bloom's red ❤️ emoji: no colour emoji font is installed, so a red heart.
		CreditText { objectName: "creditHeart"; text: "\u2764\uFE0E"; color: Tokens.settings.about.heart }
		CreditText { text: "by" }
		AuthorPill { id: dhanush; objectName: "credit:dhanush"; author: "Dhanush"; link: "https://github.com/DhanushSantosh" }
		CreditText { text: "&" }
		AuthorPill { objectName: "credit:sehaz"; author: "Sehaz"; link: "https://github.com/SehajveerSingh2005" }
	}
	Item { width: 1; height: Tokens.settings.about.bottom }

	SGroupLabel { objectName: "systemLabel"; theme: root.theme; text: "System"; above: 0; visible: root.systemRows.length > 0
		readonly property real aboveGroup: Tokens.settings.group.label.top }
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

	SGroupLabel { objectName: "dataLabel"; theme: root.theme; text: "Data"; visible: true }
	SGroup {
		theme: root.theme
		SRow { objectName: "export"; theme: root.theme; icon: "file-down"; label: root.exportLabel; desc: "Save settings to a file"; action: true; onClicked: root.exportRequested() }
		SRow { objectName: "import"; theme: root.theme; icon: "upload"; label: root.importLabel; desc: "Load settings from a file"; action: true; divider: false; onClicked: root.importRequested() }
	}
}
