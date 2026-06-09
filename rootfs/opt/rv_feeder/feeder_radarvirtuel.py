#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# feeder_radarvirtuel.py
# VERSION     : v1.1 — 2026-06-09 15:00 UTC
# DEPLOY PATH : /opt/feeder_rv/feeder_radarvirtuel.py
# DESCRIPTION : Feeder minimal radarvirtuel.com — compatible Debian Buster/Bullseye/Bookworm/Trixie
#               Lit aircraft.json depuis tar1090/readsb local
#               Envoie POST vers https://radarvirtuel.com/api/feed
#               Aucune dependance hors stdlib + requests
# HISTORY     :
#   v1.0 — 2026-06-02 — Creation pour LFRC (raspiv3-lfrc, Buster armv7l)
#   v1.1 — 2026-06-09 — kx1t- Added support for file based aircraft.json sources and improved error handling; translations in English; updated logging and stats.

import json
import time
import logging
import os
import sys
from urllib.parse import urlparse, unquote

# ── Compatibilite Buster : urllib3 peut manquer de certaines fonctions ──
try:
    import requests # type: ignore
except ImportError:
    print("ERROR: requests missing — sudo apt-get install python3-requests")
    sys.exit(1)

# ── Config ────────────────────────────────────────────────────────────────
CONFIG_FILE = os.path.join(os.path.dirname(__file__), 'config.json')

# ── Logging ───────────────────────────────────────────────────────────────
logging.basicConfig(
    level=logging.INFO,
    format='[%(levelname)s] %(message)s',
    handlers=[
        logging.StreamHandler(),
        logging.FileHandler('/var/log/feeder_rv.log', encoding='utf-8')
    ]
)
logger = logging.getLogger('feeder_rv')


# ── Charger config ────────────────────────────────────────────────────────
def load_config():
    """Lit config.json — cree un config minimal si absent."""
    if not os.path.exists(CONFIG_FILE):
        logger.error(f"config.json not found: {CONFIG_FILE}")
        sys.exit(1)
    with open(CONFIG_FILE, 'r') as f:
        return json.load(f)

# ── Fetch aircraft.json depuis tar1090 local ──────────────────────────────
AIRCRAFT_SOURCES = [
    'file:///run/readsb/aircraft.json',
    'http://localhost/tar1090/data/aircraft.json',
    'http://localhost/dump1090/data/aircraft.json',
    'http://localhost:8080/data/aircraft.json',
    'http://127.0.0.1/tar1090/data/aircraft.json',
]

FIXED_AIRCRAFT_PATH = '/run/readsb/aircraft.json'


def _read_aircraft_file(path):
    """Lit un aircraft.json local avec une petite tolerance aux ecritures partielles."""
    last_exc = None
    for _ in range(3):
        try:
            with open(path, 'r', encoding='utf-8') as f:
                data = json.load(f)
            if isinstance(data, dict) and 'aircraft' in data:
                return data
            raise ValueError("missing 'aircraft' field")
        except json.JSONDecodeError as e:
            # Le fichier peut etre lu pendant que readsb est en train de l'ecrire.
            last_exc = e
            time.sleep(0.15)

    if last_exc is not None:
        raise last_exc
    raise ValueError("JSON invalide")

def fetch_aircraft():
    """Essaie plusieurs URLs pour recuperer aircraft.json."""
    all_sources = [FIXED_AIRCRAFT_PATH] + AIRCRAFT_SOURCES
    errors = []

    for url in all_sources:
        try:
            # Lire les sources locales sans passer par requests.
            if url.startswith('file://'):
                parsed = urlparse(url)
                file_path = unquote(parsed.path)
                data = _read_aircraft_file(file_path)
            elif os.path.isabs(url):
                data = _read_aircraft_file(url)
            else:
                r = requests.get(url, timeout=5)
                if r.status_code != 200:
                    continue
                data = r.json()

            if 'aircraft' in data:
                return data
        except Exception as e:
            errors.append(f"{url}: {e}")
            continue

    if errors:
        logger.warning("[FETCH] Sources failed: %s", " | ".join(errors[:3]))
    return None

# ── Envoi vers radarvirtuel.com ───────────────────────────────────────────
def feed_radarvirtuel(data, rv_url, rv_uid, session):
    """POST aircraft.json vers radarvirtuel.com/api/feed."""
    try:
        r = session.post(
            rv_url,
            json=data,
            headers={'X-Station-UID': rv_uid},
            timeout=10
        )
        if r.status_code == 200:
            resp = r.json()
            accepted = resp.get('accepted', 0)
            logger.info(f"[RV] OK — {accepted} aircraft accepted")
            return True
        else:
            logger.warning(f"[RV] HTTP {r.status_code}")
            return False
    except requests.exceptions.ConnectionError:
        logger.warning("[RV] Connection failed (link?)")
        return False
    except requests.exceptions.Timeout:
        logger.warning("[RV] Timeout")
        return False
    except Exception as e:
        logger.warning(f"[RV] Error: {e}")
        return False

# ── Main loop ─────────────────────────────────────────────────────────────
def main():
    cfg = load_config()
    rv  = cfg.get('radarvirtuel', {})

    rv_url     = rv.get('url', 'https://radarvirtuel.com/api/feed')
    rv_uid     = rv.get('station_uid', '')
    rv_enabled = rv.get('enabled', True)
    interval   = rv.get('interval_s', 5)  # secondes entre chaque envoi

    if not rv_enabled:
        logger.info("[RV] Feeder disabled in config.json (radarvirtuel.enabled=false)")
        sys.exit(0)

    if not rv_uid:
        logger.error("[RV] station_uid missing in config.json")
        sys.exit(1)

    station = cfg.get('terrain', {}).get('nom', 'UNKNOWN')
    logger.info("=" * 50)
    logger.info(f"[START] Feeder RadarVirtuel — station {station}")
    logger.info(f"[CFG]   URL={rv_url}")
    logger.info(f"[CFG]   UID={rv_uid}")
    logger.info(f"[CFG]   Interval={interval}s")
    logger.info("=" * 50)

    # Session persistante pour les connexions HTTP
    session = requests.Session()
    # Desactiver les avertissements SSL sur Buster (certifi peut etre vieux)
    try:
        from requests.packages.urllib3.exceptions import InsecureRequestWarning # type: ignore
        requests.packages.urllib3.disable_warnings(InsecureRequestWarning)
    except Exception:
        pass

    errors_consecutive = 0
    total_sent = 0

    while True:
        t0 = time.time()

        # Fetch
        data = fetch_aircraft()
        if data is None:
            errors_consecutive += 1
            logger.warning(f"[FETCH] Cannot read aircraft.json ({errors_consecutive} tries)")
            if errors_consecutive >= 10:
                logger.error("[FETCH] 10 consecutive failures — check readsb/tar1090")
                errors_consecutive = 0
            time.sleep(interval)
            continue

        nb_ac = len(data.get('aircraft', []))

        # Envoi
        ok = feed_radarvirtuel(data, rv_url, rv_uid, session)
        if ok:
            errors_consecutive = 0
            total_sent += 1
            if total_sent % 60 == 0:
                logger.info(f"[STATS] {total_sent} sent successfully — {nb_ac} visible aircraft")
        else:
            errors_consecutive += 1

        # Attendre le reste de l'intervalle
        elapsed = time.time() - t0
        sleep_t = max(0, interval - elapsed)
        time.sleep(sleep_t)

if __name__ == '__main__':
    try:
        main()
    except KeyboardInterrupt:
        logger.info("[STOP] Feeder stopped by user")
        sys.exit(0)
