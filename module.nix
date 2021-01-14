{ config
, pkgs
, lib
, ...
}: let
  cfg = config.services.concourse-worker;
in {
  options.services.concourse-worker = with lib; {
    enable = mkEnableOption "Concourse worker";

    name = mkOption {
      description = "Worker name. Defaults to system hostname";
      type = types.str;
      default = config.networking.hostName;
    };

    tags = mkOption {
      description = "Worker tags";
      type = types.listOf types.str;
      default = [];
    };

    logLevel = mkOption {
      description = "Log level";
      default = "error";
      type = types.enum [ "debug" "info" "error" "fatal" ];
    };

    ephemeral = mkEnableOption "ephemeral mode";

    runtime = mkOption {
      description = "Concourse worker runtime";
      default = "containerd";
      type = types.enum [ "containerd" "garden" "houdini" ];
    };

    containersLimit = mkOption {
      description = "Containers limit";
      default = 250;
      type = types.ints.positive;
    };

    dnsProxy = mkEnableOption "dns proxy";

    networkPool = mkOption {
      description = "Network pool";
      default = "10.80.0.0/16";
      type = types.str;
    };

    containerdSocketPath = mkOption {
      description = "containerd socket path";
      default = "/run/concourse/containerd/containerd.sock";
      type = types.str;
    };

    workDir = mkOption {
      description = "Working directory";
      default = "/var/lib/concourse-worker/work";
      type = types.str;
    };

    privateKeyFile = mkOption {
      description = "Worker private key file";
      default = "/var/lib/concourse-worker/keys/privatekey";
      type = types.str;
    };

    tsaAddresses = mkOption {
      description = "TSA addresses";
      default = [ "127.0.0.1:2222" ];
      type = types.listOf types.str;
    };

    tsaPublicKeyFile = mkOption {
      description = "TSA public key file";
      default = "/var/lib/concourse-worker/keys/tsa_public_key";
      type = types.str;
    };

    baggageclaimDriver = mkOption {
      description = "Volumes driver";
      default = "overlay";
      type = types.enum [ "naive" "btrfs" "overlay" ];
    };

    baggageclaimLogLevel = mkOption {
      description = "Baggageclaim log level";
      default = "error";
      type = types.enum [ "debug" "info" "error" "fatal" ];
    };
  };

  config = {
    systemd.services.concourse-worker = lib.optionalAttrs cfg.enable {
      description = "Concourse worker";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        User = "root";
        Restart = "on-abnormal";
        Type = "simple";
        RestartSec = "10s";
        StartLimitIntervalSec = "60";
        Delegate = true;

        ExecStartPre = pkgs.writeShellScript "concourse-worker-pre" ''
          mkdir -p "${cfg.workDir}"
          if ! (test -f "${cfg.privateKeyFile}"); then
            mkdir -p "$(${pkgs.coreutils}/bin/dirname -- "${cfg.privateKeyFile}")"
            ${pkgs.coreutils}/bin/env -i -- ${pkgs.concourse}/bin/concourse \
              generate-key -t ssh -f "${cfg.privateKeyFile}"
          fi

          if ! (test -f "${cfg.tsaPublicKeyFile}"); then
            mkdir -p "$(${pkgs.coreutils}/bin/dirname -- "${cfg.tsaPublicKeyFile}")"
            touch -- "${cfg.tsaPublicKeyFile}"
          fi
        '';
        ExecStart = "${pkgs.concourse}/bin/concourse worker";
      };

      environment = {
        CONCOURSE_EPHEMERAL = toString cfg.ephemeral;
        CONCOURSE_LOG_LEVEL = cfg.logLevel;
        CONCOURSE_RUNTIME = cfg.runtime;
        CONCOURSE_BAGGAGECLAIM_LOG_LEVEL = cfg.baggageclaimLogLevel;
        CONCOURSE_WORK_DIR = cfg.workDir;
        CONCOURSE_TSA_PUBLIC_KEY = cfg.tsaPublicKeyFile;
        CONCOURSE_TSA_WORKER_PRIVATE_KEY = cfg.privateKeyFile;
        CONCOURSE_TSA_HOST = builtins.concatStringsSep "," cfg.tsaAddresses;
      } // (lib.optionalAttrs (cfg.runtime == "containerd") {
        CONCOURSE_CONTAINERD_NETWORK_POOL = cfg.networkPool;
        CONCOURSE_CONTAINERD_MAX_CONTAINERS = toString cfg.containersLimit;
        CONCOURSE_CONTAINERD_DNS_PROXY_ENABLE = toString cfg.dnsProxy;
        CONCOURSE_CONTAINERD_SOCKET_PATH = cfg.containerdSocketPath;
        CONTAINERD_NAMESPACE = "concourse"; # TODO: configurable
      }) // (lib.optionalAttrs (cfg.runtime == "garden") {
        CONCOURSE_GARDEN_NETWORK_POOL = cfg.networkPool;
        CONCOURSE_GARDEN_MAX_CONTAINERS = toString cfg.containersLimit;
        CONCOURSE_GARDEN_DNS_PROXY_ENABLE = toString cfg.dnsProxy;
      });
    };
  };
}
