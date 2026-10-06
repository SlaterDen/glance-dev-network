PAD = 10  # scroll safe zone: keep the outer 10 px clear of content
HEX = "0123456789abcdef"
FONT_H = {"4x5": 5, "5x7": 7, "6x8": 8, "10x16": 16}
TITLE_COLOR = "#E8C25A"
FALLBACK_TEAM_COLOR = "#B4B4B4"
MONTHS = ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"]
MONTH_DAYS = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
DEMO_TEAMS = {
    "duke": {"color": "#003087", "alt": "#ffffff"},
    "north carolina": {"color": "#7BAFD4", "alt": "#ffffff"},
}

# Rivalry names. Key = both team names lowercase, joined by "|" (either order works).
# Value = list of titles, longest first; the header uses the first one that fits.
RIVALRIES = {
    "arizona|arizona state": ["TERRITORIAL CUP"],
    "army|navy": ["ARMY-NAVY"],
    "cincinnati|xavier": ["CROSSTOWN SHOOTOUT", "CROSSTOWN"],
    "clemson|south carolina": ["PALMETTO SERIES"],
    "duke|nc state": ["TOBACCO ROAD"],
    "duke|north carolina": ["TOBACCO ROAD", "DUKE-UNC"],
    "florida|florida state": ["SUNSHINE SHOWDOWN"],
    "georgia|georgia tech": ["CLEAN, OLD-FASHIONED HATE", "OLD-FASHIONED HATE"],
    "houston|texas tech": ["LONE STAR STATE BATTLE", "LONE STAR BATTLE"],
    "illinois|missouri": ["BRAGGIN RIGHTS"],
    "indiana|purdue": ["HOOSIER STATE RIVALRY", "HOOSIER RIVALRY"],
    "iowa|iowa state": ["CY-HAWK TROPHY"],
    "byu|utah": ["THE HOLY WAR", "HOLY WAR"],
    "kansas|kansas state": ["SUNFLOWER SHOWDOWN"],
    "kansas|missouri": ["BORDER WAR"],
    "kentucky|louisville": ["BATTLE FOR THE BLUEGRASS", "BLUEGRASS BATTLE"],
    "nc state|north carolina": ["TOBACCO ROAD"],
    "new mexico|new mexico state": ["RIO GRANDE RIVALRY"],
    "oklahoma|oklahoma state": ["BEDLAM"],
    "oklahoma|texas": ["RED RIVER RIVALRY"],
    "oregon|oregon state": ["CIVIL WAR"],
    "pittsburgh|west virginia": ["BACKYARD BRAWL"],
    "texas|texas a&m": ["LONE STAR SHOWDOWN"],
    "georgetown|villanova": ["CATHOLIC SEVEN ROOTS", "CATHOLIC SEVEN"],
    "ucla|usc": ["CROSSTOWN SHOWDOWN", "CROSSTOWN"],
}

def _s(ctx, key, fallback):
    v = ctx.inputs.get(key, fallback)
    if v == None:
        return fallback
    return str(v).strip()

def _norm(name):
    return str(name).strip().lower()

def _display(s):
    # Bitmap fonts have no accents or apostrophes; they would be skipped silently.
    return str(s).replace("é", "e").replace("É", "E").replace("'", "").replace("’", "").upper()

def _absdiff(a, b):
    return a - b if a > b else b - a

def _safe_int(val):
    if val == None:
        return None
    if type(val) == "int":
        return val
    if type(val) == "float":
        return int(val)
    s = str(val).strip()
    if s.isdigit():
        return int(s.lstrip("0") or "0")
    return None

def _abbr(name, teams_map):
    if not name:
        return "TEAM"
    name_str = str(name)
    n = _norm(name_str)
    if n in teams_map and teams_map[n].get("abbreviation"):
        return _display(teams_map[n]["abbreviation"])
    if len(name_str) <= 4:
        return _display(name_str)
    parts = name_str.upper().split()
    if len(parts) >= 2:
        return _display(parts[0][:3] + parts[1][:1])
    return _display(name_str[:4])

def _hex_rgb(col):
    if col == None:
        return None
    s = str(col).strip().lower()
    if s.startswith("#"):
        s = s[1:]
    if len(s) != 6:
        return None
    rgb = []
    for i in [0, 2, 4]:
        hi = HEX.find(s[i])
        lo = HEX.find(s[i + 1])
        if hi < 0 or lo < 0:
            return None
        rgb.append(hi * 16 + lo)
    return rgb

