{ pkgs, ... }:
let
  allowed_signers = ./allowed_signers;

  env = import ./env.nix { inherit pkgs; };

  # we need bashInteractive for various commands in the grapehen envsetup.sh (like complete)
  # by default, writeShellScriptBin uses bash non interactive it seems
  writeBashInteractiveBin =
    name: text:
    pkgs.writeTextFile {
      inherit name;
      executable = true;
      destination = "/bin/${name}";
      text = ''
        #!${pkgs.bashInteractive}/bin/bash
        ${text}
      '';
      checkPhase = ''
        ${pkgs.stdenv.shellDryRun} "$target"
      '';
      meta.mainProgram = name;
    };
in
rec {

    buildGrapheneOS =
      pkgs.writeShellApplication {
        name = "buildGrapheneOS";
        runtimeInputs = [ (env.androidFHS {
                            commandPkg = buildGrapheneOS-unwrapped;
                            command = ''buildGrapheneOS-unwrapped "$@"'';
                          })
                        ];
        bashOptions = [];
        text = ''
          set -e
          CRED_STORE=$(mktemp -d)

          echo "Enter the encryption password for your signing keys:"
          systemd-ask-password -n | systemd-creds --user encrypt --name=signingkeyspassword -p - "$CRED_STORE"/signingkeyspassword.cred
          systemd-run --user --wait --property=LoadCredentialEncrypted=signingkeyspassword:"$CRED_STORE"/signingkeyspassword.cred --same-dir androidFHSbuildGrapheneOS-unwrapped "$@"
          '';
      };
  
    buildGrapheneOS-unwrapped = 
      writeBashInteractiveBin "buildGrapheneOS-unwrapped" ''
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
        cp -a $WORKDIR/keys/$CODENAME keys/
        BUILD_NUMBER=$(cat out/soong/build_number.txt)
        # the grapheneos decrypt keys script consumes the password if set in env
        set +x
        export password=$(systemd-creds --user cat signingkeyspassword)
        set -x
        script/generate-release.sh $CODENAME $BUILD_NUMBER
        echo "signed images available in grapheneos/releases/$BUILD_NUMBER/release-$CODENAME-$BUILD_NUMBER"
      '';
  
}
