#!/usr/bin/env python3
# Waybar calendar module — Chinese lunar calendar popup (GTK4, layer-shell).
#
# Clicking the waybar clock toggles a month calendar below the bar: Sunday-first
# grid, lunar date under each day, festivals/solar terms, and official CN
# holiday badges (休/班). Month navigation via ‹ › buttons, arrow keys, or
# scroll; clicking a day copies its ISO date. The popup is a fullscreen
# transparent gtk4-layer-shell surface: it closes on Escape, a click outside
# the card, or a second clock click (pidfile toggle).
#
# Lunar data (1900-2099) and solar-term dates are embedded tables validated
# against lunar-python; festivals are computed offline. Only the official
# holiday arrangement (休/班) comes from the network (holiday-cn), cached
# under ~/.cache/calendar — without it the badges are silently omitted.
#
# Commands:
#   calendar.py            show the popup (same as --popup)
#   calendar.py --popup    show the calendar popup below the bar

import base64
import json
import os
import subprocess
import sys
import time
import urllib.request
from datetime import date, timedelta

# gtk4-layer-shell must be loaded before libwayland-client (pulled in by
# libgtk-4); PyGObject's dlopen order can't guarantee that, and a late-loaded
# lib silently degrades the popup to a plain tiled toplevel ("Failed to
# initialize layer surface"). Re-exec once with LD_PRELOAD so the layer-shell
# lib loads first. https://github.com/wmww/gtk4-layer-shell/blob/main/linking.md
_LS_LIB = "/usr/lib/libgtk4-layer-shell.so"
if __name__ == "__main__" and os.path.exists(_LS_LIB) \
        and "libgtk4-layer-shell" not in os.environ.get("LD_PRELOAD", ""):
    os.environ["LD_PRELOAD"] = ":".join(
        filter(None, [_LS_LIB, os.environ.get("LD_PRELOAD", "")]))
    os.execv(sys.executable, [sys.executable, os.path.abspath(__file__), *sys.argv[1:]])

try:
    import gi

    gi.require_version("Gtk", "4.0")
    gi.require_version("Gdk", "4.0")
    from gi.repository import Gdk, GLib, Gtk
except (ValueError, ImportError):  # headless logic-only use (tests)
    Gtk = Gdk = GLib = None

if Gtk is not None:
    try:
        gi.require_version("Gtk4LayerShell", "1.0")
        from gi.repository import Gtk4LayerShell
    except (ValueError, ImportError):  # gtk4-layer-shell not installed
        Gtk4LayerShell = None
else:
    Gtk4LayerShell = None

CACHE_DIR = os.path.expanduser(os.environ.get("XDG_CACHE_HOME") or "~/.cache") + "/calendar"
PID_FILE = os.path.join(CACHE_DIR, "popup.pid")

HOLIDAY_URLS = (
    "https://cdn.jsdelivr.net/gh/NateScarlet/holiday-cn@master/{}.json",
    "https://raw.githubusercontent.com/NateScarlet/holiday-cn/master/{}.json",
)

