pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.services

// Current conditions and a short forecast, from open-meteo.
//
// This is the only part of the shell that talks to the internet, so it is
// worth being plain about what leaves the machine:
//
//   · open-meteo.com receives a latitude and longitude every 15 minutes.
//   · If no coordinates are configured, ipapi.co is asked once what city this
//     IP is in, and the answer is cached forever after.
//
// Setting Config.weatherLatitude/Longitude skips the second one entirely, and
// Config.weather = false stops both: nothing is requested and no process runs.
Singleton {
	id: root

	readonly property bool enabled: Config.weather

	property real latitude: 0
	property real longitude: 0
	property string place: ""

	readonly property bool located: root.latitude !== 0 || root.longitude !== 0

	property bool valid: false
	property real temperature: 0
	property real feelsLike: 0
	property int code: -1

	property int humidity: 0
	property real wind: 0
	property int windDirection: 0
	property real precipitation: 0
	property bool daylight: true

	property string sunrise: ""
	property string sunset: ""
	property real uvMax: 0
	property int rainChance: 0

	// [{ day, min, max, code, rain, uv, sunrise, sunset }]
	property var forecast: []

	// The next twelve hours: [{ hour, temp, code, rain }]
	property var hourly: []

	// Compass point from the direction the wind is coming from.
	function bearing(degrees: int): string {
		const points = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"];
		return points[Math.round(degrees / 45) % 8];
	}

	// "2026-09-25T06:21" to "06:21".
	function clockOf(iso: string): string {
		const at = (iso ?? "").indexOf("T");
		return at === -1 ? "" : iso.slice(at + 1, at + 6);
	}

	property string error: ""

	// Set once a place has been chosen by hand. The IP lookup is a guess and
	// is often wrong about which town you are in, so once you have corrected
	// it, it is never asked again.
	property bool manual: false

	// Geocoding results while picking a place: [{ label, detail, lat, lon }]
	property var places: []
	property bool searching: false

	property string pendingQuery: ""

	// The Nerd Font weather set rather than the Font Awesome one: a sun drawn
	// at icon weight reads as a gear at any size worth putting in a bar.
	readonly property var conditions: ({
		0: ({ text: "Clear", icon: "\ue30d", night: "\ue32b" }),
		1: ({ text: "Mainly clear", icon: "\ue30d", night: "\ue32b" }),
		2: ({ text: "Partly cloudy", icon: "\ue302", night: "\ue379" }),
		3: ({ text: "Overcast", icon: "\ue312" }),
		45: ({ text: "Fog", icon: "\ue313" }),
		48: ({ text: "Rime fog", icon: "\ue313" }),
		51: ({ text: "Light drizzle", icon: "\ue318" }),
		53: ({ text: "Drizzle", icon: "\ue318" }),
		55: ({ text: "Heavy drizzle", icon: "\ue318" }),
		61: ({ text: "Light rain", icon: "\ue318" }),
		63: ({ text: "Rain", icon: "\ue318" }),
		65: ({ text: "Heavy rain", icon: "\ue318" }),
		66: ({ text: "Freezing rain", icon: "\ue318" }),
		67: ({ text: "Freezing rain", icon: "\ue318" }),
		71: ({ text: "Light snow", icon: "\ue31a" }),
		73: ({ text: "Snow", icon: "\ue31a" }),
		75: ({ text: "Heavy snow", icon: "\ue31a" }),
		77: ({ text: "Snow grains", icon: "\ue31a" }),
		80: ({ text: "Showers", icon: "\ue318" }),
		81: ({ text: "Showers", icon: "\ue318" }),
		82: ({ text: "Violent showers", icon: "\ue318" }),
		85: ({ text: "Snow showers", icon: "\ue31a" }),
		86: ({ text: "Snow showers", icon: "\ue31a" }),
		95: ({ text: "Thunderstorm", icon: "\ue31d" }),
		96: ({ text: "Thunderstorm", icon: "\ue31d" }),
		99: ({ text: "Thunderstorm", icon: "\ue31d" })
	})

	function describe(code: int): string {
		return root.conditions[code]?.text ?? "Unknown";
	}

	// `day` is optional: the hourly and daily rows have no business showing a
	// moon just because it happens to be night right now.
	function iconFor(code, day) {
		const entry = root.conditions[code];
		if (!entry) return "\ue312";
		if (day === false && entry.night) return entry.night;
		return entry.icon;
	}

	readonly property string icon: root.iconFor(root.code, root.daylight)
	readonly property string summary: root.describe(root.code)

	// Holds a request back until NetworkManager has a connection, for up to
	// 30s. The shell comes up before Wi-Fi does — at boot, and again on
	// resume — and a request sent into that gap fails, leaving the lock
	// screen showing "unavailable" for the first thing anyone sees.
	function whenOnline(command) {
		return ["sh", "-c", "nm-online -q -t 30; exec \"$@\"", "sh"].concat(command);
	}

	function refresh() {
		if (!root.enabled) return;

		if (!root.located) {
			// Only guess when nothing has been chosen by hand.
			if (!root.manual) locate();
			return;
		}

		fetch.command = root.whenOnline(["curl", "-sS", "--max-time", "12",
			"https://api.open-meteo.com/v1/forecast"
				+ "?latitude=" + root.latitude
				+ "&longitude=" + root.longitude
				+ "&current=temperature_2m,apparent_temperature,weather_code"
					+ ",relative_humidity_2m,wind_speed_10m,wind_direction_10m"
					+ ",precipitation,is_day"
				+ "&hourly=temperature_2m,weather_code,precipitation_probability"
				+ "&daily=weather_code,temperature_2m_max,temperature_2m_min"
					+ ",sunrise,sunset,precipitation_probability_max,uv_index_max"
				+ "&timezone=auto&forecast_days=5"]);
		fetch.running = true;
	}

	// ---- choosing a place by hand ----

	function search(query: string) {
		const term = (query ?? "").trim();
		if (term.length < 2) {
			root.places = [];
			root.pendingQuery = "";
			root.searching = false;
			return;
		}

		// One process, so a fast typist queues rather than losing results.
		if (geocoder.running) {
			root.pendingQuery = term;
			return;
		}

		root.searching = true;
		root.pendingQuery = "";
		geocoder.command = ["curl", "-sS", "--max-time", "10",
			"https://geocoding-api.open-meteo.com/v1/search"
				+ "?count=6&language=en&format=json&name=" + encodeURIComponent(term)];
		geocoder.running = true;
	}

	function usePlace(place) {
		if (!place) return;

		root.latitude = place.lat;
		root.longitude = place.lon;
		root.place = place.label;
		root.manual = true;
		root.places = [];
		root.valid = false;
		root.error = "";

		Persist.set("weatherLat", root.latitude);
		Persist.set("weatherLon", root.longitude);
		Persist.set("weatherPlace", root.place);
		Persist.set("weatherManual", true);

		root.refresh();
	}

	// Back to guessing from the IP address.
	function forgetPlace() {
		root.manual = false;
		root.latitude = 0;
		root.longitude = 0;
		root.place = "";
		root.valid = false;
		root.places = [];

		Persist.set("weatherManual", false);
		Persist.set("weatherLat", 0);
		Persist.set("weatherLon", 0);
		Persist.set("weatherPlace", "");

		root.locate();
	}

	Process {
		id: geocoder

		onExited: {
			root.searching = false;
			if (root.pendingQuery) root.search(root.pendingQuery);
		}

		stdout: StdioCollector {
			onStreamFinished: {
				try {
					const data = JSON.parse(text);
					const found = [];
					for (const hit of (data.results ?? [])) {
						// "Dehradun" / "Uttarakhand, India" — the second line
						// is what separates the six identically named towns.
						const where = [hit.admin1, hit.country]
							.filter(part => part && part.length > 0).join(", ");
						found.push({
							label: hit.name,
							detail: where,
							lat: hit.latitude,
							lon: hit.longitude
						});
					}
					root.places = found;
				} catch (err) {
					root.places = [];
				}
			}
		}
	}

	// Asked once, then remembered: the coordinates are cached so this does not
	// happen again on every login.
	function locate() {
		if (locator.running) return;
		locator.command = root.whenOnline(["curl", "-sS", "--max-time", "12", "https://ipapi.co/json"]);
		locator.running = true;
	}

	Process {
		id: locator

		stdout: StdioCollector {
			onStreamFinished: {
				try {
					const data = JSON.parse(text);
					if (!data.latitude || !data.longitude) throw new Error("no coordinates");

					root.latitude = data.latitude;
					root.longitude = data.longitude;
					root.place = data.city || "";

					Persist.set("weatherLat", root.latitude);
					Persist.set("weatherLon", root.longitude);
					Persist.set("weatherPlace", root.place);

					root.error = "";
					root.refresh();
				} catch (err) {
					root.error = "Could not work out where this is";
					root.retryLater();
				}
			}
		}
	}

	Process {
		id: fetch

		stdout: StdioCollector {
			onStreamFinished: {
				try {
					const data = JSON.parse(text);
					const now = data.current;
					if (!now) throw new Error("no current conditions");

					root.temperature = now.temperature_2m;
					root.feelsLike = now.apparent_temperature;
					root.code = now.weather_code;
					root.humidity = now.relative_humidity_2m ?? 0;
					root.wind = now.wind_speed_10m ?? 0;
					root.windDirection = now.wind_direction_10m ?? 0;
					root.precipitation = now.precipitation ?? 0;
					root.daylight = (now.is_day ?? 1) === 1;

					const days = [];
					const daily = data.daily ?? ({});
					const times = daily.time ?? [];
					for (let i = 0; i < times.length; i++) {
						days.push({
							day: times[i],
							code: daily.weather_code[i],
							max: daily.temperature_2m_max[i],
							min: daily.temperature_2m_min[i],
							rain: daily.precipitation_probability_max?.[i] ?? 0,
							uv: daily.uv_index_max?.[i] ?? 0,
							sunrise: daily.sunrise?.[i] ?? "",
							sunset: daily.sunset?.[i] ?? ""
						});
					}
					root.forecast = days;

					if (days.length > 0) {
						root.sunrise = root.clockOf(days[0].sunrise);
						root.sunset = root.clockOf(days[0].sunset);
						root.uvMax = days[0].uv;
						root.rainChance = days[0].rain;
					}

					// The hourly series starts at midnight, so the part of it
					// that has already happened is dropped rather than shown.
					const hours = [];
					const series = data.hourly ?? ({});
					const stamps = series.time ?? [];
					const nowIso = (data.current?.time ?? "");
					let from = 0;
					for (let i = 0; i < stamps.length; i++) {
						if (stamps[i] >= nowIso) { from = i; break; }
					}
					for (let i = from; i < Math.min(from + 12, stamps.length); i++) {
						hours.push({
							hour: root.clockOf(stamps[i]),
							temp: series.temperature_2m[i],
							code: series.weather_code[i],
							rain: series.precipitation_probability?.[i] ?? 0
						});
					}
					root.hourly = hours;

					root.valid = true;
					root.error = "";
					retry.interval = 30000;
					retry.stop();
				} catch (err) {
					// Old data is still worth showing: it is at most a few
					// retries out of date, and a warning icon over a reading
					// that is fine is what made the bar look broken.
					if (!root.valid) root.error = "Weather unavailable";
					root.retryLater();
				}
			}
		}
	}

	// A failed request is tried again soon rather than at the next 15-minute
	// tick. The shell starts before Wi-Fi is up, especially on an auto-login,
	// so the first request of every boot and every resume tends to fail.
	// Waits 30s, then twice as long each time, up to 5 minutes.
	function retryLater() {
		if (retry.running) return;
		retry.start();
	}

	Timer {
		id: retry
		interval: 30000
		onTriggered: {
			retry.interval = Math.min(retry.interval * 2, 5 * 60000);
			root.refresh();
		}
	}

	// A failed request should not leave the last reading looking current
	// forever, but neither should one dropped connection blank the bar.
	Timer {
		interval: 15 * 60000
		repeat: true
		running: root.enabled
		onTriggered: root.refresh()
	}

	Component.onCompleted: {
		if (!root.enabled) return;

		if (Config.weatherLatitude !== 0 || Config.weatherLongitude !== 0) {
			root.latitude = Config.weatherLatitude;
			root.longitude = Config.weatherLongitude;
		} else {
			root.manual = Persist.get("weatherManual", false);
			root.latitude = Persist.get("weatherLat", 0);
			root.longitude = Persist.get("weatherLon", 0);
			root.place = Persist.get("weatherPlace", "");
		}

		root.refresh();
	}
}
