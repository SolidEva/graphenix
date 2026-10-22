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

  patchUpdater = pkgs.writers.writePython3Bin "patchUpdater" {} ''
      import fileinput
      import os
      for line in fileinput.input("packages/apps/Updater/res/values/config.xml",
                                  inplace=True):
          print(line.replace("https://releases.grapheneos.org/",
                os.getenv("UPDATE_SERVER")))
    '';
in
rec {

    latestRelease = pkgs.writers.writePython3Bin "latestRelease" {
      libraries = [ pkgs.python3Packages.requests pkgs.python3Packages.click pkgs.python3Packages.feedparser ];
    } ''
      import requests
      import click
      import feedparser


      def productname(codename):
          r = requests.get('https://grapheneos.org/build')
          for line in r.text.split("</li>"):
              if codename in line:
                  return line.lstrip(f"<li>{codename} (").rstrip(")").strip()
          raise Exception(f"could not find product name for codename {codename}")


      @click.command(no_args_is_help=True)
      @click.option('--codename',
                    help='the codename aka build target for devices can be \
                    found here https://grapheneos.org/build#build-targets')
      def run(codename):
          productnames = []
          for device in codename.split(","):
              productnames.append(productname(device))

          parser = feedparser.parse("https://grapheneos.org/releases.atom")
          release = parser.entries[0].title
          supported = (parser.entries[0]
                       .content[0]["value"]
                       .split(f"{release}</a> (")[1]
                       .split("Changes since the")[0]
                       .rstrip(")</li></ul><p>")
                       .split(", "))

          for pname in productnames:
              if pname not in supported:
                  return 1
          print(release)
          return 0


      if __name__ == '__main__':
          run()
    '';

    buildGrapheneOS =
      pkgs.writeShellApplication {
        name = "buildGrapheneOS";
        runtimeInputs = [ buildGrapheneOSandroidFHS
                          signGrapheneOSandroidFHS
                        ];
        bashOptions = [];
        text = ''
          set -e
          CRED_STORE=$(mktemp -d)

          echo "Enter the encryption password for your signing keys:"
          systemd-ask-password -n | systemd-creds --user encrypt --name=signingkeyspassword -p - "$CRED_STORE"/signingkeyspassword.cred
          systemd-run --user --wait --same-dir ${buildGrapheneOSandroidFHS.name} "$@"
          systemd-run --user --wait --property=LoadCredentialEncrypted=signingkeyspassword:"$CRED_STORE"/signingkeyspassword.cred --same-dir ${signGrapheneOSandroidFHS.name} "$@"
          '';
      };
  

    buildGrapheneOSandroidFHS = (env.androidFHS {
                            commandPkg = buildGrapheneOS-unwrapped;
                            command = ''buildGrapheneOS-unwrapped'';
                            name = "buildGrapheneOSandroidFHS";
                          });

    signGrapheneOSandroidFHS = (env.androidFHS {
                              commandPkg = signGrapheneOS-unwrapped;
                              command = ''signGrapheneOS-unwrapped'';
                              name = "signGrapheneOSandroidFHS";
                          });

    buildGrapheneOS-unwrapped = 
      writeBashInteractiveBin "buildGrapheneOS-unwrapped" ''
        set -xe

        #TODO remove
        exit 0

        if [ -z "$1" ]; then
          echo "Usage: ./buildGrapheneOS.sh <comma seperated device codenames (ex: tokay,caiman,oriale )> <grapheneos-release-tag-name> [optional update server hostname]"
          echo "the codename aka build target for devices can be found here https://grapheneos.org/build#build-targets"
          exit 1
        fi

        if [ -z "$2" ]; then
          echo "Usage: ./buildGrapheneOS.sh <device codename> <grapheneos-release-tag-name> [optional update server hostname]"
          echo "the tags can be found here https://grapheneos.org/releases"
          exit 1
        fi

        echo "all args: $@"

        CODENAMES=$1
        TAG=$2
        WORKDIR=$(pwd)

        if [ -z "$3" ]; then
          echo "not setting update server"
        else
          export UPDATE_SERVER=$3
          echo "Update server is set to $UPDATE_SERVER"
        fi

        devices=(''${CODENAMES//,/ })

        for device in ''${devices[@]}; do
          if [ ! -d "$WORKDIR/keys/$device" ]; then
            echo "keys dir $WORKDIR/keys/$device does not exist"
            exit 1
          fi
        done

        mkdir -p grapheneos
        cd grapheneos

        # must clean out/ between each device
        rm -rf out/

        repo init -u https://github.com/GrapheneOS/platform_manifest.git -b refs/tags/$TAG

        cd .repo/manifests
        git config gpg.ssh.allowedSignersFile ${allowed_signers}
        git verify-tag $(git describe)
        cd ../..

        repo sync -j8 --force-sync

        echo "repo at tag $TAG cloned and synced"

        if ! [ -z $UPDATE_SERVER ]; then
          echo "setting update server to $UPDATE_SERVER"
          ${pkgs.lib.getExe patchUpdater}
          if ${pkgs.ripgrep}/bin/rg -m1 "https://releases.grapheneos.org/" packages/apps/Updater/res/values/config.xml ; then
            echo "the offical update server is still set in the updater, refusing to build!"
            exit 1
          fi

          # includes the updater app
          export OFFICIAL_BUILD=true
        fi

        source build/envsetup.sh
        yarn --cwd vendor/adevtool/ install

        for device in ''${devices[@]}; do
          # must clean out/ between each device
          rm -rf out/

          if ${pkgs.ripgrep}/bin/rg -m1 "$TAG" ''${device}_built_tags ; then
            echo "already built $TAG for $device, not rebuilding"
            continue
          fi

          ./vendor/adevtool/bin/run generate-all -d $device

          lunch $device-cur-user

          if [[ "$device" =~ ^(oriole|raven|bluejay)$ ]]; then
            m vendorbootimage target-files-package otatools-package
          else
            #NOTE: this is currently correct for pixel 7 and newer. its possible newer devices will require different targets
            m vendorbootimage vendorkernelbootimage target-files-package otatools-package
          fi
          script/finalize.sh
        done
        
        echo $TAG > out/tag.txt
        echo "building complete"
      '';

    signGrapheneOS-unwrapped =
      writeBashInteractiveBin "signGrapheneOS-unwrapped" ''
        set -xe

        if [ -z "$1" ]; then
          echo "Usage: ./signGrapheneOS.sh <device codename>"
          echo "the codename aka build target for devices can be found here https://grapheneos.org/build#build-targets"
          exit 1
        fi

        WORKDIR=$(pwd)
        TAG=$(cat grapheneos/out/tag.txt)
        CODENAME=$1

        if [ ! -d "$WORKDIR/keys/$CODENAME" ]; then
          echo "keys dir $WORKDIR/keys/$CODENAME does not exist"
          exit 1
        fi

        if ${pkgs.ripgrep}/bin/rg -m1 "$TAG" ''${CODENAME}_built_tags ; then
          echo "already signed $TAG for $CODENAME, not signing new build"
          exit 0
        fi

        cd grapheneos

        mkdir -p keys/
        cp -a $WORKDIR/keys/$CODENAME keys/
        BUILD_NUMBER=$(cat out/soong/build_number.txt)
        # the grapheneos decrypt keys script consumes the password if set in env
        set +x
        export password=$(systemd-creds --user cat signingkeyspassword)
        set -x

        # the generate-release script doesnt decrypt the ssh signing key for us
        # and passing the key to ssh-keygen inside the script is not straightforward
        # so remove the ssh signing key so generate-release doesnt try to use it
        # signing the .zip is less important since its most useful
        # when distributing .zip files
        # additionally, the real protection comes from the other signing keys
        # since those are what are used to validate updates on device
        # TODO create a patch to generate-release to let us
        #      pass the ssh key password in easily
        rm keys/$CODENAME/id_ed25519

        script/generate-release.sh $CODENAME $BUILD_NUMBER

        mkdir -p $WORKDIR/releases/
        mv releases/* $WORKDIR/releases/

        echo "signed images available in $WORKDIR/releases/$BUILD_NUMBER/release-$CODENAME-$BUILD_NUMBER"

        echo "Completed build of GrapheneOS $TAG for $CODENAME"
        echo "$TAG" >> $WORKDIR/''${CODENAME}_built_tags
      '';
  
}
