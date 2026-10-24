# graphenix - GrapheneOS Automated Builds and Build Environment

## features
- automatically build the newest grapheneos release for multiple devices
- automated signing and signing key password management
- updater app configuration to receive ota updates


## module usage

add graphenix to your nixos config repo
use whatever tool you like to consume modules
```
lon add github solidEva/graphenix
```

then in your machines configuration:
```
{sources, ... }:
{
  imports =
    [
      "${sources.graphenix}/nix/modules/graphenix.nix"
    ];

  <other config>

  services.graphenix = {
    enable = true;
    dataDir = "/build/graphene/";
    devices = {
      # manage your device passwords with some sort of secret management, sops-nix is used here
      tokay.signingKeysPasswordFile = "${config.sops.secrets."graphenix/tokay/password".path}";
      caiman.signingKeysPasswordFile = "${config.sops.secrets."graphenix/caiman/password".path}";
    };
    updateServerHostname = "https://myupdateserver.com";
  };
}
```

before rebuilding your system, create a working dir. `/build/graphene` will be used for these instructions. whatever you choose should match the path in `${services.graphenix.dataDir}`.

in the working dir, create a `keys` directory with each device your would like to build. put your release signing keys for each device in the `keys` directory.
keys can be created by following https://grapheneos.org/build#generating-release-signing-keys

*NOTE* as noted in the grapheneos release singing keys generation instructions:
    * each device should use a unique password for its keys, do not re-use passwords between devices.
    * all keys for a device should use the same password, so that signing automation only needs a single password.
  
if you need an environment to generate keys, you can use the build environment to clone the repos. instructions for manual usage of the build env are below.

once you have your keys, the working dir should now look something like this:
```
/build/graphene/keys/
                ├── <device1>
                │   ├── avb.pem
                │   ├── <list of keys truncated>
                │   └── shared.x509.pem
                └── <device2>
                    ├── avb.pem
                    ├── <list of keys truncated>
                    └── shared.x509.pem
```



by default, this will check for new releases daily. when a new release is found, it will build and sign images for all devices in `services.graphenix.devices`.
    * sources will be checked out in `${services.graphenix.dataDir}/grapheneos`
    * all of the release files are in `${services.graphenix.dataDir}/releases`.
    * files for your update server are in `${services.graphenix.dataDir}/update_server`
        * these files can be copied directly to the root of a simple webserver, serving `${services.graphenix.updateServerHostname}`
    * the list of built tags are in `${services.graphenix.dataDir}/<device-codename>_built_tags`, this is how the automation knows which tags have been built

## example update server configuration

nginx:
```
server {
	listen 8686;
	server_name  localhost;

    root /www/data;

    location / {
    }
}
```
copy the contents of `${services.graphenix.dataDir}/update_server` to `/www/data`
automating this copy can be done with many tools: e.g. rsync, syncthing, etc


## build environment usage
use `nix-shell` to activate, then cd to your working dir

if you havent already created signing keys, clone the repos by running `cloneGrapheneOS <tag>`.
if you already have keys, you can skip this step
create your signing keys as detailed on https://grapheneos.org/build#generating-release-signing-keys


finally run `buildGrapheneOS <device> <tag>`.

ex:
```
buildGrapheneOS tokay 2026091900
buildGrapheneOS caiman 2026091900
```

`buildGrapheneOS` will prompt you for your signing keys encryption password (and store it using systemd-creds until the end of build), then use `systemd-run` to kick off the long process of cloning, building, & signing.

if the working directory already has a grapheneos checkout, it will re-use that

## maintenance
- update the nixpkgs pin by running `lon --directory nix update --commit nixpkgs`


## thanks
core of initial shell.nix borrowed from https://gist.github.com/Arian04/bea169c987d46a7f51c63a68bc117472
