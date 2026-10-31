# Tailscale. Identity lives in /var/lib/tailscale/tailscaled.state.
# Either restore that file from the old install (keeps name + 100.113.28.32),
# or log in fresh once with `sudo tailscale up`. See hosts/neptune/README.md.
{ config, ... }:
{
  services.tailscale = {
    enable = true;
    useRoutingFeatures = "client"; # use exit nodes / subnet routes
    extraSetFlags = [ "--ssh" ]; # Tailscale SSH, applied on every start
  };

  # MagicDNS works best with systemd-resolved
  services.resolved.enable = true;

  networking.firewall = {
    enable = true;
    trustedInterfaces = [ "tailscale0" ];
    allowedUDPPorts = [ config.services.tailscale.port ];
  };
}
