{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.graphenix;
  defaultUserGroup = "graphenix";

  buildGrapheneOs-unwrapped = (import ../build.nix).buildGrapheneOS-unwrapped;
  latestRelease = (import ../build.nix).latestRelease;
  buildScript = pkgs.writeShellScript "buildScript" ''
    if [ -z "$1" ]; then
      echo "Usage: ./buildGrapheneOS.sh <device codename> <grapheneos-release-tag-name>"
      echo "the codename aka build target for devices can be found here https://grapheneos.org/build#build-targets"
      exit 1
    fi
    release=$(${latestRelease} --codename $1)
    echo "found release $release for device $1"
    ${buildGrapheneOs-unwrapped} $1 $release
  '';

in

{

  # TODO setup service to serve the updates for the updater app
  # TODO setup builder to patch in our update server
  
  options.services.graphenix = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        TODO
      '';
    };
    user = lib.mkOption {
      type = lib.types.str;
      default = defaultUserGroup;
      description = ''
        The user to build as.
      '';
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = defaultUserGroup;
      description = ''
        The group to build as.
      '';
    };

    dataDir = lib.mkOption {
      type = builtins.path;
      description = ''
        Directory to checkout grapheneos and build in
      '';
    };
    onCalendar = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = "daily";
      description = ''
        how often to check for new releases, and if there is a new release, start a build
      '';
    };

    devices = lib.mkOption {
      description = "Set of devices to build for, the name should be the codename of the device";
      type = lib.attrsOf (
        lib.types.submodule {
          options = {
            signingKeysPasswordFile = lib.mkOption {
              type = builtins.path;
              description = ''
                file containing the signing key password, used to decrypt the signing keys to sign the build. should likely be a sops or age path
              '';
            };
          };
        }
      );
      default = { };
    };

  };

  config = lib.mkIf cfg.enable {

    users.users = lib.optionalAttrs (cfg.user == defaultUserGroup) {
      ${cfg.user} = {
        description = "graphenix user";
        group = cfg.group;
        isSystemUser = true;
      };
    };

    users.groups = lib.optionalAttrs (cfg.group == defaultUserGroup) {
      ${cfg.group} = { };
    };

    systemd.services = pkgs.mapAttrs' (name: devicecfg: {
      name = "graphenix-${name}";
      value = {
        description = "graphenix: GrapheneOS auto builder";
        wantedBy = [
          "multi-user.target"
          # TODO see if this actually works and starts all of our builds
          "graphenix.timer"
        ];
        serviceConfig = {
          Type = "exec";
          User = cfg.user;
          Group = cfg.group;
          Restart = "no";

          WorkingDirectory = cfg.dataDir;
          LoadCredential = [ "signingkeyspassword:${devicecfg.signingKeyPasswordFile}" ];
          ExecStart = "${buildScript} ${cfg.device}";

          # limit the grapheneos builds to run serially
          Slice = "graphenix.slice";

          # Security options:
          NoNewPrivileges = true;
          CapabilityBoundingSet = [ "" ];
          SystemCallArchitectures = "native";
          RestrictAddressFamilies = [
            "AF_UNIX"
            "AF_INET"
            "AF_INET6"
          ];
          RestrictNamespaces = true;
          RestrictRealtime = true;
          RestrictSUIDSGID = true;
          ProcSubset = "pid";
          ProtectControlGroups = true;
          ProtectClock = true;
          ProtectHostname = true;
          ProtectKernelLogs = true;
          ProtectKernelModules = true;
          ProtectKernelTunables = true;
          ProtectProc = "invisible";
          ProtectSystem = true;
          LockPersonality = true;
          PrivateTmp = true;
          PrivateUsers = true;
          RemoveIPC = true;
        };
      };
    }) cfg.devices;
  };

  # concept to start all jobs serially borrowed from https://unix.stackexchange.com/questions/806565/how-do-i-start-multiple-systemd-services-on-the-same-schedule-but-run-each-one-s
  systemd.timers.graphenix = {
    description = "Timer to check for new grapheneos releases and start builds for all devices";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      Unit = "graphenix.target";
      OnCalendar = cfg.onCalendar;
      AccuracySec = "10min";
      Persistent = true;
    };
  };

  systemd.targets.graphenix = {
    description = "dummy target for the timer, allows the actual jobs to get triggered as well";
  };

  systemd.slices.graphenix = {
    description = "serialize the builds";
    sliceConfig = {
      ConcurrencySoftMax = 1;
    };
  };
}
