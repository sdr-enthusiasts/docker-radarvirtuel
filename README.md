# Docker-RadarVirtuel

<!-- TOC -->

- [Docker-RadarVirtuel](#docker-radarvirtuel)
  - [What is it?](#what-is-it)
  - [Quick Start Guide](#quick-start-guide)
  - [Upgrade from an older RadarVirtuel configuration](#upgrade-from-an-older-radarvirtuel-configuration)
  - [All parameters](#all-parameters)
    - [Mandatory parameters](#mandatory-parameters)
    - [Optional parameters](#optional-parameters)
  - [Mapped Volumes](#mapped-volumes)
  - [MLAT results](#mlat-results)
  - [Recovering Station ID after a hardware change](#recovering-station-id-after-a-hardware-change)
  - [Further help](#further-help)
  - [OWNERSHIP AND LICENSE](#ownership-and-license)

<!-- /TOC -->

## What is it?

This application is a feeder service that takes RAW/AVR ADSB data from a service like `dump1090[-fa]`, `readsb`, and `tar1090`, and feeds this data to `adsbnetwork`'s RadarVirtuel data aggregator. It works similar to other data connectors from the @Mikenye family of ADSB tools.

RadarVirtuel can be reached at:

- <http://www.radarvirtuel.com/>

## Quick Start Guide

These instructions are for people who are deploying on Raspberry Pi (3B+ or 4) with Raspberry OS or Ubuntu, and who already have a running `Docker` and `Docker-compose` setup with `readsb`, `dump1090-fa`, or a similar ADSB decoder running. That decoder can run inside a container or directly on the host.

You should also have received a Feeder Key as per the section above.

With these 4 simple steps, you should be up and running in 5 minutes or less. If you need more detailed instructions, please continue reading the next few sections of this README.

1. Download the [`docker-compose.yml`](docker-compose.yml) example file and add it to your existing `docker-compose.yml`, or run it stand-alone.
2. In `docker-compose.yml`, make sure that `BEASTHOST` or `SOURCE_HOST` points at your BEAST ADSB data source, for example `BEAST_HOST=ultrafeeder`. You can optionally add `BEASTPORT` or `SOURCE_PORT` if they aren't using the default port `30005`.
3. Make sure that you set the following parameters at a minimum:

```yaml
      - BEASTHOST=ultrafeeder
      - RV_CONTRIB_NAME=My Name
      - RV_CONTRIB_EMAIL=user@email.com
      - LAT=${FEEDER_LAT}
      - LON=${FEEDER_LONG}
      - ALT_M=${FEEDER_ALT_M:-0}
```

4. Restart your container stack with `docker-compose up -d` and you're in business. Monitor `docker logs -f radarvirtuel` to check for any errors.

## Upgrade from an older RadarVirtuel configuration

The fastest way to upgrade is by replacing the `Environment:` section of your existing Radarvirtuel service in `docker-compose.yml` with the one from [this file](docker-compose.yml). See also item 3 of the [Quick Start Guide](#quick-start-guide) for the minimum set of parameters.

Note that you MUST fill in all parameters marked mandatory, and you MUST remove at least the `FEEDER_KEY` and `RV_SERVER` parameters from your environment. If you don't do this, the container logs will continue to complain!

Also note that you MUST mount the `data` and `cpuinfo` volumes as shown in the example [docker-compose.yml](docker-compose.yml). If you don't do this, the container won't be able to remember the UID and will regularly get a new Station ID. This is bad and really annoying! Don't be that person!

### Upgrade Troubleshooting

If things don't appear to work, check the container logs with this command: `docker logs radarvirtuel`. If you see any of the log messages below, then you haven't correctly followed the upgrade instructions:

```text
[2026-06-10 11:06:09.420][radarvirtuel] -----------------------------------------------------------------------------
[2026-06-10 11:06:09.465][radarvirtuel] ATTENTION - this container has been updated, but your environment variables
[2026-06-10 11:06:09.482][radarvirtuel] are still reflecting the old configuration. Please update your configuration
[2026-06-10 11:06:09.526][radarvirtuel] using this example: https://sdr-e.com/docker-radarvirtuel/blob/main/docker-compose.yml
[2026-06-10 11:06:09.546][radarvirtuel] The container is HALTED until you make these updates.
[2026-06-10 11:06:09.568][radarvirtuel] Then remove these parameters from your configuration to make this message go away:
[2026-06-10 11:06:09.600][radarvirtuel] RV_SERVER=mg22.adsbnetwork.com:50014
[2026-06-10 11:06:09.611][radarvirtuel] FEEDER_KEY=xxxx:CFD76443214321423ADC786B4E303173B3B5
[2026-06-10 11:06:09.641][radarvirtuel] -----------------------------------------------------------------------------
```

## All parameters

The following parameters are supported.

### Mandatory parameters

```yaml
      # ── ADSB Source ────────────────────────
      - BEASTHOST=${BEASTHOST}
      # ── Contributor (MANDATORY) ────────────────────────
      - RV_CONTRIB_NAME=${RV_CONTRIB_NAME}
      - RV_CONTRIB_EMAIL=${RV_CONTRIB_EMAIL}

      # ── Position (OBLIGATOIRE) ────────────────────────────
      # Note -- LAT, LON, ALT_M are supported as aliases
      - RV_LAT=${FEEDER_LAT}
      - RV_LON=${FEEDER_LONG}
      - RV_ALT_M=${FEEDER_ALT_M:-0}
```

### Optional parameters

```yaml
      # ── Station Label  ─────────────────────────
      # Only fill this in if auto-detection of the nearest airport fails.
      - RV_STATION_LABEL=${RV_STATION_LABEL:-}

      # ── UID station (optionnel) ───────────────────────────
      # UID is auto-generated from your CPU serial number or Mac Address.
      # Only add a random UID (for example, from `cat /proc/sys/kernel/random/uuid`)
      # when auto-generation fails!
      - RV_STATION_UID=${RV_STATION_UID:-}

      # ── aircraft.json source ──────────────────────────────
      # This parameter isn't needed if you configure the BEASTHOST
      # You can optionally point this to the URL for aircraft.json 
      # on a different machine
      # readsb/tar1090 : http://IP_MACHINE/tar1090/data/aircraft.json
      # dump1090       : http://IP_MACHINE/dump1090/data/aircraft.json
      # port 8080      : http://IP_MACHINE:8080/data/aircraft.json
      - RV_AIRCRAFT_URL=${RV_AIRCRAFT_URL}

      # ── Feeding Interval ───────────────────────────────────────────
      # How often data is sent to the RadarVirtuel server. Default: 5 secs
      - RV_INTERVAL=${RV_INTERVAL:-5}

      # ── MLAT parameters ───────────────────────────────────────────
      # Set to "off" to disable MLAT:
      ENABLE_MLAT=

      # ── Logging parameters ───────────────────────────────────────────
      # Set to "on" to show info-level messages in the container logs:
      VERBOSE=off
```

## Mapped Volumes

You really ***really*** should map the following volumes:

```yaml
    volumes:
      - "./data:/data:rw"
      - "/proc/cpuinfo:/host/cpuinfo:ro"
      - "/etc/localtime:/etc/localtime:ro"
      - "/etc/timezone:/etc/timezone:ro"
```

- the `/data` volume is used to store your UID. Without this, there's a good change that your station ID will change whenever you restart the container, especially when you are on a machine that doesn't have a Serial Number in `/proc/cpuinfo` (which is the case for most x86 machines)
- the `/proc/cpuinfo` volume mapping is to retrieve the CPU's serial number, if available. This is used to create a unique station ID
- the `/etc/localtime` and `/etc/timezone` mappings are to ensure that the container uses the same time and timezone as the host machine

## MLAT results

When MLAT is enabled and there are sufficient MLAT peers using RadarVirtuel in your region, you can feed the MLAT results back to your map. These are made available in the container on the default port `30105` and you can add them to your Ultrafeeder instance by adding this to the `ULTRAFEEDER_CONFIG` parameter: `mlathub,radarvirtuel,30105,beast_in;`

## Recovering Station ID after a hardware change

If you change your hardware, there's a good chance that the station ID will change. You can recover your original station ID when you have access to your old setup:

1. Log in to the original machine and retrieve the UID: `cat /opt/adsb/rv_data/station_uid.txt`
2. Add the following parameter to the `environment:` section of your `docker-compose.yml` file:

   ```yaml
   RV_STATION_LABEL=original_station_label
   RV_STATION_UID=uid_from_the_original_machine
   ```

3. Restart your container

If you don't have access to your original machine, you can contact <support@adsbnetwork.com> as they may be able to retrieve the UID for you.

## Further help

- For help with the RadarVirtual service and outages, please email <support@adsbnetwork.com>
- For help with the Docker Container and related issues, please contact kx1t on this Discord channel: <https://discord.gg/m42azbZydy>

## OWNERSHIP AND LICENSE

RADARVIRTUEL is owned by, and copyright by AdsbNetwork and by Laurent Duval. All rights reserved.
Note that parts of the code and scripts included with this package are NOT covered by an Open Source license, and may only be distributed and used with express permission from AdsbNetwork. Contact <support@adsbnetwork.com> for more information.

Any modifications to the existing AdsbNetwork scripts and programs, and any additional scripts are provided by `kx1t` under the MIT License as included with this package.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