# ---------- lunar calendar (1900-2099) ----------
# Per year: bits 0-3 leap month number (0 = none), bit 16 set if the leap
# month has 30 days, bits 4-15 set if months 12..1 have 30 days.
LUNAR_INFO = [
    0x04bd8, 0x04ae0, 0x0a570, 0x054d5, 0x0d260, 0x0d950, 0x16554, 0x056a0,
    0x09ad0, 0x055d2, 0x04ae0, 0x0a5b6, 0x0a4d0, 0x0d250, 0x1d255, 0x0b540,
    0x0d6a0, 0x0ada2, 0x095b0, 0x14977, 0x04970, 0x0a4b0, 0x0b4b5, 0x06a50,
    0x06d40, 0x1ab54, 0x02b60, 0x09570, 0x052f2, 0x04970, 0x06566, 0x0d4a0,
    0x0ea50, 0x16a95, 0x05ad0, 0x02b60, 0x186e3, 0x092e0, 0x1c8d7, 0x0c950,
    0x0d4a0, 0x1d8a6, 0x0b550, 0x056a0, 0x1a5b4, 0x025d0, 0x092d0, 0x0d2b2,
    0x0a950, 0x0b557, 0x06ca0, 0x0b550, 0x15355, 0x04da0, 0x0a5b0, 0x14573,
    0x052b0, 0x0a9a8, 0x0e950, 0x06aa0, 0x0aea6, 0x0ab50, 0x04b60, 0x0aae4,
    0x0a570, 0x05260, 0x0f263, 0x0d950, 0x05b57, 0x056a0, 0x096d0, 0x04dd5,
    0x04ad0, 0x0a4d0, 0x0d4d4, 0x0d250, 0x0d558, 0x0b540, 0x0b6a0, 0x195a6,
    0x095b0, 0x049b0, 0x0a974, 0x0a4b0, 0x0b27a, 0x06a50, 0x06d40, 0x0af46,
    0x0ab60, 0x09570, 0x04af5, 0x04970, 0x064b0, 0x074a3, 0x0ea50, 0x06b58,
    0x05ac0, 0x0ab60, 0x096d5, 0x092e0, 0x0c960, 0x0d954, 0x0d4a0, 0x0da50,
    0x07552, 0x056a0, 0x0abb7, 0x025d0, 0x092d0, 0x0cab5, 0x0a950, 0x0b4a0,
    0x0baa4, 0x0ad50, 0x055d9, 0x04ba0, 0x0a5b0, 0x15176, 0x052b0, 0x0a930,
    0x07954, 0x06aa0, 0x0ad50, 0x05b52, 0x04b60, 0x0a6e6, 0x0a4e0, 0x0d260,
    0x0ea65, 0x0d530, 0x05aa0, 0x076a3, 0x096d0, 0x04afb, 0x04ad0, 0x0a4d0,
    0x1d0b6, 0x0d250, 0x0d520, 0x0dd45, 0x0b5a0, 0x056d0, 0x055b2, 0x049b0,
    0x0a577, 0x0a4b0, 0x0aa50, 0x1b255, 0x06d20, 0x0ada0, 0x14b63, 0x09370,
    0x049f8, 0x04970, 0x064b0, 0x168a6, 0x0ea50, 0x06b20, 0x1a6c4, 0x0aae0,
    0x092e0, 0x0d2e3, 0x0c960, 0x0d557, 0x0d4a0, 0x0da50, 0x05d55, 0x056a0,
    0x0a6d0, 0x055d4, 0x052d0, 0x0a9b8, 0x0a950, 0x0b4a0, 0x0b6a6, 0x0ad50,
    0x055a0, 0x0aba4, 0x0a5b0, 0x052b0, 0x0b273, 0x06930, 0x07337, 0x06aa0,
    0x0ad50, 0x14b55, 0x04b60, 0x0a570, 0x054e4, 0x0d160, 0x0e968, 0x0d520,
    0x0daa0, 0x16aa6, 0x056d0, 0x04ae0, 0x0a9d4, 0x0a2d0, 0x0d150, 0x0f252,
]
BASE_DATE = date(1900, 1, 31)  # lunar 1900-01-01
MAX_YEAR = 1900 + len(LUNAR_INFO) - 1

# 24 solar terms, 1900-2099: 2 bits per term as (day - TERM_BASE), 6 bytes per
# year, base64-encoded. Validated against astronomical data for every year.
TERMS = ["小寒", "大寒", "立春", "雨水", "惊蛰", "春分", "清明", "谷雨",
         "立夏", "小满", "芒种", "夏至", "小暑", "大暑", "立秋", "处暑",
         "白露", "秋分", "寒露", "霜降", "立冬", "小雪", "大雪", "冬至"]
