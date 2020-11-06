# SPDX-FileCopyrightText: 2020 Serokell <https://serokell.io/>
#
# SPDX-License-Identifier: MPL-2.0

{ config, lib, ... }:
with lib;
let
  cfg = config.services.oauth2_proxy.nginx;
  vhostmod.options = {
    applicationChecksAuth = mkEnableOption "The backend will check the auth headers, always forward";
    host = mkOption {
      type = types.str;
      example = "serokell.io";
      default = "$host";
    };
  };
in
{
  disabledModules = [ "services/security/oauth2_proxy_nginx.nix" ];
  options.services.oauth2_proxy.nginx = {
    proxy = mkOption {
      type = types.str;
      default = config.services.oauth2_proxy.httpAddress;
      description = ''
        The address of the reverse proxy endpoint for oauth2_proxy
      '';
    };
    virtualHosts = mkOption {
      type = with types; coercedTo (listOf str) (l: lib.genAttrs l (_:{})) (attrsOf (submodule vhostmod));
      default = {};
      description = ''
        A list of nginx virtual hosts to put behind the oauth2 proxy
      '';
    };
  };
  config.services.oauth2_proxy = mkIf (cfg.virtualHosts != [] && (hasPrefix "127.0.0.1:" cfg.proxy)) {
    enable = true;
  };
  config.services.nginx = mkMerge ((optional (cfg.virtualHosts != {}) {
    recommendedProxySettings = true; # needed because duplicate headers
  }) ++ (lib.mapAttrsToList (vhost: opts: {
    virtualHosts.${vhost} = {
      locations."/oauth2/" = {
        proxyPass = cfg.proxy;
        extraConfig = ''
          proxy_set_header X-Scheme                $scheme;
          proxy_set_header X-Auth-Request-Redirect $scheme://${opts.host}$request_uri;
          proxy_set_header Host ${opts.host};
        '';
      };
      locations."/oauth2/auth" = {
        # oauth2_proxy patched to accept headersOnly query param that always returns 202, but sets the headers
        # when logged in
        proxyPass = cfg.proxy + (lib.optionalString opts.applicationChecksAuth "/oauth2/auth?headersOnly=true");
        extraConfig = ''
          proxy_set_header X-Scheme         $scheme;
          # nginx auth_request includes headers but not body
          proxy_set_header Content-Length   "";
          proxy_pass_request_body           off;
        '';
      };
      locations."/".extraConfig = ''
        auth_request /oauth2/auth;
        error_page 401 = /oauth2/sign_in;

        # pass information via X-User and X-Email headers to backend,
        # requires running with --set-xauthrequest flag
        auth_request_set $user   $upstream_http_x_auth_request_user;
        auth_request_set $email  $upstream_http_x_auth_request_email;
        proxy_set_header X-User  $user;
        proxy_set_header X-Email $email;

        # if you enabled --cookie-refresh, this is needed for it to work with auth_request
        auth_request_set $auth_cookie $upstream_http_set_cookie;
        add_header Set-Cookie $auth_cookie;
        ${lib.optionalString opts.applicationChecksAuth "proxy_intercept_errors on;"}
      '';

    };
  }) cfg.virtualHosts));
}
