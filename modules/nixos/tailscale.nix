# Tailscale. Identity lives in /var/lib/tailscale/tailscaled.state.
# Either restore that file from the old install, or log in fresh once with
#   sudo tailscale up --ssh --advertise-tags=tag:prod
# See hosts/neptune/README.md.
{ config, ... }:
{
  services.tailscale = {
    enable = true;
    useRoutingFeatures = "client"; # use exit nodes / subnet routes
    # Applied on every start. tag:prod makes the node tailnet-owned rather than
    # user-owned, which disables key expiry — but it also means autogroup:self
    # SSH rules no longer match, so the policy file needs an ssh rule with
    # dst: ["tag:prod"] or Tailscale SSH to this host breaks.
    extraSetFlags = [ "--ssh" "--advertise-tags=tag:prod" ];
  };

  # MagicDNS works best with systemd-resolved
  services.resolved.enable = true;

  networking.firewall = {
    enable = true;
    trustedInterfaces = [ "tailscale0" ];
    allowedUDPPorts = [ config.services.tailscale.port ];
  };
}
