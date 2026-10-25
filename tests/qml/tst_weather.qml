import QtQuick
import QtTest
import "../../shell/services/weather.js" as Weather

TestCase {
	name: "Weather"

	function test_forecastUrl() {
		compare(Weather.forecastUrl(12.5, 80.25, "celsius"),
			"https://api.open-meteo.com/v1/forecast?latitude=12.5&longitude=80.25&current=temperature_2m,weather_code,is_day&timezone=auto");
		verify(Weather.forecastUrl(1, 2, "fahrenheit").endsWith("&temperature_unit=fahrenheit"));
	}

	function test_parseForecast() {
		compare(Weather.parseForecast({ current: { temperature_2m: 27.6, weather_code: 2, is_day: 1 } }),
			{ temperature: 28, condition: "Partly Cloudy", isDay: true });
		compare(Weather.parseForecast({ current: { temperature_2m: 10, weather_code: 42, is_day: 0 } }).condition, "Unknown");
	}

	// Review focus 3: Bloom's truthiness check dropped 0 °C as invalid.
	function test_parseForecastKeepsZero() {
		compare(Weather.parseForecast({ current: { temperature_2m: 0, weather_code: 0, is_day: 1 } }).temperature, 0);
	}

	function test_parseForecastRejectsBadShapes() {
		compare(Weather.parseForecast(null), null);
		compare(Weather.parseForecast({}), null);
		compare(Weather.parseForecast({ current: { temperature_2m: "warm" } }), null);
	}

	function test_geolocation() {
		compare(Weather.parseIpapi({ latitude: 13.08, longitude: 80.27, city: "Chennai" }), { lat: 13.08, lon: 80.27, city: "Chennai" });
		compare(Weather.parseIpapi({ error: true, reason: "RateLimited" }), null);
		compare(Weather.parseIpApi({ status: "success", lat: 13.08, lon: 80.27, city: "Chennai" }), { lat: 13.08, lon: 80.27, city: "Chennai" });
		compare(Weather.parseIpApi({ status: "fail" }), null);
		compare(Weather.parseIpapi({ latitude: 0, longitude: 0, city: "Null Island" }), { lat: 0, lon: 0, city: "Null Island" });
		compare(Weather.parseIpApi({ status: "success", lat: 0, lon: 0 }), { lat: 0, lon: 0, city: "" });
		compare(Weather.parseIpapi({ latitude: 91, longitude: 0 }), null);
		compare(Weather.parseIpApi({ status: "fail", lat: 10, lon: 20 }), null);
		compare(Weather.DEFAULT_LOCATION, { lat: 28.6139, lon: 77.209, city: "Delhi" });
	}

	// Bloom getWeatherIcon, with lucide-static names.
	function test_icon() {
		compare(Weather.icon("Clear", true), "sun");
		compare(Weather.icon("Mostly Clear", false), "moon");
		compare(Weather.icon("Overcast", true), "cloud");
		compare(Weather.icon("Foggy", true), "cloud-fog");
		compare(Weather.icon("Freezing Drizzle", true), "cloud-drizzle");
		compare(Weather.icon("Rain Showers", true), "cloud-rain");
		compare(Weather.icon("Snow Showers", true), "cloud-snow");
		compare(Weather.icon("Stormy", true), "cloud-lightning");
		compare(Weather.icon("Unknown", true), "thermometer");
	}

	function test_text() {
		compare(Weather.label(28, "celsius"), "28°C");
		compare(Weather.label(82, "fahrenheit"), "82°F");
		compare(Weather.tooltip("Partly Cloudy", "Chennai"), "Partly Cloudy — Chennai");
		compare(Weather.tooltip("Partly Cloudy", ""), "Partly Cloudy");
	}

	// Review focus 3: a failed fetch keeps the last reading.
	function test_failedFetchKeepsCache() {
		const last = { temperature: 28, condition: "Clear", isDay: true, city: "Chennai" };
		compare(Weather.afterFetch(last, null), last);
		compare(Weather.afterFetch(last, { temperature: 30, condition: "Overcast", isDay: false, city: "Chennai" }),
			{ temperature: 30, condition: "Overcast", isDay: false, city: "Chennai" });
	}
}
