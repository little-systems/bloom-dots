import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import qs.services
import "notifications.js" as Logic

// Exactly one server per shell, created only when the notifications module is on.
// QML notification/action objects live in `live`, never in StateFile.
Scope {
	id: root
	property var history: []
	property var cards: []
	property var live: ({})
	property var timers: ({})
	readonly property int unread: Logic.unread(root.history)
	readonly property string session: String(Date.now())

	function stateObject() {
		return { history: history, cards: cards, unread: unread, dnd: Settings.values["bloom-notifications-dnd"] };
	}
	function _save() { state.save({ entries: root.history }); }
	function _removeCard(id) { root.cards = root.cards.filter(c => c.id !== id); }
	function _stopTimer(id) {
		const timer = root.timers[id];
		if (timer) { timer.stop(); timer.destroy(); }
		const next = Object.assign({}, root.timers);
		delete next[id];
		root.timers = next;
	}
	function _closed(id, notification, reason) {
		if (root.live[id] !== notification) return;
		const name = reason === NotificationCloseReason.Expired ? "expired"
			: reason === NotificationCloseReason.Dismissed ? "dismissed" : "closeRequested";
		root.history = Logic.close(root.history, root.session + ":" + id, name);
		root._save();
		root._stopTimer(id);
		root._removeCard(id);
		const next = Object.assign({}, root.live);
		delete next[id];
		root.live = next;
	}
	function _updated(id, notification) {
		if (root.live[id] !== notification) return;
		const result = Logic.ingest(root.history, notification, Date.now(), root.session,
			Settings.values["bloom-notifications-dnd"], Settings.values["bloom-notifications-history-limit"]);
		if (!result.item) return;
		root.history = result.history;
		if (!notification.transient) root._save();
		if (root.cards.some(c => c.id === id))
			root.cards = root.cards.map(c => c.id === id ? result.item : c);
	}
	function expire(id) {
		const notification = root.live[id];
		root._stopTimer(id);
		root._removeCard(id);
		if (notification) notification.expire();
	}
	function dismiss(id) {
		const notification = root.live[id];
		root._stopTimer(id);
		root._removeCard(id);
		if (notification) notification.dismiss();
		return notification ? "ok" : "notification unavailable";
	}
	function invoke(id, identifier) {
		const action = Logic.action(root.live, id, identifier);
		if (!action) return "action unavailable";
		action.invoke();
		return "ok";
	}
	function markRead() {
		root.history = root.history.map(item => Object.assign({}, item, { read: true }));
		root._save();
		return "ok";
	}
	function clear() {
		root.history = [];
		root._save();
		return "ok";
	}

	StateFile {
		id: state
		name: "notifications"
		defaultValue: ({ entries: [] })
		onLoadedChanged: if (loaded && root.history.length === 0)
			root.history = Logic.restore(value, Settings.values["bloom-notifications-history-limit"])
	}

	Component {
		id: timeoutComponent
		Timer {
			property int notificationId: 0
			repeat: false
			onTriggered: root.expire(notificationId)
		}
	}

	NotificationServer {
		keepOnReload: false
		persistenceSupported: true
		bodySupported: true
		bodyMarkupSupported: false
		bodyHyperlinksSupported: false
		bodyImagesSupported: false
		actionsSupported: true
		imageSupported: true
		onNotification: notification => {
			notification.tracked = true;
			const id = notification.id;
			const result = Logic.ingest(root.history, notification, Date.now(), root.session,
				Settings.values["bloom-notifications-dnd"], Settings.values["bloom-notifications-history-limit"]);
			if (!result.item) { notification.dismiss(); return; }
			root._stopTimer(id);
			root.history = result.history;
			if (!notification.transient) root._save();
			root.live = Object.assign({}, root.live, { [id]: notification });
			root._removeCard(id);
			if (result.popup) root.cards = [result.item].concat(root.cards).slice(0, 4);
			const duration = Logic.timeout(notification.expireTimeout, Settings.values["bloom-notifications-timeout"]);
			if (duration > 0) {
				const timer = timeoutComponent.createObject(root, { notificationId: id, interval: duration });
				root.timers = Object.assign({}, root.timers, { [id]: timer });
				timer.start();
			}
			notification.closed.connect(reason => root._closed(id, notification, reason));
			notification.summaryChanged.connect(() => root._updated(id, notification));
			notification.bodyChanged.connect(() => root._updated(id, notification));
			notification.appNameChanged.connect(() => root._updated(id, notification));
			notification.urgencyChanged.connect(() => root._updated(id, notification));
		}
	}
}
