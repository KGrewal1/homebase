# COSMIC: System76's Rust desktop (what Pop!_OS ships now).
# Auto-tiling is built in — toggle per workspace from the panel or Super+Y.
{ pkgs, ... }:
{
  services.desktopManager.cosmic.enable = true;
  services.displayManager.cosmic-greeter.enable = true;

  # Lets clipboard managers read the Wayland clipboard
  environment.sessionVariables.COSMIC_DATA_CONTROL_ENABLED = "1";

  services.pipewire = {
    enable = true;
    pulse.enable = true;
    alsa.enable = true;
  };
  security.rtkit.enable = true;

  environment.systemPackages = with pkgs; [
    cosmic-ext-tweaks
  ];
}
