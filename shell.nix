let
  sources = import ./lon.nix;
  pkgs = import sources.nixpkgs { };

  fhs = pkgs.buildFHSEnv {
    name = "android-env";
    targetPkgs = pkgs:
      with pkgs; [
        android-tools
        libxcrypt-legacy # libcrypt.so.1
        freetype # libfreetype.so.6
        fontconfig # java NPE: "sun.awt.FontConfiguration.head" is null
        yaml-cpp # necessary for some kernels according to a comment on the gist

        bc
        binutils
        bison
        ccache
        curl
        flex
        gcc
        gcc.cc
        git
        git-repo
        git-lfs
        glibc.dev
        gnumake
        gnupg
        gperf
        openssl
        imagemagick
        jdk11
        jdk17
        elfutils
        libxml2
        libxslt
        lz4
        lzop
        m4
        nettools
        nodejs_24
        openssl.dev
        perl
        pngcrush
        procps
        python3
        rsync
        schedtool
        SDL
        squashfsTools
        unzip
        util-linux
        xml2
        yarn
        zip
      ];
    multiPkgs = pkgs:
      with pkgs; [
        zlib
        ncurses5
        libcxx
        readline

        libgcc # crtbeginS.o
        iconv
        iconv.dev # sys/types.h
      ];
    runScript = "bash"; # personal preference, you could set this to bash instead if you want
    profile = ''
      export ALLOW_NINJA_ENV=true
      export ANDROID_JAVA_HOME=${pkgs.jdk17.home}
      # Building involves a phase of unzipping large files into a temporary directory
      export TMPDIR=/tmp
      export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:${pkgs.ncurses5}/lib
    '';
  };
in
  pkgs.stdenv.mkDerivation {
    name = "android-env-shell";
    nativeBuildInputs = [fhs];
    shellHook = "exec android-env";
  }
