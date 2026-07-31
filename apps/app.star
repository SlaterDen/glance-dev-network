# app.star - My PWS Weather (multi-page)

def get_obs(ctx):
    station = ctx.inputs.get("stationid", "")
    apikey = ctx.inputs.get("apikey", "")
    
    if not station or not apikey:
        return None
    
    url = "https://api.weather.com/v2/pws/observations/current"
    params = {
        "stationId": station,
        "format": "json",
        "units": "e",
        "apiKey": apikey
    }
    
    resp = http.get(url, params=params, ttl_seconds=120)
    if resp["status_code"] != 200:
        return None
    
    data = resp["json"]
    obs = data.get("observations", [{}])[0]
    return obs if obs else None

def get_pressure_trend(station, apikey):
    """
    Returns True if pressure has risen or fallen by 0.10 inHg
    within the last ~30 minutes.
    """
    url = "https://api.weather.com/v2/pws/observations/all/1day"
    params = {
        "stationId": station,
        "format": "json",
        "units": "e",
        "apiKey": apikey
    }
    
    resp = http.get(url, params=params, ttl_seconds=180)
    
    if resp["status_code"] != 200:
        return False
    
    observations = resp["json"].get("observations", [])
    if len(observations) < 2:
        return False
    
    # Take the most recent readings (last ~30 min)
    # Most PWS report every 5 minutes → last 6–8 observations ≈ 30 min
    recent = observations[-8:] if len(observations) >= 8 else observations
    
    pressures = []
    for o in recent:
        imp = o.get("imperial", {})
        p = imp.get("pressure")
        if p == None:
            # fallback for some stations
            p = imp.get("pressureMax") or imp.get("pressureMin")
        if p != None:
            pressures.append(float(p))
    
    if len(pressures) < 2:
        return False
    
    # Biggest swing in the window
    high = max(pressures)
    low = min(pressures)
    swing = high - low
    
    # Trigger on ±0.10 inHg change
    if swing >= 0.005:
        return True
    
    return False

def get_conditions(obs, is_day, station, apikey):
    temp = int(obs.get("imperial", {}).get("temp", 70))
    humidity = int(obs.get("humidity", 50))
    wind = int(obs.get("imperial", {}).get("windSpeed", 0))
    gust     = int(obs.get("imperial", {}).get("windGust", 0) or 0)
    precipTotal = float(obs.get("imperial", {}).get("precipTotal", 0) or 0)
    rate = float(obs.get("imperial", {}).get("precipRate", 0) or 0)
    pressure = float(obs.get("imperial", {}).get("pressure", 30.0) or 30.0)
    
    falling_pressure = get_pressure_trend(station, apikey)
    
    # 1. Extreme Anomalies
    if wind >= 40 and rate >= 0.50 and pressure <= 29.50:
        return "DANGEROUS", "tornado.png", "red"
    
    # 2. Thunderstorm Layer
    if (rate >= 0.10 or wind >= 20) and falling_pressure:
        return "SEVERE T-STORM", "thunderstorms-extreme-rain.png", "orange"
    if rate >= 0.05 and falling_pressure:
        return "THUNDERSTORM", "thunderstorms-overcast.png", "yellow"
    if rate > 0.0 and falling_pressure:
        return "THUNDERSTORM", "thunderstorms-rain.png", "yellow"
    if falling_pressure and rate > 0.0 and humidity > 75:
        return "OVERCAST", "extreme.png", "5A636A"
    
    # 3. Wind-Driven Rain
    if rate > 0.01 and wind >= 20 and not falling_pressure:
        return "WINDY RAIN", "umbrella-wind.png", "blue"
    
    # 4. Standard Liquid Precipitation
    if rate >= 0.10:
        return "HEAVY RAIN", "extreme-rain.png", "0055ff"
    if rate >= 0.05:
        return "RAINING", "rain.png", "blue"
    if rate >= 0.02:
        return "SHOWERS", "drizzle.png", "blue"
    if rate > 0.0:
        return "DRIZZLE", "raindrops.png", "blue"
   
    # 5. Frozen Precipitation
    if rate > 0.0 and temp >= 31 and temp <= 35:
        return "SLEET", "sleet.png", "blue"
    if rate == 0 and temp <= 32 and humidity >= 85 and falling_pressure:
        return "SNOWING", "snow.png", "blue"
    if rate == 0 and temp <= 32 and humidity >= 80:
        return "FLURRIES", "snow.png", "blue"
    
    # 6. Dry Environmental Anomalies
    if rate == 0 and wind >= 15:
        return "WINDY", "wind.png", "5A636A"
    if temp >= 100 and humidity <=40 and is_day:
        return "SUNNY AND HOT", "thermometer-sun.png", "amber"
    if rate == 0 and humidity >= 97:
     if is_day:
        return "FOGGY", "fog-day.png", "5A636A"
     else:
        return "FOGGY", "fog-night.png", "5A636A"
    
    # 7. Ambient Sky Guessing
    if pressure <= 29.70 and precipTotal >= 0.0 and humidity >= 65:
        return "OVERCAST", "overcast.png", "5A636A"
    if rate == 0 and humidity >= 65:
        return "CLOUDY", "cloudy.png", "5A636A"
    if rate == 0 and humidity >= 40 and humidity <= 65:
     if is_day:
        return "PARTLY CLOUDY", "partly-sun-day.png", "skyblue"
     else:
        return "PARTLY CLOUDY", "partly-cloudy-night.png", "skyblue"
    
    # Default fallback
    if is_day:
        return "SUNNY", "clear-day.png", "skyblue"
    else:
        return "CLEAR", "clear-night.png", "skyblue"

