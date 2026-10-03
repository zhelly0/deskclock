#!/usr/bin/env python3
"""Search places by name via Open-Meteo geocoding and print matches as JSON.

Usage: geocode.py <query> [language]
Output: [{"name": "Stockholm", "region": "Stockholm County",
          "country": "Sweden", "lat": 59.32938, "lon": 18.06871}, ...]
Prints [] when nothing matches or the lookup fails.
"""
import json
import sys
import urllib.parse
import urllib.request


def main():
    query = sys.argv[1].strip() if len(sys.argv) > 1 else ""
    lang = sys.argv[2] if len(sys.argv) > 2 else "en"
    results = []
    if len(query) >= 2:
        q = urllib.parse.urlencode({"name": query, "count": 8, "language": lang, "format": "json"})
        req = urllib.request.Request(f"https://geocoding-api.open-meteo.com/v1/search?{q}",
                                     headers={"User-Agent": "deskclock-plasmoid"})
        try:
            with urllib.request.urlopen(req, timeout=8) as r:
                for p in json.load(r).get("results") or []:
                    results.append({
                        "name": p["name"],
                        "region": p.get("admin1", ""),
                        "country": p.get("country", ""),
                        "lat": p["latitude"],
                        "lon": p["longitude"],
                    })
        except (OSError, ValueError, KeyError):
            pass
    print(json.dumps(results))


if __name__ == "__main__":
    main()
