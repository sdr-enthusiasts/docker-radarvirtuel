#/bin/bash
# RV-INSTALL.SH -- Installation script for a Dockerized version of the RadarVirtuel feeder
# Usage: ./planefence.sh or `wget -q https://raw.githubusercontent.com/kx1t/docker-radarvirtuel/main/rv-install.sh && . ./rv-install.sh`
#
# Copyright 2021 Ramon F. Kolb - licensed under the terms and conditions
# of the MIT license. The terms and conditions of this license are included with the Github
# distribution of this package, and are also available here:
# https://github.com/kx1t/docker-radarvirtuel/
#
# RadarVirtuel is owned and copyright by Laurent Duval and AdsbNetwork. All rights to that software and
# services are reserved by the respective owners.

source yaml2bash.sh

true=0
false=1


clear
cat << "EOM"
            __/\__
           `==/\==`                __           _                  _      _              _
 ____________/__\____________     /__\ __ _  __| | __ _ _ __/\   /(_)_ __| |_ _   _  ___| |
/____________________________\   / \/// _` |/ _` |/ _` | '__\ \ / / | '__| __| | | |/ _ \ |
  __||__||__/.--.\__||__||__    / _  \ (_| | (_| | (_| | |   \ V /| | |  | |_| |_| |  __/ |
 /__|___|___( >< )___|___|__\   \/ \_/\__,_|\__,_|\__,_|_|    \_/ |_|_|   \__|\__,_|\___|_|
           _/`--`\_
jgs       (/------\)
EOM

echo "Welcome to the RadarVirtuel docker installation script"
echo "We will check if Docker and Docker-compose are installed,"
echo "and then help you with your configuration."
echo
echo "Note - this scripts makes use of \"sudo\" to install Docker."
echo "If you haven't added your current login to the \"sudoer\" list,"
echo "you may be asked for your password at various times during the installation."
echo
read -p "Press ENTER to start, or CTRL-C to abort"
echo -n "Checking for Docker installation... "
if which docker >/dev/null 2>1
then
    echo "found!"
else
    echo "not found!"
    echo "Installing docker, each step may take a while:"
    echo -n "Updating repositories... "
    sudo apt-get update -qq >/dev/null
    echo -n "Ensuring dependencies are installed... "
    sudo apt-get install -y curl uidmap slirp4netns >/dev/null
    echo -n "Getting docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    echo "Installing Docker... "
    sudo sh get-docker.sh
    echo "Docker installed -- configuring docker..."
    sudo  usermod -aG docker $USER
    sudo mkdir -p /etc/docker
    sudo chmod a+rwx /etc/docker
    sudo cat > /etc/docker/daemon.json <<EOF
{
  "log-driver": "local",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
EOF
    sudo chmod a+r /etc/docker/daemon.json
    sudo service docker restart
    echo "Now let's run a test container:"
    sudo docker run --rm hello-world
    echo
    echo "Did you see the \"Hello from Docker! \" message above?"
    echo "If yes, all is good! If not, press CTRL-C and trouble-shoot."
    echo
    echo "Note - in order to run your containers as user \"${USER}\" (and without \"sudo\"), you should"
    echo "log out and log back into your Raspberry Pi once the installation is all done."
    echo
    read -p "Press ENTER to continue."
    clear
fi

echo -n "Checking for Docker-compose installation... "
if which docker-compose >/dev/null 2>1
then
    echo "found!"
else
    echo "not found!"
    echo "Installing Docker-compose... "
    sudo curl -L -s --fail https://raw.githubusercontent.com/linuxserver/docker-docker-compose/master/run.sh -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    sudo docker-compose version
    echo
    echo "Docker-compose was installed successfully."
    read -p "Press ENTER to continue".
    clear
fi

echo "Now we have made sure that your Docker environment is complete, let\'s install RadarVirtuel!"
echo "Provide the directory name where you want to put the \"docker-compose.yml\" install file for RadarVirtuel"
echo "If \"docker-compose.yml\" already exists in this directory, we will try to add RadarVirtuel to the existing container stack."

while :
do
    read -r -p "Enter your install directory: " -e -i "/opt/adsb" dcdir
    [[ -d "$dcdir" ]] && break
    if [[ "$dcdir" != "" ]]
    then
        read -r -p "Creating $dcdir -- correct? [Y/n]" -n 1 b
        [[ "${b,,}" == "y" ]] && break
    fi
done

sudo mkdir -p "$dcdir"
sudo chmod a+rwx "$dcdir"

echo "What is your RadarVirtuel Feeder Key? This should be a long sequence of characters that look like"
echo "xxxx:1234567890ABCDEF1234567890ABCDEF or something similar. If you do not have a feeder key, you must apply"
echo "for one by emailing your name, long/lat, and closest major airport to support@adsbnetwork.com"
echo
echo "If you do not have this ready to go, press ENTER below and once you receive the key, add it to the FEEDER_KEY variable in the following file:"
echo "$dcdir/docker-compose.yml"
echo
while :
do
    read -r -p "Paste your feeder key here: " feeder_key
    keyhash="${feeder_key##*:}"
    stid="${feeder_key%%:*}"
    if [[ "$feeder_key" != "" ]] && [[ "$keyhash" == "$(sed 's/[^0-9A-Fa-f]//g' <<< "$keyhash")" ]] && [[ "${#keyhash}" == "32" ]] && [[ "$stid" == "$(sed 's/[^0-9A-Za-z]//g' <<< "$stid")" ]] && [[ "${#stid}" -le "6" ]]
    then
        break
    elif [[ "$feeder_key" = "" ]]
    then
        echo "Once you receive your feeder key, please edit $dcdir/docker-compose.yml and replace the placeholder FEEDER_KEY variable with your key."
        break
    fi
    echo "Your feeder key appears to be incorrect or incomplete. It should consist of:"
    echo "- 4-6 letters or numbers (you entered $stid, which has ${#stid} characters)"
    echo "- followed by a single : (which you did `[[ "$(sed 's/[^:]//g' <<< "$feeder_key")" != ":" ]] && echo -n "NOT "`enter)"
    echo "- followed by 32 hexadecimal numbers [0-9A-F] (you entered $keyhash, which has ${#keyhash} characters`[[ "$keyhash" != "$(sed 's/[^0-9A-Fa-f]//g' <<< "$keyhash")" ]] && echo -n " and contains invalid characters"`)."
    echo "Please try entering it again. If you cannot get it right, you can leave it empty for now and add the key later."
    echo
done

if [[ -f "$dcdir/docker-compose.yml" ]]
then
    echo "We have detected an existing installation of \"docker-compose\" at $dcdir/docker-compose.yml"
    read -i "Y" -N 1 -p "Do you want to add RadarVirtuel to this stack? (Y/n) " a
    if [[ "${a,,}" == "y" ]]
    then
        # convert the YAML file to variables
        eval $(parse_yaml /opt/adsb/docker-compose.yml "adsb_")
        [[ ! -z $adsb_services_readsb_image ]] && readsb=true || readsb=false
        [[ ! -z $adsb_services_tar1090_image ]] && tar1090=true || tar1090=false

        # only add stuff if there is not already a RadarVirtuel section
        if [[ -z $adsb_services_radarvirtuel_image ]]
        then
            # there's no RadarVirtuel section and we can add one
            # Now, if there's both a READSB section and a TAR1090 section, figure out which one to hook into:
            if [[ "$readsb" == "true" ]] && [[ "$tar1090" == "true" ]]
            then
                echo
                echo "We've detected an installation of both TAR1090 and READSB in your stack."
                echo "We recommend feeding RadarVirtuel from TAR1090 as it may include additional data sources"
                echo "Please choose which of them you want to feed from:"
                read -i "1" -N 1 -p  "1. TAR1090       2. READSB     [1]: " target
                [[ "$target" == "1" ]] && readsb=false || tar1090=false
            fi

            # create a new docker-compose.yml file
            sudo rm -f $dcdir/new-docker-compose.yml
            sudo touch $dcdir/new-docker-compose.yml
            sudo chmod a+rw $dcdir/new-docker-compose.yml

            if [[ "$readsb" == "true" ]]
            then
                # First figure out if the READSB_NET_RAW_OUTPUT_PORT param is already set
                source=""
                port=""
                for a in {0..20}
                do
                    eval x='$'input_services_readsb_environment_$a
                    if [[ "${x%%=*}" == "READSB_NET_RAW_OUTPUT_PORT" ]]
                    then
                        source="found"
                        port=${x##*=}
                        break
                    fi
                done

                [[


            fi
        fi
    fi
