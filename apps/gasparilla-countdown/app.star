# Gasparilla countdown for a Glance Scroll panel (192x32).
# Draws PIRATE_FLAG.png on the left and days-until-Gasparilla on the right.

EVENT_DATE = (2027, 1, 30)   # hardcoded festival date (Y, M, D)
LABEL      = "GASPARILLA"    # hardcoded header text

# Days since an epoch for a civil date (Hinnant's algorithm). We only ever
# subtract two of these, so the epoch it counts from doesn't matter.
def days_from_civil(y, m, d):
    yy = y - 1 if m <= 2 else y
    era = (yy if yy >= 0 else yy - 399) // 400
    yoe = yy - era * 400
    mp = m - 3 if m > 2 else m + 9
    doy = (153 * mp + 2) // 5 + d - 1
    doe = yoe * 365 + yoe // 4 - yoe // 100 + doy
    return era * 146097 + doe - 719468

def font_h(name):
    return int(name.split("x")[1])

def fit_font(c, text, options, maxw):
    for f in options:
        if c.text_width(text, f) <= maxw:
            return f
    return options[len(options) - 1]

def countdown(c, ctx):
    label  = LABEL
    accent = ctx.inputs.get("accent", "#FFC300")

    c.fill("black")
    c.image("PIRATE_FLAG.png", 2, 0, w = 48, h = 32)

    tx = 52
    tw = c.width - tx - 2
    cx = tx + tw // 2

    today = days_from_civil(ctx.now.year, ctx.now.month, ctx.now.day)
    event = days_from_civil(EVENT_DATE[0], EVENT_DATE[1], EVENT_DATE[2])
    n = event - today

    if n <= 0:
        msg = "TODAY!" if n == 0 else "AHOY!"
        c.text(label, cx, 0, font = fit_font(c, label, ["6x8", "5x7", "4x5"], tw), color = accent, align = "center")
        c.text(msg, cx, 12, font = fit_font(c, msg, ["16x24", "10x16", "7x12"], tw), color = "white", align = "center")
        return

    numstr = str(n)
    daystr = "DAY" if n == 1 else "DAYS"

    # Lay out the number + small DAYS label first, centered together in the area.
    numfont = fit_font(c, numstr, ["16x24", "10x16", "7x12"], tw - 24)
    nh = font_h(numfont)
    nw = c.text_width(numstr, numfont)
    dw = c.text_width(daystr, "5x7")
    gap = 3
    startx = cx - (nw + gap + dw) // 2
    numcx  = startx + nw // 2          # center of the number itself

    # Header, centered over the number's midpoint (not the whole area).
    hdr = fit_label(c, label, ["6x8", "5x7", "4x5"], tw, numcx)
    c.text(hdr[0], hdr[1], 0, font = hdr[2], color = accent, align = "center")

    numy = 8 + (24 - nh) // 2
    c.text(numstr, startx, numy, font = numfont, color = "white", align = "left")
    c.text(daystr, startx + nw + gap, 8 + (24 - 7) // 2, font = "5x7", color = accent, align = "left")

# Pick a header font that fits, then nudge its center-x so the drawn text stays
# fully on-panel even when centered over a number near the left/right edge.
def fit_label(c, text, fonts, maxw, want_cx):
    f = fit_font(c, text, fonts, maxw)
    w = c.text_width(text, f)
    cx = want_cx
    left = 52
    right = 190
    if cx - w // 2 < left:
        cx = left + w // 2
    if cx + w // 2 > right:
        cx = right - w // 2
    return (text, cx, f)