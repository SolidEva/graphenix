#!/usr/bin/env bash

set -xe

DEVICE=tokay

# build grapheneos for tokay at a specific tagged release

 if [ -z "$1" ]; then
  echo "Usage: ./tokay.sh <grapheneos-release-tag-name>"
  echo "the tags can be found here https://grapheneos.org/releases"
  exit 1
fi

TAG=$1

./clone.sh $TAG
./build.sh $TAG $DEVICE

mkdir -p grapheneos-$TAG/keys/
cp -a keys/$DEVICE/ grapheneos-$TAG/keys/$DEVICE
cd grapheneos-$TAG
BUILD_NUMBER=$(cat out/soong/build_number.txt)
script/generate-release.sh $DEVICE $BUILD_NUMBER
cd ../
echo "signed images available in grapheneos-${TAG}/releases/${BUILD_NUMBER}/release-${DEVICE}-${BUILD_NUMBER}"
