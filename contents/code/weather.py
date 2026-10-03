#!/usr/bin/env python3
"""Print the current outdoor weather at a location as JSON, via Open-Meteo.

Usage: weather.py <latitude> <longitude> <celsius|fahrenheit>
Output: {"temp": 11.4, "code": 3, "day": true, "feels": 9.8, "humidity": 71,
         "wind": 4.2, "windUnit": "m/s", "windDir": 225, "high": 13.1, "low": 7.0,
         "rainChance": 20, "sunrise": "07:25", "sunset": "18:42"}

Results are cached in $XDG_RUNTIME_DIR for 10 minutes so the widget can
poll freely. Prints nothing on failure (unless a stale result exists).
"""
import json
import os
import sys
import time
import urllib.parse
import urllib.request

CACHE = os.path.join(os.environ.get("XDG_RUNTIME_DIR", "/tmp"), "deskclock_weather_v2.json")
TTL = 600


def main():
    if len(sys.argv) < 3:
        return
    lat, lon = float(sys.argv[1]), float(sys.argv[2])
    unit = sys.argv[3] if len(sys.argv) > 3 else "celsius"
    now = time.time()
    key = f"{lat:.4f},{lon:.4f}|{unit}"

    try:
        with open(CACHE) as f:
            cache = json.load(f)
    except (OSError, ValueError):
        cache = {}

    hit = cache.get(key)
    if hit and now - hit["t"] < TTL:
        print(json.dumps(hit["data"]))
        return

    q = urllib.parse.urlencode({
        "latitude": lat,
        "longitude": lon,
        "current": "temperature_2m,weather_code,is_day,apparent_temperature,relative_humidity_2m,"
                   "wind_speed_10m,wind_direction_10m",
        "daily": "temperature_2m_max,temperature_2m_min,precipitation_probability_max,sunrise,sunset",
        "forecast_days": 1,
        "timezone": "auto",
        "temperature_unit": unit,
        "wind_speed_unit": "mph" if unit == "fahrenheit" else "ms",
    })
    req = urllib.request.Request(f"https://api.open-meteo.com/v1/forecast?{q}",
                                 headers={"User-Agent": "deskclock-plasmoid"})
    try:
        with urllib.request.urlopen(req, timeout=8) as r:
            res = json.load(r)
        cur, day = res["current"], res["daily"]
        data = {
            "temp": cur["temperature_2m"],
            "code": cur["weather_code"],
            "day": bool(cur["is_day"]),
            "feels": cur["apparent_temperature"],
            "humidity": cur["relative_humidity_2m"],
            "wind": cur["wind_speed_10m"],
            "windUnit": "mph" if unit == "fahrenheit" else "m/s",
            "windDir": cur["wind_direction_10m"],
            "high": day["temperature_2m_max"][0],
            "low": day["temperature_2m_min"][0],
            "rainChance": day["precipitation_probability_max"][0],
            # ISO local times like "2026-10-03T07:25" -> "07:25"
            "sunrise": day["sunrise"][0][-5:],
            "sunset": day["sunset"][0][-5:],
        }
    except (OSError, ValueError, KeyError):
        # Offline or API hiccup: fall back to the last result, however old.
        if hit:
            print(json.dumps(hit["data"]))
        return

    cache[key] = {"t": now, "data": data}
    try:
        with open(CACHE, "w") as f:
            json.dump(cache, f)
    except OSError:
        pass
    print(json.dumps(data))


if __name__ == "__main__":
    main()
