#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# ─────────────────────────────────────────────────────────────
# File        : docker-entrypoint.py
# Version     : v2.0 — 2026-06-08
# Deploy      : /entrypoint.py (inside Docker image)
# Description : RadarVirtuel Docker feeder entrypoint v2.0
#               1. Station UID — CPU serial host > volume > UUID généré
#               2. Lat/lon — env vars > /etc/default/mlat-client monté
#               3. Nearest airport via radarvirtuel.com API
#               4. Register station via /api/station/register
#               5. Génère config.json pour feeder_radarvirtuel.py
#               6. Heartbeat thread — POST /api/station/feed_ping toutes les 60s
#               7. Lance feeder_radarvirtuel.py en subprocess
# v2.0 : remplace socat par feeder_radarvirtuel.py — POST /api/feed avec tagging station
# ─────────────────────────────────────────────────────────────

import os
import sys
import json
import uuid
import urllib.request
import urllib.error
import threading
import subprocess
import time

RV_REGISTER  = 'https://radarvirtuel.com/api/station/register'
RV_FEED_PING = 'https://radarvirtuel.com/api/station/feed_ping'
UID_FILE     = '/data/station_uid.txt'
CONFIG_FILE  = '/opt/feeder_rv/config.json'
UA           = 'Mozilla/5.0 (compatible; RadarVirtuel-feeder/2.0)'

def log(msg):
    print(f"[RV] {msg}", flush=True)

def api_get(url):
    req = urllib.request.Request(url, headers={'User-Agent': UA})
    with urllib.request.urlopen(req, timeout=10) as r:
        return json.loads(r.read().decode())

def api_post(url, payload_dict, uid):
    payload = json.dumps(payload_dict).encode('utf-8')
    req = urllib.request.Request(
        url, data=payload,
        headers={
            'Content-Type':  'application/json',
            'X-Station-UID': uid,
            'User-Agent':    UA,
        },
        method='POST'
    )
    with urllib.request.urlopen(req, timeout=15) as r:
        return json.loads(r.read().decode())

# ── Station UID ───────────────────────────────────────────────
# Priority 1 : RV_STATION_UID env var
# Priority 2 : CPU serial from host /proc/cpuinfo (mounted as /host/cpuinfo)
# Priority 3 : persisted UUID in Docker volume /data/station_uid.txt
# Priority 4 : generate new UUID and persist it
def get_or_create_uid():
    env_uid = os.environ.get('RV_STATION_UID', '').strip()
    if env_uid and len(env_uid) >= 8:
        log(f"UID from environment: {env_uid}")
        return env_uid
    try:
        with open('/host/cpuinfo') as f:
            for line in f:
                if line.startswith('Serial'):
                    serial = line.split(':')[1].strip().lstrip('0')
                    if serial and len(serial) >= 8:
                        log(f"UID from CPU serial: {serial}")
                        return serial
    except Exception:
        pass
    os.makedirs('/data', exist_ok=True)
    if os.path.exists(UID_FILE):
        uid = open(UID_FILE).read().strip()
        if uid and len(uid) >= 8:
            log(f"UID loaded from {UID_FILE}: {uid}")
            return uid
    uid = uuid.uuid4().hex
    open(UID_FILE, 'w').write(uid)
    log(f"UID generated: {uid} → saved to {UID_FILE}")
    return uid

# ── Coordinates ───────────────────────────────────────────────
# Priority 1 : RV_LAT / RV_LON env vars
# Priority 2 : /etc/default/mlat-client monté dans le container
def get_coords():
    lat = os.environ.get('RV_LAT', '').strip()
    lon = os.environ.get('RV_LON', '').strip()
    alt = os.environ.get('RV_ALT_M', '0').strip()
    if not lat or not lon:
        try:
            with open('/etc/default/mlat-client') as f:
                for line in f:
                    line = line.strip()
                    if line.startswith('LAT='):
                        lat = line.split('=', 1)[1].strip().strip('"')
                    elif line.startswith('LON='):
                        lon = line.split('=', 1)[1].strip().strip('"')
                    elif line.startswith('ALT=') and not alt:
                        alt = line.split('=', 1)[1].strip().strip('"')
            if lat and lon:
                log(f"Coordinates from /etc/default/mlat-client")
        except Exception:
            pass
    if not lat or not lon:
        log("ERROR: RV_LAT and RV_LON must be set (env vars or mount /etc/default/mlat-client)")
        sys.exit(1)
    try:
        return float(lat), float(lon), float(alt or 0)
    except ValueError:
        log(f"ERROR: Invalid coordinates: lat={lat} lon={lon}")
        sys.exit(1)

