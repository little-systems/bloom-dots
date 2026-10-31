import QtQuick
import "../../../common/tokens.js" as Tokens

// .qp-list: a panel's scrolling rows, with Bloom's 4 px scrollbar once they
// overflow. `items` may be replaced with a fresh array at any time (BlueZ and
// NetworkManager refresh several times a second): rows are kept by key, so a
// refresh keeps them and the scroll position. A delegate takes
// `required property string key` and reads its data with entry(key).
Item {
	id: root

	property QtObject theme: QpTheme {}
	property var items: []
	// The property of an item that identifies it.
	property string keyName: "path"
	property alias delegate: view.delegate
	readonly property alias scrollY: view.contentY
	readonly property bool overflowing: view.contentHeight > view.height + 0.5
	// The width a row takes.
	readonly property real rowWidth: root.width - Tokens.qp.list.rightPad - (root.overflowing ? Tokens.qp.list.scrollbar : 0)

	property var _known: ({})
	function entry(key) { return root._known[key]; }

	ListModel { id: rows }
	function _sync() {
		const fresh = root.items || [];
		const known = Object.assign({}, root._known);
		for (const item of fresh) known[item[root.keyName]] = item;
		root._known = known;
		const keys = fresh.map(item => item[root.keyName]);
		for (let j = rows.count - 1; j >= 0; j--)
			if (!keys.includes(rows.get(j).key)) rows.remove(j);
		fresh.forEach((item, i) => {
			const key = item[root.keyName];
			let at = -1;
			for (let j = i; j < rows.count; j++) if (rows.get(j).key === key) { at = j; break; }
			if (at < 0) rows.insert(i, { key: key });
			else if (at !== i) rows.move(at, i, 1);
		});
		const kept = {};
		for (const item of fresh) kept[item[root.keyName]] = item;
		root._known = kept;
	}
	onItemsChanged: root._sync()
	Component.onCompleted: root._sync()

	ListView {
		id: view
		objectName: "view"
		anchors.fill: parent
		clip: true
		spacing: Tokens.qp.list.gap
		boundsBehavior: Flickable.StopAtBounds
		interactive: false // QpScroll scrolls it
		model: rows
	}

	QpScroll { flickable: view }

	Rectangle {
		objectName: "scrollbar"
		visible: root.overflowing
		anchors.right: parent.right
		y: view.visibleArea.yPosition * root.height
		width: Tokens.qp.list.scrollbar
		height: view.visibleArea.heightRatio * root.height
		radius: 2
		color: root.theme.scrollbarThumb
	}
}
