#!/usr/bin/env bash

DEVICE=caiman

# build grapheneos for tokay at a specific tagged release

 if [ -z "$1" ]; then
  echo "Usage: ./caiman.sh <grapheneos-release-tag-name>"
  echo "the tags can be found here https://grapheneos.org/releases"
  exit 1
fi

TAG=$1

./clone.sh $TAG
./build.sh $TAG $DEVICE

mkdir -p grapheneos-$TAG/keys/
cp -a keys/$DEVICE grapheneos-$TAG/keys/$DEVICE
cd grapheneos-$TAG
script/generate-release.sh $DEVICE $TAG
cd ../
echo "signed images available in grapheneos-${TAG}/releases/${TAG}/release-${DEVICE}-${TAG}"