TERM_BASE = [4, 19, 3, 18, 4, 19, 4, 19, 4, 20, 4, 20, 6, 22, 6, 22, 6, 22, 7, 22, 6, 21, 6, 21]
TERM_DATA = (
    "VlqmZaZaWpqqpqpqaqq6qqqqqq+7uquqq1qmZaZaWpqqpqpqaqqqqqqqqq+7uquqq1qmZaZaWpqq"
    "pqpqaqqqqqqqqq+7uquqq1qmZaZWVpqqpqZqWpqqqqqqqq66qquqqlqmZZZWVpqmpqZqWpqqqqpq"
    "qq66qquqqlqmZZZWVlqmpqZaWpqqqqpqaqq6qquqqlqmZZZWVlqmpqZaWpqqpqpqaqq6qquqqlqm"
    "ZVZVVlqmZaZaWpqqpqpqaqq6qqqqqlpmZVZVVlqmZaZaWpqqpqpqaqqqqqqqqlpmZVZVVlqmZaZa"
    "WpqqpqpqaqqqqqqqqlpmZVZVVlqmZaZaWpqqpqpqaqqqqqqqqlplZVZVVlqmZZZWVpqqpqZqWpqq"
    "qqqqqlllVVZVVVqmZZZWVlqmpqZqWpqqqqqqqlllVVZVVVqmZZZWVlqmpqZaWpqqpqpqqlVlVVZV"
    "VVqmZZZWVlqmZaZaWpqqpqpqalVlVVVVVVpmZVZVVlqmZaZaWpqqpqpqalVlVVVVVVpmZVZVVlqm"
    "ZaZaWpqqpqpqalVVVVVVVVpmZVZVVlqmZaZaWpqqpqpqalVVVVVVVVplZVZVVlqmZaZaWpqqpqZq"
    "akVVVVVVVVplVVZVVlqmZZZaVpqmpqZqakVVVVVVVVplVVZVVlqmZZZWVlqmpqZqWkVVUVVVVVll"
    "VVZVVVqmZZZWVlqmpaZaWkVVUVUVVVVlVVVVVVpmZZZWVlqmZaZaWkVVUVUVFVVlVVVVVVpmZVZV"
    "VlqmZaZaWkVVUVUVFVVVVVVVVVpmZVZVVlqmZaZaWkVVUVUVFVVVVVVVVVpmZVZVVlqmZaZaWkVV"
    "UVUVFVVVVVVVVVplVVZVVlqmZaZaWkVVUVEVFUVVVVVVVVplVVZVVlqmZZZaWkVRUVEVFUVVUVVV"
    "VVplVVZVVlqmZZZWVgVRUVEVBUVVUVVVVVllVVZVVVpmZZZWVgVREFEVBUVVUVUVVVVlVVVVVVpm"
    "ZZZWVgVREFEFBUVVUVUVFVVVVVVVVVpmZVZVVgVREFEFBUVVUVUVFVVVVVVVVVpmZVZVVgVREFEF"
    "BUVVUVUVFVVVVVVVVVplVVZVVgVREFEFBUVVUVUVFVVVVVVVVVplVVZVVgVREFEFBUVRUVEVFUVV"
    "VVVVVVplVVZVVgVREEEFBQVRUVEVFUVVUVVVVVplVVZVVgUREEEBAQVREFEVBUVVUVVVVVVlVVVV"
    "VQUREEEBAQVREFEVBUVVUVVVVVVVVVVVVQUREEEBAQVREFEFBUVVUVUVVVVVVVVVVQUREAEAAQVR"
    "EFEFBUVVUVUVFVVVVVVVVQUREAEAAQVREFEFBUVVUVUVFVVVVVVVVQUQAAEAAQVREFEFBUVRUVEV"
    "FVVVVVVVVQUQAAEAAQVREEEFBUVRUVEVFUVVUVVVVQUQAAEAAQVREEEFBQVRUFEVFUVVUVVVVQUQ"
    "AAEAAQUREEEBBQVREFEVBUVVUVVVVQAQAAAAAAUREEEBAQVREFEVBUVVUVVVVQAAAAAAAAUREEEB"
    "AQVREFEFBUVVUVUVVQAAAAAAAAUREAEAAQVREFEFBUVVUVUVFQAAAAAAAAURAAEAAQVREFEFBUVV"
    "UVUV"
)

MONTH_NAMES = ["正月", "二月", "三月", "四月", "五月", "六月",
               "七月", "八月", "九月", "十月", "冬月", "腊月"]
DAY_NAMES = ["初一", "初二", "初三", "初四", "初五", "初六", "初七", "初八", "初九", "初十",
             "十一", "十二", "十三", "十四", "十五", "十六", "十七", "十八", "十九", "二十",
             "廿一", "廿二", "廿三", "廿四", "廿五", "廿六", "廿七", "廿八", "廿九", "三十"]

# (lunar month, day) -> festival; not observed in leap months. 除夕 (last day
# of the lunar year) is computed separately.
LUNAR_FESTIVALS = {
    (1, 1): "春节", (1, 15): "元宵节", (2, 2): "龙抬头",
    (5, 5): "端午节", (7, 7): "七夕", (7, 15): "中元节",
    (8, 15): "中秋节", (9, 9): "重阳节",
    (12, 8): "腊八节", (12, 23): "北小年", (12, 24): "南小年",
}
SOLAR_FESTIVALS = {
    (1, 1): "元旦", (3, 8): "妇女节", (3, 12): "植树节",
    (5, 1): "劳动节", (5, 4): "青年节", (6, 1): "儿童节",
    (7, 1): "建党节", (8, 1): "建军节", (9, 10): "教师节", (10, 1): "国庆节",
}


