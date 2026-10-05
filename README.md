# graphenix - A GrapheneOS Build environment using nix

## usage
use `nix-shell` to activate, then cd to your working dir

create your signing keys as detailed on https://grapheneos.org/build#generating-release-signing-keys

then run `buildGrapheneOS <device> <tag>`.

ex:
```
buildGrapheneOS tokay 2026091900
buildGrapheneOS caiman 2026091900
```


## details
`buildGrapheneOS` will prompt you for your signing keys encryption password (and store it using systemd-creds until the end of build), then use `systemd-run` to kick off the long process of cloning, building, & signing.

if the working directory already has a grapheneos checkout, it will re-use that


## maintenance
- update the nixpkgs pin by running `lon --directory nix update --commit nixpkgs`


## thanks
core of initial shell.nix borrowed from https://gist.github.com/Arian04/bea169c987d46a7f51c63a68bc117472