# ── Nearest airport ───────────────────────────────────────────
def get_nearest_airport(lat, lon):
    try:
        data     = api_get(f"https://radarvirtuel.com/api/nearest_airport?lat={lat}&lon={lon}")
        airports = data.get('airports', [])
        if airports:
            first     = airports[0]
            icao      = first.get('icao_code', '')
            name      = first.get('name', '')
            dist      = first.get('distance_km', 0)
            suggested = first.get('suggested_label', f"{icao}1")
            log(f"Nearest airport: {icao} — {name} ({dist:.1f} km) → suggested: {suggested}")
            return suggested, first
    except Exception as e:
        log(f"Warning: nearest_airport API: {e}")
    return None, {}

# ── Station label ─────────────────────────────────────────────
def get_station_label(suggested_label):
    label = os.environ.get('RV_STATION_LABEL', '').strip().upper()
    if label:
        log(f"Label from environment: {label}")
        return label
    if not suggested_label:
        log("ERROR: RV_STATION_LABEL must be set (no nearest airport found)")
        sys.exit(1)
    log(f"Label auto-selected: {suggested_label}")
    return suggested_label

# ── Validate contrib info ─────────────────────────────────────
def get_contrib_info():
    name  = os.environ.get('RV_CONTRIB_NAME', '').strip()
    email = os.environ.get('RV_CONTRIB_EMAIL', '').strip()
    if not name:
        log("ERROR: RV_CONTRIB_NAME must be set")
        sys.exit(1)
    if not email or '@' not in email:
        log("ERROR: RV_CONTRIB_EMAIL must be set (valid email address)")
        sys.exit(1)
    return name, email

# ── Register station ──────────────────────────────────────────
def register_station(uid, label, lat, lon, alt_m, name, email):
    try:
        resp = api_post(RV_REGISTER, {
            'station_uid':   uid,
            'station_label': label,
            'lat':           lat,
            'lon':           lon,
            'alt_m':         alt_m,
            'contrib_name':  name,
            'contrib_email': email,
            'description':   f"Docker feeder — {label}",
        }, uid)
        status = resp.get('status', '?').upper()
        actual = resp.get('station_label', label)
        log(f"Registration: {status} — station {actual} uid={uid}")
        return resp.get('ok', False), actual
    except urllib.error.HTTPError as e:
        body = e.read().decode('utf-8', errors='replace')
        log(f"Registration HTTP {e.code}: {body[:200]}")
        return True, label
    except Exception as e:
        log(f"Registration warning: {e} — continuing")
        return True, label

# ── Generate config.json for feeder_radarvirtuel.py ───────────
def generate_config(uid, label, lat, lon, alt_m, name, email):
    aircraft_url = os.environ.get('RV_AIRCRAFT_URL', 'http://localhost/tar1090/data/aircraft.json')
    interval     = int(os.environ.get('RV_INTERVAL', '5'))
    config = {
        "terrain": {
            "nom":        label,
            "latitude":   lat,
            "longitude":  lon,
            "altitude_m": alt_m,
            "contrib_name":  name,
            "contrib_email": email,
        },
        "radarvirtuel": {
            "url":         "https://radarvirtuel.com/api/feed",
            "station_uid": uid,
            "enabled":     True,
            "interval_s":  interval,
        },
        "aircraft_sources": [
            aircraft_url,
            "http://localhost/tar1090/data/aircraft.json",
            "http://localhost/dump1090/data/aircraft.json",
            "http://localhost:8080/data/aircraft.json",
        ]
    }
    os.makedirs(os.path.dirname(CONFIG_FILE), exist_ok=True)
    with open(CONFIG_FILE, 'w') as f:
        json.dump(config, f, indent=2)
    log(f"Config written: {CONFIG_FILE}")
    log(f"  aircraft_url : {aircraft_url}")
    log(f"  station_uid  : {uid}")
    log(f"  label        : {label}")
    log(f"  contrib      : {name} <{email}>")