def leap_month(year):
    return LUNAR_INFO[year - 1900] & 0xF


def leap_days(year):
    if not leap_month(year):
        return 0
    return 30 if LUNAR_INFO[year - 1900] & 0x10000 else 29


def lunar_month_days(year, month):
    return 30 if LUNAR_INFO[year - 1900] & (1 << (16 - month)) else 29


def _lunar_year_days(year):
    return sum(lunar_month_days(year, m) for m in range(1, 13)) + leap_days(year)


def lunar_from_solar(d):
    """Solar date -> (lunar year, lunar month, lunar day, is_leap_month).
    Covers lunar years 1900-2099 (solar 1900-01-31 through the end of lunar
    2099, ~2100-02); raises ValueError outside."""
    n = (d - BASE_DATE).days
    if n < 0:
        raise ValueError(f"date out of range: {d}")
    year = 1900
    while year <= MAX_YEAR:
        days = _lunar_year_days(year)
        if n < days:
            break
        n -= days
        year += 1
    else:
        raise ValueError(f"date out of range: {d}")
    leap = leap_month(year)
    months = []
    for m in range(1, 13):
        months.append((m, False, lunar_month_days(year, m)))
        if m == leap:
            months.append((m, True, leap_days(year)))
    for m, is_leap, days in months:
        if n < days:
            return (year, m, n + 1, is_leap)
        n -= days
    raise ValueError(f"date out of range: {d}")  # unreachable


