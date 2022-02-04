#!/bin/bash
#
set -x

[[ "$1" != "" ]] && BRANCH="$1" || BRANCH=main
[[ "$BRANCH" == "main" ]] && TAG="latest" || TAG="$BRANCH"
[[ "$ARCHS" == "" ]] && ARCHS="linux/armhf,linux/arm64,linux/amd64"

IMAGE=kx1t/$(pwd | sed -n 's|.*/docker-\(.*\)|\1|p'):$TAG
echo "press enter to start building $IMAGE from $BRANCH"
read

# rebuild the container
git checkout $BRANCH || exit 2

# make the build certs root_certs folder:
# Note that this is normally done as part of the github actions - we don't have those here, so we need to do it ourselves before building:
#ls -la /etc/ssl/certs/
#mkdir -p ./root_certs/etc/ssl/certs
#mkdir -p ./root_certs/usr/share/ca-certificates/mozilla

#cp -P /etc/ssl/certs/*.crt ./root_certs/etc/ssl/certs
#cp -P /etc/ssl/certs/*.pem ./root_certs/etc/ssl/certs
#cp -P /usr/share/ca-certificates/mozilla/*.crt ./root_certs/usr/share/ca-certificates/mozilla

git pull -a
docker buildx build --compress --push $2 --platform $ARCHS --tag $IMAGE .
#rm -rf ./root_certs