# ── Heartbeat thread ──────────────────────────────────────────
def heartbeat_loop(uid, label, interval=60):
    """POST /api/station/feed_ping toutes les 60s — maintient le statut ONLINE."""
    log(f"Heartbeat started — ping every {interval}s")
    while True:
        time.sleep(interval)
        try:
            resp = api_post(RV_FEED_PING, {'station_uid': uid}, uid)
            if resp.get('ok'):
                log(f"Heartbeat OK — station {label}")
            else:
                log(f"Heartbeat warning: {resp.get('error','?')}")
        except Exception as e:
            log(f"Heartbeat error: {e}")

# ── Patch AIRCRAFT_SOURCES dans feeder_radarvirtuel.py ───────
def patch_feeder_sources():
    """Remplace localhost par RV_AIRCRAFT_URL dans AIRCRAFT_SOURCES du feeder."""
    aircraft_url = os.environ.get('RV_AIRCRAFT_URL', '').strip()
    if not aircraft_url or 'localhost' in aircraft_url or '127.0.0.1' in aircraft_url:
        return  # Pas besoin de patch si localhost ou non défini
    feeder_path = '/opt/feeder_rv/feeder_radarvirtuel.py'
    try:
        with open(feeder_path) as f:
            src = f.read()
        # Insérer RV_AIRCRAFT_URL en tête de AIRCRAFT_SOURCES
        old = "AIRCRAFT_SOURCES = ["
        new = f"AIRCRAFT_SOURCES = [\n    '{aircraft_url}',"
        if aircraft_url not in src:
            src = src.replace(old, new)
            with open(feeder_path, 'w') as f:
                f.write(src)
            log(f"Feeder patched — aircraft URL: {aircraft_url}")
        else:
            log(f"Feeder already patched — aircraft URL: {aircraft_url}")
    except Exception as e:
        log(f"Warning: cannot patch feeder sources: {e}")

# ── Launch feeder_radarvirtuel.py ─────────────────────────────
def launch_feeder():
    """Lance feeder_radarvirtuel.py en subprocess avec restart automatique."""
    patch_feeder_sources()
    cmd = ['python3', '-u', '/opt/feeder_rv/feeder_radarvirtuel.py']
    log(f"Launching feeder_radarvirtuel.py...")
    log("─" * 50)
    while True:
        proc = subprocess.Popen(cmd)
        ret  = proc.wait()
        log(f"feeder exited (code {ret}) — restarting in 5s")
        time.sleep(5)

# ── Main ──────────────────────────────────────────────────────
def main():
    log("=" * 50)
    log("RadarVirtuel Docker Feeder v2.0 — 2026-06-08")
    log("=" * 50)

    uid             = get_or_create_uid()
    lat, lon, alt_m = get_coords()
    name, email     = get_contrib_info()
    log(f"Position   : lat={lat} lon={lon} alt={alt_m}m")
    log(f"Contributor: {name} <{email}>")

    suggested, _    = get_nearest_airport(lat, lon)
    label           = get_station_label(suggested)
    _, label        = register_station(uid, label, lat, lon, alt_m, name, email)

    generate_config(uid, label, lat, lon, alt_m, name, email)

    # Heartbeat thread daemon
    threading.Thread(
        target=heartbeat_loop, args=(uid, label, 60), daemon=True
    ).start()

    launch_feeder()

if __name__ == '__main__':
    main()
