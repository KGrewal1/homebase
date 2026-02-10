{ configFiles, ... }:
{
  home.stateVersion = "24.11";
  xdg.configFile = configFiles;
}