def main(c, ctx):
    location = ctx.inputs.get("location", "")
    obs = get_obs(ctx)
    
    c.fill("black")
    
    if not obs:
     # Header
     c.rect(0, 0, 191, 8, fill="red")
     c.text("PWS ERROR", 69, 1, font="5x7", color="black")
    
     # Logo
     c.image("WUnderground.png", 4, 9, w=25, h=20)
    
     # Two left-aligned lines next to the logo
     c.text("NO DATA FROM WEATHER UNDERGROUND", 32, 12, font="4x5", color="amber")
     c.text("ENTER API KEY + STATION ID", 32, 22, font="4x5", color="amber")
     return
    
    # ---- Data ----
    temp = int(obs.get("imperial", {}).get("temp", 0))
    humidity = int(obs.get("humidity", 0))
    pressure = obs.get("imperial", {}).get("pressure", 0)
    dewpt = int(obs.get("imperial", {}).get("dewpt", 0))
    heat_index = int(obs.get("imperial", {}).get("heatIndex", temp))
    wind_chill = int(obs.get("imperial", {}).get("windChill", temp))
    precip = obs.get("imperial", {}).get("precipRate", 0) or 0
    uv = obs.get("uv", 0) or 0
    
    # Location
    if location:
        loc = location.upper()[:16]
    else:
        # 1. Try to grab the clean city name first
        # 2. Fall back to neighborhood if city is missing
        # 3. Fall back to "PWS" if everything is missing
        city_name = obs.get("city") or obs.get("neighborhood") or "N/A"
        loc = city_name.upper()[:16]

    
    # Feels-like logic
    if temp >= 70:
        feels = heat_index
        feels_label = "HEAT"
    else:
        feels = wind_chill
        feels_label = "CHILL"
    
    # ---- Day / Night ----
    is_day = True
    local_time = obs.get("obsTimeLocal", "")
    if len(local_time) >= 13:
        hour_str = local_time[11:13]
        if hour_str.isdigit():
            hour = int(hour_str)
            is_day = hour >= 6 and hour < 19

    # Add a variable name (like icon_img) to capture the 3rd returned value
    station = ctx.inputs.get("stationid", "")
    apikey  = ctx.inputs.get("apikey", "")

    condition_text, icon_img, header_color = get_conditions(obs, is_day, station, apikey)
    
    update_text = condition_text.upper()

    # Flip text to white on dark backgrounds so it stays legible
    text_color = "black"
    if header_color in ["red", "purple", "0055ff", "5A636A"]:
        text_color = "white"

    # ==========================================
    # ---- Render Header ----
    # ==========================================
    c.rect(0, 0, 191, 8, fill=header_color)
    
    # Condition text on the left
    c.text(update_text, 2, 1, font="5x7", color=text_color)
    
    # Location text on the right
    update_x = 192 - (len(loc) * 6) - 2
    c.text(loc, update_x, 1, font="5x7", color=text_color)

    
    # ---- Icon + Temperature ----
    c.image(icon_img, 2, 5, w=24, h=24)
    
    temp_color = "white"
    if temp > 89:
        temp_color = "red"
    elif temp > 79:
        temp_color = "orange"
    elif temp > 59:
        temp_color = "green"
    elif temp > 33:
        temp_color = "skyblue"
    else:
        temp_color = "blue"
    
    c.text(str(temp), 26, 10, font="7x14", color=temp_color)
    deg_x = 21 + len(str(temp)) * 10 + 2
    c.rect(deg_x, 11, deg_x+2, 13, fill=temp_color)

    # ---- Feels-like logic ----
    heat_index = int(obs.get("imperial", {}).get("heatIndex", temp))
    wind_chill = int(obs.get("imperial", {}).get("windChill", temp))

    feels = None
    feels_color = "white"

    if heat_index > temp:
     feels = heat_index
    elif wind_chill < temp:
     feels = wind_chill
    else:
     feels = temp

    # Color rules
    if feels != None:
     diff = feels - temp
    if diff < 0:
        diff = -diff          # absolute difference
    
    if diff <= 5:
        feels_color = "white" 
    elif feels > 69:
        feels_color = "orange"
    elif feels < 49:
        feels_color = "blue"
    else:
        feels_color = "white"

    c.text("FEEL " + str(feels), 7, 26, font="4x5", color=feels_color)
    
    # ---- Dynamic colors ----
    # Air Pressure color
    if pressure >= 29.90:
     pres_color = "puregreen"
    elif pressure >= 29.80:
     pres_color = "skyblue"
    else:
     pres_color = "orange"

    # Humidity color
    if humidity >= 70:
     hum_color = "blue"
    elif humidity >= 40:
     hum_color = "green"
    elif humidity >= 10:
     hum_color = "amber"
    else:
     hum_color = "red"          # below 10%

