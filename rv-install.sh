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

function parse_yaml {
   local prefix=$2
   local s='[[:space:]]*' w='[a-zA-Z0-9_]*' fs=$(echo @|tr @ '\034')
   sed -ne "s|^\($s\):|\1|" \
        -e "s|^\($s\)\($w\)$s:$s[\"']\(.*\)[\"']$s\$|\1$fs\2$fs\3|p" \
        -e "s|^\($s\)\($w\)$s:$s\(.*\)$s\$|\1$fs\2$fs\3|p"  $1 |
   awk -F$fs '{
      indent = length($1)/2;
      vname[indent] = $2;
      for (i in vname) {if (i > indent) {delete vname[i]}}
      if (length($3) > 0) {
         vn=""; for (i=0; i<indent; i++) {vn=(vn)(vname[i])("_")}
         printf("%s%s%s=\"%s\"\n", "'$prefix'",vn, $2, $3);
      }
   }'
}

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

echo "Now we've made sure that your Docker environment is complete, let's install RadarVirtuel!

if [[ -f "/opt/adsb/docker-compose.yml" ]]
then
    echo "We have detected an existing installation of \"docker-compose\" at /opt/adsb/docker-compose.yml"
    read -i "Y" -N 1 -p "Do you want to add RadarVirtuel to this stack? (Y/n) " a
    if [[ "${a,,}" == "y" ]]
    then
        # convert the YAML file to variables
        eval $(parse_yaml /opt/adsb/docker-compose.yml "adsb_")
        [[ ! -z $adsb_services_readsb_image ]] && readsb=true || readsb=false
        [[ ! -z $adsb_services_tar1090_image ]] && tar1090=true || tar1090=false

        if [[ "$readsb" == "true" ]]
        then
            while read -r line
            do
