rec {
  # Exposure 0.0, but can't really do anything
  isolate = {
    PrivateNetwork = "yes";
    # CapabilityBoundingSet = [
    #   "~CAP_(CHOWN|FSETID|SETFCAP)"
    #   "~CAP_(DAC_*|FOWNER|IPC_OWNER)"
    #   "~CAP_AUDIT_*"
    #   "~CAP_BLOCK_SUSPEND"
    #   "~CAP_IPC_LOCK"
    #   "~CAP_KILL"
    #   "~CAP_LEASE"
    #   "~CAP_LINUX_IMMUTABLE"
    #   "~CAP_MAC_*"
    #   "~CAP_MKNOD"
    #   "~CAP_NET_(BIND_SERVICE|BROADCAST|RAW)"
    #   "~CAP_NET_ADMIN"
    #   "~CAP_SET(UID|GID|PCAP)"
    #   "~CAP_SYSLOG"
    #   "~CAP_SYS_(NICE|RESOURCE)"
    #   "~CAP_SYS_ADMIN"
    #   "~CAP_SYS_BOOT"
    #   "~CAP_SYS_CHROOT"
    #   "~CAP_SYS_MODULE"
    #   "~CAP_SYS_PACCT"
    #   "~CAP_SYS_PTRACE"
    #   "~CAP_SYS_RAWIO"
    #   "~CAP_SYS_TIME"
    #   "~CAP_SYS_TTY_CONFIG"
    #   "~CAP_WAKE_ALARM"
    # ];
    CapabilityBoundingSet = [ "" ];
    # RestrictAddressFamilies = "~AF_(UNIX|INET|INET6|PACKET|NETLINK)";
    RestrictAddressFamilies = [ "" ];
    # RestrictNamespaces = [
    #   "~CLONE_NEWUSER"
    #   "~CLONE_NEWCGROUP"
    #   "~CLONE_NEWIPC"
    #   "~CLONE_NEWNET"
    #   "~CLONE_NEWNS"
    #   "~CLONE_NEWPID"
    #   "~CLONE_NEWUTS"
    # ];
    RestrictNamespaces = "yes";
    DeviceAllow = "no";
    IPAddressDeny = "any";
    KeyringMode = "private";
    NoNewPrivileges = "yes";
    NotifyAccess = "none";
    PrivateDevices = "yes";
    PrivateMounts = "yes";
    PrivateTmp = "yes";
    PrivateUsers = "yes";
    ProtectClock = "yes";
    ProtectControlGroups = "yes";
    ProtectHome = "yes";
    ProtectKernelLogs = "yes";
    ProtectKernelModules = "yes";
    ProtectKernelTunables = "yes";
    ProtectProc = "invisible";
    ProtectSystem = "strict";
    RestrictSUIDSGID = "yes";
    SystemCallArchitectures = "native";
    SystemCallFilter = [
      "~@clock"
      "~@debug"
      "~@module"
      "~@mount"
      "~@raw-io"
      "~@reboot"
      "~@swap"
      "~@privileged"
      "~@resources"
      "~@cpu-emulation"
      "~@obsolete"
    ];
    AmbientCapabilities = [ "" ];
    RestrictRealtime = "yes";
    # Not sure when to really use this
    # RootDirectory = "";
    SupplementaryGroups = [ "" ];
    Delegate = "no";
    LockPersonality = "yes";
    MemoryDenyWriteExecute = "yes";
    RemoveIPC = "yes";
    UMask = "0077";
    ProtectHostname = "yes";
    ProcSubset = "pid";
  };
  # Exposure 1.1 OK, suitable for most of our backends
  backend = isolate // {
    RestrictAddressFamilies = [
      "AF_INET"
      "AF_UNIX" # For postgresql etc
    ];
    # Most of our backends need network access
    IPAddressDeny = [ "" ];
    PrivateNetwork = "no";
  };
  # Exposure 0.8 OK, suitable for backends that listen on UNIX sockets only
  backend_unix_socket = backend // {
    RestrictAddressFamilies = [ "AF_UNIX" ];
  };
}