def _rgb_hex(rgb):
    out = "#"
    for v in rgb:
        out += HEX[v // 16] + HEX[v % 16]
    return out

def _too_close(a, b):
    ra = _hex_rgb(a)
    rb = _hex_rgb(b)
    if ra == None or rb == None:
        return False
    return _absdiff(ra[0], rb[0]) + _absdiff(ra[1], rb[1]) + _absdiff(ra[2], rb[2]) < 80

def _team_color(team_name, teams_map, avoid=None):
    # Print colors: black and deep navy vanish on an LED. Skip black, lift the rest to a
    # bright version of the same hue, and fall back to the alternate color when the primary
    # is black or too close to the other team's color (`avoid`).
    info = teams_map.get(_norm(team_name), {})
    options = []
    for key in ["color", "alt"]:
        rgb = _hex_rgb(info.get(key))
        if rgb != None and max(rgb) >= 24:
            peak = max(rgb)
            if peak < 210:
                rgb = [min(255, v * 210 // peak) for v in rgb]
            options.append(_rgb_hex(rgb))
    if avoid != None:
        distinct = [o for o in options + [FALLBACK_TEAM_COLOR] if not _too_close(o, avoid)]
        if distinct:
            return distinct[0]
    return options[0] if options else FALLBACK_TEAM_COLOR

def _text_y(font, top, height):
    return top + (height - FONT_H[font]) // 2

def _fit(c, text, fonts, maxw):
    # Largest font that fits; if none does, clip the smallest and end with "..".
    for f in fonts:
        if c.text_width(text, font=f) <= maxw:
            return text, f
    f = fonts[len(fonts) - 1]
    s = text
    for _ in range(len(text)):
        if len(s) <= 1 or c.text_width(s + "..", font=f) <= maxw:
            break
        s = s[:len(s) - 1]
    cut = s.rfind(" ")
    if cut > 0 and cut * 10 >= len(s) * 7:
        s = s[:cut]
    return s.rstrip(" ,-") + "..", f

def _lv_width(c, label, value):
    return c.text_width(label, font="4x5") + 4 + c.text_width(value, font="4x5")

def _label_value(c, label, value, x, y, align):
    lw = c.text_width(label, font="4x5")
    total = _lv_width(c, label, value)
    if align == "right":
        x = x - total + 1
    elif align == "center":
        x = x - total // 2
    c.text(label, x, y, font="4x5", color="gray")
    c.text(value, x + lw + 4, y, font="4x5", color="white")

def _message(c, title, detail, color):
    # Two-line status screen: what happened, then what to do about it.
    c.text_center(title, 8, font="5x7", color=color)
    c.text_center(detail, 19, font="4x5", color="gray")

def _tags_width(c, tags):
    w = 0
    for t in tags:
        if t:
            w = max(w, c.text_width(t, font="4x5"))
    return w + 3 if w > 0 else 0

def _pick_title(c, titles, maxw):
    # Prefer any title that fits in the big font, then the small font, else clip the last one.
    for f in ["5x7", "4x5"]:
        for t in titles:
            if c.text_width(t, font=f) <= maxw:
                return t, f
    return _fit(c, titles[len(titles) - 1], ["4x5"], maxw)

def _draw_header(c, titles, label1, label2, col1, col2, full_names):
    # Team chips pinned to the safe-zone edges, rivalry name centered between them.
    right = c.width - 1 - PAD
    font = "4x5" if full_names else "5x7"
    if full_names:
        label1, _ = _fit(c, label1, ["4x5"], 56)
        label2, _ = _fit(c, label2, ["4x5"], 56)
    w1 = c.text_width(label1, font=font) + 4
    w2 = c.text_width(label2, font=font) + 4
    ty = _text_y(font, 0, 9)
    c.rect(PAD, 0, PAD + w1 - 1, 8, fill=col1)
    c.text_stroke(label1, PAD + 2, ty, font=font, color="white", stroke="black")
    c.rect(right - w2 + 1, 0, right, 8, fill=col2)
    c.text_stroke(label2, right - w2 + 3, ty, font=font, color="white", stroke="black")

    x0 = PAD + w1 + 4
    x1 = right - w2 - 4
    maxw = x1 - x0 + 1
    title, tfont = _pick_title(c, titles, maxw)
    tw = c.text_width(title, font=tfont)
    c.text(title, x0 + (maxw - tw) // 2, _text_y(tfont, 0, 9), font=tfont, color=TITLE_COLOR)

def _draw_series(c, w1, w2, col1, col2, tags1, tags2):
    # Win totals flank a tug-of-war bar; rank sits at the top of each total, streak at the bottom.
    right = c.width - 1 - PAD
    n1 = str(w1)
    n2 = str(w2)
    d1 = c.text_width(n1, font="10x16")
    d2 = c.text_width(n2, font="10x16")
    c.text(n1, PAD, 10, font="10x16", color="white")
    c.text(n2, right - d2 + 1, 10, font="10x16", color="white")

    for i in range(2):
        if tags1[i]:
            c.text(tags1[i], PAD + d1 + 3, 10 + 11 * i, font="4x5", color="white")
        if tags2[i]:
            tw = c.text_width(tags2[i], font="4x5")
            c.text(tags2[i], right - d2 - 2 - tw, 10 + 11 * i, font="4x5", color="white")

    side = max(d1 + _tags_width(c, tags1), d2 + _tags_width(c, tags2))
    bx0 = PAD + side + 4
    bx1 = right - side - 4
    bw = bx1 - bx0 + 1
    total = w1 + w2
    p1 = (bw * w1 + total // 2) // total

    c.rect(bx0, 13, bx1, 22, fill=col2)
    if p1 > 0:
        c.rect(bx0, 13, bx0 + p1 - 1, 22, fill=col1)
    sx = bx0 + p1
    if sx > bx0 and sx <= bx1:
        c.vline(sx, 13, 10, "black")

    # Midfield marker: whichever color crosses it leads the series.
    mid = bx0 + bw // 2
    c.vline(mid, 10, 2, "white")

def _draw_first_meeting(c, rank1, rank2):
    right = c.width - 1 - PAD
    side = max(_tags_width(c, [rank1]), _tags_width(c, [rank2]))
    if rank1:
        c.text(rank1, PAD, 15, font="4x5", color="white")
    if rank2:
        c.text(rank2, right - c.text_width(rank2, font="4x5") + 1, 15, font="4x5", color="white")
    maxw = right - PAD + 1 - 2 * (side + 1)
    text, font = _fit(c, "FIRST MEETING", ["10x16", "6x8", "5x7"], maxw)
    c.text_center(text, _text_y(font, 10, 16), font=font, color="white")

def _draw_demo(c, full_names):
    # No API key yet: a sample Tobacco Road screen marked DEMO.
    col1 = _team_color("Duke", DEMO_TEAMS)
    col2 = _team_color("North Carolina", DEMO_TEAMS, col1)
    label1 = "DUKE"
    label2 = "NORTH CAROLINA" if full_names else "UNC"
    _draw_header(c, ["TOBACCO ROAD"], label1, label2, col1, col2, full_names)
    _draw_series(c, 142, 112, col1, col2, ["#4", ""], ["#7", "W2"])
    _label_value(c, "LAST", "DUKE 74-71", PAD, 27, "left")
    c.text_center("DEMO", 27, font="4x5", color="amber")
    _label_value(c, "NEXT", "FEB 07", c.width - 1 - PAD, 27, "right")

def rivalry_titles(t1, t2):
    a = _norm(t1)
    b = _norm(t2)
    t = RIVALRIES.get(a + "|" + b)
    if t == None:
        t = RIVALRIES.get(b + "|" + a)
    if t == None:
        return None
    return [_display(x) for x in t]

def cbbd_get(path, params, apikey, ttl):
    return http.get(
        "https://api.collegebasketballdata.com" + path,
        headers={"Authorization": "Bearer " + apikey},
        params=params,
        ttl_seconds=ttl,
    )

def _num(s):
    return _safe_int(s)

def _fmt_date(dt_str, tbd):
    # Tip-offs are mostly evening US time, which is the next day in UTC. Shift back 8 hours
    # so the calendar day matches what fans expect (skipped when the time is TBD).
    s = str(dt_str or "")
    if len(s) < 13:
        return "TBD"
    y = _num(s[0:4])
    m = _num(s[5:7])
    d = _num(s[8:10])
    h = _num(s[11:13])
    if y == None or m == None or d == None or h == None or m < 1 or m > 12:
        return "TBD"
    if not tbd and h < 8:
        d -= 1
        if d < 1:
            m -= 1
            if m < 1:
                m = 12
                y -= 1
            d = MONTH_DAYS[m - 1]
            if m == 2 and ((y % 4 == 0 and y % 100 != 0) or y % 400 == 0):
                d = 29
    return MONTHS[m - 1] + " " + str(d)

def _season_end(ctx):
    return ctx.now.year + 1 if ctx.now.month >= 11 else ctx.now.year

def _load_teams(apikey, ctx):
    # Returns (status, name -> abbreviation/colors, name -> team id). Season is optional
    # on some endpoints, so retry without it if the first call comes back empty.
    status = 0
    rows = []
    for params in [{"season": _season_end(ctx)}, {}]:
        r = cbbd_get("/teams", params, apikey, 86400)
        status = r["status_code"]
        if status in [401, 403]:
            return status, {}, {}
        if status == 200 and type(r["json"]) == "list" and len(r["json"]) > 0:
            rows = r["json"]
            break
    teams_map = {}
    ids = {}
    for t in rows:
        school = t.get("school") or t.get("displayName") or t.get("name") or ""
        if not school:
            continue
        key = _norm(school)
        teams_map[key] = {
            "abbreviation": t.get("abbreviation"),
            "color": t.get("primaryColor") or t.get("color"),
            "alt": t.get("secondaryColor") or t.get("alternateColor"),
        }
        if t.get("id") != None:
            ids[key] = t.get("id")
    return status, teams_map, ids

def _load_rankings(apikey, ctx):
    # Latest AP poll as a map of lowercase school -> rank. Only in-season (Nov-Apr);
    # in the offseason the last poll of the old year would be misleading.
    out = {}
    if ctx.now.month >= 5 and ctx.now.month <= 10:
        return out
    end = _season_end(ctx)
    for season in [end, end - 1]:
        r = cbbd_get("/rankings", {"season": season}, apikey, 21600)
        if r["status_code"] != 200 or type(r["json"]) != "list" or len(r["json"]) == 0:
            continue
        best_week = -1
        for p in r["json"]:
            if "ap" not in _norm(p.get("pollType", "")):
                continue
            wk = _safe_int(p.get("week")) or 0
            if wk > best_week:
                best_week = wk
        for p in r["json"]:
            if "ap" not in _norm(p.get("pollType", "")):
                continue
            if (_safe_int(p.get("week")) or 0) != best_week:
                continue
            rk = _safe_int(p.get("ranking"))
            if p.get("team") and rk != None:
                out[_norm(p.get("team"))] = rk
        if len(out) > 0:
            return out
    return out

def _load_games(apikey, team, ctx):
    # One call for the team's whole history. If the API refuses a season-less query, fall
    # back to the last ten seasons. If the 3,000-game cap was hit (it keeps the oldest),
    # add the last two years so the newest games are never missing.
    r = cbbd_get("/games", {"team": team}, apikey, 86400)
    status = r["status_code"]
    if status == 200 and type(r["json"]) == "list":
        games = list(r["json"])
        if len(games) >= 3000:
            start = str(ctx.now.year - 2) + "-01-01T00:00:00Z"
            rr = cbbd_get("/games", {"team": team, "startDateRange": start}, apikey, 86400)
            if rr["status_code"] == 200 and type(rr["json"]) == "list":
                seen = {}
                for g in games:
                    seen[g.get("id")] = True
                for g in rr["json"]:
                    if not seen.get(g.get("id")):
                        games.append(g)
        return 200, games
    if status == 400:
        games = []
        end = _season_end(ctx)
        for s in range(end - 9, end + 1):
            rr = cbbd_get("/games", {"team": team, "season": s}, apikey, 86400)
            if rr["status_code"] == 200 and type(rr["json"]) == "list":
                games += rr["json"]
        if len(games) > 0:
            return 200, games
    return status, []

def _side(g, name, tid):
    # Which side of the game this team is on: "home", "away", or None.
    if _norm(g.get("homeTeam", "")) == name or (tid != None and g.get("homeTeamId") == tid):
        return "home"
    if _norm(g.get("awayTeam", "")) == name or (tid != None and g.get("awayTeamId") == tid):
        return "away"
    return None

def main(c, ctx):
    c.fill("black")

    apikey = _s(ctx, "apikey", "")
    team1 = _s(ctx, "team1", "Duke")
    team2 = _s(ctx, "team2", "North Carolina")
    full_names = _s(ctx, "teamnamelength", "Abbreviations") == "Full Name"

    if not apikey:
        _draw_demo(c, full_names)
        return

    t1n = _norm(team1)
    t2n = _norm(team2)
    if t1n == t2n:
        _message(c, "PICK TWO DIFFERENT TEAMS", "TEAM 1 AND TEAM 2 MATCH", "amber")
        return

    teams_status, teams_map, ids = _load_teams(apikey, ctx)
    if teams_status in [401, 403]:
        _message(c, "API KEY REJECTED", "CHECK THE API KEY IN SETTINGS", "red")
        return
    if len(teams_map) > 0 and (t1n not in teams_map or t2n not in teams_map):
        _message(c, "TEAM NOT RECOGNIZED", "PICK BOTH TEAMS AGAIN IN SETTINGS", "amber")
        return

    status, games = _load_games(apikey, team1, ctx)
    if status in [401, 403]:
        _message(c, "API KEY REJECTED", "CHECK THE API KEY IN SETTINGS", "red")
        return
    if status == 429:
        _message(c, "API LIMIT REACHED", "TRY AGAIN LATER", "amber")
        return
    if status != 200:
        _message(c, "API UNAVAILABLE", "CHECK KEY OR TRY AGAIN LATER", "red")
        return

    id1 = ids.get(t1n)
    id2 = ids.get(t2n)

    # Tally the series from team 1's schedule: keep only games against team 2.
    w1 = 0
    w2 = 0
    played = []
    upcoming = []
    earliest = ""
    for g in games:
        sd = str(g.get("startDate") or "")
        if sd != "" and (earliest == "" or sd < earliest):
            earliest = sd
        s1 = _side(g, t1n, id1)
        s2 = _side(g, t2n, id2)
        if s1 == None or s2 == None or s1 == s2:
            continue
        gstatus = str(g.get("status") or "")
        hp = _safe_int(g.get("homePoints"))
        ap = _safe_int(g.get("awayPoints"))
        if gstatus == "final" and hp != None and ap != None and hp != ap:
            p1 = hp if s1 == "home" else ap
            p2 = ap if s1 == "home" else hp
            played.append((sd, p1, p2))
            if p1 > p2:
                w1 += 1
            else:
                w2 += 1
        elif gstatus in ["scheduled", "in_progress"]:
            upcoming.append((sd, gstatus, 1 if g.get("startTimeTbd") == True else 0))

    played = sorted(played, reverse=True)
    upcoming = sorted(upcoming)
    total = w1 + w2

    a1 = _abbr(team1, teams_map)
    a2 = _abbr(team2, teams_map)

    titles = rivalry_titles(team1, team2)
    if titles == None:
        titles = ["ALL-TIME SERIES", "SERIES", "VS"] if total > 0 else ["HEAD TO HEAD", "VS"]

    last_game_str = "-"
    streak_who = 0
    streak_len = 0
    if len(played) > 0:
        _, p1, p2 = played[0]
        if p1 > p2:
            last_game_str = a1 + " " + str(p1) + "-" + str(p2)
        else:
            last_game_str = a2 + " " + str(p2) + "-" + str(p1)
        for _, p1, p2 in played:
            who = 1 if p1 > p2 else 2
            if streak_who == 0:
                streak_who = who
            if who != streak_who:
                break
            streak_len += 1

    next_date = "TBD"
    if len(upcoming) > 0:
        nsd, nstatus, ntbd = upcoming[0]
        next_date = "LIVE" if nstatus == "in_progress" else _fmt_date(nsd, ntbd == 1)

    since = ""
    if total > 0 and len(earliest) >= 4:
        since = "SINCE " + earliest[0:4]

    col1 = _team_color(team1, teams_map)
    col2 = _team_color(team2, teams_map, col1)
    label1 = _display(team1) if full_names else a1
    label2 = _display(team2) if full_names else a2

    rankings = _load_rankings(apikey, ctx)
    r1 = rankings.get(t1n)
    r2 = rankings.get(t2n)
    rank1 = "#" + str(r1) if r1 != None else ""
    rank2 = "#" + str(r2) if r2 != None else ""
    streak1 = "W" + str(streak_len) if streak_who == 1 else ""
    streak2 = "W" + str(streak_len) if streak_who == 2 else ""
    right = c.width - 1 - PAD

    _draw_header(c, titles, label1, label2, col1, col2, full_names)

    if total > 0:
        _draw_series(c, w1, w2, col1, col2, [rank1, streak1], [rank2, streak2])
        last_v = last_game_str.upper()
        next_v = next_date.upper()
        _label_value(c, "LAST", last_v, PAD, 27, "left")
        _label_value(c, "NEXT", next_v, right, 27, "right")
        # Coverage note in the middle, only when it fits with room on both sides.
        if since != "":
            sw = c.text_width(since, font="4x5")
            sx = c.width // 2 - sw // 2
            left_end = PAD + _lv_width(c, "LAST", last_v)
            right_start = right - _lv_width(c, "NEXT", next_v)
            if sx - left_end >= 4 and right_start - (sx + sw) >= 4:
                c.text(since, sx, 27, font="4x5", color="gray")
    else:
        _draw_first_meeting(c, rank1, rank2)
        _label_value(c, "NEXT", next_date.upper(), c.width // 2, 27, "center")
