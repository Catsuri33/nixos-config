{ pkgs, ... }:
{
  home.packages = with pkgs; [
    # Communication
    mattermost-desktop

    # Dev tools
    dbeaver-bin

    # Network analysis
    wireshark
  ];
}