def solar_term_days(year):
    """All 24 solar terms of a year: [(month, day, name)]."""
    chunk = base64.b64decode(TERM_DATA)[(year - 1900) * 6:(year - 1900) * 6 + 6]
    bits = int.from_bytes(chunk, "little")
    out = []
    for i, name in enumerate(TERMS):
        day = TERM_BASE[i] + ((bits >> (2 * i)) & 3)
        out.append((i // 2 + 1, day, name))
    return out


def lunar_month_name(month, is_leap):
    return ("闰" if is_leap else "") + MONTH_NAMES[month - 1]


def lunar_day_name(day):
    return DAY_NAMES[day - 1]


def _nth_weekday_of_month(year, month, weekday, n):
    """Date of the n-th `weekday` (Mon=0) in a month, e.g. 母亲节 = May, Sun, 2."""
    d = date(year, month, 1)
    d += timedelta(days=(weekday - d.weekday()) % 7)
    return d + timedelta(weeks=n - 1)


def day_sub_text(d):
    """Second line of a day cell: (text, kind), kind ∈ festival|term|month|day.
    Priority: lunar festival > solar festival > solar term > month name on 初一
    > lunar day name."""
    try:
        ly, lm, ld, is_leap = lunar_from_solar(d)
    except ValueError:  # outside 1900-2099 (dimmed spill cells)
        return ("", "day")
    if lm == 12 and not is_leap and ld == lunar_month_days(ly, 12):
        return ("除夕", "festival")
    name = None if is_leap else LUNAR_FESTIVALS.get((lm, ld))
    if name:
        return (name, "festival")
    name = SOLAR_FESTIVALS.get((d.month, d.day))
    if name:
        return (name, "festival")
    if d == _nth_weekday_of_month(d.year, 5, 6, 2):
        return ("母亲节", "festival")
    if d == _nth_weekday_of_month(d.year, 6, 6, 3):
        return ("父亲节", "festival")
    for mo, dd, term in solar_term_days(d.year):
        if mo == d.month and dd == d.day:
            return (term, "term")
    if ld == 1:
        return (lunar_month_name(lm, is_leap), "month")
    return (lunar_day_name(ld), "day")


def month_grid(year, month):
    """Sunday-first grid of dates covering the month (spill days included).
    4-6 rows: trailing rows made entirely of other months' days are dropped
    (e.g. a 28-day February starting on Sunday needs only 4 rows)."""
    first = date(year, month, 1)
    start = first - timedelta(days=(first.weekday() + 1) % 7)
    rows = [[start + timedelta(days=7 * r + c) for c in range(7)] for r in range(6)]
    while len(rows) > 1 and all(d.month != month for d in rows[-1]):
        rows.pop()
    return rows


# ---------- official holiday arrangement (holiday-cn, cached) ----------

def parse_holidays(text):
    """holiday-cn JSON -> {date: (is_off_day, name)}; {} on malformed input."""
    try:
        data = json.loads(text)
    except ValueError:
        return {}
    out = {}
    for item in data.get("days", []):
        try:
            y, m, dd = item["date"].split("-")
            out[date(int(y), int(m), int(dd))] = (bool(item["isOffDay"]), str(item["name"]))
        except (KeyError, TypeError, ValueError):
            continue
    return out


def fetch_year(year):
    """Download holiday-cn JSON for a year; raise OSError on total failure."""
    for url_t in HOLIDAY_URLS:
        try:
            with urllib.request.urlopen(url_t.format(year), timeout=3) as resp:
                return resp.read().decode("utf-8")
        except Exception:
            continue
    raise OSError(f"holiday fetch failed for {year}")


def should_fetch(year, cache_mtime, missing_mtime, today):
    """Cache policy: published data is final; only the current year re-fetches
    (every 30d, guarding against mid-year adjustments); a failed fetch is
    retried at most every 7 days."""
    if cache_mtime is None:
        return missing_mtime is None or (today - missing_mtime).days >= 7
    if year < today.year:
        return False
    if year == today.year:
        return (today - cache_mtime).days >= 30
    return False


class HolidayStore:
    def __init__(self, cache_dir, fetcher=None, today=None):
        self.cache_dir = cache_dir
        self.fetcher = fetcher or fetch_year
        self.today = today or date.today()

    def _mtime(self, path):
        try:
            return date.fromtimestamp(os.path.getmtime(path))
        except OSError:
            return None

    def _set_mtime(self, path):
        # file mtimes drive the cache policy; pin them to self.today so the
        # policy is deterministic (and testable with a fake today)
        epoch = time.mktime(self.today.timetuple())
        os.utime(path, (epoch, epoch))

    def for_year(self, year):
        cache = os.path.join(self.cache_dir, f"holidays-{year}.json")
        missing = cache + ".missing"
        if should_fetch(year, self._mtime(cache), self._mtime(missing), self.today):
            try:
                text = self.fetcher(year)
                parsed = parse_holidays(text)
                if not parsed:
                    raise OSError("empty holiday data")
                os.makedirs(self.cache_dir, exist_ok=True)
                with open(cache, "w", encoding="utf-8") as f:
                    f.write(text)
                self._set_mtime(cache)
                try:
                    os.remove(missing)
                except OSError:
                    pass
                return parsed
            except Exception:
                try:
                    os.makedirs(self.cache_dir, exist_ok=True)
                    with open(missing, "w", encoding="utf-8") as f:
                        f.write(self.today.isoformat() + "\n")
                    self._set_mtime(missing)
                except OSError:
                    pass
        try:
            with open(cache, encoding="utf-8") as f:
                return parse_holidays(f.read())
        except OSError:
            return {}


# ---------- popup (Gtk.Window) ----------

BAR_HEIGHT = 36  # matches waybar "height"; the card hangs flush below the bar
CELL_WIDTH = 44
SIDE_GAP = 6     # minimum distance to the screen's left/right edge

CSS = """
window#calendar-popup {
  background-color: transparent;
}
#calendar-content {
  background-color: #1e1e2e;
  color: #cdd6f4;
  border-radius: 8px;
  padding: 12px;
  /* subtle shadow - a wide CSS blur reads heavier than the compositor's */
  box-shadow: 0 0 6px rgba(26, 26, 26, 0.55);
}
#cal-title {
  font-size: 15px;
  color: #cdd6f4;
}
#calendar-content button.nav {
  border: none;
  outline-style: none;
  box-shadow: none;
  background: transparent;
  border-radius: 6px;
  min-width: 0;
  min-height: 0;
  padding: 0 10px;
  color: #a6adc8;
  font-size: 15px;
}
#calendar-content button.nav:hover {
  background-color: #313244;
  color: #cdd6f4;
}
label.week {
  color: #a6adc8;
  font-size: 12px;
  margin-bottom: 4px;
}
label.week.weekend {
  color: #f38ba8;
}
#calendar-content button.day {
  border: none;
  outline-style: none;
  box-shadow: none;
  background: transparent;
  border-radius: 6px;
  min-width: 0;
  min-height: 0;
  padding: 5px 4px;
}
#calendar-content button.day:hover {
  background-color: #313244;
}
label.solar {
  font-size: 14px;
  color: #cdd6f4;
}
button.day.weekend label.solar {
  color: #f38ba8;
}
label.sub {
  font-size: 10px;
  color: #a6adc8;
}
label.sub.festival {
  color: #f38ba8;
}
label.sub.term {
  color: #94e2d5;
}
label.badge {
  font-size: 9px;
}
label.badge.off {
  color: #a6e3a1;
}
label.badge.work {
  color: #fab387;
}
button.day.out-month label.solar,
button.day.out-month label.sub {
  color: #6c7086;
}
/* today: must be ID-qualified AND come last - the plain #calendar-content
   button.day rules above would otherwise outrank these by specificity
   (symptom: blue background never paints, dark-on-dark text = invisible) */
#calendar-content button.day.today,
#calendar-content button.day.today:hover {
  background-color: #89b4fa;
}
#calendar-content button.day.today label.solar,
#calendar-content button.day.today label.sub,
#calendar-content button.day.today label.badge {
  color: #1e1e2e;
}
"""

WEEKDAYS = ["日", "一", "二", "三", "四", "五", "六"]


def run(*args, wait=False):
    try:
        if wait:
            return subprocess.run(args, capture_output=True, text=True, timeout=40)
        subprocess.Popen(args, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except Exception:
        return None
    return None


# waybar exposes no module geometry of its own; waybar_geom finds the clock
# label via the AT-SPI tree (see that file). Missing module/import -> []
# -> the popup falls back to monitor-center placement.
try:
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    from waybar_geom import find_module_extents, popup_margins
except ImportError:
    find_module_extents = popup_margins = None


def find_clock_extents():
    if find_module_extents is None:
        return []
    return find_module_extents(date.today().strftime("%Y.%m.%d"))


class CalendarPopup:
    def __init__(self, win, card):
        self.win = win
        self.card = card
        today = date.today()
        self.year, self.month = today.year, today.month
        self.store = HolidayStore(CACHE_DIR)
        self.title = None
        self.grid = None
        # Hand cursor over clickable cells ("pointer" is the css name, "hand2"
        # the legacy X name; silently no-op if the theme lacks both).
        self.hand = (Gdk.Cursor.new_from_name("pointer", None)
                     or Gdk.Cursor.new_from_name("hand2", None))

    def nav(self, delta):
        m = self.month - 1 + delta
        self.year, self.month = self.year + m // 12, m % 12 + 1
        self.rebuild()

    def go_today(self):
        today = date.today()
        self.year, self.month = today.year, today.month
        self.rebuild()

    def copy_day(self, _btn, d):
        iso = d.isoformat()
        run("wl-copy", iso)
        run("notify-send", "-t", "1500", f"已复制 {iso}")

    def rebuild(self):
        if self.grid is not None:
            self.card.remove(self.grid)
        self.title.set_text(f"{self.year}年{self.month}月")
        holidays = self.store.for_year(self.year)
        today = date.today()

        grid = Gtk.Grid()
        grid.set_column_homogeneous(True)
        grid.set_halign(Gtk.Align.CENTER)
        for c, name in enumerate(WEEKDAYS):
            lbl = Gtk.Label(label=name)
            lbl.get_style_context().add_class("week")
            if c in (0, 6):  # 日/六
                lbl.get_style_context().add_class("weekend")
            lbl.set_size_request(CELL_WIDTH, -1)
            grid.attach(lbl, c, 0, 1, 1)

        for r, row in enumerate(month_grid(self.year, self.month)):
            for c, d in enumerate(row):
                btn = Gtk.Button()
                btn.set_has_frame(False)
                ctx = btn.get_style_context()
                ctx.add_class("day")
                if c in (0, 6):  # 日/六
                    ctx.add_class("weekend")
                if d.month != self.month:
                    ctx.add_class("out-month")
                if d == today:
                    ctx.add_class("today")

                box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
                top = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=2)
                top.set_halign(Gtk.Align.CENTER)
                solar = Gtk.Label(label=str(d.day))
                solar.get_style_context().add_class("solar")
                top.append(solar)
                badge_text = {True: "休", False: "班"}.get(holidays.get(d, (None, ""))[0])
                if badge_text:
                    badge = Gtk.Label(label=badge_text)
                    bctx = badge.get_style_context()
                    bctx.add_class("badge")
                    bctx.add_class("off" if holidays[d][0] else "work")
                    top.append(badge)
                text, kind = day_sub_text(d)
                sub = Gtk.Label(label=text)
                sub.get_style_context().add_class("sub")
                sub.get_style_context().add_class(kind)
                box.append(top)
                box.append(sub)
                btn.set_child(box)
                btn.set_cursor(self.hand)
                btn.connect("clicked", self.copy_day, d)
                grid.attach(btn, c, r + 1, 1, 1)

        self.grid = grid
        self.card.append(grid)


def on_click_outside(_gesture, _n_press, x, y, win, card):
    # The surface fills the whole output, so every click reaches us; dismiss
    # only when it lands outside the card (clicks inside go to the buttons).
    # Gesture coordinates are relative to the window, matching
    # compute_bounds' coordinate space (GTK4 has no child-relative
    # double-click quirk, so fast month-nav clicking is safe).
    ok, b = card.compute_bounds(win)
    if ok and b.origin.x <= x < b.origin.x + b.size.width \
            and b.origin.y <= y < b.origin.y + b.size.height:
        return
    win.close()


def on_key(_ctrl, keyval, _keycode, _state, popup, win):
    if keyval == Gdk.KEY_Escape:
        win.close()
        return True
    if keyval == Gdk.KEY_Left:
        popup.nav(-1)
        return True
    if keyval == Gdk.KEY_Right:
        popup.nav(1)
        return True
    if keyval == Gdk.KEY_Home:
        popup.go_today()
        return True
    return False


def on_scroll(_ctrl, _dx, dy, popup):
    if dy < 0:
        popup.nav(-1)
    elif dy > 0:
        popup.nav(1)
    return True


def find_monitor_at(display, px, py):
    """Monitor containing (px, py); the first monitor as fallback (GTK4 has
    no primary-monitor concept)."""
    if display is None:
        return None
    monitors = display.get_monitors()
    for i in range(monitors.get_n_items()):
        m = monitors.get_item(i)
        g = m.get_geometry()
        if g.x <= px < g.x + g.width and g.y <= py < g.y + g.height:
            return m
    return monitors.get_item(0) if monitors.get_n_items() > 0 else None


def build_window(app, mon, clocks, px):
    # Same pattern as weather.py --popup: a fullscreen transparent layer-shell
    # surface (the outside-click catcher); the visible card hangs flush below
    # the bar, horizontally centered on the clock module when its geometry is
    # known (AT-SPI), else centered on the monitor.
    win = Gtk.Window(application=app, title="calendar-popup")
    win.set_name("calendar-popup")

    Gtk4LayerShell.init_for_window(win)
    Gtk4LayerShell.set_layer(win, Gtk4LayerShell.Layer.TOP)
    Gtk4LayerShell.set_namespace(win, "calendar-popup")
    Gtk4LayerShell.set_keyboard_mode(win, Gtk4LayerShell.KeyboardMode.EXCLUSIVE)
    Gtk4LayerShell.set_exclusive_zone(win, -1)  # overlay, never shifts the bar
    for edge in (Gtk4LayerShell.Edge.TOP, Gtk4LayerShell.Edge.BOTTOM,
                 Gtk4LayerShell.Edge.LEFT, Gtk4LayerShell.Edge.RIGHT):
        Gtk4LayerShell.set_anchor(win, edge, True)
    if mon is not None:
        Gtk4LayerShell.set_monitor(win, mon)

    provider = Gtk.CssProvider()
    provider.load_from_string(CSS)
    # PRIORITY_USER (800), not APPLICATION (600): the GTK theme is symlinked
    # into ~/.config/gtk-4.0/gtk.css, which GTK loads at USER priority — an
    # APPLICATION-priority provider loses to the theme's opaque
    # `.background { background-color: @window_bg_color }` and the popup
    # becomes an opaque fullscreen surface that hides the desktop.
    Gtk.StyleContext.add_provider_for_display(
        win.get_display(), provider, Gtk.STYLE_PROVIDER_PRIORITY_USER)

    card = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6)
    card.set_name("calendar-content")

    popup = CalendarPopup(win, card)

    # header: 今天 2026年8月 ‹ › (title stays centered: button groups on
    # both ends are roughly the same width)
    header = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL)
    today_btn = Gtk.Button(label="今天")
    today_btn.get_style_context().add_class("nav")
    today_btn.set_has_frame(False)
    today_btn.connect("clicked", lambda *a: popup.go_today())
    prev_btn = Gtk.Button(label="‹")
    prev_btn.get_style_context().add_class("nav")
    prev_btn.set_has_frame(False)
    prev_btn.connect("clicked", lambda *a: popup.nav(-1))
    title = Gtk.Label()
    title.set_name("cal-title")
    title.set_hexpand(True)
    next_btn = Gtk.Button(label="›")
    next_btn.get_style_context().add_class("nav")
    next_btn.set_has_frame(False)
    next_btn.connect("clicked", lambda *a: popup.nav(1))
    header.append(today_btn)
    header.append(title)
    header.append(prev_btn)
    header.append(next_btn)
    card.append(header)
    popup.title = title

    # Hand cursor over the nav buttons (day cells get theirs in rebuild()).
    for b in (today_btn, prev_btn, next_btn):
        b.set_cursor(popup.hand)

    popup.rebuild()

    # Dropdown placement: centered on the clock module (AT-SPI geometry), else
    # centered on the monitor; clamped to the monitor edges either way.
    card.set_halign(Gtk.Align.START)
    card.set_valign(Gtk.Align.START)
    width = card.measure(Gtk.Orientation.HORIZONTAL, -1)[1]
    geo_t = None
    if mon is not None:
        g = mon.get_geometry()
        geo_t = (g.x, g.y, g.width, g.height)
    if popup_margins is not None:
        mx, mt = popup_margins(width, clocks, geo_t, px, BAR_HEIGHT, SIDE_GAP)
    elif geo_t is not None:  # waybar_geom missing: monitor center
        mx = min(max((geo_t[2] - width) // 2, SIDE_GAP),
                 max(geo_t[2] - width - SIDE_GAP, SIDE_GAP))
        mt = BAR_HEIGHT
    else:
        mx, mt = px - width // 2, BAR_HEIGHT
    card.set_margin_start(mx)
    card.set_margin_top(mt)

    win.set_child(card)

    # Clicking outside the card, Escape, scrolling and arrow keys; moving the
    # mouse away does nothing (no focus-out handler).
    click = Gtk.GestureClick()
    click.connect("pressed", on_click_outside, win, card)
    win.add_controller(click)
    key = Gtk.EventControllerKey()
    key.connect("key-pressed", on_key, popup, win)
    win.add_controller(key)
    scroll = Gtk.EventControllerScroll.new(Gtk.EventControllerScrollFlags.VERTICAL)
    scroll.connect("scroll", on_scroll, popup)
    win.add_controller(scroll)
    return win


def kill_existing_popup(pid_file=PID_FILE):
    """Toggle helper: if the pidfile names a live calendar.py process, kill it
    and return True. A stale pidfile (dead pid) is ignored; a live pid whose
    cmdline is NOT calendar.py (pid reuse) is left alone."""
    try:
        with open(pid_file, encoding="utf-8") as f:
            pid = int(f.read().strip())
    except (OSError, ValueError):
        return False
    if pid <= 0:
        return False
    try:
        with open(f"/proc/{pid}/cmdline", "rb") as f:
            cmdline = f.read()
    except OSError:
        return False  # process is gone (stale pidfile)
    if b"calendar.py" not in cmdline:
        return False  # pid was reused by something else
    run("kill", str(pid))
    return True


def run_popup():
    GLib.set_prgname("calendar-popup")
    os.makedirs(CACHE_DIR, exist_ok=True)
    if Gtk4LayerShell is None:
        print("calendar.py --popup requires gtk4-layer-shell", file=sys.stderr)
        return

    # Toggle: a second click on the clock closes an already-open popup.
    if kill_existing_popup():
        return

    # The pointer position only picks WHICH monitor's bar was clicked; the
    # card's horizontal anchor comes from the clock module's geometry (AT-SPI).
    px = py = 0
    try:
        cursor = json.loads(subprocess.check_output(["hyprctl", "-j", "cursorpos"]).decode())
        px = int(cursor.get("x", 0))
        py = int(cursor.get("y", 0))
    except Exception:
        pass

    app = Gtk.Application(application_id="calendar.popup")

    def on_activate(app):
        mon = find_monitor_at(Gdk.Display.get_default(), px, py)
        build_window(app, mon, find_clock_extents(), px).present()

    app.connect("activate", on_activate)

    try:
        with open(PID_FILE, "w", encoding="utf-8") as f:
            f.write(str(os.getpid()) + "\n")
    except OSError:
        pass

    app.run(None)

    try:
        os.remove(PID_FILE)
    except OSError:
        pass


def main():
    run_popup()


if __name__ == "__main__":
    main()
