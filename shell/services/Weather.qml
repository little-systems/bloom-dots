pragma Singleton

import QtQuick
import Quickshell
import "weather.js" as Logic

// Current weather for the notch (Bloom useWeather): Open-Meteo for the
// configured coordinates, else IP geolocation (ipapi.co, then ip-api.com),
// else Delhi. Refreshes every 30 minutes, but only while the weather widget
// is enabled and configured. The last reading is cached in state so the
// widget has a value before the first fetch and while offline.
Singleton {
	id: root

	readonly property var _widgets: Settings.values["bloom-status-widgets"]
	readonly property bool wanted: Settings.values["bloom-weather-enabled"]
		&& (root._widgets.left.indexOf("weather") >= 0 || root._widgets.right.indexOf("weather") >= 0)
	readonly property string unit: Settings.values["bloom-temp-unit"]

	property var temperature: null
	property string condition: ""
	property bool isDay: true
	property string city: ""

	readonly property bool shown: Settings.values["bloom-weather-enabled"] && root.temperature !== null
	readonly property string label: root.temperature === null ? "" : Logic.label(root.temperature, root.unit)
	readonly property string icon: Logic.icon(root.condition, root.isDay)
	readonly property string tooltip: Logic.tooltip(root.condition, root.city)

	property bool _busy: false
	property bool _pending: false

	function refresh() {
		if (root._busy) {
			root._pending = true;
			return;
		}
		root._busy = true;
		const requestedUnit = root.unit;
		root._locate(loc => root._get(Logic.forecastUrl(loc.lat, loc.lon, requestedUnit), json => {
			const r = Logic.parseForecast(json);
			if (r && !root._pending && requestedUnit === root.unit) {
				root._set({ temperature: r.temperature, condition: r.condition, isDay: r.isDay, city: loc.city });
				cache.save({ temperature: r.temperature, condition: r.condition, isDay: r.isDay, city: loc.city, unit: requestedUnit });
			} else if (!root._pending) {
				console.warn("bloom weather: update failed; keeping the last reading");
			}
			root._busy = false;
			if (root._pending && root.wanted) {
				root._pending = false;
				root.refresh();
			} else {
				root._pending = false;
			}
		}));
	}

	function _set(s) {
		root.temperature = s.temperature;
		root.condition = s.condition;
		root.isDay = s.isDay;
		root.city = s.city;
	}

	function _locate(done) {
		const lat = Settings.values["bloom-weather-lat"];
		const lon = Settings.values["bloom-weather-lon"];
		if (lat !== null && lon !== null) {
			done({ lat: lat, lon: lon, city: Settings.values["bloom-weather-city"] });
			return;
		}
		root._get("https://ipapi.co/json/", json => {
			const a = Logic.parseIpapi(json);
			if (a) {
				done(root._named(a));
				return;
			}
			// ip-api.com's free tier is HTTP-only (its https endpoint needs a paid key).
			root._get("http://ip-api.com/json/?fields=status,lat,lon,city,country", json2 => {
				const b = Logic.parseIpApi(json2);
				done(b ? root._named(b) : Logic.DEFAULT_LOCATION);
			});
		});
	}

	// A city typed in settings names the place even when the coordinates come
	// from IP geolocation.
	function _named(loc) {
		const city = Settings.values["bloom-weather-city"];
		return city ? { lat: loc.lat, lon: loc.lon, city: city } : loc;
	}

	function _get(url, done) {
		// Http ends stalled requests; QML's own XHR timeout never fires.
		Http.get(url, done, 10000);
	}

	StateFile {
		id: cache
		name: "weather"
		defaultValue: ({})
		onLoadedChanged: {
			const v = cache.value;
			if (cache.loaded && root.temperature === null && typeof v.temperature === "number" && v.unit === root.unit)
				root._set({ temperature: v.temperature, condition: v.condition || "", isDay: v.isDay !== false, city: v.city || "" });
		}
	}

	Timer {
		interval: 30 * 60 * 1000
		repeat: true
		triggeredOnStart: true
		running: root.wanted
		onTriggered: root.refresh()
	}

	onUnitChanged: if (root.wanted) root.refresh()

	Connections {
		target: Settings
		function onSettingChanged(key) {
			if (root.wanted && ["bloom-weather-lat", "bloom-weather-lon", "bloom-weather-city"].indexOf(key) >= 0)
				root.refresh();
		}
	}
}
