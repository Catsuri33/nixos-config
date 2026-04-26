{ config, pkgs, ... }:

{
  programs.wofi = {
    enable = true;

    settings = {
      width = 600;
      height = 400;
      location = "center";
      show = "drun";
      prompt = "Rechercher...";
      filter_rate = 100;
      allow_markup = true;
      no_actions = true;
      halign = "fill";
      orientation = "vertical";
      content_halign = "fill";
      insensitive = true;
      allow_images = true;
      image_size = 32;
      gtk_dark = true;
    };

    style = ''
      * {
        font-family: "JetBrainsMono Nerd Font";
        font-size: 14px;
      }

      window {
        background-color: #1e1e2e;
        border: 2px solid #89b4fa;
        border-radius: 12px;
      }

      #input {
        background-color: #313244;
        color: #cdd6f4;
        border: none;
        border-radius: 8px;
        padding: 8px 12px;
        margin: 10px;
      }

      #input:focus {
        border: 1px solid #cba6f7;
      }

      #inner-box {
        background-color: transparent;
        margin: 0 10px 10px 10px;
      }

      #outer-box {
        background-color: transparent;
      }

      #scroll {
        background-color: transparent;
      }

      #text {
        color: #cdd6f4;
        padding: 2px 8px;
      }

      #entry {
        background-color: transparent;
        border-radius: 8px;
        padding: 4px;
        margin: 2px 0;
      }

      #entry:selected {
        background: linear-gradient(45deg, #89b4fa33, #cba6f733);
        border: 1px solid #89b4fa;
      }

      #entry:selected #text {
        color: #cdd6f4;
      }
    '';
  };
}
