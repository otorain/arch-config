#!/usr/bin/env python3
# Shared helper for the waybar popups (weather.py, calendar.py): locate a
# waybar module's screen geometry so the popup can anchor under it.
#
# waybar exposes no module geometry of its own, but GTK3's atk-bridge
# publishes its widget tree on the AT-SPI bus; a module label is found by
# matching a needle in its text (e.g. today's date for the clock, "°C" for
# the weather). GetExtents' coord_type must be UNSIGNED — the signed variant
# is rejected with InvalidArgs.
#
# find_module_extents() returns [] on any failure (a11y stack down, waybar
# missing, needle not found); callers fall back to monitor-center placement.

from gi.repository import Gio, GLib

_TIMEOUT_MS = 2000


def find_module_extents(needle):
    """Geometry of every waybar module label whose text contains `needle`:
    one (x, y, w, h) per match (multi-monitor bars each have their own copy),
    in logical screen coordinates. [] when unavailable."""
    try:
        session = Gio.bus_get_sync(Gio.BusType.SESSION, None)
        addr = session.call_sync(
            "org.a11y.Bus", "/org/a11y/bus", "org.a11y.Bus", "GetAddress",
            None, None, Gio.DBusCallFlags.NONE, _TIMEOUT_MS, None).unpack()[0]
        acon = Gio.DBusConnection.new_for_address_sync(
            addr,
            Gio.DBusConnectionFlags.AUTHENTICATION_CLIENT
            | Gio.DBusConnectionFlags.MESSAGE_BUS_CONNECTION,
            None, None)
    except Exception:
        return []

    def call(dest, path, iface, method, args=None):
        return acon.call_sync(dest, path, iface, method, args, None,
                              Gio.DBusCallFlags.NONE, _TIMEOUT_MS, None).unpack()

    try:
        apps = call("org.a11y.atspi.Registry", "/org/a11y/atspi/accessible/root",
                    "org.a11y.atspi.Accessible", "GetChildren")[0]
    except Exception:
        return []
    waybar = None
    for bus, path in apps:
        try:
            name = call(bus, path, "org.freedesktop.DBus.Properties", "Get",
                        GLib.Variant("(ss)", ("org.a11y.atspi.Accessible", "Name")))[0]
        except Exception:
            continue
        if name == "waybar":
            waybar = bus
            break
    if waybar is None:
        return []

    found = []

    def walk(bus, path, depth):
        if depth > 15:
            return
        try:
            text = call(bus, path, "org.a11y.atspi.Text", "GetText",
                        GLib.Variant("(ii)", (0, -1)))[0]
        except Exception:
            text = ""
        if needle and needle in text:
            try:
                found.append(tuple(call(bus, path, "org.a11y.atspi.Component",
                                        "GetExtents", GLib.Variant("(u)", (0,)))[0]))
            except Exception:
                pass
            return
        try:
            children = call(bus, path, "org.a11y.atspi.Accessible", "GetChildren")[0]
        except Exception:
            return
        for child_bus, child_path in children:
            walk(child_bus, child_path, depth + 1)

    walk(waybar, "/org/a11y/atspi/accessible/root", 0)
    return found


def popup_margins(card_width, exts, geo, px, bar_height, side_gap):
    """(margin_start, margin_top) for a popup card hanging below the bar.

    exts: screen-coord (x, y, w, h) of the anchor module, one per bar
    instance; geo: (x, y, w, h) of the target monitor (or None); px: pointer
    x, last-resort anchor. Priority: module center on the clicked monitor >
    monitor center > pointer x; clamped to the monitor with side_gap."""
    ext = None
    if exts:
        for e in exts:
            if geo is None or geo[0] <= e[0] < geo[0] + geo[2]:
                ext = e
                break
        if ext is None:
            ext = exts[0]
    if ext is not None:
        mx = ext[0] + ext[2] // 2 - card_width // 2
        top = ext[1] + ext[3] - (geo[1] if geo is not None else 0)
    elif geo is not None:
        mx = geo[0] + (geo[2] - card_width) // 2
        top = bar_height
    else:
        mx = px - card_width // 2
        top = bar_height
    if geo is not None:
        mx = min(max(mx - geo[0], side_gap),
                 max(geo[2] - card_width - side_gap, side_gap))
    return mx, top
