#!/usr/bin/env python3
# Waybar weather module — Amap (Gaode) live weather + GTK3 popup.
#
# Reads the API key from ~/.config/weather/amap-key (one line).
# The module shows one city; clicking toggles a popup below the bar listing
# all cities. Picking a city switches the default (SIGUSR2 reloads waybar so
# the new city shows immediately). The popup is a fullscreen transparent
# gtk-layer-shell surface: it closes on city pick, Escape, a click outside
# the card, or a second module click (pidfile toggle).
#
# Commands:
#   weather.py                  fetch weather, cache it, print the waybar JSON
#   weather.py --switch <city>  set the default city and reload waybar
#   weather.py --popup          show the city list popup below the bar

import json
import os
import subprocess
import sys
import time
import urllib.request

import gi

gi.require_version("Gtk", "3.0")
gi.require_version("Gdk", "3.0")
from gi.repository import Gdk, GLib, Gtk  # noqa: E402

try:
    gi.require_version("GtkLayerShell", "0.1")
    from gi.repository import GtkLayerShell  # noqa: E402
except (ValueError, ImportError):  # gtk-layer-shell not installed
    GtkLayerShell = None

CACHE_DIR = os.path.expanduser(os.environ.get("XDG_CACHE_HOME") or "~/.cache") + "/weather"
KEY_FILE = os.path.expanduser(os.environ.get("XDG_CONFIG_HOME") or "~/.config") + "/weather/amap-key"
STATE_FILE = os.path.join(CACHE_DIR, "default")
DATA_FILE = os.path.join(CACHE_DIR, "data.json")
PID_FILE = os.path.join(CACHE_DIR, "popup.pid")

DEFAULT_CITY = "baoan"

# city: adcode, fallback adcode (empty = none), display label
CITIES = [
    {"id": "baoan", "adcode": "440306", "fallback": "440300", "name": "深圳宝安"},
    {"id": "guangzhou", "adcode": "440100", "fallback": "", "name": "广东广州"},
    {"id": "shanwei", "adcode": "441500", "fallback": "", "name": "广东汕尾"},
]

# md-weather_* NerdFont icons (verified present in CaskaydiaCove NF);
# matched in order, most specific first
ICONS = [
    ("雷阵雨", "\U000f067e"),  # md-weather_lightning_rainy
    ("雨夹雪", "\U000f067f"),  # md-weather_snowy_rainy
    ("冰雹", "\U000f0592"),    # md-weather_hail
    ("雷", "\U000f0593"),      # md-weather_lightning
    ("暴雪", "\U000f0f36"),    # md-weather_snowy_heavy
    ("大雪", "\U000f0f36"),
    ("雪", "\U000f0598"),      # md-weather_snowy
    ("暴雨", "\U000f0596"),    # md-weather_pouring
    ("大雨", "\U000f0596"),
    ("中雨", "\U000f0596"),
    ("小雨", "\U000f0597"),    # md-weather_rainy
    ("阵雨", "\U000f0597"),
    ("雨", "\U000f0597"),
    ("霾", "\U000f0f30"),      # md-weather_hazy
    ("浮尘", "\U000f0f30"),
    ("扬沙", "\U000f0f30"),
    ("沙尘暴", "\U000f0f30"),
    ("雾", "\U000f0591"),      # md-weather_fog
    ("多云", "\U000f0595"),    # md-weather_partly_cloudy
    ("少云", "\U000f0595"),
    ("阴", "\U000f0590"),      # md-weather_cloudy
    ("云", "\U000f0590"),
    ("晴", "\U000f0599"),      # md-weather_sunny
]
DEFAULT_ICON = "\U000f0590"  # md-weather_cloudy

# CSS class so style.css can colour the module by condition
CLASSES = [
    ("雷", "stormy"),
    ("雨", "rainy"),
    ("冰雹", "rainy"),
    ("雪", "snowy"),
    ("雾", "foggy"),
    ("霾", "foggy"),
    ("浮尘", "foggy"),
    ("扬沙", "foggy"),
    ("沙尘暴", "foggy"),
    ("晴", "sunny"),
]

