import QtQuick
import QtQuick.Effects
import "../../common"
import "../../common/tokens.js" as Tokens
import "../../common/render"

// Bloom's panel AnimatePresence: each panel arrives with its opacity on a
// 400/30 spring; the one it replaces fades and blurs out (0 → 4 px) over
// 0.1 s at the same time, then goes. Like Bloom's, a panel fills the notch
// and clips to it, leaving or not.
Item {
	id: root

	// The panel showing now, or null, and its Loader status.
	readonly property Item item: root._current?.content ?? null
	readonly property int status: root._current?.status ?? Loader.Null
	// A panel is still fading out.
	readonly property bool leaving: root._leavingCount > 0

	property Item _current: null
	property int _leavingCount: 0

	// Shows the panel at `source` (a QML file; "" for none), inset `inset` px
	// on each side.
	function show(source, inset) {
		const url = source ? String(source) : "";
		if (root._current && root._current.source === url)
			return;
		if (root._current) {
			root._leavingCount++;
			root._current.leave();
		}
		root._current = url ? slotComponent.createObject(root, { source: url, inset: inset }) : null;
	}

	Component {
		id: slotComponent

		Item {
			id: slot

			property string source
			property real inset: 0
			property bool leaving: false
			property real blur: 0
			readonly property Item content: loader.item
			readonly property int status: loader.status

			objectName: "panelSlot"
			x: slot.inset
			width: root.width - slot.inset * 2
			height: root.height
			opacity: enter.value
			// overflow: hidden, as each of Bloom's panels.
			clip: true

			function leave() {
				// Keep the current opacity and fade from there.
				slot.opacity = enter.value;
				slot.leaving = true;
				exit.start();
			}

			Spring {
				id: enter
				stiffness: 400
				damping: 30
				initial: 0
				target: 1
				autoRun: !slot.leaving
			}

			Loader {
				id: loader
				anchors.fill: parent
				source: slot.source
			}

			layer.enabled: slot.leaving
			layer.textureSize: Render.texture(width, height)
			layer.effect: MultiEffect {
				blurEnabled: true
				blurMax: 8
				blur: slot.blur / 8
			}

			ParallelAnimation {
				id: exit

				readonly property var curve: Tokens.easing.framerEaseOut.concat([1, 1])

				NumberAnimation { target: slot; property: "opacity"; to: 0; duration: 100; easing.type: Easing.BezierSpline; easing.bezierCurve: exit.curve }
				NumberAnimation { target: slot; property: "blur"; from: 0; to: 4; duration: 100; easing.type: Easing.BezierSpline; easing.bezierCurve: exit.curve }

				onFinished: {
					root._leavingCount--;
					slot.destroy();
				}
			}
		}
	}
}
