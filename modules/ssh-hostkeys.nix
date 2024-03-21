{ pkgs, ... } :
rec {
  programs.ssh = {
    knownHosts = {
      "[enif.pegasus.serokell.team]:17788" = { publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKBl5xDVPpBwnDjy3/vocWhkxd4gzG2/XhCqu4BKBqSP"; };
      "[helvetios.pegasus.serokell.team]:17788" = { publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGMP/QMBHckFeyyexEXkb/7mda52G5wZsdSE78fBMmop"; };
      "[tt.serokell.io]:17788" = { publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIN/DPi5VvEabvJIYCIeydk6JlIdrbBw5Y4OYC3Z1WFc9"; };
      "[tejat-prior.gemini.serokell.team]:17788" = { publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOUHTzCw27rNtOFGt6ILtAcWDIMSWWy78m1uyfTDjrYW"; };
      "agora.tezos.serokell.team" = { publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIH/2LMJECtHWdJDvWBcGFtwJmFnGp1nTt3dE+Tibig+g"; };
      "blend.stakerdao.serokell.team" = { publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPyV4zyowfZf71F2MlRFyIvtWfqWFhc+lxqyCHXQWa2X"; };
      "bridge.stakerdao.serokell.team" = { publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIL8S9rAPQ9Ha+tcRBgYSayvQ+7iV15muiYNiwWYOLc8C"; };
      "ch-s012.rsync.net" = { publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIO5lfML3qjBiDXi4yh3xPoXPHqIOeLNp66P3Unrl+8g3"; };
      "demo.edna.serokell.team" = { publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIELrARU5i3TM7PR1fcCmtRsnW0vFFTib0hNCBw561WtQ"; };
      "pont.ee" = { publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEIWQaHzlzVhBo8Yld/5bUp5fvOQiPJOMHFJyu7iMPHs"; };
      "pont.serokell.team" = { publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMTEXN9yBPSTdFRtOkJGt/CzlemqS/bSzbsOGDRvU/U/"; };
      "sadalbari.pegasus.serokell.team" = { publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILlXjtyvFlJIH8d4KEf/YG0c2fwYBjIoig5ZvQjw5qkl"; };
      "social-network.serokell.team" = { publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIM0fI99uE0u0iExolwIFDMEw9ITX3jNlvSMa+YmzN+ar"; };
      "staging.edna.serokell.team" = { publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAdeUbotl2b/CbCmXWZ0UBkp0kbritHc9Sw//UnFIJi1" ; };
      "www.tezosagora.org" = { publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIK3YKZ2BSk/Ysb/qfUVQSbHOkkiALiVjv1DAKTKQFhp3"; };
      "algenib.pegasus.serokell.team" = { publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPKGJVl1ob4KAYGPcJkHdoZMLgnOLDNsyKIgJI/iScAt"; };
      "staging.ment.serokell.team" = { publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMTEXN9yBPSTdFRtOkJGt/CzlemqS/bSzbsOGDRvU/U/"; };
      "biham.pegasus.serokell.team" = { publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIE9HYKeUNkKcMgqfJ86BYdLE90FRgWwxx+qEiEp70Md2"; };
      "[skat.aquarius.serokell.team]:17788" = { publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILyJ3GkPNLcFGYW46Y7k0SDTuNqIOse03nsNOu0OHLVT"; };
    };
    knownHostsFiles = [
      (pkgs.writeText "github.keys" ''
        github.com ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCj7ndNxQowgcQnjshcLrqPEiiphnt+VTTvDP6mHBL9j1aNUkY4Ue1gvwnGLVlOhGeYrnZaMgRK6+PKCUXaDbC7qtbW8gIkhL7aGCsOr/C56SJMy/BCZfxd1nWzAOxSDPgVsmerOBYfNqltV9/hWCqBywINIR+5dIg6JTJ72pcEpEjcYgXkE2YEFXV1JHnsKgbLWNlhScqb2UmyRkQyytRLtL+38TGxkxCflmO+5Z8CSSNY7GidjMIZ7Q4zMjA2n1nGrlTDkzwDCsw+wqFPGQA179cnfGWOWRVruj16z6XyvxvjJwbz0wQZ75XK5tKSb7FNyeIEs4TT4jk+S4dhPeAUC5y+bDYirYgM4GC7uEnztnZyaVWQ7B381AK4Qdrwt51ZqExKbQpTUNn+EjqoTwvqNj4kqx5QUCI0ThS/YkOxJCXmPUWZbhjpCg56i+2aB6CmK2JGhn57K5mj0MNdBXA4/WnwH6XoPWJzK5Nyu2zB3nAZp+S5hpQs+p1vN1/wsjk=
        github.com ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBEmKSENjQEezOmxkZMy7opKgwFB9nkt5YRrYMjNuG5N87uRgg6CLrbo5wAdT/y6v0mKV0U2w0WZ2YB/++Tpockg=
        github.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl
      '')
      (pkgs.writeText "gitlab.keys" ''
        gitlab.com ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCsj2bNKTBSpIYDEGk9KxsGh3mySTRgMtXL583qmBpzeQ+jqCMRgBqB98u3z++J1sKlXHWfM9dyhSevkMwSbhoR8XIq/U0tCNyokEi/ueaBMCvbcTHhO7FcwzY92WK4Yt0aGROY5qX2UKSeOvuP4D6TPqKF1onrSzH9bx9XUf2lEdWT/ia1NEKjunUqu1xOB/StKDHMoX4/OKyIzuS0q/T1zOATthvasJFoPrAjkohTyaDUz2LN5JoH839hViyEG82yB+MjcFV5MU3N1l1QL3cVUCh93xSaua1N85qivl+siMkPGbO5xR/En4iEY6K2XPASUEMaieWVNTRCtJ4S8H+9
        gitlab.com ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBFSMqzJeV9rUzU4kWitGjeR4PWSa29SPqJ1fVkhtj3Hw9xjLVXVYrU9QlYWrOLXBpQ6KWjbjTDTdDkoohFzgbEY=
        gitlab.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAfuCHKVTjquxvt6CM6tdG4SLp1Btn/nOeHHE5UOzRdf
      '')
    ];
  };
}