# ---- Gauges ----
    # Air Pressure gauge
    c.gauge(72, 31, 21, min(100, int((pressure - 28.70) * 50)), color=pres_color, label="")
    c.text("PRES", 62, 18, font="4x5", color=pres_color)
    # Force two decimal places for pressure
    pressure_str = str(int(pressure * 100) / 100)
    if pressure_str.find(".") == -1:
     pressure_str += ".00"
    elif len(pressure_str.split(".")[1]) == 1:
     pressure_str += "0"
    c.text(pressure_str, 60, 25, font="4x5", color="white")
    
    # Humidity gauge
    c.gauge(121, 31, 21, humidity, color=hum_color, label="")
    c.text("HUMID", 110, 18, font="4x5", color=hum_color)
    c.text(str(humidity) + "%", 115, 25, font="4x5", color="white")

    # Dewpoint (icon + value)
    c.image("thermometer-raindrop.png", 142, 11, w=24, h=24)
    c.text("DEW", 160, 10, font="5x5", color="skyblue")
    c.text(str(dewpt), 165, 17, font="8x12", color="skyblue")
    dew_deg_x = 165 + len(str(dewpt)) * 9 + 1
    c.rect(dew_deg_x, 18, dew_deg_x+1, 19, fill="skyblue")

def get_wind_color(val):
    if val > 30:
        return "red"
    elif val > 20:
        return "orange"
    elif val > 13:
        return "amber"
    else:
        return "puregreen"

