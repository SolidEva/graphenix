#!/usr/bin/env bash

# build a grapheneos release, assumes the sources for a tagged release are already downloaded

if [ -z "$1" ]; then
  echo "Usage: ./build.sh <grapheneos-release-tag-name> <device codename>"
  echo "the tags can be found here https://grapheneos.org/releases"
  exit 1
fi

if [ -z "$2" ]; then
  echo "Usage: ./build.sh <grapheneos-release-tag-name> <device codename>"
  echo "the codename aka build target for devices can be found here https://grapheneos.org/build#build-targets"
  exit 1
fi

TAG=$1
CODENAME=$2


cd grapheneos=$TAG || echo "source clone does not exist at grapheneos-$TAG, run 'clone.sh $TAG' first"; exit 1

source build/envsetup.sh
yarn --cwd vendor/adevtool/ install
adevtool generate-all -d $CODENAME
lunch $CODENAME-cur-user

rm -r out

#NOTE: this is only correct for pixel 7 and newer!
m vendorbootimage vendorkernelbootimage target-files-package

m otatools-package

script/finalize.sh

echo "build complete, but you still need to sign it before you can use it"
echo "see https://grapheneos.org/build#generating-release-signing-keys"
