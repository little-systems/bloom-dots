// Weather parsing and text, ported from Bloom hooks/useWeather.ts. Plain JS
// (shared with tests).

// WMO weather interpretation codes (https://open-meteo.com/en/docs).
var WMO = {
	0: "Clear", 1: "Mostly Clear", 2: "Partly Cloudy", 3: "Overcast",
	45: "Foggy", 48: "Foggy",
	51: "Drizzle", 53: "Drizzle", 55: "Drizzle", 56: "Freezing Drizzle", 57: "Freezing Drizzle",
	61: "Rainy", 63: "Rainy", 65: "Rainy", 66: "Freezing Rain", 67: "Freezing Rain",
	71: "Snowy", 73: "Snowy", 75: "Snowy", 77: "Snowy",
	80: "Rain Showers", 81: "Rain Showers", 82: "Rain Showers", 85: "Snow Showers", 86: "Snow Showers",
	95: "Stormy", 96: "Stormy", 99: "Stormy"
};

// Bloom's last-resort location.
var DEFAULT_LOCATION = { lat: 28.6139, lon: 77.209, city: "Delhi" };

function forecastUrl(lat, lon, unit) {
	const unitParam = unit === "fahrenheit" ? "&temperature_unit=fahrenheit" : "";
	return `https://api.open-meteo.com/v1/forecast?latitude=${lat}&longitude=${lon}&current=temperature_2m,weather_code,is_day&timezone=auto${unitParam}`;
}

// Bloom tested `!temperature_2m`, which rejected 0 °C; a type check keeps it.
function parseForecast(json) {
	const c = json && json.current;
	if (!c || typeof c.temperature_2m !== "number")
		return null;
	return { temperature: Math.round(c.temperature_2m), condition: WMO[c.weather_code] || "Unknown", isDay: c.is_day === 1 };
}

function parseIpapi(json) {
	const lat = json?.latitude ?? json?.lat;
	const lon = json?.longitude ?? json?.lon;
	return _validCoordinates(lat, lon) ? { lat: lat, lon: lon, city: json.city || "" } : null;
}

function parseIpApi(json) {
	return json?.status === "success" && _validCoordinates(json.lat, json.lon)
		? { lat: json.lat, lon: json.lon, city: json.city || "" } : null;
}

function _validCoordinates(lat, lon) {
	return typeof lat === "number" && isFinite(lat) && lat >= -90 && lat <= 90
		&& typeof lon === "number" && isFinite(lon) && lon >= -180 && lon <= 180;
}

function icon(condition, isDay) {
	switch (condition) {
	case "Clear":
	case "Mostly Clear":
		return isDay ? "sun" : "moon";
	case "Partly Cloudy":
	case "Overcast":
		return "cloud";
	case "Foggy":
		return "cloud-fog";
	case "Drizzle":
	case "Freezing Drizzle":
		return "cloud-drizzle";
	case "Rainy":
	case "Rain Showers":
	case "Freezing Rain":
		return "cloud-rain";
	case "Snowy":
	case "Snow Showers":
		return "cloud-snow";
	case "Stormy":
		return "cloud-lightning";
	}
	return "thermometer";
}

function label(temperature, unit) {
	return `${temperature}°${unit === "fahrenheit" ? "F" : "C"}`;
}

function tooltip(condition, city) {
	return city ? `${condition} — ${city}` : condition;
}

// A failed fetch (null) keeps the last reading.
function afterFetch(state, result) {
	return result ? result : state;
}
