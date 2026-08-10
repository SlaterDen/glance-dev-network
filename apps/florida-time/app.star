# Florida Time - the current time in Florida, on a Glance panel.
#
# No network call. Florida's clock is fully determined by the calendar: the
# peninsula runs on Eastern (UTC-5), the panhandle west of the Apalachicola
# River runs on Central (UTC-6), and both follow the federal daylight-saving
# rule -- forward on the second Sunday in March, back on the first Sunday in
# November. That rule is a dozen lines of arithmetic, so this computes it from
# ctx.now (UTC) rather than asking a time API. Nothing to be down, nothing to
# rate-limit, and no error screen to design: the panel is always right.
#
# LAYOUT (128x32). Everything on the right edge is measured from c.width, so a
# wider panel just gets more black between the clock and the labels.
#
#   header  y=0..7    sunset gradient bar: FLORIDA left, local date right
#   palm    y=11      x=1, 14x16 sprite
#   time    y=10      x=20, 16x20  (H:MM or HH:MM -- max width 84px)
#   AM/PM   y=11      right, 6x8   (12-hour mode only)
#   zone    y=21      right, 5x7   -- green while DST is in effect
#   bar     y=31      how far through the day it is

DOW = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"]
MONTHS = ["JAN", "FEB", "MAR", "APR", "MAY", "JUN",
          "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"]

# Fronds, a leaning trunk, and a little sand. Drawn with c.sprite, so it needs
# no PNG in the folder and no `assets:` entry in the manifest.
PALM = """
.....ggg......
...ggggggg....
..ggg.t.ggg...
.gg...t...gg..
gg....tt...gg.
g.....tt....g.
......tt......
.....tt.......
.....tt.......
....tt........
....tt........
...tt.........
...tt.........
..tt..........
..tt..........
sssssssssssss.
"""
PALM_COLORS = {"g": "#1FA64A", "t": "#8A5A2B", "s": "#5A4020"}

HEADER_A = "#FF8A00"
HEADER_B = "#FF2E7E"
TIME_COLOR = "#FFF3D6"
AMPM_COLOR = "#FFB03A"
DST_COLOR = "#5FD0A0"
STD_COLOR = "#9AA6B2"

# The two zones Florida actually uses: (standard UTC offset, abbreviations).
ZONES = {
    "peninsula": (-5, "EST", "EDT"),
    "panhandle": (-6, "CST", "CDT"),
}

# ---------- input ----------

def _s(ctx, key, fallback):
    # An unset input can come back as None, so coerce before using it.
    v = ctx.inputs.get(key, fallback)
    if v == None:
        return fallback
    return str(v).strip().lower()

# ---------- calendar ----------

def _days_from_civil(y, m, d):
    # (year, month, day) -> days since 1970-01-01.
    yy = y - 1 if m <= 2 else y
    era = (yy if yy >= 0 else yy - 399) // 400
    yoe = yy - era * 400
    mm = m + (-3 if m > 2 else 9)
    doy = (153 * mm + 2) // 5 + d - 1
    doe = yoe * 365 + yoe // 4 - yoe // 100 + doy
    return era * 146097 + doe - 719468

def _civil_from_days(z):
    z = z + 719468
    era = (z if z >= 0 else z - 146096) // 146097
    doe = z - era * 146097
    yoe = (doe - doe // 1460 + doe // 36524 - doe // 146096) // 365
    y = yoe + era * 400
    doy = doe - (365 * yoe + yoe // 4 - yoe // 100)
    mp = (5 * doy + 2) // 153
    d = doy - (153 * mp + 2) // 5 + 1
    m = mp + 3 if mp < 10 else mp - 9
    if m <= 2:
        y = y + 1
    return y, m, d

def _nth_sunday(y, month, nth):
    # Days since epoch for the nth Sunday of a month. Day 0 was a Thursday, so
    # (days + 4) % 7 is the weekday with 0 = Sunday.
    first = _days_from_civil(y, month, 1)
    return first + ((7 - (first + 4) % 7) % 7) + (nth - 1) * 7

# ---------- the actual clock ----------

def florida_offset(ctx, region):
    """Hours from UTC right now, the zone abbreviation, and whether it's DST."""
    zone = ZONES.get(region, ZONES["peninsula"])
    std = zone[0]

    now = ctx.now.unix
    year, _, _ = _civil_from_days(now // 86400)

    # Both transitions land at 2:00 *local* -- standard time in spring, daylight
    # time in autumn -- which is (2 - that offset) o'clock UTC.
    starts = _nth_sunday(year, 3, 2) * 86400 + (2 - std) * 3600
    ends = _nth_sunday(year, 11, 1) * 86400 + (2 - (std + 1)) * 3600

    if now >= starts and now < ends:
        return std + 1, zone[2], True
    return std, zone[1], False

def local_parts(ctx, off_hours):
    # Clock and date both come off this one shifted timestamp, so they can
    # never disagree across midnight.
    local = ctx.now.unix + off_hours * 3600
    sod = local % 86400
    days = (local - sod) // 86400
    year, month, day = _civil_from_days(days)
    return {
        "h": sod // 3600,
        "mi": (sod % 3600) // 60,
        "mo": month,
        "d": day,
        "wd": (days + 4) % 7,  # 0 = Sunday, to match DOW
    }

def pad2(n):
    return str(n) if n >= 10 else "0" + str(n)

# ---------- the page ----------

def main(c, ctx):
    region = _s(ctx, "region", "peninsula")
    fmt = _s(ctx, "hourformat", "12")

    off, abbr, is_dst = florida_offset(ctx, region)
    t = local_parts(ctx, off)

    ampm = ""
    h = t["h"]
    if fmt != "24":
        ampm = "AM" if h < 12 else "PM"
        h = h % 12
        if h == 0:
            h = 12
    time_s = str(h) + ":" + pad2(t["mi"])

    right = c.width - 2

    c.fill("black")

    # ----- header: the state, and today's date in Florida -----
    c.gradient_rect(0, 0, c.width - 1, 7, HEADER_A, HEADER_B)
    c.text("FLORIDA", 3, 1, font = "5x7b", color = "black")
    date_s = DOW[t["wd"]] + " " + MONTHS[t["mo"] - 1] + " " + str(t["d"])
    c.text(date_s, right, 2, font = "4x5", color = "black", align = "right")

    # ----- the palm, then the clock -----
    c.sprite(PALM, 1, 11, legend = PALM_COLORS)
    c.text(time_s, 20, 10, font = "16x20", color = TIME_COLOR)

    if ampm:
        c.text(ampm, right, 11, font = "6x8", color = AMPM_COLOR, align = "right")
    c.text(abbr, right, 21, font = "5x7",
           color = DST_COLOR if is_dst else STD_COLOR, align = "right")

    # ----- how far through the day it is -----
    mins = t["h"] * 60 + t["mi"]
    c.rect(0, 31, c.width - 1, 31, fill = "#241018")
    filled = (mins * (c.width - 1)) // 1440
    if filled > 0:
        c.rect(0, 31, filled, 31, fill = HEADER_A)
