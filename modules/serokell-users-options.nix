{lib, ...}:
let
  inherit (lib) mkOption types;
in
{
  wheelUsers = mkOption rec {
    type = types.listOf types.str;
    description = "Users added to wheel group";
    example = [ "gosha" "masha" ];
    default = [
      "gromak"
      "jaga"
      "sweater"
      "balsoft"
      "rvem"
      "sereja"
      "savely"
    ];
    apply = users: default ++ users;
  };

  wheelUsersExtraGroups = mkOption {
    default = [ ];
    type = types.listOf types.str;
    description = "Extra groups added to users in wheelUsers";
    example = [ "docker" ];
  };

  regularUsers = mkOption {
    default = [ ];
    type = types.listOf types.str;
    description = "Regular users";
    example = [ "misha" "vasya" "petya" ];
  };

  regularUsersExtraGroups = mkOption {
    default = [ ];
    type = types.listOf types.str;
    description = "Extra groups added to all users";
    example = [ "systemd-journal" ];
  };
}
