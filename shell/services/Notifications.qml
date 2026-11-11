import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import "../modules/notifications/notifications.js" as Logic

// The optional module creates this service once. It owns D-Bus and persistent
// state; the module owns only windows. Live actions never enter StateFile.
Scope {
	id: root
	property var history: []
	property var cards: []
	property var live: ({})
	property var timers: ({})
	property bool cardsHovered: false
	property bool historyOpen: false
	property string ownership: "checking"
	property string ownershipError: ""
	property int _ownershipChecks: 0
	readonly property int unread: Logic.unread(root.history)
	readonly property string session: String(Date.now())

	function stateObject() { return { history: history, cards: cards, unread: unread,
		dnd: Settings.values["bloom-notifications-dnd"], ownership: ownership, ownershipError: ownershipError }; }
	function openHistory() { root.historyOpen = true; return "ok"; }
	function closeHistory() { root.historyOpen = false; return "ok"; }
	function _save() { state.save({ entries: root.history }); }
	function _removeCard(id) { root.cards = root.cards.filter(c => c.id !== id); }
	function setCardsHovered(hovered) {
		if (root.cardsHovered === hovered) return;
		root.cardsHovered = hovered;
		for (const card of root.cards) {
			const timer = root.timers[card.id];
			if (timer) {
				if (hovered) timer.stop();
				else timer.restart();
			}
		}
	}
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
			root.cards = root.cards.map(c => c.id === id ? Object.assign({}, result.item, { image: Logic.safeImage(notification.image) }) : c);
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
	function liveFor(key, id) { return key === root.session + ":" + id ? root.live[id] : null; }
	function invokeHistory(key, id, identifier) {
		const action = Logic.actionForKey(root.live, root.session, key, id, identifier);
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
		for (const id of Object.keys(root.live)) root.dismiss(Number(id));
		root.cards = [];
		root.history = [];
		root._save();
		return "ok";
	}
	function remove(key, id) {
		const live = root.liveFor(key, id);
		if (live) root.dismiss(id);
		root.history = root.history.filter(item => item.key !== key);
		root._save();
		return "ok";
	}

	StateFile {
		id: state
		name: "notifications"
		defaultValue: ({ entries: [] })
		validate: v => v !== null && typeof v === "object" && !Array.isArray(v) && (v.entries === undefined || Array.isArray(v.entries)) ? v : undefined
		maxBytes: 1048576
		onLoadedChanged: if (loaded)
			root.history = Logic.restore(value, Settings.values["bloom-notifications-history-limit"])
		onExternallyChanged: root.history = Logic.restore(value, Settings.values["bloom-notifications-history-limit"])
	}
	Timer {
		id: ownerCheckDelay
		interval: 500
		running: state.loaded
		onTriggered: if (!ownerCheck.running) ownerCheck.running = true
	}
	Process {
		id: ownerCheck
		command: ["busctl", "--user", "status", "org.freedesktop.Notifications"]
		stdout: StdioCollector { id: ownerOutput }
		onExited: code => {
			root._ownershipChecks++;
			const match = /^PID=(\d+)/m.exec(ownerOutput.text);
			if (code !== 0 || !match) {
				if (root._ownershipChecks < 3) { ownerCheckDelay.restart(); return; }
				root.ownership = "unavailable";
				root.ownershipError = "Notification bus name is unavailable";
			} else if (Number(match[1]) !== Quickshell.processId) {
				root.ownership = "conflict";
				root.ownershipError = "Notification bus name belongs to PID " + match[1];
			} else {
				root.ownership = "owned";
				root.ownershipError = "";
			}
			if (root.ownershipError) console.warn("bloom notifications: " + root.ownershipError);
		}
	}

	Component {
		id: timeoutComponent
		Timer {
			property int notificationId: 0
			repeat: false
			onTriggered: root.expire(notificationId)
		}
	}

	LazyLoader {
		active: state.loaded
		component: NotificationServer {
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
			if (result.popup) root.cards = [Object.assign({}, result.item, { image: Logic.safeImage(notification.image) })].concat(root.cards).slice(0, 4);
			const duration = Logic.timeout(notification.expireTimeout, Settings.values["bloom-notifications-timeout"]);
			if (duration > 0) {
				const timer = timeoutComponent.createObject(root, { notificationId: id, interval: duration });
				root.timers = Object.assign({}, root.timers, { [id]: timer });
				if (!root.cardsHovered || !result.popup) timer.start();
			}
			notification.closed.connect(reason => root._closed(id, notification, reason));
			notification.summaryChanged.connect(() => root._updated(id, notification));
			notification.bodyChanged.connect(() => root._updated(id, notification));
			notification.appNameChanged.connect(() => root._updated(id, notification));
			notification.appIconChanged.connect(() => root._updated(id, notification));
			notification.desktopEntryChanged.connect(() => root._updated(id, notification));
			notification.urgencyChanged.connect(() => root._updated(id, notification));
		}
	}
	}
}
