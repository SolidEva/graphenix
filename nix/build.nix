{ pkgs, ... }:
let
  allowed_signers = ./allowed_signers;
in
rec {

    buildGrapheneOS =
      pkgs.writeShellApplication {
        name = "buildGrapheneOS";
        runtimeInputs = [ buildGrapheneOS-unwrapped ];
        text = ''
          set -e

          CRED_STORE=$(mktemp -d)

          echo "Enter the encryption password for your signing keys:"
          systemd-ask-password -n | systemd-creds --user encrypt --name=signingkeyspassword -p - "$CRED_STORE"/signingkeyspassword.cred

          systemd-run --user --pipe --wait --property=LoadCredentialEncrypted=signingkeyspassword:"$CRED_STORE"/signingkeyspassword.cred buildGrapheneOS-unwrapped "$@"
          '';
      };
  
    buildGrapheneOS-unwrapped = 
      pkgs.writeShellScriptBin "buildGrapheneOS-unwrapped" ''
        set -xe

        if [ -z "$1" ]; then
          echo "Usage: ./buildGrapheneOS.sh <device codename> <grapheneos-release-tag-name>"
          echo "the codename aka build target for devices can be found here https://grapheneos.org/build#build-targets"
          exit 1
        fi

        if [ -z "$2" ]; then
          echo "Usage: ./buildGrapheneOS.sh <device codename> <grapheneos-release-tag-name>"
          echo "the tags can be found here https://grapheneos.org/releases"
          exit 1
        fi

        CODENAME=$1
        TAG=$2

        WORKDIR=$(pwd)

        if [ ! -d "$WORKDIR/keys/$CODENAME" ]; then
          echo "keys dir $WORKDIR/keys/$CODENAME does not exist"
          exit 1
        fi

        mkdir -p grapheneos
        cd grapheneos
        rm -rf out/

        repo init -u https://github.com/GrapheneOS/platform_manifest.git -b refs/tags/$TAG

        cd .repo/manifests
        git config gpg.ssh.allowedSignersFile ${allowed_signers}
        git verify-tag $(git describe)
        cd ../..

        repo sync -j8 --force-sync

        echo "repo at tag $TAG cloned and synced"

        source build/envsetup.sh
        yarn --cwd vendor/adevtool/ install
        ./vendor/adevtool/bin/run generate-all -d $CODENAME
        lunch $CODENAME-cur-user

        if [[ "$CODENAME" =~ ^(oriole|raven|bluejay)$ ]]; then
          m vendorbootimage target-files-package 
        else
          #NOTE: this is currently correct for pixel 7 and newer. its possible newer devices will require different targets
          m vendorbootimage vendorkernelbootimage target-files-package
        fi

        m otatools-package
        script/finalize.sh
        echo "building complete"

        mkdir -p keys/
        cp -a $WORKDIR/keys/$CODENAME keys/$CODENAME
        BUILD_NUMBER=$(cat out/soong/build_number.txt)
        # the grapheneos decrypt keys script consumes the password if set in env
        password=$(systemd-creds --user cat signingkeyspassword)
        script/generate-release.sh $CODENAME $BUILD_NUMBER
        echo "signed images available in grapheneos/releases/$BUILD_NUMBER/release-$CODENAME-$BUILD_NUMBER"
      '';
  
}
