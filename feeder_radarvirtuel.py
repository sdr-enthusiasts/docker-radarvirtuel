#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# feeder_radarvirtuel.py
# VERSION     : v1.0 — 2026-06-02 15:00 UTC
# DEPLOY PATH : /opt/feeder_rv/feeder_radarvirtuel.py
# DESCRIPTION : Feeder minimal radarvirtuel.com — compatible Debian Buster/Bullseye/Bookworm/Trixie
#               Lit aircraft.json depuis tar1090/readsb local
#               Envoie POST vers https://radarvirtuel.com/api/feed
#               Aucune dependance hors stdlib + requests
# HISTORY     :
#   v1.0 — 2026-06-02 — Creation pour LFRC (raspiv3-lfrc, Buster armv7l)

import json
import time
import logging
import os
import sys

# ── Compatibilite Buster : urllib3 peut manquer de certaines fonctions ──
try:
    import requests
except ImportError:
    print("ERREUR: requests manquant — sudo apt-get install python3-requests")
    sys.exit(1)

# ── Config ────────────────────────────────────────────────────────────────
CONFIG_FILE = os.path.join(os.path.dirname(__file__), 'config.json')

# ── Logging ───────────────────────────────────────────────────────────────
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(message)s',
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
        logger.error(f"config.json introuvable : {CONFIG_FILE}")
        sys.exit(1)
    with open(CONFIG_FILE, 'r') as f:
        return json.load(f)

# ── Fetch aircraft.json depuis tar1090 local ──────────────────────────────
AIRCRAFT_SOURCES = [
    'http://localhost/tar1090/data/aircraft.json',
    'http://localhost/dump1090/data/aircraft.json',
    'http://localhost:8080/data/aircraft.json',
    'http://127.0.0.1/tar1090/data/aircraft.json',
]

def fetch_aircraft():
    """Essaie plusieurs URLs pour recuperer aircraft.json."""
    for url in AIRCRAFT_SOURCES:
        try:
            r = requests.get(url, timeout=5)
            if r.status_code == 200:
                data = r.json()
                if 'aircraft' in data:
                    return data
        except Exception:
            continue
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
            logger.info(f"[RV] OK — {accepted} avions acceptes")
            return True
        else:
            logger.warning(f"[RV] HTTP {r.status_code}")
            return False
    except requests.exceptions.ConnectionError:
        logger.warning("[RV] Connexion impossible (reseau?)")
        return False
    except requests.exceptions.Timeout:
        logger.warning("[RV] Timeout")
        return False
    except Exception as e:
        logger.warning(f"[RV] Erreur: {e}")
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
        logger.info("[RV] Feeder desactive dans config.json (radarvirtuel.enabled=false)")
        sys.exit(0)

    if not rv_uid:
        logger.error("[RV] station_uid manquant dans config.json")
        sys.exit(1)

    station = cfg.get('terrain', {}).get('nom', 'UNKNOWN')
    logger.info("=" * 50)
    logger.info(f"[START] Feeder RadarVirtuel — station {station}")
    logger.info(f"[CFG]   URL={rv_url}")
    logger.info(f"[CFG]   UID={rv_uid}")
    logger.info(f"[CFG]   Intervalle={interval}s")
    logger.info("=" * 50)

    # Session persistante pour les connexions HTTP
    session = requests.Session()
    # Desactiver les avertissements SSL sur Buster (certifi peut etre vieux)
    try:
        from requests.packages.urllib3.exceptions import InsecureRequestWarning
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
            logger.warning(f"[FETCH] Impossible de lire aircraft.json (tentative {errors_consecutive})")
            if errors_consecutive >= 10:
                logger.error("[FETCH] 10 echecs consecutifs — verifier readsb/tar1090")
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
                logger.info(f"[STATS] {total_sent} envois OK — {nb_ac} avions visibles")
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
        logger.info("[STOP] Feeder arrete par l'utilisateur")
        sys.exit(0)
