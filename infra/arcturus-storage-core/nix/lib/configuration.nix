{ config, host, pkgs, pkgs-unstable, ... }:

{
  sops.defaultSopsFile = ./secrets.sops.yaml;
  sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
  sops.age.keyFile = "/var/lib/sops-nix/key.txt";
  sops.age.generateKey = true;
  sops.secrets.domain = { };
  sops.templates."k3s-config".content = ''
    disable:
      - 'local-storage'
      - 'traefik'
    tls-san:
      - '${host.name}.${config.sops.placeholder.domain}'
  '';

  boot.initrd.kernelModules = [ "i915" ];
  boot.kernelModules = [ "kvm-intel" ];

  environment.variables.VDPAU_DRIVER = "va_gl";

  boot.loader.systemd-boot.configurationLimit = 10;
  boot.loader.systemd-boot.enable = true;

  documentation.nixos.enable = false;
  networking.hostName = host.name;

  i18n = {
    defaultLocale = "en_US.UTF-8";
  };
  hardware.cpu.intel.updateMicrocode = true;
  hardware.opengl.extraPackages = [
    pkgs.intel-compute-runtime
    pkgs.intel-media-driver
    pkgs.vaapiIntel
    pkgs.vaapiVdpau
    pkgs.libvdpau-va-gl
  ];

  nix = {
    settings = {
      experimental-features = [ "nix-command" "flakes" ];
      warn-dirty = false;
    };
    gc = {
      automatic = true;
      options = "--delete-older-than 2d";
    };
  };
  nix.gc.dates = "weekly";
  networking.hostId = host.id;
  networking.firewall.allowedTCPPorts = [ 2049 6443 ];


  security.pam.enableSSHAgentAuth = true;
  security.pam.loginLimits = [
    {
      domain = "@wheel";
      item = "nofile";
      type = "soft";
      value = "524288";
    }
    {
      domain = "@wheel";
      item = "nofile";
      type = "hard";
      value = "1048576";
    }
  ];
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
      StreamLocalBindUnlink = "yes";
      GatewayPorts = "clientspecified";
    };
  };
  services.xserver.videoDrivers = [ "modesetting" ];
  services.k3s = {
    enable = true;
    role = "server";
    package = pkgs-unstable.k3s_1_27;
  };
  services.k3s.configPath = config.sops.templates."k3s-config".path;
  services.smartd = {
    enable = true;
    defaults.monitored = ''
      -a -o on -S on -n standby,q -s (S/../.././01|L/../../7/04:002) -W 4,40,45
    '';
    notifications = {
      mail = {
        enable = false;
      };
      wall.enable = false;
    };
  };
  environment.systemPackages = [
    pkgs.smartmontools
    pkgs-unstable.k3s_1_27
  ];

  services.nfs.server.enable = true;
  services.samba-wsdd.enable = true;
  services.samba = {
    enable = true;
    openFirewall = true;
    securityType = "user";
    extraConfig = ''
      min protocol = SMB2
      workgroup = WORKGROUP

      ea support = yes
      vfs objects = acl_xattr catia fruit streams_xattr
      fruit:metadata = stream
      fruit:model = MacSamba
      fruit:veto_appledouble = no
      fruit:posix_rename = yes
      fruit:zero_file_id = yes
      fruit:wipe_intentionally_left_blank_rfork = yes
      fruit:delete_empty_adfiles = yes
      fruit:nfs_aces = no

      browseable = yes
      guest ok = no
      guest account = nobody
      map to guest = bad user
      inherit acls = yes
      map acl inherit = yes
      valid users = @samba-users

      veto files = /._*/.DS_Store/
      delete veto files = yes
    '';
    shares = {
      Void = {
        path = "/tank/void";
        "read only" = "no";
      };
      Media = {
        path = "/tank/media";
        "read only" = "no";
      };
      Paperless = {
        path = "/tank/apps/paperless/incoming";
        "read only" = "no";

      };
    };
  };

  boot = {
    supportedFilesystems = [ "zfs" ];
    zfs = {
      forceImportRoot = false;
      extraPools = [ "tank" ];
    };
  };

  services.zfs = {
    autoScrub.enable = true;
    trim.enable = true;
  };

  system.stateVersion = "23.11";

  time.timeZone = "Europe/Prague";

  users.mutableUsers = false;

  users.groups = {
    external-services = {
      gid = 65542;
    };
    admins = {
      gid = 991;
      members = [ "aka-raccoon" ];
    };
    samba-users = { };
  };

  users.users.aka-raccoon = {
    isNormalUser = true;
    uid = 1000;
    extraGroups = [
      "wheel"
      "network"
      "samba-users"
    ];

    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKnOmCg9nezqX9c5sTeopMX65bitv51KbzTW8Eco5T3+ aka-raccoon"
    ];
  };


}




