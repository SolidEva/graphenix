# graphenix - A GrapheneOS Build environment using nix

## usage
use `nix-shell` to activate, then follow https://grapheneos.org/build like usual

or use `clone.sh` and `build.sh` to clone the sources, and perform a build for a specific device at a specific release



## maintenance
- update the nixpkgs pin by running `lon --directory nix update --commit nixpkgs`


core of initial shell.nix borrowed from https://gist.github.com/Arian04/bea169c987d46a7f51c63a68bc117472
