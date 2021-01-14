{ config, pkgs, ... }:
{
  imports = [
    ../module.nix
  ];

  nixpkgs.overlays = [
    (self: super: {
      concourse = super.callPackage ../default.nix {};
    })
  ];

  networking.hostName = "nixos";
  networking.useDHCP = true;

  i18n.defaultLocale = "en_US.UTF-8";
  console = {
    font = "Lat2-Terminus16";
    keyMap = "us";
  };

  time.timeZone = "Europe/Tallinn";

  systemd.enableUnifiedCgroupHierarchy = false;

  services.openssh = {
    enable = true;
    permitRootLogin = "yes";
  };

  services.concourse-worker.enable = true;

  users.mutableUsers = false;
  users.users.root.initialPassword = "root";
  services.getty.autologinUser = "root";
  
  system.stateVersion = "21.03";
}
