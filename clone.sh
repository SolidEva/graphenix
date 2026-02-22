#!/usr/bin/env bash

# clone sources for a stable grapheneos build

if [ -z "$1" ]; then
  echo "Usage: ./clone.sh <grapheneos-release-tag-name>"
  echo "the tags can be found here https://grapheneos.org/releases"
  exit 1
fi

TAG=$1

if [ ! -f ~/.ssh/grapheneos_allowed_signers ]; then
  echo "you must pull the grapheneos SSH public key so we can validate signatures"
  echo "curl https://grapheneos.org/allowed_signers > ~/.ssh/grapheneos_allowed_signers"
  exit 1
fi

if [ ! -f grapheneos-$TAG ]; then
  mkdir grapheneos-$TAG
  cd grapheneos-$TAG
  repo init -u https://github.com/GrapheneOS/platform_manifest.git -b refs/tags/$TAG

  cd .repo/manifests
  git config gpg.ssh.allowedSignersFile ~/.ssh/grapheneos_allowed_signers
  git verify-tag $(git describe)
  cd ../..
else
  cd grapheneos-$TAG
fi

repo sync -j8

cd ../
