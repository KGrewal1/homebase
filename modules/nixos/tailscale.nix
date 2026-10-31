# Tailscale. After the first boot run once:  sudo tailscale up --ssh
# (Login state persists in /var/lib/tailscale, so no auth key is needed.)
{ config, ... }:
{
  services.tailscale = {
    enable = true;
    useRoutingFeatures = "client"; # use exit nodes / subnet routes
  };

  # MagicDNS works best with systemd-resolved
  services.resolved.enable = true;

  networking.firewall = {
    enable = true;
    trustedInterfaces = [ "tailscale0" ];
    allowedUDPPorts = [ config.services.tailscale.port ];
  };
}
