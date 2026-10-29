import QtQuick

// A stand-in panel for tst_panelstage.
Rectangle {
	property bool pinned: true
	signal subpanelRequested(string name)
	color: "red"
}
