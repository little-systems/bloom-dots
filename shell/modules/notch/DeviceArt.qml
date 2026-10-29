import QtQuick

Item {
	id: root
	property string art: "device"
	property bool still: false
	width: 60; height: 60
	Image {
		anchors.fill: parent
		source: Qt.resolvedUrl("../../assets/device-art/" + root.art + ".svg")
		fillMode: Image.PreserveAspectFit
		asynchronous: true
	}
	NumberAnimation on scale { from: 0.86; to: 1; duration: 420; running: !root.still }
	NumberAnimation on opacity { from: 0; to: 1; duration: 420; running: !root.still }
}
