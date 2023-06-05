#!/bin/bash

args="$@"

if [ "$1" == "-b" ]; then
  args="${@:2}"
  docker image prune -f
  docker build -t chunk-purge .
fi

if [ "$1" == "-bo" ]; then
  args="${@:2}"
  docker build -t chunk-purge .
  exit 0
fi

if [ "$1" == "-c" ]; then
  rm -rfv data/*.tar.gz
  rm -rfv data/Kings\ World\ *.zip
  exit 0
fi

docker rm -f chunk-purge

docker run --name chunk-purge \
  -v ./data:/data \
  -v /root/docker/pterodactyl/shared/data/backups:/backups \
  --env-file .env \
  --pull never \
  -ti chunk-purge $args