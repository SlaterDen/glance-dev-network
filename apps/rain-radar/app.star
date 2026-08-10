# Rain Radar — average daily rainfall (inches) across a chosen radius of a
# US ZIP over the past 60 days, drawn as a sparkline.
#
# Two fetches: the ZIP's coordinates, then one Open-Meteo call sampling five
# points (center + N/S/E/W at the radius) so the average reflects the area,
# not just one rooftop. Every failure has its own screen: a bad ZIP says so,
# a dead API says so, and a dry 60 days is labeled rather than left as a
# suspicious flat line.

ZIP_URL = "https://api.zippopotam.us/us/"
METEO_URL = "https://api.open-meteo.com/v1/forecast"

# Degrees per mile: latitude is ~69 mi/deg; longitude ~54.5 mi/deg at
# continental-US latitudes.
MILES_PER_LAT_DEG = 69.0
MILES_PER_LON_DEG = 54.5

CLOUD = ".AAAA.\nAAAAAA\nB.B.B.\n.B.B.B"


def _get_center(zip_code):
    resp = http.get(ZIP_URL + zip_code, ttl_seconds=86400)
    if resp.get("status_code", 0) == 0:
        return None  # transport failure — the API never answered
    data = resp.get("json")
    if resp.get("status_code") != 200 or data == None:
        return "bad_zip"  # the API answered: no such ZIP
    places = data.get("places", [])
    if len(places) == 0:
        return "bad_zip"
    return (float(places[0].get("latitude", "0")),
            float(places[0].get("longitude", "0")))


def _get_daily_rain(lat, lon, radius_miles):
    """One call, five sample points -> list of 60 area-averaged daily inches."""
    dlat = radius_miles / MILES_PER_LAT_DEG
    dlon = radius_miles / MILES_PER_LON_DEG
    lats = [lat, lat + dlat, lat - dlat, lat, lat]
    lons = [lon, lon, lon, lon + dlon, lon - dlon]
    resp = http.get(
        METEO_URL,
        params={
            "latitude": ",".join([str(v) for v in lats]),
            "longitude": ",".join([str(v) for v in lons]),
            "daily": "precipitation_sum",
            "past_days": 60,
            "forecast_days": 1,
            "precipitation_unit": "inch",
            "timezone": "UTC",
        },
        ttl_seconds=3600,
    )
    if resp.get("status_code", 0) != 200:
        return None
    data = resp.get("json")
    if data == None:
        return None
    if type(data) != "list":
        data = [data]

    series = []
    for loc in data:
        daily = loc.get("daily", {})
        vals = daily.get("precipitation_sum", [])
        if len(vals) > 0:
            series.append(vals)
    if len(series) == 0:
        return None

    days = []
    for i in range(60):  # indices 0..59 are the past days; the last is today (partial)
        total = 0.0
        n = 0
        for vals in series:
            if i < len(vals) and vals[i] != None:
                total += vals[i]
                n += 1
        days.append(total / n if n > 0 else 0.0)
    return days


def _fmt_hundredths(x):
    cents = int(x * 100 + 0.5)
    return "%d.%s" % (cents // 100, ("0%d" % (cents % 100))[-2:])


def _fallback(c, line1, line2):
    """The no-data screen: a dim cloud, what went wrong, what to do about it."""
    c.sprite(CLOUD, 4, 14, legend={"A": "midgray", "B": "darkgray"})
    c.text(line1, 68, 12, font="5x7", color="red", align="center")
    c.text(line2, 68, 22, font="picopixel", color="gray", align="center")


def rain(c, ctx):
    c.fill("black")
    zip_code = ctx.inputs.get("zip", "32601")
    radius = ctx.inputs.get("radius", "100")

    c.text("RAIN " + radius + "MI 60D", 1, 1, font="4x7", color="white")
    c.text(zip_code.upper(), 127, 2, font="picopixel", color="midgray",
           align="right")

    center = _get_center(zip_code)
    if center == "bad_zip":
        _fallback(c, "ZIP NOT FOUND", "CHECK THE ZIP INPUT")
        return
    if center == None:
        _fallback(c, "NO DATA", "RETRYING IN 1 HOUR")
        return

    days = _get_daily_rain(center[0], center[1], float(radius))
    if days == None:
        _fallback(c, "NO DATA", "RETRYING IN 1 HOUR")
        return

    c.hline(1, 31, 126, color.dim("skyblue", 25))
    c.sparkline(days, 1, 10, 126, 21, color="skyblue",
                fill=color.dim("skyblue", 55))

    total = 0.0
    peak = 0.0
    for v in days:
        total += v
        if v > peak:
            peak = v
    if peak == 0.0:
        c.text_center("NO RAIN IN 60 DAYS", 18, font="4x7", color="amber")
        return
    c.text_stroke(_fmt_hundredths(total / len(days)) + " IN/DAY", 127, 12,
                  font="5x7", color="amber", stroke="black", align="right")
