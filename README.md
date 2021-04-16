# Docker-RadarVirtuel

## What is it?

This application is a feeder service that takes RAW/AVR ADSB data from a service like `dump1090[-fa]`, `readsb`, and `tar1090`, and feeds this data to `adsbnetwork`'s RadarVirtuel data aggregator. It works similar to other data connectors from the @Mikenye family of ADSB tools.

RadarVirtuel can be reached at:
- http://www.radarvirtuel.com/

Before you install this container, you need a feeder key. To request one, email support@adsbnetwork.com with the following information:
- Your name
- The Lat/Lon and nearest airport of your station
- Your Raspberry Pi model (or other hardware if not Raspberry Pi)
- Mention that you will feed using a Docker container.


## Quick Start Guide
These instructions are for people who are deploying on Raspberry Pi (3B+ or 4) with Raspberry OS or Ubuntu, and who already have a running `Docker` and `Docker-compose` setup with `readsb`, `dump1090-fa`, or a similar ADSB decoder running. That decoder can run inside a container or directly on the host.

You should also have received a Feeder Key as per the section above.

With these 4 simple steps, you should be up and running in 5 minutes or less. If you need more detailed instructions, please continue reading the next few sections of this README.

1. Download the [`docker-compose.yml`](https://raw.githubusercontent.com/kx1t/docker-radarvirtuel/main/docker-compose.yml) example file.
2. Edit that file --
- replace `FEEDER_KEY` value with the feeder key you received from ADSB Network
- replace `SOURCE_HOST` value:
    - if you are using dump1090[-fa], readsb, or tar1090 WITHOUT docker or in a different docker stack:
        - if it's on the local machine -- use the default value of `${HOSTNAME}:30002`
        - if it's on a different machine -- put in the hostname or IP address of the target machine, for example SOURCE_HOST=192.168.1.10:30002
        - (Note - NEVER put "127.0.0.1" as the IP address - this won't work!)
        - (Also note - make sure to enable and expose RAW (AVR) data on port 30002 on dump1090[-fa] / readsb / tar1090)
- if you are using dockerized `readsb` or `tar1090` in the same docker-compose stack, then you can put in the name of the target container. Example: `SOURCE_HOST=readsb:30002`
3. If you want to add the setup to an existing `docker-compose.yml` stack, simply copy and paste the (edited) radarvirtuel: section into the services: section of your existing `docker-compose.yml` file
4. Restart your container stack with `docker-compose up -d` and you're in business. Monitor `docker logs -f radarvirtuel` to check for any errors.

## Detailed Instructions
## Prerequisites
1. The use of this connector service assumes that you already have a working ADS-B station setup
- Ensure you enabled RAW (=AVR) data output on the application that actively processes your ADS-B data.
- Your ADS-B station can be on the same machine as this application, or on a different machine.
- Similarly, it doesn't matter if you are using a Containerized or non-Containerized setup.

2. The use of this connector also assumes that you have installed `Docker` and `Docker-compose` on the machine you want to run `Docker-RadarVirtuel` on.
- For instructions on installing Docker, and (if you want) installing `readsb` and other ADS-B data collectors, please follow Mike Nye's excellent [gitbook](https://mikenye.gitbook.io/ads-b/).
- For the RadarVirtuel container to work with an existing non-Containerized ADS-B station, please follow at least the 3 chapters in the `Setting up the host system` section.

3. Last, you will need to get a `FEEDER_KEY` to identify your station to RadarVirtuel. You can get this key by emailing support@adsbnetwork.com. When doing so, please provide the following information:
- Your Lat / Lon in decimal degrees
- Mention that you are using a Docker setup
- Your nearest major airport (4 letter ICAO code, for example "KBOS" or "EGGL")
- A quick introduction to yourself, and how you heard about RadarVirtuel
- If approved, you will receive a key that will look like this: `xxxx:123456ABCDEF123456ABCDEF`

## Stand-alone Installation
For a stand-alone installation on a machine with an existing ADS-B receiver, you can simply do this:
```
sudo mkdir -p /opt/adsb && sudo chmod a+rwx /opt/adsb && cd /opt/adsb
wget https://raw.githubusercontent.com/kx1t/docker-radarvirtuel/main/docker-compose.yml
```
Then, edit the `docker-compose.yml` file and make sure the following 3 parameters are set:
| Parameter   | Definition                    | Value                     |
|-------------|-------------------------------|---------------------------|
| `FEEDER_KEY`  | This key is provided by RadarVirtuel and is your PRIVATE KEY. Do no share this with anyone else.       | `[icao]:[private_key]`        |
| `SOURCE_HOST` | host and port number of your ADSB receiver. When running stand-alone on your local machine, this should be `${HOSTNAME}`. The value after the `:` is the port number to the RAW or AVR service on the target machine, most probably `30002`.       | `${HOSTNAME}:30002`       |
| `RV_SERVER`    | The hostname and the TCP port of the RadarVirtuel server. You should NOT change this unless specifically instructed.       | `mg2.adsbnetwork.com:50050`       |
| `VERBOSE` | Write verbose messages to the log | `OFF` (default) / `ON` |

## Adding to an existing ADS-B Docker Installation
If you are already running a stack of ADS-B related containers on your machine, you can add `RadarVirtuel` to your existing `docker-compose.yml` file.
- To do so, download the example `docker-compose.yml` file from [here](https://raw.githubusercontent.com/kx1t/docker-radarvirtuel/main/docker-compose.yml) and add everything starting with `radarvirtuel` to the Services section of your existin `docker-compose.yml`.
- Configuration is similar to the stand-alone version (see above), with a minor difference for the `SOURCE_HOST` parameter: you can connect that one directly to the container that provides the data.
- For example, if your data is provided by the `readsb` container, you can use:
```
SOURCE_HOST=readsb:30002
```

## Timezone configuration
- The default timezone setting for the container mimics the host machine's timezone. Sometimes, it is desired to run the container in UTC instead.
- To run the container in UTC, comment out the following lines (using `#`) in `docker-compose.yml`:
```
#    volumes:
#      - "/etc/localtime:/etc/localtime:ro"
#      - "/etc/timezone:/etc/timezone:ro"
```

## Starting, stopping, upgrading, and monitoring the container

To start the container for the first time:
- `pushd /opt/adsb && docker-compose up -d && popd`

To restart the container:
- `docker restart radarvirtuel`

To stop the container:
- `pushd /opt/adsb && docker-compose down && popd`   <-- this stops all containers in the stack
- `docker stop radarvirtuel`   <-- this stops only RadarVirtuel

To download and deploy a new version of the container, if one exists:
- `pushd /opt/adsb && docker-compose pull && docker-compose up -d && popd`

To monitor the logs of the RadarVirtuel container:
- `docker logs radarvirtuel`   <-- shows all logs for RadarVirtuel in the buffer (warning - can be very long!)
- `docker logs -f radarvirtuel`   <-- shows the last few logs and waits for any new log entries, abort with CTRL-C

## Troubleshooting
- If things don't appear to work as they should, set `VERBOSE=ON` in your `docker-compose.yml` and restart the container. Then monitor `docker logs -f radarvirtuel` to see what is going on
- If it complains about your `SOURCE_HOST`:
    - Make sure your data source can be reached from inside the container. `SOURCE_HOST` should be set to:
        - if it's a container within the same stack: the container name, for example `SOURCE_HOST=readsb:30002`
        - if it's a separate container or a stand-alone installation on the same machine, `SOURCE_HOST` must be set to `SOURCE_HOST=${HOSTNAME}:30002`
        - If it's a separate container on a different machine, you should use the full hostname or IP address of that machine. For example `SOURCE_HOST=192.168.1.10:30002`.
    - Make sure that your `readsb` or `dump1090[-fa]` installation is providing RAW (AVR) data:
        - Stand-alone `dump1090` variants must use the `--net-ro-port 30002` command line parameter
        - Containerized `readsb` or `readsb-protobuf` should pass the following variable in the `environment:` section of `docker-compose.yml`: `READSB_NET_RAW_OUTPUT_PORT=30002`
- If the logs complain about not being able to reach the RadarVirtuel server:
    - Make sure your machine is connected to the internet. Try this command to check connectivity:
    `netcat -u -z -v mg2.adsbnetwork.com 50050`
- If it complains about errors in your `docker-compose.yml` file
    - SPACING IS IMPORTANT. Spacing is important. There, I said it. Check that each line has the correct indentation
    - Sometimes, there are problems with newline characters when you import from a Windows machine. In that case, you can easily convert your file to Unix format. There are multiple ways to do this, one of them is:
    `cat docker-compose.yml | tr -dc '[:print:]\n' >/tmp/tmp.tmp && sudo mv -f /tmp/tmp.tmp docker-compose.yml`


# OWNERSHIP AND LICENSE
RADARVIRTUEL is owned by, and copyright by AdsbNetwork and by Laurent Duval. All rights reserved.
Note that parts of the code and scripts included with this package are NOT covered by an Open Source license, and may only be distributed and used with express permission from AdsbNetwork. Contact support@adsbnetwork.com for more information.

Any modifications to the existing AdsbNetwork scripts and programs, and any additional scripts are provided by `kx1t` under the MIT License as included with this package.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
