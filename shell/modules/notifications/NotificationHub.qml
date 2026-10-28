import QtQuick
import Quickshell
import qs.services

// The optional notification module: one service plus per-screen visual
// surfaces. History windows are created only while the panel is open.
Scope {
	id: root
	Notifications { id: service }

	function _surfaces(variants) {
		const result = [];
		if (variants) for (const loader of variants.instances) if (loader.item) result.push(loader.item.stateObject());
		return result;
	}
	function stateObject() {
		const result = service.stateObject();
		result.surfaces = _surfaces(cardVariants).concat(_surfaces(historyLoader.item));
		return result;
	}
	function openHistory() { return service.openHistory(); }
	function closeHistory() { return service.closeHistory(); }
	function markRead() { return service.markRead(); }
	function clear() { return service.clear(); }
	function dismiss(id) { return service.dismiss(id); }
	function invoke(id, identifier) { return service.invoke(id, identifier); }
	function invokeHistory(key, id, identifier) { return service.invokeHistory(key, id, identifier); }

	Variants {
		id: cardVariants
		model: Quickshell.screens
		delegate: Loader {
			required property var modelData
			Component.onCompleted: setSource(Qt.resolvedUrl("NotificationCards.qml"), { modelData: modelData, hub: service })
		}
	}
	LazyLoader {
		id: historyLoader
		active: service.historyOpen
		component: Variants {
			model: Quickshell.screens
			delegate: Loader {
				required property var modelData
				Component.onCompleted: setSource(Qt.resolvedUrl("NotificationHistoryWindow.qml"), { modelData: modelData, hub: service })
			}
		}
	}
}