def wind(c, ctx):
    obs = get_obs(ctx)
    c.fill("black")
    
    if not obs:
     # Header
     c.rect(0, 0, 191, 8, fill="red")
     c.text("PWS ERROR", 69, 1, font="5x7", color="black")
    
     # Two lines of message (centered)
     c.text("NO DATA FROM WEATHER UNDERGROUND", 16, 12, font="4x5", color="amber")
     c.text("ENTER API KEY + STATION ID", 31, 22, font="4x5", color="amber")
     return
    
    speed = int(obs.get("imperial", {}).get("windSpeed", 0))
    gust     = int(obs.get("imperial", {}).get("windGust", 0) or 0)
    direction = int(obs.get("winddir", 0))
     
    # 1. Evaluate Speeds Against Custom Thresholds
    speed_color = get_wind_color(speed)
    gust_color = get_wind_color(gust)

    # 2. Compass Conversion
    dirs = ["NORTH", "NNE", "NE", "ENE", "EAST", "ESE", "SE", "SSE",
            "SOUTH", "SSW", "SW", "WSW", "WEST", "WNW", "NW", "NNW"]
    compass = dirs[int((direction + 11.25) / 22.5) % 16]

    # ==========================================
    # GLOBAL HEADER BANNER (0,0 to 191,8)
    # ==========================================
    c.rect(0, 0, 191, 8, fill="5A636A")
    header_text = "CURRENT WINDS"
    header_x = (192 - (len(header_text) * 6)) // 2  # 5x7 font width is 6px per char with gap
    c.text(header_text, header_x, 1, font="5x7", color="yellow")

    # ==========================================
    # COLUMN 1: SUSTAINED WIND (0 to 62)
    # ==========================================
    c.text("SPEED", 17, 11, font="5x7", color="skyblue")
    
    # Calculate combined width of large number (7px wide) and "MPH" (5px wide per char)
    # Total " MPH" = 4 characters * 6px spacing = 24px wide
    speed_str = str(speed)
    col1_total_w = (len(speed_str) * 7) + 24
    col1_start_x = 0 + ((62 - col1_total_w) // 2)
    
    # Render value and label inline
    c.text(speed_str, col1_start_x, 20, font="7x12", color=speed_color)
    c.text(" MPH", col1_start_x + (len(speed_str) * 6), 20, font="6x8", color="gray")

    # Column Divider
    c.rect(63, 11, 64, 29, fill="yellow")

    # ==========================================
    # COLUMN 2: GUSTS (65 to 127)
    # ==========================================
    c.text("GUST", 85, 11, font="5x7", color="skyblue")
    
    # Calculate combined width
    gust_str = str(gust)
    col2_total_w = (len(gust_str) * 7) + 24
    col2_start_x = 65 + ((62 - col2_total_w) // 2)
    
    # Render value and label inline
    c.text(gust_str, col2_start_x, 20, font="7x12", color=gust_color)
    c.text(" MPH", col2_start_x + (len(gust_str) * 6), 20, font="7x12", color="gray")

    # Column Divider
    c.rect(128, 11, 129, 29, fill="yellow")

    # ==========================================
    # COLUMN 3: DIRECTION (131 to 191)
    # ==========================================
    c.text("DIRECTION", 134, 11, font="5x7", color="skyblue")
    
    # Column 3 width is roughly 131 → 191 (60 px wide)
    col3_left = 131
    col3_width = 60

    # Just the compass (recommended – cleanest)
    compass_w = len(compass) * 7          # 7x12 font ≈ 7 px wide
    compass_x = col3_left + ((col3_width - compass_w) // 2)

    c.text(compass, compass_x, 21, font="7x12", color="yellow")


def get_rain_status(rate):
    if rate > 0.30:
        return "DOWNPOUR", "red"
    elif rate > 0.20:
        return "HEAVY", "orange"
    elif rate > 0.04:
        return "MODERATE", "amber"
    elif rate > 0:
        return "LIGHT", "puregreen"
    else:
        return "DRY", "white"

def rain(c, ctx):
    station = ctx.inputs.get("stationid", "")
    apikey = ctx.inputs.get("apikey", "")
    
    c.fill("black")
    
    if not station or not apikey:
        c.rect(0, 0, 191, 8, fill="red")
        c.text("PWS ERROR", 69, 1, font="5x7", color="black")
        c.text("NO DATA FROM WEATHER UNDERGROUND", 16, 12, font="4x5", color="amber")
        c.text("ENTER API KEY + STATION ID", 31, 22, font="4x5", color="amber")
        return
    
    # ---- Current observation (for the numbers) ----
    url = "https://api.weather.com/v2/pws/observations/current"
    params = {
        "stationId": station,
        "format": "json",
        "units": "e",
        "apiKey": apikey
    }
    resp = http.get(url, params=params, ttl_seconds=120)
    
    today = 0.0
    rate = 0.0
    
    if resp["status_code"] == 200:
        obs = resp["json"].get("observations", [{}])[0]
        if obs:
            today = float(obs.get("imperial", {}).get("precipTotal", 0) or 0)
            rate = float(obs.get("imperial", {}).get("precipRate", 0) or 0)

   # ---- Early exit when no rain today ----
    if today == 0.0:
     c.rect(0, 0, 191, 8, fill="0055ff")
     header_text = "RAIN MONITOR"
     header_x = (192 - (len(header_text) * 6)) // 2  # 5x7 font width is 6px per char with gap
     c.text(header_text, header_x, 1, font="5x7", color="white")
       
     msg = "NO RAIN DETECTED TODAY"
     msg_x = (192 - len(msg) * 7) // 2          # 6x8 font ≈ 7 px wide
     c.text(msg, msg_x, 16, font="6x8", color="cyan")
     return
    
    # ---- Historical data for sparklines ----
    hist_url = "https://api.weather.com/v2/pws/observations/hourly/7day"
    hist_params = {
        "stationId": station,
        "format": "json",
        "units": "e",
        "apiKey": apikey
    }
    hist_resp = http.get(hist_url, params=hist_params, ttl_seconds=300)
    
    rate_list = [0, 0, 0, 0]
    total_list = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    
    if hist_resp["status_code"] == 200:
        observations = hist_resp["json"].get("observations", [])
        
        # Last 12 hours for Today Total
        recent12 = observations[-12:] if len(observations) >= 12 else observations
        total_list = []
        for o in recent12:
            total_list.append(float(o.get("imperial", {}).get("precipTotal", 0) or 0))
        
        # Last 4 hours for Rate
        recent4 = observations[-4:] if len(observations) >= 4 else observations
        rate_list = []
        for o in recent4:
            rate_list.append(float(o.get("imperial", {}).get("precipRate", 0) or 0))
    
    # Make sure lists are never empty
    if len(total_list) == 0:
        total_list = [0]
    if len(rate_list) == 0:
        rate_list = [0]
    
    status_text, status_color = get_rain_status(rate)
    
    data_color = "white" if status_text == "DRY" else status_color
    
    # ---- Header ----
    c.rect(0, 0, 191, 8, fill="0055ff")
    header_text = "RAIN MONITOR"
    header_x = (192 - (len(header_text) * 6)) // 2  # 5x7 font width is 6px per char with gap
    c.text(header_text, header_x, 1, font="5x7", color="white")
    
    # Color for Today total (based on amount)
    if today >= 5.0:
     today_color = "red"
    elif today >= 2.0:
     today_color = "orange"
    elif today >= 1.0:
     today_color = "amber"
    elif today > 0:
     today_color = "puregreen"
    else:
     today_color = "white"

    # ---- Column 1: TODAY ----
    c.text("TODAY", 16, 11, font="5x7", color="skyblue")
    today_str = str(today)
    c.text(today_str, 10, 20, font="6x8", color=today_color)
    c.text(" IN", 10 + len(today_str)*7, 20, font="6x8", color="gray")
    c.sparkline(total_list, 3, 28, 57, 4, color="skyblue")
   
    # Divider
    c.rect(63, 11, 64, 29, fill="0055ff")
    
    # ---- Column 2: RATE ----
    c.text("RATE", 85, 11, font="5x7", color="skyblue")
    c.text(str(rate), 75, 20, font="6x8", color=status_color)
    c.text(" IN", 73 + len(str(rate))*7, 20, font="6x8", color="gray")
    c.sparkline(rate_list, 68, 28, 57, 4, color="skyblue")
    
    # Divider
    c.rect(128, 11, 129, 29, fill="0055ff")
    
    # ---- Column 3: STATUS (centered) ----
    c.text("STATUS", 143, 11, font="5x7", color="skyblue")
    
    status_w = len(status_text) * 6
    status_x = 126 + ((62 - status_w) // 2)
    c.text(status_text, status_x, 20, font="6x8", color=status_color)