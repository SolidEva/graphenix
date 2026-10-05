let
  sources = import ./nix/lon.nix;
  pkgs = import sources.nixpkgs { };
  env = import ./nix/env.nix { inherit pkgs; };
  build = import ./nix/build.nix { inherit pkgs; };

in
pkgs.stdenv.mkDerivation {
  name = "android-env-shell";
  nativeBuildInputs = [
    (env.androidFHS {
      commandPkg = pkgs.bash;
      command = "bash";
    })
    (build.buildGrapheneOS)
  ];
  shellHook = ''
    echo "run buildGrapheneOS to build images"
    exec androidFHS
  '';
}