# popup styling — catppuccin mocha, matching the bar. The window is a
# fullscreen transparent layer-shell surface (the outside-click catcher);
# the visible popup is #weather-content, a dropdown card hanging flush below
# the bar (square top corners, rounded bottom corners).
BAR_HEIGHT = 36  # matches waybar "height"; the card hangs flush below the bar
MIN_WIDTH = 240
SIDE_GAP = 6     # minimum distance to the screen's left/right edge
CSS = b"""
window#weather-popup {
  background-color: transparent;
}
#weather-content {
  background-color: #1e1e2e;
  color: #cdd6f4;
  border-radius: 0 0 8px 8px;
  padding: 5px;
}
#weather-content button.city-row {
  border: none;
  outline-style: none;
  box-shadow: none;
  text-shadow: none;
  -gtk-icon-shadow: none;
  background: transparent;
  border-radius: 6px;
  min-width: 0;
  min-height: 0;
  padding: 6px 12px;
}
#weather-content button.city-row:hover {
  background-color: #313244;
}
.city-name {
  color: #cdd6f4;
  font-size: 15px;
}
.active .city-name {
  color: #89b4fa;
}
.city-wx {
  color: #a6adc8;
  font-size: 14px;
}
.active .city-wx {
  color: #89b4fa;
}
"""


def icon_for(weather):
    for key, icon in ICONS:
        if key in weather:
            return icon
    return DEFAULT_ICON


def class_for(weather):
    for key, cls in CLASSES:
        if key in weather:
            return cls
    return ""


def fetch_city(adcode, api_key):
    """Return (weather, temp, reporttime) or None.
    Amap's free tier enforces a tight QPS limit (error 10021), so space
    requests 1s apart and retry once on failure."""
    url = (f"https://restapi.amap.com/v3/weather/weatherInfo"
           f"?key={api_key}&city={adcode}&extensions=base")
    for attempt in range(2):
        time.sleep(1)
        data = None
        try:
            with urllib.request.urlopen(url, timeout=8) as resp:
                data = json.load(resp)
        except Exception:
            data = None
        if data:
            try:
                if data.get("status") == "1" and data.get("lives"):
                    live = data["lives"][0]
                    return (live.get("weather"), live.get("temperature"), live.get("reporttime"))
            except (AttributeError, IndexError, TypeError):
                pass
        if attempt == 0:
            time.sleep(2)
    return None


def read_key():
    try:
        with open(KEY_FILE, encoding="utf-8") as f:
            return f.read().strip()
    except OSError:
        return ""


def read_default_city():
    try:
        with open(STATE_FILE, encoding="utf-8") as f:
            city = f.read().strip()
        if any(c["id"] == city for c in CITIES):
            return city
    except OSError:
        pass
    return DEFAULT_CITY


