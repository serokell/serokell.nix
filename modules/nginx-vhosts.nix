{ config, lib, ... }:

with lib;

let
  inherit (config.networking) domain;
  cert = config.services.acme-sh.certs.serokell;
  # todo: match against cert.domains

  overrideVirtualHost = name: vhost: vhost // ({
    forceSSL = true;
  }) // (optionalAttrs (vhost.sslCertificate == null && vhost.enableACME == false) {
    sslCertificate = cert.certPath;
    sslCertificateKey = cert.keyPath;
  }) // (optionalAttrs (vhost.serverName == null) {
    serverName = "${name}.${domain}";
  });
in

{
  options.services.nginx.virtualHosts = mkOption {
    apply = vhosts: mapAttrs overrideVirtualHost vhosts;
  };
}
