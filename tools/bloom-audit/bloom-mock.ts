// Audit-only: Tauri backend mocked so Bloom's UI runs in a browser.
import { mockIPC, mockWindows } from "@tauri-apps/api/mocks";
import { emit } from "@tauri-apps/api/event";

const label = new URLSearchParams(location.search).get("w") || "main";
mockWindows(label);
localStorage.setItem("bloom-first-run", "done");
localStorage.setItem("bloom-app-version", "3.10.1");
// No announcement card in the audit.
localStorage.setItem("bloom-announcement-cache", "null");
localStorage.setItem("bloom-announcement-cache-at", String(Date.now()));

const settings: Record<string, string> = {
	"bloom-notch-mode": "fixed",
	"bloom-dock-mode": "fixed",
	"bloom-notch-devices-enabled": "true",
	"bloom-notch-command-center-enabled": "true",
	"bloom-music-compact-notch": "true",
	...JSON.parse(localStorage.getItem("mock-settings") || "{}")
};

const bt = [
	{ id: "bt1", name: "AirPods Pro", kind: "audio", form: "earbuds", connected: true, battery: 72, can_connect: true },
	{ id: "bt2", name: "MX Master 3", kind: "mouse", form: null, connected: true, battery: 15, can_connect: true },
	{ id: "bt3", name: "Pixel 8", kind: "phone", form: null, connected: false, battery: null, can_connect: true }
];

const responses: Record<string, unknown> = {
	load_settings: settings,
	get_battery_details: { present: true, percent: 73, plugged_in: true, charging: true, seconds_left: null, seconds_to_full: 2340, health_percent: 95, power_mode: "Balanced" },
	get_wifi_status: { enabled: true, connected: true, ssid: "Dhanush's iPhone" },
	get_bluetooth_state: true,
	get_battery_saver_state: false,
	get_volume_state: { volume: 0.6, is_muted: false },
	get_brightness: 70,
	get_update_state: { available: false },
	get_cpu_usage: 23,
	get_ram_usage: 61,
	get_disk_space: 48,
	get_network_speed: [12000, 340000],
	bluetooth_list_devices: bt,
	usb_list_devices: [],
	jack_list_devices: [],
	wifi_list_networks: {
		location_denied: false,
		networks: [
			{ ssid: "Dhanush's iPhone", signal: 90, security: "wpa2", connected: true, saved: true },
			{ ssid: "JioFiber-3rd-floor", signal: 62, security: "wpa2", connected: false, saved: true },
			{ ssid: "Cafe Guest", signal: 40, security: "open", connected: false, saved: false },
			{ ssid: "Office-Enterprise", signal: 20, security: "wpa2-enterprise", connected: false, saved: false }
		]
	},
	"plugin:app|version": "3.10.1"
};

const ICONS: Record<string, string> = {}; // the audit fills these with data: URIs of /usr/share/icons PNGs (firefox, brave-desktop, apple-music, libreoffice-writer, kdenlive)
const app = (name: string, icon: string, running: boolean, hwnds: number) => ({
	name, path: `C:\\Apps\\${name}.exe`, icon: ICONS[icon], is_running: running,
	hwnd: running ? 100 + hwnds : undefined, executable: `${name}.exe`,
	all_hwnds: Array.from({ length: hwnds }, (_, i) => [100 + i, `${name} window ${i + 1}`])
});
responses.load_pinned_apps = [app("Firefox", "firefox", true, 2), app("Music", "apple-music", false, 0), app("Writer", "libreoffice-writer", false, 0)];
responses.get_active_windows = [app("Firefox", "firefox", true, 2), app("Brave", "brave-desktop", true, 1), app("Kdenlive", "kdenlive", true, 1)];
responses.get_tray_apps = [];
responses.get_custom_icons = {};
responses.get_dock_extras = [];
responses.get_installed_apps = [];
responses.get_audio_sessions = [
	{ pid: 1, name: "Firefox", process_path: "firefox", volume: 0.8, is_muted: false },
	{ pid: 2, name: "Music", process_path: "apple-music", volume: 0.5, is_muted: false }
];

mockIPC(
	(cmd, args) => {
		if (cmd in responses) return responses[cmd];
		if (cmd === "get_app_icon") {
			const a = (args as any) || {};
			const key = Object.keys(ICONS).find(k => String(a.path || a.name || "").toLowerCase().includes(k.split("-")[0].replace("apple", "music"))) ;
			return key ? ICONS[key] : null;
		}
		if (cmd === "plugin:window|is_visible") return true;
		if (cmd.startsWith("plugin:window|scale_factor")) return 1.25;
		return null;
	},
	{ shouldMockEvents: true }
);

(window as any).bloomMock = { emit, responses, settings };

// The owner's Windows display scale (125%) and a desktop-like backdrop.
const audit = document.createElement("style");
audit.textContent = `html { zoom: ${new URLSearchParams(location.search).get("zoom") || "1.25"}; } body { background: #3a3f4a !important; }`;
document.head.appendChild(audit);

// The overlay window would announce the splash end; do it at once.
for (let i = 1; i <= 8; i++) setTimeout(() => void emit("splash-done"), i * 500);