def switch_city(city):
    with open(STATE_FILE, "w", encoding="utf-8") as f:
        f.write(city + "\n")
    subprocess.run(["pkill", "-SIGUSR2", "waybar"],
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def fetch_all(api_key):
    """Fetch every city once, write data.json for the popup, return results."""
    results = {}
    for c in CITIES:
        data = fetch_city(c["adcode"], api_key)
        if data is None and c["fallback"]:
            data = fetch_city(c["fallback"], api_key)
        results[c["id"]] = data

    cities_json = []
    for c in CITIES:
        data = results[c["id"]]
        if data:
            weather, temp, rt = data
            cities_json.append({"id": c["id"], "name": c["name"], "weather": weather,
                                "temp": temp, "icon": icon_for(weather), "reporttime": rt})
        else:
            cities_json.append({"id": c["id"], "name": c["name"]})
    with open(DATA_FILE, "w", encoding="utf-8") as f:
        json.dump({"default": read_default_city(), "cities": cities_json}, f, ensure_ascii=False)
    return results


def print_payload(results):
    def_city = read_default_city()
    data = results.get(def_city)
    if data is None:
        print(json.dumps({"text": "\U000f0450 获取失败", "class": "unknown"}, ensure_ascii=False))
        return
    weather, temp, _ = data
    payload = {"text": f"{icon_for(weather)} {temp}\u00b0C"}
    cls = class_for(weather)
    if cls:
        payload["class"] = cls
    print(json.dumps(payload, ensure_ascii=False))


# ---------- popup (Gtk.Window) ----------

def run(*args, wait=False):
    try:
        if wait:
            return subprocess.run(args, capture_output=True, text=True, timeout=40)
        subprocess.Popen(args, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except Exception:
        return None
    return None


def read_cache():
    try:
        with open(DATA_FILE, encoding="utf-8") as f:
            data = json.load(f)
        if data.get("cities"):
            return data
    except Exception:
        pass
    return None


def ensure_data():
    data = read_cache()
    fresh = data is not None
    if fresh:
        try:
            fresh = time.time() - os.path.getmtime(DATA_FILE) < 15 * 60
        except OSError:
            fresh = False
    if fresh:
        return data
    api_key = read_key()
    if api_key:
        fetch_all(api_key)
    return read_cache()


def build_window(data, mon, px):
    # The popup is a fullscreen, transparent layer-shell surface; the visible
    # card (#weather-content) hangs flush below the bar, centered on the click
    # point. The click always lands on the weather module, so centering there
    # anchors the dropdown to the module as closely as possible — waybar
    # exposes no module geometry. Any click outside the card is caught by the
    # surface itself and dismisses the popup (see on_click_outside). Plain
    # toplevels cannot do "click outside to close" on Wayland — they never
    # see clicks on other surfaces.
    win = Gtk.Window(title="weather-popup")
    win.set_name("weather-popup")

    GtkLayerShell.init_for_window(win)
    GtkLayerShell.set_layer(win, GtkLayerShell.Layer.TOP)
    GtkLayerShell.set_namespace(win, "weather-popup")
    GtkLayerShell.set_keyboard_mode(win, GtkLayerShell.KeyboardMode.EXCLUSIVE)
    GtkLayerShell.set_exclusive_zone(win, -1)  # overlay, never shifts the bar
    for edge in (GtkLayerShell.Edge.TOP, GtkLayerShell.Edge.BOTTOM,
                 GtkLayerShell.Edge.LEFT, GtkLayerShell.Edge.RIGHT):
        GtkLayerShell.set_anchor(win, edge, True)
    if mon is not None:
        GtkLayerShell.set_monitor(win, mon)

    # RGBA visual keeps the fullscreen background actually transparent.
    screen = Gdk.Screen.get_default()
    visual = screen.get_rgba_visual()
    if visual is not None:
        win.set_visual(visual)

    provider = Gtk.CssProvider()
    provider.load_from_data(CSS)
    Gtk.StyleContext.add_provider_for_screen(
        screen, provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)

    card = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
    card.set_name("weather-content")
    default_city = data.get("default", "baoan") if data else ""
    cities = data.get("cities", []) if data else []

    if not cities:
        btn = Gtk.Button(label="天气获取失败（网络或 key 问题）")
        btn.get_style_context().add_class("city-row")
        btn.connect("clicked", lambda *a: Gtk.main_quit())
        card.pack_start(btn, False, False, 0)
    else:
        for city in cities:
            cid = city.get("id", "")
            btn = Gtk.Button()
            btn.get_style_context().add_class("city-row")
            if cid == default_city:
                btn.get_style_context().add_class("active")
            h = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
            icon_lbl = Gtk.Label(label=city.get("icon", ""))
            icon_lbl.get_style_context().add_class("city-name")
            name = Gtk.Label(label=city.get("name", cid))
            name.get_style_context().add_class("city-name")
            wx = Gtk.Label(xalign=1)
            wx.get_style_context().add_class("city-wx")
            weather = city.get("weather")
            temp = city.get("temp")
            wx.set_text(f"{weather} {temp}\u00b0C" if weather and temp else "获取失败")
            h.pack_start(icon_lbl, False, False, 0)
            h.pack_start(name, True, True, 0)
            h.pack_start(wx, False, False, 0)
            btn.add(h)
            btn.connect("clicked", lambda *a, c=cid: (switch_city(c), Gtk.main_quit()))
            card.pack_start(btn, False, False, 0)

    # Dropdown placement: flush under the bar, horizontally centered on the
    # click point, clamped to the monitor edges.
    card.set_size_request(MIN_WIDTH, -1)
    card.set_halign(Gtk.Align.START)
    card.set_valign(Gtk.Align.START)
    card.set_margin_top(BAR_HEIGHT)
    width = max(card.get_preferred_width().natural_width, MIN_WIDTH)
    mx = px - width // 2
    if mon is not None:
        geo = mon.get_geometry()
        mx = min(max(mx - geo.x, SIDE_GAP), max(geo.width - width - SIDE_GAP, SIDE_GAP))
    card.set_margin_start(mx)

    win.add(card)
    return win, card


def dismiss(*_):
    Gtk.main_quit()
    return False


def on_click_outside(win, event, card):
    # The surface fills the whole output, so every click reaches us; dismiss
    # only when it lands outside the card (clicks inside go to the row
    # buttons or harmlessly hit padding).
    a = card.get_allocation()
    if a.x <= event.x < a.x + a.width and a.y <= event.y < a.y + a.height:
        return False
    dismiss()
    return True


def on_key(win, event):
    if event.keyval == Gdk.KEY_Escape:
        return dismiss()
    return False


def run_popup():
    GLib.set_prgname("weather-popup")
    Gdk.set_program_class("weather-popup")
    os.makedirs(CACHE_DIR, exist_ok=True)
    if GtkLayerShell is None:
        print("weather.py --popup requires gtk-layer-shell", file=sys.stderr)
        return

    # Toggle: a second click on the module closes an already-open popup.
    try:
        with open(PID_FILE, encoding="utf-8") as f:
            pid = int(f.read().strip())
        if pid > 0:
            os.kill(pid, 0)  # raises OSError if the process is gone
            run("kill", str(pid))
            return
    except (OSError, ValueError):
        pass

    data = ensure_data()

    # Dropdown hangs below the bar, centered on the pointer's x, on the
    # pointer's monitor.
    px = py = 0
    try:
        cursor = json.loads(subprocess.check_output(["hyprctl", "-j", "cursorpos"]).decode())
        px = int(cursor.get("x", 0))
        py = int(cursor.get("y", 0))
    except Exception:
        pass
    display = Gdk.Display.get_default()
    mon = None
    if display is not None:
        mon = display.get_monitor_at_point(px, py) or display.get_primary_monitor()

    win, card = build_window(data, mon, px)
    win.show_all()

    try:
        with open(PID_FILE, "w", encoding="utf-8") as f:
            f.write(str(os.getpid()) + "\n")
    except OSError:
        pass

    # Clicking outside the card or Escape dismisses the popup; moving the
    # mouse away does nothing (no focus-out handler).
    win.add_events(Gdk.EventMask.BUTTON_PRESS_MASK)
    win.connect("button-press-event", on_click_outside, card)
    win.connect("key-press-event", on_key)
    Gtk.main()

    try:
        os.remove(PID_FILE)
    except OSError:
        pass


def main():
    if len(sys.argv) > 1:
        if sys.argv[1] == "--switch":
            city = sys.argv[2] if len(sys.argv) > 2 else ""
            if any(c["id"] == city for c in CITIES):
                switch_city(city)
            return
        if sys.argv[1] == "--popup":
            run_popup()
            return

    api_key = read_key()
    if not api_key:
        print(json.dumps({"text": "未配置", "class": "unknown"}, ensure_ascii=False))
        return
    print_payload(fetch_all(api_key))


if __name__ == "__main__":
    main()
